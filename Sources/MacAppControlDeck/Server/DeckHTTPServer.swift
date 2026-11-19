import Foundation
import Network

func debugLog(_ message: String) {
    var handle = FileHandle.standardError
    if ProcessInfo.processInfo.environment["DECK_DEBUG"] != nil {
        handle.write(Data("[deck-debug] \(message)\n".utf8))
    }
}

struct ServerStatus {
    var running: Bool
    var port: UInt16
    var errorText: String?
}

final class DeckHTTPServer {
    private var listener: NWListener?
    private let router: APIRouter
    private let queue = DispatchQueue(label: "deck.httpserver")
    private(set) var port: UInt16 = 0
    private var activeReaders: [ObjectIdentifier: HTTPRequestReader] = [:]

    init(router: APIRouter) {
        self.router = router
    }

    func start(preferredPort: UInt16 = 47615) -> ServerStatus {
        stop()
        for port in stride(from: Int(preferredPort), to: Int(preferredPort) + 20, by: 1) {
            do {
                let status = try startListener(on: UInt16(port))
                if status.running { return status }
            } catch {
                continue
            }
        }
        return ServerStatus(running: false, port: 0, errorText: "未能找到可用端口")
    }

    private func startListener(on port: UInt16) throws -> ServerStatus {
        let tcp = NWProtocolTCP.Options()
        tcp.noDelay = true
        let parameters = NWParameters(tls: nil, tcp: tcp)
        parameters.allowLocalEndpointReuse = true

        let listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port)!)
        listener.stateUpdateHandler = { [weak self] state in
            if case .failed(let error) = state {
                print("[deck] 监听失败: \(error)")
                self?.listener?.cancel()
            }
        }
        listener.newConnectionHandler = { [weak self] connection in
            self?.accept(connection)
        }
        listener.start(queue: queue)
        self.listener = listener
        self.port = port
        return ServerStatus(running: true, port: port, errorText: nil)
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    private func accept(_ connection: NWConnection) {
        debugLog("连接接受: \(connection.endpoint)")
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                debugLog("连接就绪，开始读取")
                self?.beginReading(connection)
            case .failed(let error):
                debugLog("连接失败: \(error)")
                connection.cancel()
            default:
                break
            }
        }
        connection.start(queue: queue)
    }

    private func beginReading(_ connection: NWConnection) {
        let key = ObjectIdentifier(connection)
        let reader = HTTPRequestReader(connection: connection, router: router)
        queue.async { [weak self] in
            self?.activeReaders[key] = reader
        }
        reader.begin { [weak self] conn in
            conn.cancel()
            self?.queue.async { [weak self] in
                self?.activeReaders.removeValue(forKey: ObjectIdentifier(conn))
            }
        }
    }
}

final class HTTPRequestReader {
    private enum Constants {
        static let maxHeaderBytes = 16_384
        static let maxBodyBytes = 65_536
    }

    private let connection: NWConnection
    private let router: APIRouter
    private var buffer = Data()
    private var closeAction: ((NWConnection) -> Void)?

    init(connection: NWConnection, router: APIRouter) {
        self.connection = connection
        self.router = router
    }

    func begin(closeAction: @escaping (NWConnection) -> Void) {
        self.closeAction = closeAction
        read()
    }

    private func read() {
        debugLog("receive 调用前")
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, isComplete, error in
            debugLog("receive 回调: data=\(data?.count ?? -1) isComplete=\(isComplete) error=\(error.map(String.init(describing:)) ?? "nil")")
            guard let self else { return }
            if let error {
                print("[deck] 连接错误: \(error)")
                self.close()
                return
            }
            if let data {
                self.buffer.append(data)
                debugLog("收到 \(data.count) 字节, state=\(self.connection.state)")
            }
            if self.buffer.count > Constants.maxHeaderBytes + Constants.maxBodyBytes {
                self.respond(HTTPResponse.error("payload-too-large", message: "请求过大", status: 413))
                return
            }
            if let request = self.parse() {
                debugLog("解析成功: \(request.method) \(request.path)")
                Task {
                    debugLog("Task 开始: \(request.path)")
                    let response = await self.router.handle(request)
                    debugLog("handle 返回 \(response.status)")
                    self.respond(response)
                }
            } else if isComplete && data == nil || self.buffer.isEmpty && isComplete {
                self.close()
            } else {
                self.read()
            }
        }
    }

    private func parse() -> HTTPRequest? {
        guard let headerEnd = buffer.range(of: Data("\r\n\r\n".utf8)) else { return nil }
        let headerData = buffer[buffer.startIndex..<headerEnd.lowerBound]
        guard let headerText = String(data: headerData, encoding: .utf8) else {
            close()
            return nil
        }
        var lines = headerText.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { close(); return nil }
        let parts = requestLine.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        guard parts.count >= 2 else {
            respond(HTTPResponse.error("bad-request", message: "非法请求", status: 400))
            return nil
        }
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let sep = line.firstIndex(of: ":") else { continue }
            let key = String(line[..<sep]).trimmingCharacters(in: .whitespaces)
            let value = String(line[line.index(after: sep)...]).trimmingCharacters(in: .whitespaces)
            headers[key] = value
        }
        let contentLength = Int(headers["Content-Length"] ?? headers["content-length"] ?? "0") ?? 0
        let bodyStart = buffer.index(after: headerEnd.upperBound - 1)
        let available = buffer.distance(from: bodyStart, to: buffer.endIndex)
        guard available >= contentLength, contentLength <= Constants.maxBodyBytes else {
            if contentLength > Constants.maxBodyBytes {
                respond(HTTPResponse.error("payload-too-large", message: "请求体过大", status: 413))
                return nil
            }
            return nil
        }
        lines.removeAll()
        let body = buffer.subdata(in: bodyStart..<buffer.index(bodyStart, offsetBy: contentLength))
        let request = HTTPRequest(method: parts[0].uppercased(),
                                  path: parts[1],
                                  headers: headers,
                                  body: body)
        buffer.removeAll()
        return request
    }

    private func respond(_ response: HTTPResponse) {
        debugLog("响应 \(response.status)")
        var head = "HTTP/1.1 \(response.status) \(HTTPResponse.statusText(response.status))\r\n"
        head += "Content-Type: \(response.contentType)\r\n"
        head += "Content-Length: \(response.body.count)\r\n"
        head += "Connection: close\r\n\r\n"
        var data = Data(head.utf8)
        data.append(response.body)
        connection.send(content: data, completion: .contentProcessed { [weak self] _ in
            self?.close()
        })
    }

    private func close() {
        connection.cancel()
        closeAction?(connection)
    }
}

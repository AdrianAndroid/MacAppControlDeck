import Foundation

enum LANAddress {
    struct Candidate {
        var interface: String
        var address: String
        var isLinkLocal: Bool
    }

    /// 收集所有可用于局域网访问的 IPv4 地址（跳过回环与未启用接口）。
    /// 说明：Mac mini 等机型的以太网是 en0、Wi-Fi 是 en1，不能只看 en0；
    /// 169.254.x.x 是链路本地地址，手机通过 Wi-Fi 无法访问，必须排到最低优先级。
    static func candidates() -> [Candidate] {
        var results: [Candidate] = []
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return [] }
        defer { freeifaddrs(ifaddr) }

        var ptr = ifaddr
        while let current = ptr {
            defer { ptr = current.pointee.ifa_next }
            let flags = Int32(current.pointee.ifa_flags)
            guard flags & IFF_UP != 0, flags & IFF_LOOPBACK == 0 else { continue }
            guard let sa = current.pointee.ifa_addr,
                  sa.pointee.sa_family == sa_family_t(AF_INET) else { continue }
            let name = String(cString: current.pointee.ifa_name)
            guard name.hasPrefix("en") || name.hasPrefix("bridge") else { continue }
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            guard getnameinfo(sa, socklen_t(sa.pointee.sa_len), &host, socklen_t(host.count),
                              nil, 0, NI_NUMERICHOST) == 0 else { continue }
            let text = String(cString: host)
            guard !text.isEmpty else { continue }
            results.append(Candidate(interface: name,
                                     address: text,
                                     isLinkLocal: text.hasPrefix("169.254.")))
        }

        func priority(_ candidate: Candidate) -> Int {
            if candidate.isLinkLocal { return 90 }
            switch candidate.interface {
            case "en0": return 0        // 有线以太网优先
            case "en1": return 1        // Wi-Fi
            default:
                if candidate.interface.hasPrefix("en") { return 10 }
                return 20               // bridge 等
            }
        }
        return results.sorted { priority($0) < priority($1) }
    }

    /// 面板地址用的首选 IPv4：优先真实可路由地址，链路本地地址仅作兜底。
    static func localIPv4() -> String? {
        candidates().first?.address
    }

    /// Host 白名单：所有本机局域网地址（含链路本地），用于识别"访问的是本机"。
    static func localIPv4s() -> [String] {
        var seen = Set<String>()
        return candidates().map(\.address).filter { seen.insert($0).inserted }
    }

    static func panelURL(port: UInt16) -> URL? {
        guard let ip = localIPv4() else { return nil }
        return URL(string: "http://\(ip):\(port)/panel/")
    }

    /// 副屏地址：与面板同主机端口，只读页面，免配对。
    static func screenURL(port: UInt16) -> URL? {
        guard let ip = localIPv4() else { return nil }
        return URL(string: "http://\(ip):\(port)/screen/")
    }
}

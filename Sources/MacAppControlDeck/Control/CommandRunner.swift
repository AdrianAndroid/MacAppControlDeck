import Foundation

struct CommandRunResult {
    var ok: Bool
    var message: String
}

enum CommandRunner {
    /// 执行应用内置 CLI（白名单由 Mac 端配置决定，参数只来自本机配置）。
    static func run(appPath: String, arguments: [String]) -> CommandRunResult {
        guard let bundle = Bundle(path: appPath), let executable = bundle.executableURL else {
            return CommandRunResult(ok: false, message: "找不到应用的可执行文件")
        }
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return CommandRunResult(ok: false, message: "命令执行失败：\(error.localizedDescription)")
        }
        let deadline = Date().addingTimeInterval(3)
        while process.isRunning && Date() < deadline {
            usleep(50_000)
        }
        if process.isRunning { process.terminate() }
        return CommandRunResult(ok: process.terminationStatus == 0,
                                message: process.terminationStatus == 0 ? "已执行命令" : "命令返回错误")
    }
}

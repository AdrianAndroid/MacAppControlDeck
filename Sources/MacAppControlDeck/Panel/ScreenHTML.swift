import Foundation

/// 只读副屏页面：模拟时钟 + 当月月历。
/// 页面不包含 token、不调用任何 /api/* 接口，拿到地址也只能看时间与日期。
/// HTML 正文放在 Panel/Screen/index.html 资源中：改页面不再触发 Swift module 全量重编译。
enum ScreenHTML {
    static let version = "2026-11-27.8"

    static let content: String = {
        let candidates = [
            Bundle.module.url(forResource: "index", withExtension: "html", subdirectory: "Screen"),
            Bundle.module.url(forResource: "index", withExtension: "html"),
            Bundle.module.resourceURL?.appendingPathComponent("Screen/index.html")
        ]
        guard let url = candidates.compactMap({ $0 }).first,
              let html = try? String(contentsOf: url, encoding: .utf8) else {
            return ""
        }
        return html.replacingOccurrences(of: "%%SCREEN_VERSION%%", with: version)
    }()
}

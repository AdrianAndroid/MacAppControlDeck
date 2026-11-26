import Foundation

/// 只读副屏页面：模拟时钟 + 当月月历。
/// 页面不包含 token、不调用任何 /api/* 接口，拿到地址也只能看时间与日期。
/// HTML 正文放在 Panel/Screen/index.html 资源中：改页面不再触发 Swift module 全量重编译。
enum ScreenHTML {
    static let version = "2026-11-27.14"

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

    /// 主天气图标资源（Meteocons Monochrome 动画 SVG）。
    /// 只允许小写字母 / 数字 / 连字符，避免路径穿越。
    static func iconData(named name: String) -> Data? {
        guard name.range(of: "^[a-z0-9-]{1,64}$", options: .regularExpression) != nil else {
            return nil
        }
        let candidates = [
            Bundle.module.url(forResource: name, withExtension: "svg", subdirectory: "Screen/icons"),
            Bundle.module.url(forResource: "icons/\(name)", withExtension: "svg"),
            Bundle.module.resourceURL?.appendingPathComponent("Screen/icons/\(name).svg")
        ]
        guard let url = candidates.compactMap({ $0 }).first else { return nil }
        return try? Data(contentsOf: url)
    }
}

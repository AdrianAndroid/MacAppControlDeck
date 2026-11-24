import Foundation
import MacShotKit

/// 内置操作：由本程序自身实现的能力（截图、OCR 等），不经过外部应用或命令行。
enum BuiltinActions {
    struct Preset: Identifiable, Equatable {
        var id: String
        var name: String
        var symbol: String
    }

    static let all: [Preset] = [
        Preset(id: "settings.open", name: "打开设置", symbol: "⚙"),
        Preset(id: "hotkeys.open", name: "打开快捷键设置", symbol: "⌨"),
        Preset(id: "capture.area", name: "截图（区域）", symbol: "⛶"),
        Preset(id: "capture.full", name: "截全屏", symbol: "▣"),
        Preset(id: "capture.window", name: "截窗口", symbol: "⬚"),
        Preset(id: "capture.scroll", name: "滚动截图", symbol: "⇕"),
        Preset(id: "capture.ocr", name: "OCR（区域）", symbol: "⌖"),
        Preset(id: "sketch.open", name: "打开 UI 草图", symbol: "✎"),
        Preset(id: "calendar.open", name: "打开万年历", symbol: "▦"),
        Preset(id: "screen.open", name: "打开副屏", symbol: "🖥"),
        Preset(id: "pet.open", name: "打开桌面宠物", symbol: "🐾"),
        Preset(id: "update.check", name: "检查更新", symbol: "↑"),
        Preset(id: "systemTool.open", name: "打开 PureMac", symbol: "🧹")
    ]

    static func preset(for id: String) -> Preset? {
        all.first { $0.id == id }
    }

    static func symbol(for id: String?) -> String {
        guard let id, let preset = preset(for: id) else { return "▶" }
        return preset.symbol
    }

    @discardableResult
    static func run(_ action: String) -> (ok: Bool, message: String) {
        guard all.contains(where: { $0.id == action }) else {
            return (false, "未知的内置操作")
        }
        DispatchQueue.main.async {
            switch action {
            case "settings.open": MenuBarController.shared.openSettings()
            case "hotkeys.open": MenuBarController.shared.openSettings(tab: .hotkeys)
            case "capture.area": MacShotController.shared.captureArea()
            case "capture.full": MacShotController.shared.captureFullScreen()
            case "capture.window": MacShotController.shared.captureWindow()
            case "capture.scroll": MacShotController.shared.scrollCapture()
            case "capture.ocr": MacShotController.shared.quickOCRArea()
            case "sketch.open": SketchModule.shared.openBoard()
            case "calendar.open": CalendarModule.shared.open()
            case "screen.open": DeckState.shared.openScreenInBrowser()
            case "pet.open": PetModule.shared.open()
            case "update.check": UpdateController.shared.checkForUpdates()
            case "systemTool.open": SystemToolModule.shared.open()
            default: break
            }
        }
        return (true, "已触发内置操作")
    }
}

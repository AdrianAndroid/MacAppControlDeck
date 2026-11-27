import AppKit
import MacShotKit

/// 状态栏第五个条目：一个区域截图图标，点一下直接进入框选截图。
/// 截图能力本身属于 `capture` 模块，这里只提供快捷入口，不持有窗口或状态。
@MainActor
final class CaptureStatusBarEntry: StatusBarEntry {
    let id = "capture.region"
    let moduleID = CaptureModule.id
    let groupID = CaptureModule.id
    let order = 4
    let title = "区域截图"
    let subtitle = "独立状态项 · 点击立即框选截图"
    let defaultVisible = true

    private let capture: @MainActor () -> Void

    init(capture: (@MainActor () -> Void)? = nil) {
        self.capture = capture ?? { MacShotController.shared.captureArea() }
    }

    var isAvailable: Bool { ModuleRegistry.shared.isEnabled(moduleID) }

    func makeView() -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 22, height: 22))
        view.toolTip = "区域截图"
        view.translatesAutoresizingMaskIntoConstraints = false

        let imageView = NSImageView(frame: NSRect(x: 2, y: 2, width: 18, height: 18))
        imageView.image = NSImage(systemSymbolName: "rectangle.dashed",
                                  accessibilityDescription: "区域截图")
        imageView.symbolConfiguration = .init(pointSize: 15, weight: .regular)
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 18),
            imageView.heightAnchor.constraint(equalToConstant: 18)
        ])
        return view
    }

    func activate(from view: NSView) {
        guard isAvailable else { return }
        capture()
    }
}

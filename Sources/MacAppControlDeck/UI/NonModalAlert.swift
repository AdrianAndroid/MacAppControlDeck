import AppKit

/// 非模态提示窗：不用 `runModal()`，避免应用进入模态会话后菜单栏与全局快捷键全部失效
/// （典型症状：提示出现时点菜单栏没反应、F1 也截不了图）。
/// 窗口浮在普通窗口之上，但仍然可以被截图；点「好」或回车即关闭。
@MainActor
final class NonModalAlert: NSObject {
    static let shared = NonModalAlert()

    private var alert: NSAlert?

    func show(title: String, message: String, style: NSAlert.Style = .warning) {
        dismiss()

        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = style
        alert.addButton(withTitle: "好")

        // 按钮自己关窗：NSAlert 的默认按钮动作是结束模态会话，这里没有模态会话。
        for button in alert.buttons {
            button.target = self
            button.action = #selector(dismiss)
        }

        let window = alert.window
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.center()
        self.alert = alert
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func dismiss() {
        alert?.window.orderOut(nil)
        alert = nil
    }
}

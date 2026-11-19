import AppKit
import SwiftUI

final class CaptureEditorWindowController {
    static let shared = CaptureEditorWindowController()

    private var window: NSWindow?
    private var model: CaptureEditorModel?

    func show(image: CGImage) {
        close()
        let model = CaptureEditorModel(image: image)
        self.model = model

        let root = CaptureEditorView(
            model: model,
            onSave: { image in
                MacShotController.shared.saveEditedImage(image)
            },
            onCopy: { image in
                CaptureExporter.copyToPasteboard(image)
                MacShotController.shared.showToast("已复制到剪贴板")
            },
            onPin: { image in
                PinWindowController.shared.pin(image)
            },
            onOCR: { image in
                OCRResultController.shared.recognize(image)
            },
            onClose: { [weak self] in
                self?.close()
            }
        )

        let imageSize = CGSize(width: image.width, height: image.height)
        let contentSize = CGSize(width: min(max(imageSize.width + 40, 760), 1500),
                                 height: min(max(imageSize.height + 150, 520), 1000))
        let hosting = NSHostingView(rootView: root)
        let window = EditorWindow(contentRect: CGRect(origin: .zero, size: contentSize),
                                  styleMask: [.borderless, .resizable],
                                  backing: .buffered, defer: false)
        window.title = "截图编辑"
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = .normal
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.contentView = hosting
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.cornerRadius = 12
        window.contentView?.layer?.masksToBounds = true
        window.isMovableByWindowBackground = false
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 680, height: 420)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }

    func close() {
        window?.orderOut(nil)
        window?.close()
        window = nil
        model = nil
    }
}

private final class EditorWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

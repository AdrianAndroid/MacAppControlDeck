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
        let screenFrame = NSScreen.main?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        let minW: CGFloat = 800
        let minH: CGFloat = 400
        let maxW = screenFrame.width * 0.9
        let maxH = screenFrame.height * 0.9
        // DetachedEditorWindowController: chromeW = 46 + 60, chromeH = 32 + 44 + 40 + 40.
        let winW = min(maxW, max(minW, imageSize.width + 106))
        let winH = min(maxH, max(minH, imageSize.height + 156))
        let hosting = NSHostingView(rootView: root)
        let window = EditorWindow(contentRect: CGRect(x: screenFrame.midX - winW / 2,
                                                      y: screenFrame.midY - winH / 2,
                                                      width: winW, height: winH),
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
        window.contentView?.layer?.cornerRadius = 10
        window.contentView?.layer?.masksToBounds = true
        window.isMovableByWindowBackground = false
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: minW, height: minH)
        window.maxSize = NSSize(width: screenFrame.width, height: screenFrame.height)
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

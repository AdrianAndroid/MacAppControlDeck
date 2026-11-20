import AppKit
import SwiftUI

final class CaptureEditorWindowController {
    static let shared = CaptureEditorWindowController()

    private var window: NSWindow?
    private var model: CaptureEditorModel?
    private var keyMonitor: Any?
    private var hasOutput = false

    func show(image: CGImage, annotations: [CaptureAnnotation] = []) {
        close(force: true)
        hasOutput = false
        let model = CaptureEditorModel(image: image, annotations: annotations)
        self.model = model

        let root = CaptureEditorView(
            model: model,
            onSave: { image in
                MacShotController.shared.saveEditedImage(image,
                                                        base: model.previewBaseImage(),
                                                        annotations: model.annotations)
                self.hasOutput = true
            },
            onCopy: { image in
                CaptureExporter.copyToPasteboard(image)
                MacShotController.shared.showToast("已复制到剪贴板")
                self.hasOutput = true
            },
            onPin: { image in
                PinWindowController.shared.pin(image)
            },
            onOCR: { image in
                OCRResultController.shared.recognize(image)
            },
            onQR: { image in
                QRResultController.shared.detect(image)
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

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let model = self.model, self.window?.isKeyWindow == true else { return event }
            // Let text fields keep their own editing keys.
            if let responder = self.window?.firstResponder, responder is NSTextView { return event }
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let chars = event.charactersIgnoringModifiers?.lowercased() ?? ""
            if mods.contains(.command) {
                switch chars {
                case "v":
                    if let cg = Self.pasteboardImage() {
                        model.addImage(cg)
                        MacShotController.shared.showToast("已添加剪贴板图片")
                    }
                    return nil
                case "c":
                    if let image = model.render() {
                        CaptureExporter.copyToPasteboard(image)
                        MacShotController.shared.showToast("已复制到剪贴板")
                    }
                    return nil
                case "s":
                    if let image = model.render() {
                        MacShotController.shared.saveEditedImage(image)
                    }
                    return nil
                case "z":
                    if mods.contains(.shift) { model.redo() } else { model.undo() }
                    return nil
                case "0":
                    NotificationCenter.default.post(name: .captureEditorResetZoom, object: nil)
                    return nil
                case "=", "+":
                    NotificationCenter.default.post(name: .captureEditorZoomIn, object: nil)
                    return nil
                case "-":
                    NotificationCenter.default.post(name: .captureEditorZoomOut, object: nil)
                    return nil
                default:
                    return event
                }
            }
            if let tool = Self.tool(for: chars) {
                model.tool = tool
                return nil
            }
            let nudge: CGFloat = mods.contains(.shift) ? 10 : 1
            switch event.keyCode {
            case 123: model.nudgeSelected(dx: -nudge, dy: 0); return nil
            case 124: model.nudgeSelected(dx: nudge, dy: 0); return nil
            case 125: model.nudgeSelected(dx: 0, dy: nudge); return nil
            case 126: model.nudgeSelected(dx: 0, dy: -nudge); return nil
            default: break
            }
            if event.keyCode == 51 || event.keyCode == 117 {
                model.deleteSelected()
                return nil
            }
            if event.keyCode == 53 {
                self.close()
                return nil
            }
            return event
        }
    }

    func close(force: Bool = false) {
        if !force, let model, model.isDirty, !hasOutput {
            let alert = NSAlert()
            alert.messageText = "还有未保存的编辑"
            alert.informativeText = "关闭前要保存这张截图吗？"
            alert.addButton(withTitle: "保存并关闭")
            alert.addButton(withTitle: "直接关闭")
            alert.addButton(withTitle: "取消")
            switch alert.runModal() {
            case .alertFirstButtonReturn:
                if let image = model.render() {
                    MacShotController.shared.saveEditedImage(image,
                                                            base: model.previewBaseImage(),
                                                            annotations: model.annotations)
                }
            case .alertSecondButtonReturn:
                break
            default:
                return
            }
        }
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
        window?.orderOut(nil)
        window?.close()
        window = nil
        model = nil
    }
}

extension CaptureEditorWindowController {
    /// 编辑器单键工具快捷键（对应上游 ToolShortcutManager 的默认映射）。
    static func tool(for key: String) -> CaptureTool? {
        switch key {
        case "v": return .select
        case "r": return .rectangle
        case "e": return .ellipse
        case "l": return .line
        case "a": return .arrow
        case "p": return .pen
        case "m": return .marker
        case "t": return .text
        case "n": return .number
        case "x": return .pixelate
        case "b": return .blur
        case "h": return .highlight
        case "d": return .measure
        case "z": return .loupe
        case "g": return .stamp
        case "i": return .image
        case "c": return .crop
        default: return nil
        }
    }

    static func pasteboardImage() -> CGImage? {
        let pb = NSPasteboard.general
        if let data = pb.data(forType: .png),
           let rep = NSBitmapImageRep(data: data), let cg = rep.cgImage { return cg }
        if let objects = pb.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage],
           let image = objects.first {
            var rect = CGRect(origin: .zero, size: image.size)
            return image.cgImage(forProposedRect: &rect, context: nil, hints: nil)
        }
        return ClipboardPinService.renderedClipboardContent()
    }
}

private final class EditorWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

extension Notification.Name {
    static let captureEditorResetZoom = Notification.Name("captureEditorResetZoom")
    static let captureEditorZoomIn = Notification.Name("captureEditorZoomIn")
    static let captureEditorZoomOut = Notification.Name("captureEditorZoomOut")
}

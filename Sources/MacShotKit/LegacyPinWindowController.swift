import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Port of macshot/UI/Windows/LegacyPinWindowController.swift.
/// A pin is a borderless floating panel. It shows no chrome until hovered:
/// hover reveals Edit + Close, and right-click exposes Copy / Save As / Close.
@MainActor final class LegacyPinWindowController {
    static let shared = LegacyPinWindowController()

    private var pins: [NSPanel] = []
    private var escMonitor: Any?
    private var localEscMonitor: Any?

    /// `at` 不为空时，贴图窗口精确落在该屏幕区域（原地贴图，不偏移）。
    func pin(_ image: CGImage, at frame: CGRect? = nil) {
        let imageSize = CGSize(width: image.width, height: image.height)
        let maxSize = CGSize(width: 720, height: 520)
        let scale = min(1, min(maxSize.width / imageSize.width,
                               maxSize.height / imageSize.height))
        let displaySize = frame.map { CGSize(width: $0.width, height: $0.height) }
            ?? CGSize(width: imageSize.width * scale, height: imageSize.height * scale)

        let window = NSPanel(contentRect: CGRect(origin: .zero, size: displaySize),
                             styleMask: [.borderless, .nonactivatingPanel],
                             backing: .buffered, defer: false)
        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.hidesOnDeactivate = false
        window.becomesKeyOnlyIfNeeded = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false
        window.isMovableByWindowBackground = true

        let zoom = PinZoomModel(baseSize: displaySize)
        let view = PinImageView(
            image: image,
            zoom: zoom,
            onEdit: { [weak self, weak window] in
                guard let window else { return }
                self?.edit(image, window: window)
            },
            onCopy: {
                CaptureExporter.copyToPasteboard(image)
            },
            onSaveAs: { [weak self, weak window] in
                guard let window else { return }
                self?.saveAs(image, window: window)
            },
            onClose: { [weak self, weak window] in
                guard let window else { return }
                self?.close(window)
            })
        let hosting = PinHostingView(rootView: view)
        hosting.zoom = zoom
        hosting.onClose = { [weak self, weak window] in
            guard let window else { return }
            self?.close(window)
        }
        zoom.onResize = { [weak window] size in
            guard let window else { return }
            let old = window.frame
            let newSize = NSSize(width: max(size.width, 40), height: max(size.height, 40))
            var frame = window.frame
            frame.origin.x = old.midX - newSize.width / 2
            frame.origin.y = old.midY - newSize.height / 2
            frame.size = newSize
            window.setFrame(frame, display: true)
        }
        window.contentView = hosting

        if let frame {
            window.setFrame(frame, display: true)
            self.pins.append(window)
            window.orderFrontRegardless()
            updateEscMonitor()
            return
        }

        let mouse = NSEvent.mouseLocation
        let visible = (NSScreen.main?.visibleFrame ?? .zero)
        // Place new pins beside the cursor, cascading down-left so several
        // pinned screenshots stay reachable and do not cover the pin button.
        let step = CGFloat(pins.count % 8) * 26
        let origin = CGPoint(x: min(max(mouse.x - displaySize.width - 20 - step, visible.minX + 20),
                                    visible.maxX - displaySize.width - 20),
                             y: min(max(mouse.y - displaySize.height * 0.35 - step, visible.minY + 20),
                                    visible.maxY - displaySize.height - 20))
        window.setFrameOrigin(origin)
        window.orderFrontRegardless()
        pins.append(window)
        updateEscMonitor()
    }

    private func close(_ window: NSWindow) {
        pins.removeAll { $0 === window }
        window.orderOut(nil)
        window.close()
        updateEscMonitor()
    }

    /// 钉图是 nonactivating 面板，未点击时收不到 Esc。这里加全局/本地监听：
    /// 鼠标停在钉图上按 Esc、或钉图已是 key window 时按 Esc 都能关闭，
    /// 不要求先点一下图片（与用户对截图工具的预期一致）。
    private func updateEscMonitor() {
        guard !pins.isEmpty else {
            if let escMonitor { NSEvent.removeMonitor(escMonitor) }
            if let localEscMonitor { NSEvent.removeMonitor(localEscMonitor) }
            escMonitor = nil
            localEscMonitor = nil
            return
        }
        if escMonitor == nil {
            escMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard event.keyCode == 53 else { return }
                DispatchQueue.main.async { self?.closePinForEscape(allowAnyPin: false) }
            }
            localEscMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard event.keyCode == 53 else { return event }
                if self?.closePinForEscape(allowAnyPin: true) == true { return nil }
                return event
            }
        }
    }

    @discardableResult
    private func closePinForEscape(allowAnyPin: Bool) -> Bool {
        let mouse = NSEvent.mouseLocation
        let target = pins.last(where: { $0.frame.contains(mouse) })
            ?? pins.last(where: { $0.isKeyWindow })
            ?? (allowAnyPin ? pins.last : nil)
        guard let target else { return false }
        close(target)
        return true
    }

    private func edit(_ image: CGImage, window: NSWindow) {
        DetachedEditorWindowController.open(image: NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height)))
        close(window)
    }

    private func saveAs(_ image: CGImage, window: NSWindow) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.level = .floating
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        panel.nameFieldStringValue = "Pinned \(formatter.string(from: Date())).png"
        if let dir = FileManager.default.urls(for: .picturesDirectory,
                                              in: .userDomainMask).first {
            panel.directoryURL = dir.appendingPathComponent("MacAppControlDeck")
        }
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            panel.begin { response in
                guard response == .OK, let url = panel.url else { return }
                do {
                    try CaptureExporter.writePNG(image, to: url)
                } catch {
                    NSSound.beep()
                }
            }
        }
    }
}

struct PinImageView: View {
    let image: CGImage
    @ObservedObject var zoom: PinZoomModel
    let onEdit: () -> Void
    let onCopy: () -> Void
    let onSaveAs: () -> Void
    let onClose: () -> Void

    @State private var hovering = false

    var body: some View {
        let size = zoom.displaySize
        ZStack(alignment: .topTrailing) {
            Image(nsImage: NSImage(cgImage: image,
                                   size: NSSize(width: image.width, height: image.height)))
                .resizable()
                .interpolation(.high)
                .frame(width: size.width, height: size.height)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
                .contentShape(Rectangle())
                .onHover { hovering = $0 }

            if hovering {
                HStack(spacing: 4) {
                    overlayButton(symbol: "pencil", help: "编辑", action: onEdit)
                    overlayButton(symbol: "xmark", help: "关闭", action: onClose)
                }
                .padding(6)

                Text(String(format: "%.0f%%", zoom.scale * 100))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .frame(height: 20)
                    .background(Capsule().fill(Color.black.opacity(0.6)))
                    .padding(.top, 38)
                    .padding(.trailing, 8)
                    .onTapGesture { zoom.reset() }
                    .help("点击恢复 100%")
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private func overlayButton(symbol: String, help: String,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.black.opacity(0.6)))
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

final class PinZoomModel: ObservableObject {
    let baseSize: CGSize
    @Published var scale: CGFloat = 1 {
        didSet {
            let clamped = min(max(scale, 0.1), 5)
            if clamped != scale {
                scale = clamped
                return
            }
            onResize?(displaySize)
        }
    }
    var onResize: ((CGSize) -> Void)?

    init(baseSize: CGSize) { self.baseSize = baseSize }
    var displaySize: CGSize {
        CGSize(width: max(baseSize.width * scale, 40),
               height: max(baseSize.height * scale, 40))
    }
    func reset() { scale = 1 }
}

/// AppKit context menu, mirroring macshot's PinView.menu(for:).
/// SwiftUI's `.contextMenu` disabled the Save As item inside a
/// non-activating panel, so the menu is built explicitly here.
final class PinHostingView: NSHostingView<PinImageView> {
    var zoom: PinZoomModel?
    var onCopy: (() -> Void)?
    var onSaveAs: (() -> Void)?
    var onClose: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        // 点击钉图后让它成为 key window，Esc / ⌘Q 才会送到这里。
        window?.makeKey()
        window?.makeFirstResponder(self)
        super.mouseDown(with: event)
    }

    override func cancelOperation(_ sender: Any?) {
        onClose?()
    }

    override func scrollWheel(with event: NSEvent) {
        guard let zoom else { return }
        let delta = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY * 0.008
                                                    : event.scrollingDeltaY * 0.03
        zoom.scale += delta
    }

    override func magnify(with event: NSEvent) {
        guard let zoom else { return }
        zoom.scale += event.magnification
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onClose?()
            return
        }
        super.keyDown(with: event)
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        window?.makeKey()
        let menu = NSMenu()
        menu.autoenablesItems = false
        let copy = NSMenuItem(title: "复制到剪贴板", action: #selector(copyImage), keyEquivalent: "c")
        let save = NSMenuItem(title: "另存为…", action: #selector(saveImage), keyEquivalent: "s")
        let close = NSMenuItem(title: "关闭", action: #selector(closePin), keyEquivalent: "")
        for item in [copy, save, NSMenuItem.separator(), close] {
            item.target = self
            menu.addItem(item)
        }
        return menu
    }

    @objc private func copyImage() { onCopy?() }
    @objc private func saveImage() { onSaveAs?() }
    @objc private func closePin() { onClose?() }
}

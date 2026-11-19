import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Port of macshot/UI/Windows/PinWindowController.swift.
/// A pin is a borderless floating panel. It shows no chrome until hovered:
/// hover reveals Edit + Close, and right-click exposes Copy / Save As / Close.
final class PinWindowController {
    static let shared = PinWindowController()

    private var pins: [NSPanel] = []

    func pin(_ image: CGImage) {
        let imageSize = CGSize(width: image.width, height: image.height)
        let maxSize = CGSize(width: 720, height: 520)
        let scale = min(1, min(maxSize.width / imageSize.width,
                               maxSize.height / imageSize.height))
        let displaySize = CGSize(width: imageSize.width * scale,
                                 height: imageSize.height * scale)

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

        let view = PinImageView(
            image: image,
            displaySize: displaySize,
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
        hosting.onCopy = { CaptureExporter.copyToPasteboard(image) }
        hosting.onSaveAs = { [weak self, weak window] in
            guard let window else { return }
            self?.saveAs(image, window: window)
        }
        hosting.onClose = { [weak self, weak window] in
            guard let window else { return }
            self?.close(window)
        }
        window.contentView = hosting

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
    }

    private func close(_ window: NSWindow) {
        pins.removeAll { $0 === window }
        window.orderOut(nil)
        window.close()
    }

    private func edit(_ image: CGImage, window: NSWindow) {
        CaptureEditorWindowController.shared.show(image: image)
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
    let displaySize: CGSize
    let onEdit: () -> Void
    let onCopy: () -> Void
    let onSaveAs: () -> Void
    let onClose: () -> Void

    @State private var hovering = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(nsImage: NSImage(cgImage: image,
                                   size: NSSize(width: image.width, height: image.height)))
                .resizable()
                .frame(width: displaySize.width, height: displaySize.height)
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
            }
        }
        .frame(width: displaySize.width, height: displaySize.height)
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


/// AppKit context menu, mirroring macshot's PinView.menu(for:).
/// SwiftUI's `.contextMenu` disabled the Save As item inside a
/// non-activating panel, so the menu is built explicitly here.
final class PinHostingView: NSHostingView<PinImageView> {
    var onCopy: (() -> Void)?
    var onSaveAs: (() -> Void)?
    var onClose: (() -> Void)?

    override func menu(for event: NSEvent) -> NSMenu? {
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

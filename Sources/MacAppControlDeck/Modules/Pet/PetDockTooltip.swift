import AppKit
import SwiftUI

/// 桌宠快捷栏的悬停提示：长悬停 0.7 秒后浮在快捷栏上方，移开立即消失。
/// 用独立且 `ignoresMouseEvents` 的浮层，避免盖住桌宠时影响点击与拖动。
@MainActor
final class PetDockTooltip {
    static let shared = PetDockTooltip()

    private var panel: NSPanel?
    private var hosting: NSHostingView<PetDockTooltipView>?
    private var currentText: String?

    func show(text: String, anchorX: CGFloat) {
        guard let dockFrame = PetDockCenter.shared.dockFrame, !text.isEmpty else { return }
        if currentText == text, panel?.isVisible == true { return }
        currentText = text

        guard let panel = ensurePanel() else { return }
        let hosting = ensureHosting(text: text)
        hosting.layoutSubtreeIfNeeded()
        let size = Self.size(for: text)
        let visible = (screen(for: dockFrame)?.visibleFrame ?? dockFrame)
        let frame = Self.frame(anchorX: anchorX, dockFrame: dockFrame, size: size, visibleFrame: visible)

        panel.setFrame(frame, display: true)
        hosting.frame = NSRect(origin: .zero, size: size)
        panel.alphaValue = panel.isVisible ? 1 : 0
        panel.orderFrontRegardless()
        if panel.alphaValue < 1 {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.12
                panel.animator().alphaValue = 1
            }
        }
    }

    func hide() {
        currentText = nil
        panel?.orderOut(nil)
    }

    // MARK: - 计算

    static func size(for text: String) -> NSSize {
        let font = NSFont.systemFont(ofSize: 11, weight: .medium)
        let width = ceil((text as NSString).size(withAttributes: [.font: font]).width) + 17
        let line = ceil(font.ascender - font.descender + font.leading)
        return NSSize(width: min(width, 280), height: line + 8)
    }

    /// 默认贴在快捷栏上方；屏幕顶部放不下时翻到下方，并夹在本屏可见区域内。
    static func frame(anchorX: CGFloat, dockFrame: NSRect, size: NSSize, visibleFrame: NSRect) -> NSRect {
        let margin: CGFloat = 6
        var x = dockFrame.minX + anchorX - size.width / 2
        let minX = visibleFrame.minX + margin
        let maxX = max(minX, visibleFrame.maxX - size.width - margin)
        x = min(max(x, minX), maxX)

        var y = dockFrame.maxY + margin
        if y + size.height > visibleFrame.maxY - margin {
            y = dockFrame.minY - size.height - margin
        }
        let minY = visibleFrame.minY + margin
        let maxY = max(minY, visibleFrame.maxY - size.height - margin)
        y = min(max(y, minY), maxY)
        return NSRect(x: x, y: y, width: size.width, height: size.height)
    }

    private func screen(for frame: NSRect) -> NSScreen? {
        NSScreen.screens.first { $0.frame.intersects(frame) } ?? NSScreen.main
    }

    // MARK: - 窗口

    private func ensurePanel() -> NSPanel? {
        if let panel { return panel }
        let panel = NSPanel(contentRect: .zero,
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered,
                            defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        panel.animationBehavior = .none
        panel.ignoresMouseEvents = true
        if let hosting { panel.contentView = hosting }
        self.panel = panel
        return panel
    }

    private func ensureHosting(text: String) -> NSHostingView<PetDockTooltipView> {
        if let hosting {
            hosting.rootView = PetDockTooltipView(text: text)
            return hosting
        }
        let hosting = NSHostingView(rootView: PetDockTooltipView(text: text))
        hosting.wantsLayer = true
        panel?.contentView = hosting
        self.hosting = hosting
        return hosting
    }
}

struct PetDockTooltipView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.white.opacity(0.95))
            .lineLimit(1)
            .truncationMode(.middle)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.black.opacity(0.78))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
            )
    }
}

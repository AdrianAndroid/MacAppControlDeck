import AppKit
import SwiftUI

/// 桌宠底部快捷栏：单行、宽度等于桌宠窗口，超出部分靠长按拖动横向滚动。
/// 没有箭头、没有页点、没有翻页；图标顺序只由排序规则决定，拖动只移动视口。
struct PetDockView: View {
    let size: PetSize

    @ObservedObject private var settings = PetDockSettings.shared
    @ObservedObject private var stats = PetDockStats.shared
    @ObservedObject private var deck = DeckState.shared

    @State private var orderedIDs: [String] = []
    @State private var offset: CGFloat = 0
    @State private var dragStart: CGFloat = 0
    @State private var scrolling = false
    @State private var hoveredID: String?
    @State private var runningBundleIDs: Set<String> = []
    @State private var reorderWork: DispatchWorkItem?

    private var metrics: PetDockMetrics { PetDockMetrics(size: size, width: 0) }

    private var apps: [ButtonConfig] {
        let byID = Dictionary(uniqueKeysWithValues: deck.appButtons.map { ($0.id, $0) })
        let ordered = orderedIDs.compactMap { byID[$0] }
        let rest = deck.appButtons.filter { !orderedIDs.contains($0.id) }
        return ordered + rest
    }

    var body: some View {
        GeometryReader { geo in
            let spacing = metrics.spacing
            let tile = metrics.tile
            let padding = metrics.paddingX
            let contentWidth = metrics.contentWidth(count: apps.count)
            let maxScroll = max(0, contentWidth - geo.size.width)

            HStack(spacing: spacing) {
                ForEach(apps) { button in
                    tileView(button, tile: tile)
                }
            }
            .padding(.horizontal, padding)
            .frame(width: contentWidth, height: metrics.height, alignment: .leading)
            .offset(x: clampedOffset(maxScroll))
            .frame(width: geo.size.width, height: metrics.height, alignment: .leading)
            .clipped()
            .mask(
                HStack(spacing: 0) {
                    if clampedOffset(maxScroll) < -0.5 {
                        LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .trailing)
                            .frame(width: 16)
                    }
                    Rectangle()
                    if clampedOffset(maxScroll) > -maxScroll + 0.5 {
                        LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                            .frame(width: 16)
                    }
                }
            )
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if abs(value.translation.width) >= 3 { scrolling = true }
                        guard scrolling else { return }
                        if dragStart == 0 { dragStart = offset }
                        offset = dragStart + value.translation.width
                    }
                    .onEnded { value in
                        offset = clampedOffset(maxScroll)
                        dragStart = 0
                        let moved = abs(value.translation.width) >= 3
                        scrolling = false
                        guard !moved else { return }
                        activateAt(localX: value.startLocation.x,
                                   width: geo.size.width,
                                   spacing: spacing, tile: tile, padding: padding)
                    }
            )
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.black.opacity(0.22))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1))
            )
            .onAppear {
                refreshOrder()
                refreshRunning()
                stats.clearLastClickedIfNotRunning()
            }
            .onReceive(Timer.publish(every: 3, on: .main, in: .common).autoconnect()) { _ in
                refreshRunning()
                stats.clearLastClickedIfNotRunning()
            }
        }
        .frame(height: metrics.height)
    }

    // MARK: - 单个图标

    private func tileView(_ button: ButtonConfig, tile: CGFloat) -> some View {
        let isLast = settings.markLastClicked && stats.lastClickedID == button.bundleID
        let running = runningBundleIDs.contains(button.bundleID)
        let radius = tile * 0.24
        let hovered = hoveredID == button.id
        let content = ZStack(alignment: .bottomTrailing) {
                Image(nsImage: deck.icon(for: button))
                    .resizable()
                    .interpolation(.high)
                    .frame(width: tile, height: tile)
                    .shadow(color: .black.opacity(0.28), radius: 2, y: 1)
                if running && settings.showRunningDot {
                    Circle()
                        .fill(Color.green)
                        .overlay(Circle().stroke(Color.black.opacity(0.55), lineWidth: 0.8))
                        .frame(width: 5.5, height: 5.5)
                        .offset(x: 1, y: 1)
                }
            }
            .frame(width: tile, height: tile)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Color.white.opacity(hovered ? 0.12 : 0))
            )
            .scaleEffect(hovered ? 1.06 : 1)
            .animation(.easeOut(duration: 0.15), value: hovered)
            .opacity(isLast ? 0.45 : 1)
            .contentShape(RoundedRectangle(cornerRadius: radius))
        return content
            .help(button.name)
            .onHover { inside in
                hoveredID = inside ? button.id : (hoveredID == button.id ? nil : hoveredID)
                if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
            }
    }

    private func clampedOffset(_ maxScroll: CGFloat) -> CGFloat {
        guard maxScroll > 0 else { return 0 }
        return min(0, max(-maxScroll, offset))
    }

    /// 松手时按横坐标命中一格（内容坐标 = 触点 − 当前偏移），位移 <3px 视为点击。
    private func activateAt(localX: CGFloat, width: CGFloat, spacing: CGFloat, tile: CGFloat, padding: CGFloat) {
        let contentWidth = metrics.contentWidth(count: apps.count)
        let contentX = localX - clampedOffset(max(0, contentWidth - width))
        let step = tile + spacing
        let index = Int(floor((contentX - padding) / step))
        guard index >= 0, index < apps.count else { return }
        let within = contentX - (padding + CGFloat(index) * step)
        guard within >= 0, within <= tile else { return }
        activate(apps[index])
    }

    private func activate(_ button: ButtonConfig) {
        DeckState.shared.perform(button)
        stats.record(bundleID: button.bundleID)
        refreshRunning()
        guard settings.sortMode != .manual else { return }
        reorderWork?.cancel()
        let work = DispatchWorkItem { refreshOrder() }
        reorderWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: work)
    }

    private func refreshOrder() {
        let buttons = deck.appButtons
        let indexOf = Dictionary(uniqueKeysWithValues: buttons.enumerated().map { ($0.element.id, $0.offset) })
        switch settings.sortMode {
        case .manual:
            orderedIDs = buttons.map(\.id)
        case .recent:
            orderedIDs = buttons
                .sorted { lhs, rhs in
                    let l = stats.events[lhs.bundleID]?.last ?? 0
                    let r = stats.events[rhs.bundleID]?.last ?? 0
                    if l == r { return (indexOf[lhs.id] ?? 0) < (indexOf[rhs.id] ?? 0) }
                    return l > r
                }
                .map(\.id)
        case .frequency:
            let now = Date()
            orderedIDs = buttons
                .sorted { lhs, rhs in
                    let l = stats.score(bundleID: lhs.bundleID, settings: settings, now: now)
                    let r = stats.score(bundleID: rhs.bundleID, settings: settings, now: now)
                    if abs(l - r) < 0.0001 { return (indexOf[lhs.id] ?? 0) < (indexOf[rhs.id] ?? 0) }
                    return l > r
                }
                .map(\.id)
        }
    }

    private func refreshRunning() {
        runningBundleIDs = Set(NSWorkspace.shared.runningApplications.compactMap { $0.bundleIdentifier })
    }
}

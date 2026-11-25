import SwiftUI

/// 按钮管理页的两个排序分组：应用组与快捷组，和 ConfigStore.kindRank 保持一致。
enum ButtonGridGroup: String, CaseIterable, Identifiable, Hashable {
    case apps
    case quick

    var id: String { rawValue }

    var title: String {
        switch self {
        case .apps: return "应用"
        case .quick: return "快捷操作"
        }
    }

    func contains(_ button: ButtonConfig) -> Bool {
        switch self {
        case .apps: return button.kind == .app
        case .quick: return button.kind != .app
        }
    }
}

enum ButtonGridEntry: Identifiable {
    case button(ButtonConfig)
    case placeholder

    var id: String {
        switch self {
        case .button(let button): return button.id
        case .placeholder: return "__button-grid-placeholder__"
        }
    }
}

/// 把拖拽指针位置换算成“移除拖动项之后”的插入序号。
/// 返回值可直接传给 DeckState.moveToIndex(_:toIndex:)。
enum ButtonGridReorder {
    static func targetIndex(pointer: CGPoint,
                            frames: [String: CGRect],
                            order: [String]) -> Int {
        let available = order.enumerated().compactMap { index, id -> (Int, CGRect)? in
            guard let frame = frames[id] else { return nil }
            return (index, frame)
        }
        guard !available.isEmpty else { return 0 }

        var bestIndex = 0
        var bestDistance = CGFloat.greatestFiniteMagnitude

        // 每张卡左右各有一个插入点。相邻卡片共享同一个序号，
        // 取距离最近的那个，自然覆盖行首、行尾和换行位置。
        // 只对当前可见卡片计算，长列表滚动后也不会把视口顶部误判成组首。
        for (index, frame) in available {
            let before = CGPoint(x: frame.minX - 6, y: frame.midY)
            let after = CGPoint(x: frame.maxX + 6, y: frame.midY)
            for (candidate, point) in [(index, before), (index + 1, after)] {
                let dx = pointer.x - point.x
                let dy = pointer.y - point.y
                let distance = dx * dx + dy * dy
                if distance < bestDistance {
                    bestDistance = distance
                    bestIndex = candidate
                }
            }
        }

        return min(max(0, bestIndex), order.count)
    }
}

struct ButtonCardFramePreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]

    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

struct ButtonGridPlaceholder: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(
                Color.accentColor.opacity(0.55),
                style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [5, 4])
            )
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.accentColor.opacity(0.06))
            )
            .overlay {
                Image(systemName: "arrow.left.and.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.accentColor.opacity(0.65))
            }
            .frame(maxWidth: .infinity, minHeight: 118, maxHeight: 118)
    }
}

struct ButtonGridCard: View {
    let button: ButtonConfig
    let installed: Bool
    var isSelected = false
    var isArmed = false
    var isGhost = false
    var isBlocked = false
    var isHovered = false

    var body: some View {
        VStack(spacing: 7) {
            icon
                .frame(width: 44, height: 44)

            Text(button.name)
                .font(.system(size: 12, weight: .medium))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(maxWidth: .infinity, minHeight: 30, alignment: .top)

            Text(subtitle)
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(subtitleColor)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 118, maxHeight: 118)
        .background(cardBackground)
        .overlay(cardBorder)
        .overlay {
            if isBlocked {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.red.opacity(0.9), lineWidth: 2)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.red.opacity(0.08))
                    )
            }
        }
        .scaleEffect(isArmed ? 1.03 : 1)
        .shadow(color: .black.opacity(isArmed || isGhost ? 0.22 : 0.06),
                radius: isArmed || isGhost ? 14 : 4,
                y: isArmed || isGhost ? 7 : 2)
        .opacity(isGhost ? 0.94 : 1)
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .animation(.easeOut(duration: 0.14), value: isArmed)
        .animation(.easeOut(duration: 0.12), value: isSelected)
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }

    @ViewBuilder
    private var icon: some View {
        switch button.kind {
        case .app:
            AppIconView(path: button.appPath, size: 42)
        case .shortcut:
            Text(button.displaySymbol ?? "—")
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .frame(maxWidth: 52)
                .padding(.horizontal, 6)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.28))
                )
        case .command:
            Image(systemName: "terminal")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.secondary)
        case .builtin:
            Text(BuiltinActions.symbol(for: button.builtinAction))
                .font(.system(size: 22, weight: .semibold))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
    }

    private var subtitle: String {
        switch button.kind {
        case .app: return installed ? "应用" : "应用缺失"
        case .shortcut: return "快捷操作"
        case .command: return "命令"
        case .builtin: return "内置"
        }
    }

    private var subtitleColor: Color {
        if button.kind == .app && !installed { return .orange }
        return .secondary
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(isSelected
                  ? Color.accentColor.opacity(0.14)
                  : Color(nsColor: .controlBackgroundColor).opacity(isHovered ? 0.98 : 0.86))
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(isSelected ? Color.accentColor : Color(nsColor: .separatorColor).opacity(0.55),
                          lineWidth: isSelected ? 2 : 1)
    }
}

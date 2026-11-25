import AppKit

// 状态栏两行指标视图：被各模块的 StatusBarEntry 复用，避免每个模块各写一套绘制。
/// 状态项中的一列：上行数值 + 下行标签（网速项则为 ↑/↓ 两行速率）。
struct StatusBarMetricColumn {
    let top: String
    let bottom: String
    var topColor: NSColor = .labelColor
    var bottomColor: NSColor = .secondaryLabelColor
    /// 指定后两行共用该字体/字号（网速列用等宽数字字体，上下统一）。nil 时上行数值、下行小标签。
    var font: NSFont?
    /// 指定后列宽固定为该值（网速列用，避免数值位数变化引起整条状态项宽度抖动）。
    var fixedWidth: CGFloat?
}

/// 菜单栏状态项的两行指标视图（上数值、下标签），用自定义绘制避免 NSStatusItem
/// 对多行 attributedTitle 的贴顶裁切；内容居中，支持多列（保留列间竖线能力），跟随系统深浅色。
final class StatusBarMetricView: NSView {
    var columns: [StatusBarMetricColumn] = [] {
        didSet { invalidateIntrinsicContentSize(); needsDisplay = true }
    }

    private let valueFont = NSFont.systemFont(ofSize: 11, weight: .semibold)
    private let labelFont = NSFont.systemFont(ofSize: 8, weight: .regular)
    private let separatorSpacing: CGFloat = 5   // 竖线两侧留白
    private let columnPadding: CGFloat = 3

    /// 网速列：等宽数字字体，上下两行同字号（9pt），避免位数变化抖动、上下字号不一。
    static let netSpeedFont = NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .semibold)
    /// 网速列固定宽度，按最宽模板 "↑ 999.9 M/s" 计算一次，之后恒定。
    static let netSpeedColumnWidth: CGFloat = {
        let w = ("↑ 999.9 M/s" as NSString).size(withAttributes: [.font: netSpeedFont]).width
        return w + 3 * 2 // 与 columnPadding 一致
    }()

    private func fonts(for column: StatusBarMetricColumn) -> (top: NSFont, bottom: NSFont) {
        if let f = column.font { return (f, f) }
        return (valueFont, labelFont)
    }

    private func columnWidth(_ column: StatusBarMetricColumn) -> CGFloat {
        if let fixed = column.fixedWidth { return fixed }
        let fonts = fonts(for: column)
        let topW = (column.top as NSString).size(withAttributes: [.font: fonts.top]).width
        let bottomW = (column.bottom as NSString).size(withAttributes: [.font: fonts.bottom]).width
        return max(topW, bottomW) + columnPadding * 2
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard !columns.isEmpty else { return }

        let widths = columns.map { columnWidth($0) }
        let separatorW: CGFloat = separatorSpacing * 2 + 1
        let totalW = widths.reduce(0, +) + separatorW * CGFloat(max(0, columns.count - 1))
        var x = (bounds.width - totalW) / 2  // 整块居中

        for (index, column) in columns.enumerated() {
            let w = widths[index]
            let fonts = fonts(for: column)
            let topAttrs: [NSAttributedString.Key: Any] = [
                .font: fonts.top, .foregroundColor: column.topColor
            ]
            let bottomAttrs: [NSAttributedString.Key: Any] = [
                .font: fonts.bottom, .foregroundColor: column.bottomColor
            ]
            let topSize = (column.top as NSString).size(withAttributes: topAttrs)
            let bottomSize = (column.bottom as NSString).size(withAttributes: bottomAttrs)

            // draw(at:) 的 y 是文字左下角（NSView 原点在左下）。两行对称落在 22pt 内。
            let topY = bounds.height - topSize.height
            let bottomY: CGFloat = 0
            (column.top as NSString).draw(
                at: NSPoint(x: x + (w - topSize.width) / 2, y: topY),
                withAttributes: topAttrs)
            (column.bottom as NSString).draw(
                at: NSPoint(x: x + (w - bottomSize.width) / 2, y: bottomY),
                withAttributes: bottomAttrs)

            x += w
            if index < columns.count - 1 {
                // 竖线：菜单栏高度内画一条淡色分隔线。
                let lineX = x + separatorSpacing
                NSColor.tertiaryLabelColor.setStroke()
                let line = NSBezierPath()
                line.lineWidth = 1
                line.move(to: NSPoint(x: lineX, y: 3))
                line.line(to: NSPoint(x: lineX, y: bounds.height - 3))
                line.stroke()
                x += separatorW
            }
        }
    }

    override var intrinsicContentSize: NSSize {
        guard !columns.isEmpty else { return NSSize(width: 1, height: 22) }
        let widths = columns.reduce(CGFloat(0)) { $0 + columnWidth($1) }
        let separatorW: CGFloat = separatorSpacing * 2 + 1
        let total = widths + separatorW * CGFloat(max(0, columns.count - 1))
        return NSSize(width: max(total, 34), height: 22)
    }
}


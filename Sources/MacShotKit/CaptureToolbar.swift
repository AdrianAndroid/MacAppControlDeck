import AppKit

/// 移植自 macshot/UI/Toolbar/ToolbarDefinitions.swift 的配色与度量。
enum ToolbarLayout {
    static let accentColor = NSColor(calibratedRed: 0.55, green: 0.30, blue: 0.85, alpha: 1.0)
    static let iconColor = NSColor.white
    static let bgColor = NSColor(white: 0.12, alpha: 1.0)
    static let cornerRadius: CGFloat = 6
    static var appearance: NSAppearance? { NSAppearance(named: .darkAqua) }
}

enum CaptureToolbarAction: Equatable {
    case tool(String)
    case color(NSColor)
    case palette
    case width(CGFloat)
    case lineStyle(String)
    case undo
    case redo
    case copy
    case save
    case pin
    case ocr
    case cancel
}

struct CaptureToolbarButton {
    let action: CaptureToolbarAction
    var sfSymbol: String?
    var text: String?
    var tooltip: String = ""
    var isSelected: Bool = false
    var swatchColor: NSColor?
}

/// 移植自 macshot/UI/Toolbar/ToolbarButtonView.swift（去掉录音电平和主题切换）。
final class CaptureToolbarButtonView: NSView {
    let action: CaptureToolbarAction
    var sfSymbol: String?
    var text: String?
    var isOn: Bool = false { didSet { if oldValue != isOn { cachedIcon = nil; needsDisplay = true } } }
    var swatchColor: NSColor? { didSet { needsDisplay = true } }
    var tooltipText: String = ""

    private var isHovered = false
    private var isPressed = false
    private var trackingArea: NSTrackingArea?
    private var cachedIcon: NSImage?
    private var cachedIconIsOn: Bool?
    private static var iconCache: [String: NSImage] = [:]

    var onClick: ((CaptureToolbarAction) -> Void)?

    static let size: CGFloat = 32
    private static let radius: CGFloat = 6

    init(action: CaptureToolbarAction, sfSymbol: String?, text: String?, tooltip: String) {
        self.action = action
        self.sfSymbol = sfSymbol
        self.text = text
        self.tooltipText = tooltip
        super.init(frame: NSRect(x: 0, y: 0, width: Self.size, height: Self.size))
        toolTip = tooltip
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(with data: CaptureToolbarButton) {
        sfSymbol = data.sfSymbol
        text = data.text
        isOn = data.isSelected
        swatchColor = data.swatchColor
        tooltipText = data.tooltip
        toolTip = data.tooltip
        cachedIcon = nil
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        let bg: NSColor
        if isPressed {
            bg = ToolbarLayout.accentColor.withAlphaComponent(0.6)
        } else if isOn {
            bg = ToolbarLayout.accentColor
        } else if isHovered {
            bg = ToolbarLayout.iconColor.withAlphaComponent(0.12)
        } else {
            bg = .clear
        }
        bg.setFill()
        NSBezierPath(roundedRect: bounds, xRadius: Self.radius, yRadius: Self.radius).fill()

        if let swatch = swatchColor {
            let inset: CGFloat = 6
            let r = bounds.insetBy(dx: inset, dy: inset)
            swatch.setFill()
            NSBezierPath(roundedRect: r, xRadius: 4, yRadius: 4).fill()
            ToolbarLayout.iconColor.withAlphaComponent(0.4).setStroke()
            let border = NSBezierPath(roundedRect: r, xRadius: 4, yRadius: 4)
            border.lineWidth = 0.5
            border.stroke()
            return
        }

        if let text {
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
                .foregroundColor: ToolbarLayout.iconColor,
            ]
            let size = (text as NSString).size(withAttributes: attrs)
            (text as NSString).draw(at: NSPoint(x: bounds.midX - size.width / 2,
                                                y: bounds.midY - size.height / 2),
                                    withAttributes: attrs)
            return
        }

        guard let name = sfSymbol else { return }
        if cachedIcon == nil || cachedIconIsOn != isOn {
            let color = ToolbarLayout.iconColor
            let key = "\(name)|\(isOn)|\(color.description)"
            if let cached = Self.iconCache[key] {
                cachedIcon = cached
            } else {
                let cfg = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
                let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
                    .withSymbolConfiguration(cfg)
                if let image {
                    let tinted = NSImage(size: image.size, flipped: false) { rect in
                        image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
                        color.setFill()
                        rect.fill(using: .sourceAtop)
                        return true
                    }
                    Self.iconCache[key] = tinted
                    cachedIcon = tinted
                }
            }
            cachedIconIsOn = isOn
        }
        if let icon = cachedIcon {
            icon.draw(at: NSPoint(x: bounds.midX - icon.size.width / 2,
                                  y: bounds.midY - icon.size.height / 2),
                      from: .zero, operation: .sourceOver, fraction: 1)
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(rect: bounds,
                                  options: [.mouseEnteredAndExited, .activeAlways],
                                  owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        isPressed = false
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        isPressed = true
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        isPressed = false
        needsDisplay = true
        let p = convert(event.locationInWindow, from: nil)
        if bounds.contains(p) { onClick?(action) }
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .arrow)
    }
}

/// 移植自 macshot/UI/Toolbar/ToolbarStripView.swift。
final class CaptureToolbarStripView: NSView {
    enum Orientation { case horizontal, vertical }

    let orientation: Orientation
    private(set) var buttonViews: [CaptureToolbarButtonView] = []
    var onClick: ((CaptureToolbarAction) -> Void)?

    private let padding: CGFloat = 4
    private let spacing: CGFloat = 2

    init(orientation: Orientation) {
        self.orientation = orientation
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { fatalError() }

    func setButtons(_ buttons: [CaptureToolbarButton]) {
        for view in buttonViews { view.removeFromSuperview() }
        buttonViews.removeAll()
        for data in buttons {
            let view = CaptureToolbarButtonView(action: data.action,
                                                sfSymbol: data.sfSymbol,
                                                text: data.text,
                                                tooltip: data.tooltip)
            view.configure(with: data)
            view.onClick = { [weak self] action in self?.onClick?(action) }
            addSubview(view)
            buttonViews.append(view)
        }
        layoutButtons()
    }

    func updateState(from buttons: [CaptureToolbarButton]) {
        for (index, data) in buttons.enumerated() where index < buttonViews.count {
            buttonViews[index].configure(with: data)
        }
    }

    private func layoutButtons() {
        let btnSize = CaptureToolbarButtonView.size
        let count = CGFloat(buttonViews.count)
        guard count > 0 else {
            frame.size = .zero
            return
        }
        switch orientation {
        case .horizontal:
            let width = count * btnSize + max(0, count - 1) * spacing + padding * 2
            frame.size = NSSize(width: width, height: btnSize + padding * 2)
            for (index, view) in buttonViews.enumerated() {
                view.frame.origin = NSPoint(x: padding + CGFloat(index) * (btnSize + spacing),
                                            y: padding)
            }
        case .vertical:
            let height = count * btnSize + max(0, count - 1) * spacing + padding * 2
            frame.size = NSSize(width: btnSize + padding * 2, height: height)
            for (index, view) in buttonViews.enumerated() {
                view.frame.origin = NSPoint(x: padding,
                                            y: height - padding - btnSize - CGFloat(index) * (btnSize + spacing))
            }
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        ToolbarLayout.bgColor.setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 6, yRadius: 6).fill()
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = convert(point, from: superview)
        guard bounds.contains(local) else { return nil }
        if let result = super.hitTest(point), result !== self { return result }
        return self
    }

    override func mouseDown(with event: NSEvent) {}
    override func mouseUp(with event: NSEvent) {}

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .arrow)
    }
}

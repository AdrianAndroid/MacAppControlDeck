import AppKit
import CoreGraphics

/// 桌宠的纯几何计算：尺寸、位置、点击路径、锚点。
/// 不持有窗口或状态，方便单元测试。
enum PetGeometry {
    static let baseSize = CGSize(width: 288, height: 384)
    /// 官方画布为 612×354；窗口采用 612:372，保留完整键盘所需的上下余量。
    static let bongoBaseSize = CGSize(width: 350, height: 350 * 372 / 612)
    /// KeyCat 上游默认裁剪区为 360×368。
    static let keyCatBaseSize = CGSize(width: 288, height: 288 * 368 / 360)
    static let windowPadding: CGFloat = 4
    static let screenMargin: CGFloat = 24

    static func windowSize(for size: PetSize, bongoCat: Bool = false, keyCat: Bool = false) -> CGSize {
        let base = keyCat ? keyCatBaseSize : (bongoCat ? bongoBaseSize : baseSize)
        return CGSize(
            width: (base.width * size.scale).rounded() + windowPadding * 2,
            height: (base.height * size.scale).rounded() + windowPadding * 2
        )
    }

    static func visualSize(for size: PetSize, bongoCat: Bool = false, keyCat: Bool = false) -> CGSize {
        let base = keyCat ? keyCatBaseSize : (bongoCat ? bongoBaseSize : baseSize)
        return CGSize(
            width: (base.width * size.scale).rounded(),
            height: (base.height * size.scale).rounded()
        )
    }

    static func defaultAnchor(in visibleFrame: CGRect, size: PetSize, bongoCat: Bool = false, keyCat: Bool = false) -> CGPoint {
        let window = windowSize(for: size, bongoCat: bongoCat, keyCat: keyCat)
        return CGPoint(
            x: visibleFrame.maxX - screenMargin - window.width / 2,
            y: visibleFrame.minY + screenMargin
        )
    }

    static func frame(anchor: CGPoint, size: PetSize, bongoCat: Bool = false, keyCat: Bool = false) -> CGRect {
        let window = windowSize(for: size, bongoCat: bongoCat, keyCat: keyCat)
        return CGRect(
            x: anchor.x - window.width / 2,
            y: anchor.y,
            width: window.width,
            height: window.height
        )
    }

    static func clamp(_ frame: CGRect, to visibleFrame: CGRect) -> CGRect {
        var origin = frame.origin
        origin.x = min(max(origin.x, visibleFrame.minX), visibleFrame.maxX - frame.width)
        origin.y = min(max(origin.y, visibleFrame.minY), visibleFrame.maxY - frame.height)
        return CGRect(origin: origin, size: frame.size)
    }

    static func screenID(for screen: NSScreen) -> String {
        let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        return number?.stringValue ?? "main"
    }

    static func normalizedPosition(of frame: CGRect, in visibleFrame: CGRect) -> CGPoint {
        guard visibleFrame.width > 0, visibleFrame.height > 0 else { return CGPoint(x: 0.5, y: 0.1) }
        return CGPoint(
            x: min(max((frame.midX - visibleFrame.minX) / visibleFrame.width, 0), 1),
            y: min(max((frame.minY - visibleFrame.minY) / visibleFrame.height, 0), 1)
        )
    }

    static func frame(normalizedPosition: CGPoint, in visibleFrame: CGRect, size: PetSize, bongoCat: Bool = false, keyCat: Bool = false) -> CGRect {
        let anchor = CGPoint(
            x: visibleFrame.minX + normalizedPosition.x * visibleFrame.width,
            y: visibleFrame.minY + normalizedPosition.y * visibleFrame.height
        )
        return clamp(frame(anchor: anchor, size: size, bongoCat: bongoCat, keyCat: keyCat), to: visibleFrame)
    }

    static func hitPath(for skin: PetSkin, in bounds: CGRect) -> CGPath {
        let path = CGMutablePath()
        for region in skin.hitRegions {
            let rect = region.rect.absolute(in: bounds)
            switch region.shape {
            case .ellipse:
                path.addEllipse(in: rect)
            case .roundedRect:
                let radius = min(12, rect.height / 3)
                path.addRoundedRect(in: rect, cornerWidth: radius, cornerHeight: radius)
            }
        }
        return path
    }

    static func contains(_ point: CGPoint, skin: PetSkin, in bounds: CGRect) -> Bool {
        hitPath(for: skin, in: bounds).contains(point)
    }

    static func part(at point: CGPoint, skin: PetSkin, in bounds: CGRect) -> PetPart {
        let headRect = CGRect(
            x: skin.anchors.head.x - 0.21,
            y: skin.anchors.head.y - 0.15,
            width: 0.42,
            height: 0.32
        ).absolute(in: bounds)
        if headRect.contains(point) { return .head }

        let leftPaw = pawRect(at: skin.anchors.leftPaw, in: bounds)
        if leftPaw.contains(point) { return .leftPaw }

        let rightPaw = pawRect(at: skin.anchors.rightPaw, in: bounds)
        if rightPaw.contains(point) { return .rightPaw }

        let keyboard = CGRect(
            x: skin.anchors.keyboard.x - 0.46,
            y: skin.anchors.keyboard.y - 0.08,
            width: 0.92,
            height: 0.16
        ).absolute(in: bounds)
        if keyboard.contains(point) { return .keyboard }

        let body = CGRect(
            x: skin.anchors.body.x - 0.23,
            y: skin.anchors.body.y - 0.25,
            width: 0.46,
            height: 0.50
        ).absolute(in: bounds)
        if body.contains(point) { return .body }

        return .transparent
    }

    static func point(for anchor: PetPoint, in bounds: CGRect) -> CGPoint {
        CGPoint(x: bounds.minX + anchor.x * bounds.width, y: bounds.minY + anchor.y * bounds.height)
    }

    static func point(for part: PetPart, skin: PetSkin, in bounds: CGRect) -> CGPoint? {
        switch part {
        case .head: return point(for: skin.anchors.head, in: bounds)
        case .leftPaw: return point(for: skin.anchors.leftPaw, in: bounds)
        case .rightPaw: return point(for: skin.anchors.rightPaw, in: bounds)
        case .keyboard: return point(for: skin.anchors.keyboard, in: bounds)
        case .body: return point(for: skin.anchors.body, in: bounds)
        case .transparent: return nil
        }
    }

    private static func pawRect(at anchor: PetPoint, in bounds: CGRect) -> CGRect {
        let center = point(for: anchor, in: bounds)
        let radius = min(bounds.width, bounds.height) * 0.09
        return CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
    }
}

private extension CGRect {
    func absolute(in bounds: CGRect) -> CGRect {
        CGRect(
            x: bounds.minX + minX * bounds.width,
            y: bounds.minY + minY * bounds.height,
            width: width * bounds.width,
            height: height * bounds.height
        )
    }
}

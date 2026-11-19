import AppKit
import CoreGraphics

/// 截图模块内部的坐标换算。全部使用“屏幕全局坐标”，避免多显示器时把
/// AppKit 左下原点、CGWindow 左上原点混在一起。
enum CaptureGeometry {
    /// 主屏顶部为 0 的全局坐标，单位 point。
    static func globalTopLeftPoint(fromScreenPoint point: NSPoint) -> NSPoint {
        let mainHeight = NSScreen.screens.first?.frame.height ?? 0
        return NSPoint(x: point.x, y: mainHeight - point.y)
    }

    /// 某个屏幕内的点，转换为该屏幕截图（左上原点）中的 point。
    static func pointInScreen(_ point: NSPoint, screen: NSScreen) -> NSPoint {
        NSPoint(x: point.x - screen.frame.minX,
                y: screen.frame.maxY - point.y)
    }

    /// 屏幕全局选择框，转换为某块屏幕截图内的矩形（左上原点）。
    static func rectInScreen(_ rect: CGRect, screen: NSScreen) -> CGRect {
        CGRect(x: rect.minX - screen.frame.minX,
               y: screen.frame.maxY - rect.maxY,
               width: rect.width,
               height: rect.height)
    }

    /// 截图内 point 矩形转换为像素矩形。
    static func pixelRect(for rect: CGRect, image: CGImage, screen: NSScreen) -> CGRect {
        let scaleX = CGFloat(image.width) / max(screen.frame.width, 1)
        let scaleY = CGFloat(image.height) / max(screen.frame.height, 1)
        return CGRect(x: rect.minX * scaleX,
                      y: rect.minY * scaleY,
                      width: rect.width * scaleX,
                      height: rect.height * scaleY)
            .integral
            .intersection(CGRect(x: 0, y: 0, width: image.width, height: image.height))
    }

    static func screen(containing point: NSPoint) -> NSScreen? {
        NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main
    }

    static func screen(with displayID: CGDirectDisplayID) -> NSScreen? {
        NSScreen.screens.first {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?
                .uint32Value == displayID
        }
    }

    static func displayID(of screen: NSScreen) -> CGDirectDisplayID? {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
}

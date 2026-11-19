import AppKit
import CoreGraphics

/// 截图引擎：只负责把某个屏幕/区域/窗口抓成 CGImage。
enum ScreenCaptureService {
    static func captureFullScreen() -> CGImage? {
        guard let screen = NSScreen.main else { return nil }
        return capture(screen: screen)
    }

    static func capture(screen: NSScreen) -> CGImage? {
        let context = ScreenCaptureManager.makeImmediateCaptureContext()
        let captures = ScreenCaptureManager.captureAllScreensImmediately(context: context)
        let displayID = CaptureGeometry.displayID(of: screen)
        if let match = captures.first(where: { CaptureGeometry.displayID(of: $0.screen) == displayID }) {
            return match.image
        }
        return captures.first(where: { $0.screen === screen })?.image
    }

    static func capture(area globalRect: CGRect, on screen: NSScreen) -> CGImage? {
        guard let full = capture(screen: screen) else { return nil }
        let local = CaptureGeometry.rectInScreen(globalRect, screen: screen)
        let pixelRect = CaptureGeometry.pixelRect(for: local, image: full, screen: screen)
        guard pixelRect.width >= 1, pixelRect.height >= 1 else { return nil }
        return full.cropping(to: pixelRect)
    }

    static func capture(window: WindowCaptureTarget) -> CGImage? {
        let image = CGWindowListCreateImage(
            .null,
            .optionIncludingWindow,
            window.windowID,
            [.boundsIgnoreFraming, .bestResolution])
        return image
    }

    /// 当前鼠标所在窗口（用于“窗口截图”快捷键/从菜单直接触发时不需要再点一次）。
    static func windowUnderMouse() -> WindowCaptureTarget? {
        guard let list = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID
        ) as? [[String: Any]] else { return nil }
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let topLeftMouse = CaptureGeometry.globalTopLeftPoint(fromScreenPoint: NSEvent.mouseLocation)
        for info in list {
            guard let layer = info[kCGWindowLayer as String] as? NSNumber, layer.intValue == 0,
                  let ownerPID = info[kCGWindowOwnerPID as String] as? NSNumber,
                  ownerPID.int32Value != ownPID,
                  let windowID = info[kCGWindowNumber as String] as? NSNumber,
                  let boundsDict = info[kCGWindowBounds as String] as? [String: Any],
                  let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary),
                  bounds.width >= 60, bounds.height >= 60,
                  bounds.contains(topLeftMouse)
            else { continue }
            let owner = info[kCGWindowOwnerName as String] as? String ?? ""
            let name = info[kCGWindowName as String] as? String ?? ""
            if owner == "Window Server" || owner == "Dock" { continue }
            return WindowCaptureTarget(windowID: CGWindowID(windowID.uint32Value),
                                       ownerName: owner, windowName: name, bounds: bounds)
        }
        return nil
    }
}

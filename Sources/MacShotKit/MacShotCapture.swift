import AppKit
import CoreGraphics

/// MacShotKit 对外暴露的最小截图入口。
/// 目前只开放“主屏全屏截图”；区域/窗口/标注/录屏在后续阶段接入。
public enum MacShotCapture {
    public static func hasScreenRecordingPermission() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    @discardableResult
    public static func requestScreenRecordingPermission() -> Bool {
        CGRequestScreenCaptureAccess()
    }

    /// 同步抓取主屏。调用前应确认屏幕录制权限；返回 nil 表示权限/显示器状态不可用。
    public static func captureMainScreen() -> CGImage? {
        let context = LegacyScreenCaptureManager.makeImmediateCaptureContext()
        let captures = LegacyScreenCaptureManager.captureAllScreensImmediately(context: context)
        if let main = NSScreen.main,
           let match = captures.first(where: { $0.screen === main }) {
            return match.image
        }
        return captures.first?.image
    }
}

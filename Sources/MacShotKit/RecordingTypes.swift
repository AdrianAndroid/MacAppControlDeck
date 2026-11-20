import AppKit
import AVFoundation
import CoreMedia
import CoreVideo
import ScreenCaptureKit
import UniformTypeIdentifiers

public enum RecordingFormat {
    case mp4
    case gif
}

public struct RecordingOptions {
    public var fps: Int
    public var showsCursor: Bool
    public var systemAudio: Bool
    public var microphone: Bool
    public var gifFPS: Int
    public var gifMaxWidth: Int

    public init(fps: Int = 30,
                showsCursor: Bool = true,
                systemAudio: Bool = true,
                microphone: Bool = false,
                gifFPS: Int = 10,
                gifMaxWidth: Int = 900) {
        self.fps = fps
        self.showsCursor = showsCursor
        self.systemAudio = systemAudio
        self.microphone = microphone
        self.gifFPS = gifFPS
        self.gifMaxWidth = gifMaxWidth
    }
}

enum RecordingTarget {
    case screen(NSScreen)
    case area(NSScreen, CGRect)
    case window(WindowCaptureTarget)
}

enum RecordingError: LocalizedError {
    case noDisplay
    case noWindow
    case permission
    case writer
    case noFrames
    case noScreenFrames

    var errorDescription: String? {
        switch self {
        case .noDisplay: return "找不到可录制的显示器"
        case .noWindow: return "找不到可录制的窗口"
        case .permission: return "没有屏幕录制权限"
        case .writer: return "录制文件写入失败"
        case .noScreenFrames: return "没有收到屏幕画面。请在系统设置 → 隐私与安全 → 屏幕录制中删除旧的 MacAppControlDeck 条目，重新添加当前应用并重启后再试。"
        case .noFrames: return "没有采集到画面"
        }
    }
}


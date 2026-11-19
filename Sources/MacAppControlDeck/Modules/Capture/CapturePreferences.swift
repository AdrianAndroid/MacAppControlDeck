import Combine
import Foundation
import UniformTypeIdentifiers

enum CaptureImageFormat: String, CaseIterable, Identifiable {
    case png
    case jpeg
    case heic
    case webp
    case avif

    var id: String { rawValue }

    var title: String {
        switch self {
        case .png: return "PNG"
        case .jpeg: return "JPEG"
        case .heic: return "HEIC"
        case .webp: return "WebP"
        case .avif: return "AVIF"
        }
    }

    var fileExtension: String {
        switch self {
        case .png: return "png"
        case .jpeg: return "jpg"
        case .heic: return "heic"
        case .webp: return "webp"
        case .avif: return "avif"
        }
    }

    var utType: UTType? {
        switch self {
        case .png: return .png
        case .jpeg: return .jpeg
        case .heic: return .heic
        case .webp: return UTType(filenameExtension: "webp")
        case .avif: return UTType(filenameExtension: "avif")
        }
    }
}

/// capture 模块自己的偏好，不读写 remote 模块的任何配置。
final class CapturePreferences: ObservableObject {
    static let shared = CapturePreferences()

    @Published var saveToFile: Bool {
        didSet { defaults.set(saveToFile, forKey: Keys.saveToFile) }
    }
    @Published var copyToClipboard: Bool {
        didSet { defaults.set(copyToClipboard, forKey: Keys.copyToClipboard) }
    }
    @Published var saveDirectory: String {
        didSet { defaults.set(saveDirectory, forKey: Keys.saveDirectory) }
    }
    @Published var recordingDirectory: String {
        didSet { defaults.set(recordingDirectory, forKey: Keys.recordingDirectory) }
    }
    @Published var recordingSystemAudio: Bool {
        didSet { defaults.set(recordingSystemAudio, forKey: Keys.recordingSystemAudio) }
    }
    @Published var recordingCursor: Bool {
        didSet { defaults.set(recordingCursor, forKey: Keys.recordingCursor) }
    }
    @Published var imageFormat: CaptureImageFormat {
        didSet { defaults.set(imageFormat.rawValue, forKey: Keys.imageFormat) }
    }
    @Published var imageQuality: Double {
        didSet { defaults.set(imageQuality, forKey: Keys.imageQuality) }
    }
    @Published var recordingFPS: Int {
        didSet { defaults.set(recordingFPS, forKey: Keys.recordingFPS) }
    }
    @Published var gifFPS: Int {
        didSet { defaults.set(gifFPS, forKey: Keys.gifFPS) }
    }
    @Published var captureDelay: Int {
        didSet { defaults.set(captureDelay, forKey: Keys.captureDelay) }
    }

    private let defaults = UserDefaults.standard
    private enum Keys {
        static let saveToFile = "capture.saveToFile"
        static let copyToClipboard = "capture.copyToClipboard"
        static let saveDirectory = "capture.saveDirectory"
        static let recordingDirectory = "capture.recordingDirectory"
        static let recordingSystemAudio = "capture.recordingSystemAudio"
        static let recordingCursor = "capture.recordingCursor"
        static let imageFormat = "capture.imageFormat"
        static let imageQuality = "capture.imageQuality"
        static let recordingFPS = "capture.recordingFPS"
        static let gifFPS = "capture.gifFPS"
        static let captureDelay = "capture.delay"
    }

    private init() {
        saveToFile = defaults.object(forKey: Keys.saveToFile) as? Bool ?? true
        copyToClipboard = defaults.object(forKey: Keys.copyToClipboard) as? Bool ?? true
        if let stored = defaults.string(forKey: Keys.saveDirectory), !stored.isEmpty {
            saveDirectory = stored
        } else {
            let pictures = FileManager.default.urls(for: .picturesDirectory,
                                                    in: .userDomainMask).first
            saveDirectory = (pictures ?? URL(fileURLWithPath: NSHomeDirectory()))
                .appendingPathComponent("MacAppControlDeck", isDirectory: true)
                .path
        }
        if let stored = defaults.string(forKey: Keys.recordingDirectory), !stored.isEmpty {
            recordingDirectory = stored
        } else {
            let movies = FileManager.default.urls(for: .moviesDirectory,
                                                  in: .userDomainMask).first
            recordingDirectory = (movies ?? URL(fileURLWithPath: NSHomeDirectory()))
                .appendingPathComponent("MacAppControlDeck", isDirectory: true)
                .path
        }
        recordingSystemAudio = defaults.object(forKey: Keys.recordingSystemAudio) as? Bool ?? true
        recordingCursor = defaults.object(forKey: Keys.recordingCursor) as? Bool ?? true
        imageFormat = CaptureImageFormat(rawValue: defaults.string(forKey: Keys.imageFormat) ?? "") ?? .png
        let storedQuality = defaults.object(forKey: Keys.imageQuality) as? Double
        imageQuality = storedQuality ?? 0.9
        let storedFPS = defaults.object(forKey: Keys.recordingFPS) as? Int
        recordingFPS = storedFPS ?? 30
        let storedGIF = defaults.object(forKey: Keys.gifFPS) as? Int
        gifFPS = storedGIF ?? 10
        captureDelay = defaults.object(forKey: Keys.captureDelay) as? Int ?? 0
    }

    var directoryURL: URL {
        URL(fileURLWithPath: saveDirectory, isDirectory: true)
    }

    var recordingDirectoryURL: URL {
        URL(fileURLWithPath: recordingDirectory, isDirectory: true)
    }
}

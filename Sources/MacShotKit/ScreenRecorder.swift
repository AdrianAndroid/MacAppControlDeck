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

final class ScreenRecorder: NSObject, SCStreamOutput, SCStreamDelegate {
    private var stream: SCStream?
    private var writer: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var microphoneInput: AVAssetWriterInput?
    private var adaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var outputURL: URL?
    private var format: RecordingFormat = .mp4
    private var options = RecordingOptions()
    private var startedAt: CMTime?
    private var isStopping = false
    private var gifFrames: [(CGImage, CMTime)] = []
    private var videoFrameIndex: Int64 = 0
    private var pixelWidth = 0
    private var pixelHeight = 0
    private var latestPixelBuffer: CVPixelBuffer?
    private var frameTimer: DispatchSourceTimer?
    private var audioStart: CMTime?
    private var microphoneStart: CMTime?
    private var isPaused = false
    private var pausedAt: Date?
    private var totalPaused: TimeInterval = 0
    private var originPTS: CMTime?
    private var sessionStarted = false
    private var isRecordingSession: Bool { writer != nil && !isStopping }
    private var screenFramesReceived = 0
    private var videoFramesWritten = 0
    private var diskTimer: DispatchSourceTimer?
    private var sleepObserver: NSObjectProtocol?
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    private let stateQueue = DispatchQueue(label: "MacShotKit.recorder.state")

    var onFinish: ((Result<URL, Error>) -> Void)?

    func start(target: RecordingTarget,
               format: RecordingFormat,
               options: RecordingOptions,
               outputURL: URL) async throws {
        self.format = format
        self.options = options
        self.outputURL = outputURL
        self.gifFrames = []
        self.isStopping = false
        self.videoFrameIndex = 0
        self.startedAt = nil
        self.latestPixelBuffer = nil
        self.frameTimer?.cancel()
        self.frameTimer = nil
        self.audioStart = nil
        self.microphoneStart = nil
        self.isPaused = false
        self.pausedAt = nil
        self.totalPaused = 0
        self.sessionStarted = false

        let content: SCShareableContent
        do {
            content = try await SCShareableContent.excludingDesktopWindows(
                false, onScreenWindowsOnly: true)
        } catch {
            throw RecordingError.permission
        }

        let filter: SCContentFilter
        var outputSize: CGSize
        var sourceRect: CGRect = .zero
        var scale: CGFloat = 2

        switch target {
        case .screen(let screen):
            guard let displayID = CaptureGeometry.displayID(of: screen),
                  let display = content.displays.first(where: { $0.displayID == displayID })
            else { throw RecordingError.noDisplay }
            filter = SCContentFilter(display: display, excludingWindows: [])
            outputSize = CGSize(width: display.width, height: display.height)
            scale = screen.backingScaleFactor

        case .area(let screen, let rect):
            guard let displayID = CaptureGeometry.displayID(of: screen),
                  let display = content.displays.first(where: { $0.displayID == displayID })
            else { throw RecordingError.noDisplay }
            filter = SCContentFilter(display: display, excludingWindows: [])
            let local = CaptureGeometry.rectInScreen(rect, screen: screen)
            sourceRect = local
            outputSize = local.size
            scale = screen.backingScaleFactor

        case .window(let target):
            guard let window = content.windows.first(where: { $0.windowID == target.windowID })
            else { throw RecordingError.noWindow }
            filter = SCContentFilter(desktopIndependentWindow: window)
            outputSize = window.frame.size
            scale = NSScreen.main?.backingScaleFactor ?? 2
            sourceRect = CGRect(origin: .zero, size: outputSize)
        }

        let pixelWidth = max(Int(outputSize.width * scale) & ~1, 2)
        let pixelHeight = max(Int(outputSize.height * scale) & ~1, 2)
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight

        let configuration = SCStreamConfiguration()
        configuration.width = pixelWidth
        configuration.height = pixelHeight
        configuration.pixelFormat = kCVPixelFormatType_32BGRA
        configuration.showsCursor = options.showsCursor
        configuration.minimumFrameInterval = CMTime(value: 1,
                                                     timescale: CMTimeScale(max(options.fps, 1)))
        configuration.queueDepth = 6
        configuration.capturesAudio = format == .mp4 && options.systemAudio
        configuration.excludesCurrentProcessAudio = true
        if #available(macOS 15.0, *), format == .mp4 && options.microphone {
            configuration.captureMicrophone = true
        }
        configuration.sampleRate = 48_000
        configuration.channelCount = 2
        if sourceRect.width > 0, sourceRect.height > 0 {
            configuration.sourceRect = sourceRect
        }

        if format == .mp4 {
            let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
            let settings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: pixelWidth,
                AVVideoHeightKey: pixelHeight,
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: max(pixelWidth * pixelHeight * 4, 2_000_000),
                    AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
                ]
            ]
            let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
            input.expectsMediaDataInRealTime = true
            let adaptor = AVAssetWriterInputPixelBufferAdaptor(
                assetWriterInput: input,
                sourcePixelBufferAttributes: [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                    kCVPixelBufferWidthKey as String: pixelWidth,
                    kCVPixelBufferHeightKey as String: pixelHeight
                ])
            guard writer.canAdd(input) else { throw RecordingError.writer }
            writer.add(input)
            self.videoInput = input
            self.adaptor = adaptor

            if options.systemAudio {
                let audioSettings: [String: Any] = [
                    AVFormatIDKey: kAudioFormatMPEG4AAC,
                    AVSampleRateKey: 48_000,
                    AVNumberOfChannelsKey: 2,
                    AVEncoderBitRateKey: 128_000
                ]
                let audio = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
                audio.expectsMediaDataInRealTime = true
                if writer.canAdd(audio) {
                    writer.add(audio)
                    self.audioInput = audio
                }
            }

            if options.microphone {
                let micSettings: [String: Any] = [
                    AVFormatIDKey: kAudioFormatMPEG4AAC,
                    AVSampleRateKey: 48_000,
                    AVNumberOfChannelsKey: 1,
                    AVEncoderBitRateKey: 96_000
                ]
                let mic = AVAssetWriterInput(mediaType: .audio, outputSettings: micSettings)
                mic.expectsMediaDataInRealTime = true
                if writer.canAdd(mic) {
                    writer.add(mic)
                    self.microphoneInput = mic
                }
            }

            guard writer.startWriting() else {
                throw writer.error ?? RecordingError.writer
            }
            // 必须先开 session，AVAssetWriterInput 才会进入 ready 状态；
            // 之前在首个屏幕帧里才调用会导致 isReadyForMoreMediaData 永远为 false。
            writer.startSession(atSourceTime: .zero)
            self.sessionStarted = true
            self.writer = writer
        } else {
            self.writer = nil
            self.videoInput = nil
            self.audioInput = nil
            self.microphoneInput = nil
            self.adaptor = nil
        }

        let stream = SCStream(filter: filter, configuration: configuration, delegate: self)
        try stream.addStreamOutput(self, type: .screen,
                                   sampleHandlerQueue: stateQueue)
        if format == .mp4 && options.systemAudio {
            try stream.addStreamOutput(self, type: .audio,
                                       sampleHandlerQueue: stateQueue)
        }
        if #available(macOS 15.0, *), format == .mp4 && options.microphone {
            try stream.addStreamOutput(self, type: .microphone,
                                       sampleHandlerQueue: stateQueue)
        }
        self.stream = stream
        try await startCapture(stream)
        originPTS = nil
        startDiskMonitor()
        stateQueue.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            guard let self, self.isRecordingSession, self.format == .mp4,
                  self.screenFramesReceived == 0 else { return }
            NSLog("MacShotKit: no screen frames received; likely missing screen-recording trust")
            self.stop()
        }
        sleepObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.stop()
        }
    }

    /// 磁盘空间低于阈值时自动停止，避免录出无法使用的文件。
    private func startDiskMonitor() {
        diskTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: stateQueue)
        timer.schedule(deadline: .now() + 5, repeating: 5)
        timer.setEventHandler { [weak self] in
            guard let self, let outputURL = self.outputURL else { return }
            let values = try? outputURL.deletingLastPathComponent()
                .resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            let free = values?.volumeAvailableCapacityForImportantUsage ?? .max
            if free < 200 * 1024 * 1024 {
                NSLog("MacShotKit: 磁盘空间不足，自动停止录制")
                self.stop()
            }
        }
        diskTimer = timer
        timer.resume()
    }

    private func stopDiskMonitor() {
        diskTimer?.cancel()
        diskTimer = nil
    }

    private func startFrameTimer() {
        guard frameTimer == nil else { return }
        let fps = format == .gif ? max(options.gifFPS, 1) : max(options.fps, 1)
        let interval = 1.0 / Double(fps)
        let timer = DispatchSource.makeTimerSource(queue: stateQueue)
        timer.schedule(deadline: .now() + interval,
                       repeating: interval,
                       leeway: .milliseconds(1))
        timer.setEventHandler { [weak self] in
            self?.emitFrame()
        }
        frameTimer = timer
        timer.resume()
    }

    func setPaused(_ paused: Bool) {
        stateQueue.async { [weak self] in
            guard let self else { return }
            if paused {
                if !self.isPaused {
                    self.isPaused = true
                    self.pausedAt = Date()
                }
            } else if self.isPaused {
                if let pausedAt = self.pausedAt {
                    self.totalPaused += Date().timeIntervalSince(pausedAt)
                }
                self.pausedAt = nil
                self.isPaused = false
            }
        }
    }

    private func emitFrame() {
        guard !isPaused, !isStopping, let sourceBuffer = latestPixelBuffer else { return }

        if format == .gif {
            let gifTime = CMTime(value: Int64(gifFrames.count),
                                 timescale: CMTimeScale(max(options.gifFPS, 1)))
            let extent = CGRect(x: 0, y: 0,
                                width: CVPixelBufferGetWidth(sourceBuffer),
                                height: CVPixelBufferGetHeight(sourceBuffer))
            let image = CIImage(cvPixelBuffer: sourceBuffer)
            if let cgImage = ciContext.createCGImage(image, from: extent) {
                gifFrames.append((cgImage, gifTime))
                if gifFrames.count > 900 { gifFrames.removeFirst() }
            }
            return
        }

        guard let adaptor, let videoInput, videoInput.isReadyForMoreMediaData else { return }
        let frameTime = CMTime(value: videoFrameIndex,
                               timescale: CMTimeScale(max(options.fps, 1)))
        videoFrameIndex += 1

        var createdBuffer: CVPixelBuffer?
        let attrs: [String: Any] = [
            kCVPixelBufferIOSurfacePropertiesKey as String: [:],
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]
        guard CVPixelBufferCreate(kCFAllocatorDefault,
                                  pixelWidth,
                                  pixelHeight,
                                  kCVPixelFormatType_32BGRA,
                                  attrs as CFDictionary,
                                  &createdBuffer) == kCVReturnSuccess,
              let targetBuffer = createdBuffer else {
            NSLog("MacShotKit: pixel buffer creation failed")
            return
        }

        let image = CIImage(cvPixelBuffer: sourceBuffer)
        let scaleX = CGFloat(pixelWidth) / max(image.extent.width, 1)
        let scaleY = CGFloat(pixelHeight) / max(image.extent.height, 1)
        let scaled = image.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        ciContext.render(scaled,
                         to: targetBuffer,
                         bounds: CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight),
                         colorSpace: CGColorSpaceCreateDeviceRGB())
        if adaptor.append(targetBuffer, withPresentationTime: frameTime) {
            videoFramesWritten += 1
        } else {
            NSLog("MacShotKit: video append failed: \(String(describing: writer?.error))")
        }
    }

    /// 把 SCK 缓冲重绘到可编码的 BGRA 缓冲（尺寸不一致时顺带缩放）。
    private func renderBuffer(from source: CVPixelBuffer) -> CVPixelBuffer {
        var created: CVPixelBuffer?
        let attrs: [String: Any] = [
            kCVPixelBufferIOSurfacePropertiesKey as String: [:],
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]
        guard CVPixelBufferCreate(kCFAllocatorDefault, pixelWidth, pixelHeight,
                                  kCVPixelFormatType_32BGRA, attrs as CFDictionary,
                                  &created) == kCVReturnSuccess,
              let target = created else { return source }
        let image = CIImage(cvPixelBuffer: source)
        ciContext.render(image,
                         to: target,
                         bounds: CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight),
                         colorSpace: CGColorSpaceCreateDeviceRGB())
        return target
    }

    /// SCK 偶尔给出与配置尺寸不一致的缓冲；此时缩放一次再写入，避免整段录制失败。
    private func normalizedBuffer(_ source: CVPixelBuffer) -> CVPixelBuffer {
        let width = CVPixelBufferGetWidth(source)
        let height = CVPixelBufferGetHeight(source)
        guard width != pixelWidth || height != pixelHeight else { return source }
        var created: CVPixelBuffer?
        let attrs: [String: Any] = [
            kCVPixelBufferIOSurfacePropertiesKey as String: [:],
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]
        guard CVPixelBufferCreate(kCFAllocatorDefault, pixelWidth, pixelHeight,
                                  kCVPixelFormatType_32BGRA, attrs as CFDictionary,
                                  &created) == kCVReturnSuccess,
              let target = created else { return source }
        let image = CIImage(cvPixelBuffer: source)
        ciContext.render(image,
                         to: target,
                         bounds: CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight),
                         colorSpace: CGColorSpaceCreateDeviceRGB())
        return target
    }

    private func stopFrameTimer() {
        frameTimer?.cancel()
        frameTimer = nil
        latestPixelBuffer = nil
        diskTimer?.cancel()
        diskTimer = nil
        if let sleepObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(sleepObserver)
            self.sleepObserver = nil
        }
    }

    func stop() {
        stateQueue.async { [weak self] in
            guard let self, !self.isStopping else { return }
            self.isStopping = true
            guard let stream = self.stream else {
                self.finishOnQueue(nil)
                return
            }
            stream.stopCapture { [weak self] error in
                guard let self else { return }
                self.stateQueue.async {
                    if let error {
                        self.finishOnQueue(error)
                    } else {
                        self.finishOnQueue(nil)
                    }
                }
            }
        }
    }

    private func startCapture(_ stream: SCStream) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            stream.startCapture { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func finishOnQueue(_ error: Error?) {
        guard let outputURL else { return }
        stopFrameTimer()
        if let error {
            writer?.cancelWriting()
            stream = nil
            DispatchQueue.main.async { self.onFinish?(.failure(error)) }
            return
        }

        if format == .gif {
            let frames = gifFrames
            stream = nil
            guard !frames.isEmpty else {
                DispatchQueue.main.async { self.onFinish?(.failure(RecordingError.noFrames)) }
                return
            }
            do {
                try GIFEncoder.write(frames: frames,
                                     maxWidth: options.gifMaxWidth,
                                     to: outputURL)
                DispatchQueue.main.async { self.onFinish?(.success(outputURL)) }
            } catch {
                DispatchQueue.main.async { self.onFinish?(.failure(error)) }
            }
            return
        }

        guard let writer, let videoInput else {
            stream = nil
            DispatchQueue.main.async { self.onFinish?(.failure(RecordingError.writer)) }
            return
        }
        videoInput.markAsFinished()
        audioInput?.markAsFinished()
        microphoneInput?.markAsFinished()
        writer.finishWriting { [weak self] in
            guard let self else { return }
            self.stream = nil
            let result: Result<URL, Error>
            if writer.status == .completed {
                result = .success(outputURL)
            } else {
                result = .failure(writer.error ?? RecordingError.writer)
            }
            DispatchQueue.main.async { self.onFinish?(result) }
        }
    }

    func stream(_ stream: SCStream,
                didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
                of type: SCStreamOutputType) {
        guard !isStopping else { return }
        switch type {
        case .screen:
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            latestPixelBuffer = pixelBuffer
            screenFramesReceived += 1
            if !sessionStarted {
                writer?.startSession(atSourceTime: .zero)
                sessionStarted = true
            }
            if startedAt == nil {
                startedAt = .zero
                startFrameTimer()
            }

        case .audio:
            guard !isPaused, startedAt != nil, let audioInput,
                  audioInput.isReadyForMoreMediaData else { return }

            let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            if audioStart == nil { audioStart = pts }
            var paused = totalPaused
            if let pausedAt { paused += Date().timeIntervalSince(pausedAt) }
            var relative = CMTimeSubtract(pts, audioStart ?? pts)
            relative = CMTimeSubtract(relative, CMTime(seconds: paused, preferredTimescale: 48_000))
            if relative.seconds < 0 { relative = .zero }
            var timing = CMSampleTimingInfo(duration: CMSampleBufferGetDuration(sampleBuffer),
                                           presentationTimeStamp: relative,
                                           decodeTimeStamp: .invalid)
            var retimed: CMSampleBuffer?
            let status = withUnsafePointer(to: &timing) { timingPtr in
                CMSampleBufferCreateCopyWithNewTiming(allocator: kCFAllocatorDefault,
                                                      sampleBuffer: sampleBuffer,
                                                      sampleTimingEntryCount: 1,
                                                      sampleTimingArray: timingPtr,
                                                      sampleBufferOut: &retimed)
            }
            if status == noErr, let retimed {
                audioInput.append(retimed)
            } else {
                audioInput.append(sampleBuffer)
            }

        case .microphone:
            guard !isPaused, startedAt != nil, let microphoneInput,
                  microphoneInput.isReadyForMoreMediaData else { return }
            let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            if microphoneStart == nil { microphoneStart = pts }
            var paused = totalPaused
            if let pausedAt { paused += Date().timeIntervalSince(pausedAt) }
            var relative = CMTimeSubtract(pts, microphoneStart ?? pts)
            relative = CMTimeSubtract(relative, CMTime(seconds: paused, preferredTimescale: 48_000))
            if relative.seconds < 0 { relative = .zero }
            var timing = CMSampleTimingInfo(duration: CMSampleBufferGetDuration(sampleBuffer),
                                           presentationTimeStamp: relative,
                                           decodeTimeStamp: .invalid)
            var retimed: CMSampleBuffer?
            let status = withUnsafePointer(to: &timing) { ptr in
                CMSampleBufferCreateCopyWithNewTiming(allocator: kCFAllocatorDefault,
                                                      sampleBuffer: sampleBuffer,
                                                      sampleTimingEntryCount: 1,
                                                      sampleTimingArray: ptr,
                                                      sampleBufferOut: &retimed)
            }
            if status == noErr, let retimed { microphoneInput.append(retimed) }
            else { microphoneInput.append(sampleBuffer) }

        @unknown default:
            break
        }
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        stateQueue.async { [weak self] in
            self?.finishOnQueue(error)
        }
    }
}

enum GIFEncoder {
    static func write(frames: [(CGImage, CMTime)], maxWidth: Int, to url: URL) throws {
        guard !frames.isEmpty else { throw RecordingError.noFrames }
        let sourceWidth = frames[0].0.width
        let scale = min(1.0, Double(maxWidth) / Double(max(sourceWidth, 1)))
        let width = max(Int(Double(frames[0].0.width) * scale), 1)
        let height = max(Int(Double(frames[0].0.height) * scale), 1)

        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL, UTType.gif.identifier as CFString, frames.count, nil
        ) else { throw RecordingError.writer }

        let fileProperties: [CFString: Any] = [
            kCGImagePropertyGIFDictionary: [
                kCGImagePropertyGIFLoopCount: 0
            ]
        ]
        CGImageDestinationSetProperties(destination, fileProperties as CFDictionary)

        for (index, frame) in frames.enumerated() {
            let delay: Double
            if index + 1 < frames.count {
                delay = CMTimeGetSeconds(CMTimeSubtract(frames[index + 1].1, frame.1))
            } else {
                delay = 0.1
            }
            let properties: [CFString: Any] = [
                kCGImagePropertyGIFDictionary: [
                    kCGImagePropertyGIFDelayTime: max(delay, 0.03)
                ]
            ]
            let resized = resize(frame.0, width: width, height: height) ?? frame.0
            CGImageDestinationAddImage(destination, resized, properties as CFDictionary)
        }

        guard CGImageDestinationFinalize(destination) else {
            throw RecordingError.writer
        }
    }

    private static func resize(_ image: CGImage, width: Int, height: Int) -> CGImage? {
        guard let context = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }
}

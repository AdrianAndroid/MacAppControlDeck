import AppKit
import AVFoundation
import CoreGraphics

public enum CaptureSelectionPreset: Equatable, CaseIterable {
    case free
    case ratio(String, CGFloat)
    case pixels(String, Int, Int)

    public static var allCases: [CaptureSelectionPreset] {
        [.free, .ratio("1:1", 1), .ratio("4:3", 4.0/3), .ratio("16:9", 16.0/9),
         .ratio("9:16", 9.0/16), .ratio("3:4", 3.0/4),
         .pixels("1920×1080", 1920, 1080), .pixels("1080×1920", 1080, 1920)]
    }

    public var label: String {
        switch self {
        case .free: return "自由"
        case .ratio(let name, _): return name
        case .pixels(let name, _, _): return name
        }
    }
}

public final class MacShotController {
    public static let shared = MacShotController()

    public var outputDirectory: URL = {
        let pictures = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first
        return (pictures ?? URL(fileURLWithPath: NSHomeDirectory()))
            .appendingPathComponent("MacAppControlDeck", isDirectory: true)
    }()

    public var recordingDirectory: URL = {
        let movies = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first
        return (movies ?? URL(fileURLWithPath: NSHomeDirectory()))
            .appendingPathComponent("MacAppControlDeck", isDirectory: true)
    }()

    public private(set) var isRecording = false
    public private(set) var recordingFormat: RecordingFormat = .mp4
    public var recordingOptions = RecordingOptions()
    public var imageFormat = "png"
    public var imageQuality = 0.9
    public var captureDelay: TimeInterval = 0
    public var selectionPreset: CaptureSelectionPreset = .free
    public var playShutterSound = true
    public var saveToFile = true
    public var copyToClipboard = true
    public var showFloatingThumbnail = true
    private var recorder: ScreenRecorder?
    private var recordingTarget: RecordingTarget?
    private var recordingIntent: RecordingFormat = .mp4
    private var toastPanel: NSPanel?
    private var toastTimer: Timer?

    // MARK: - 截图

    public func captureFullScreen() {
        guard ensurePermission() else { return }
        scheduleCapture { [weak self] in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
                guard let image = ScreenCaptureService.captureFullScreen() else {
                    self?.showPermissionAlert()
                    return
                }
                self?.openEditor(image)
            }
        }
    }

    public func captureAllScreens() {
        guard ensurePermission() else { return }
        scheduleCapture { [weak self] in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
                guard let image = ScreenCaptureService.captureAllScreensStitched() else {
                    self?.showPermissionAlert()
                    return
                }
                self?.openEditor(image)
            }
        }
    }

    public func captureArea() {
        guard ensurePermission() else { return }
        scheduleCapture { [weak self] in
            AreaSelectionController.shared.begin { [weak self] screen, rect, snapshot in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                    guard let image = snapshot ?? ScreenCaptureService.capture(area: rect, on: screen) else {
                        self?.showPermissionAlert()
                        return
                    }
                    self?.openEditor(image)
                }
            }
        }
    }

    public func captureWindow() {
        guard ensurePermission() else { return }
        scheduleCapture { [weak self] in
            WindowSelectionController.shared.begin { [weak self] target in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                    guard let image = ScreenCaptureService.capture(window: target) else {
                        self?.showAlert("窗口截图失败", "窗口可能已关闭，请重试。")
                        return
                    }
                    self?.openEditor(image)
                }
            }
        }
    }

    /// 快速截图：选区后直接保存并复制，不打开编辑器。
    public func quickSaveArea() {
        guard ensurePermission() else { return }
        scheduleCapture { [weak self] in
            AreaSelectionController.shared.begin { [weak self] screen, rect, snapshot in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                    guard let self,
                          let image = snapshot ?? ScreenCaptureService.capture(area: rect, on: screen)
                    else { return }
                    self.saveEditorImage(image, notify: true)
                }
            }
        }
    }

    /// 快速 OCR：选区后直接识别文字并复制到剪贴板。
    public func quickOCRArea() {
        guard ensurePermission() else { return }
        scheduleCapture {
            AreaSelectionController.shared.begin { screen, rect, snapshot in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                    guard let image = snapshot ?? ScreenCaptureService.capture(area: rect, on: screen)
                    else { return }
                    OCRResultController.shared.recognize(image, autoCopy: true)
                }
            }
        }
    }

    public func scrollCapture() {
        guard ensurePermission() else { return }
        scheduleCapture {
            ScrollCaptureController.shared.begin()
        }
    }

    public func openRecentCapture(_ url: URL) {
        guard let image = NSImage(contentsOf: url),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else {
            showAlert("无法打开", "截图文件可能已被移动或删除。")
            return
        }
        openEditor(cgImage)
    }

    private func scheduleCapture(_ action: @escaping () -> Void) {
        guard captureDelay > 0 else {
            action()
            return
        }
        showToast("\(Int(captureDelay)) 秒后截图…")
        DispatchQueue.main.asyncAfter(deadline: .now() + captureDelay, execute: action)
    }

    func openEditor(_ image: CGImage, annotations: [CaptureAnnotation] = []) {
        CaptureEditorWindowController.shared.show(image: image, annotations: annotations)
    }

    func saveEditedImage(_ image: CGImage, base: CGImage? = nil,
                         annotations: [CaptureAnnotation] = []) {
        saveEditorImage(image, base: base, annotations: annotations, notify: true)
    }

    private func saveEditorImage(_ image: CGImage, base: CGImage? = nil,
                                 annotations: [CaptureAnnotation] = [], notify: Bool) {
        let ext = imageFormat == "jpeg" ? "jpg" : imageFormat
        var savedURL: URL?
        do {
            if saveToFile {
                let template = FilenameFormatter.template(forRecording: false)
                let url = try FilenameFormatter.makeURL(directory: outputDirectory,
                                                        template: template,
                                                        fileExtension: ext)
                try CaptureExporter.write(image, to: url, format: imageFormat, quality: imageQuality)
                savedURL = url
                CaptureHistoryStore.shared.add(url)
                if let base { persistEditSession(savedURL: url, base: base, annotations: annotations) }
            }
            if copyToClipboard || !saveToFile {
                CaptureExporter.copyToPasteboard(image)
            }
            if playShutterSound { CaptureSound.shared.play() }
            if showFloatingThumbnail {
                FloatingThumbnailController.shared.show(image: image, fileURL: savedURL)
            }
            if notify {
                if let savedURL {
                    showToast(copyToClipboard
                        ? "已保存 \(savedURL.lastPathComponent)，并复制到剪贴板"
                        : "已保存 \(savedURL.lastPathComponent)")
                } else {
                    showToast("已复制到剪贴板")
                }
            }
        } catch {
            showAlert("保存失败", error.localizedDescription)
        }
    }

    // MARK: - Editable history

    private var editSessionDirectory: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory,
                                           in: .userDomainMask)[0]
            .appendingPathComponent("MacAppControlDeck/EditSessions", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func persistEditSession(savedURL: URL, base: CGImage,
                                    annotations: [CaptureAnnotation]) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let name = "Session-\(formatter.string(from: Date()))-\(UUID().uuidString.prefix(6))"
        let dir = editSessionDirectory.appendingPathComponent(name, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let baseURL = dir.appendingPathComponent("base.png")
            let rep = NSBitmapImageRep(cgImage: base)
            guard let data = rep.representation(using: .png, properties: [:]) else { return }
            try data.write(to: baseURL)
            let session = CaptureEditSession(savedPath: savedURL.path,
                                             baseFile: "base.png",
                                             annotations: annotations.map(CaptureAnnotationArchive.init))
            let json = try JSONEncoder().encode(session)
            try json.write(to: dir.appendingPathComponent("session.json"))
        } catch {
            // Session persistence is best-effort; the saved image is unaffected.
        }
    }

    public func reopenLastEditSession() {
        let dir = editSessionDirectory
        guard let children = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: [.contentModificationDateKey]) else {
            showToast("暂无可重新编辑的会话"); return
        }
        let sessions = children
            .filter { $0.hasDirectoryPath && FileManager.default.fileExists(atPath: $0.appendingPathComponent("session.json").path) }
            .sorted { a, b in
                let da = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let db = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return da > db
            }
        guard let latest = sessions.first,
              let data = try? Data(contentsOf: latest.appendingPathComponent("session.json")),
              let session = try? JSONDecoder().decode(CaptureEditSession.self, from: data),
              let baseImage = NSImage(contentsOf: latest.appendingPathComponent(session.baseFile)) else {
            showToast("暂无可重新编辑的会话"); return
        }
        var rect = CGRect(origin: .zero, size: baseImage.size)
        guard let cg = baseImage.cgImage(forProposedRect: &rect, context: nil, hints: nil) else { return }
        openEditor(cg, annotations: session.annotations.map(\.annotation))
    }

    // MARK: - 录屏

    public func startRecording(format: RecordingFormat,
                        target mode: RecordingTargetMode = .area) {
        guard !isRecording else {
            stopRecording()
            return
        }
        guard ensurePermission() else { return }
        recordingIntent = format

        switch mode {
        case .fullScreen:
            guard let screen = NSScreen.main else { return }
            beginRecording(target: .screen(screen), format: format)
        case .area:
            AreaSelectionController.shared.beginRecording(initialFormat: format) { [weak self] screen, rect, chosenFormat, fps, sysAudio, mic in
                guard let self else { return }
                var options = self.recordingOptions
                options.fps = fps
                options.systemAudio = sysAudio && chosenFormat == .mp4
                options.microphone = mic && chosenFormat == .mp4
                self.recordingOptions = options
                self.recordingIntent = chosenFormat
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    self.beginRecording(target: .area(screen, rect), format: .mp4)
                }
            }
        case .window:
            WindowSelectionController.shared.begin { [weak self] target in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    self?.beginRecording(target: .window(target), format: format)
                }
            }
        }
    }

    public func stopRecording() {
        recorder?.stop()
    }

    private func beginRecording(target: RecordingTarget, format: RecordingFormat) {
        recordingIntent = (format == .gif) ? .gif : recordingIntent
        // 录制始终产出 MP4 take；GIF 通过视频编辑器导出（与 macshot 一致）。
        let ext = "mp4"
        let url: URL
        do {
            try FileManager.default.createDirectory(at: recordingDirectory,
                                                    withIntermediateDirectories: true)
            let template = FilenameFormatter.template(forRecording: true)
            url = try FilenameFormatter.makeURL(directory: recordingDirectory,
                                                template: template,
                                                fileExtension: ext)
        } catch {
            showAlert("录制失败", error.localizedDescription)
            return
        }

        let recorder = ScreenRecorder()
        recorder.onFinish = { [weak self] result in
            Task { @MainActor in
                self?.isRecording = false
                self?.recorder = nil
                self?.recordingTarget = nil
                RecordingHUDController.shared.hide()
                ClickHighlightController.shared.stop()
                switch result {
                case .success(let url):
                    self?.showToast(self?.recordingIntent == .gif
                        ? "录制完成，正在准备 GIF 编辑"
                        : "已保存 \(url.lastPathComponent)")
                    if url.pathExtension.lowercased() == "mp4" {
                        VideoEditorController.shared.present(url,
                                                            preferGIF: self?.recordingIntent == .gif)
                    }
                case .failure(let error):
                    self?.showAlert("录制失败", error.localizedDescription)
                }
            }
        }
        self.recorder = recorder
        self.recordingTarget = target
        self.recordingFormat = format

        Task { @MainActor in
            if recordingOptions.microphone {
                let granted = await AVCaptureDevice.requestAccess(for: .audio)
                if !granted {
                    self.recorder = nil
                    self.isRecording = false
                    self.showAlert("没有麦克风权限", "请在系统设置中允许麦克风访问后重试。")
                    return
                }
            }
            let countdown = RecordingCountdown()
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                countdown.show(over: Self.anchor(for: target).rect,
                               screen: Self.anchor(for: target).screen,
                               seconds: 3) {
                    continuation.resume()
                }
            }
            do {
                try await recorder.start(target: target,
                                         format: format,
                                         options: recordingOptions,
                                         outputURL: url)
                self.isRecording = true
                ClickHighlightController.shared.start()
                let anchor = Self.anchor(for: target)
                RecordingHUDController.shared.show(
                    format: format,
                    relativeTo: anchor.rect,
                    screen: anchor.screen,
                    onTogglePause: { paused in
                        recorder.setPaused(paused)
                    },
                    onStop: { [weak self] in
                        self?.stopRecording()
                    })
            } catch {
                self.recorder = nil
                self.recordingTarget = nil
                self.isRecording = false
                self.showAlert("无法开始录制", error.localizedDescription)
            }
        }
    }

    private static func anchor(for target: RecordingTarget) -> (rect: CGRect, screen: NSScreen?) {
        switch target {
        case .screen(let screen):
            return (screen.frame, screen)
        case .area(let screen, let rect):
            return (rect, screen)
        case .window(let window):
            let center = CGPoint(x: window.bounds.midX, y: window.bounds.midY)
            let screen = NSScreen.screens.first { $0.frame.contains(center) }
            return (window.bounds, screen)
        }
    }

    // MARK: - 权限/提示

    /// 不再用 CGPreflightScreenCaptureAccess 阻塞判断：重签名后它会误报未授权，
    /// 但真实抓屏往往仍然可用。这里直接放行，只有抓图失败时才提示授权。
    public func ensurePermission() -> Bool { true }

    func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "需要「屏幕录制」权限"
        alert.informativeText = "请在系统设置 → 隐私与安全 → 屏幕录制中勾选「Mac 应用快捷控制台」，然后重启应用。\n\n若开关已经是打开状态，多半是重新构建后签名变化导致系统保留了旧条目：先删除列表里的旧条目，再重新添加本应用；或执行 Build/setup-signing.sh 使用固定证书后重新授权一次。"
        alert.addButton(withTitle: "打开系统设置")
        alert.addButton(withTitle: "稍后")
        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    public func showAlert(_ title: String, _ message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "好")
        alert.runModal()
    }

    public func showToast(_ message: String) {
        toastTimer?.invalidate()
        toastPanel?.orderOut(nil)

        let label = NSTextField(labelWithString: message)
        label.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        label.textColor = .white
        label.alignment = .center
        label.lineBreakMode = .byTruncatingMiddle
        label.frame = CGRect(x: 14, y: 10, width: 360, height: 18)

        let panel = NSPanel(contentRect: CGRect(x: 0, y: 0, width: 388, height: 38),
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = NSColor.black.withAlphaComponent(0.78)
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isReleasedWhenClosed = false
        panel.contentView = NSView(frame: CGRect(x: 0, y: 0, width: 388, height: 38))
        panel.contentView?.addSubview(label)

        let visible = NSScreen.main?.visibleFrame ?? .zero
        panel.setFrameOrigin(CGPoint(x: visible.midX - 194, y: visible.minY + 48))
        panel.orderFrontRegardless()
        toastPanel = panel

        toastTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            self?.toastPanel?.orderOut(nil)
            self?.toastPanel = nil
        }
    }
}

public enum RecordingTargetMode {
    case fullScreen
    case area
    case window
}

import AppKit
import ApplicationServices

/// 上游 `OverlayWindowControllerDelegate` 的宿主实现：
/// 把覆盖层的确认/钉图/OCR/录制/滚动等动作接到本应用既有链路。
@MainActor
final class OverlayCoordinator: NSObject, OverlayWindowControllerDelegate, PinWindowControllerDelegate {
    static let shared = OverlayCoordinator()

    private var thumbnailControllers: [FloatingThumbnailController] = []
    private var ocrController: OCRResultController?
    private var pins: [PinWindowController] = []
    private var lastSelectionRect: NSRect?
    private var overlayControllers: [OverlayWindowController] = []
    private var isFinishingOverlay = false

    // 录屏延时倒计时（与上游一致）
    private var countdownWindow: NSWindow?
    private var countdownTimer: Timer?
    private var countdownBorder: SelectionBorderOverlay?
    private var countdownEscMonitor: Any?

    // 滚动截图（上游 ScrollCaptureController）
    private var scrollCaptureController: ScrollCaptureController?
    private var scrollCapturePreviewPanel: ScrollCapturePreviewPanel?
    private weak var scrollCaptureOverlayController: OverlayWindowController?
    private var scrollCaptureCopyRequested = false

    enum AutoAction { case none, quickSave, ocr }
    var pendingAutoAction: AutoAction = .none

    // MARK: - Overlay lifecycle

    /// 与上游一致：先抓取全部显示器的静态画面，再为每块屏幕各建一个覆盖层。
    /// 这样暗色遮罩来自真实截图，选区也能跨屏。
    @discardableResult
    func beginOverlay(screen: NSScreen? = nil, auto: AutoAction = .none,
                      fullScreen: Bool = false) -> OverlayWindowController {
        endCountdown()
        // 丢弃上一次尚未结束的覆盖层，避免热键连按时叠加多个遮罩。
        for stale in overlayControllers { stale.dismiss() }
        overlayControllers.removeAll()
        isFinishingOverlay = false
        MacShotController.shared.overlayController = nil
        let preferred = screen ?? NSScreen.preferred ?? NSScreen.main ?? NSScreen.screens.first!

        // 必须在任何覆盖层出现之前抓屏，否则截到的是遮罩本身。
        let context = ScreenCaptureManager.makeImmediateCaptureContext()
        let captures = ScreenCaptureManager.captureAllScreensImmediately(context: context)

        var controllers: [OverlayWindowController] = []
        for capture in captures {
            let controller = OverlayWindowController(screen: capture.screen)
            controller.overlayDelegate = self
            controller.setScreenshot(capture.image)
            controllers.append(controller)
        }
        if controllers.isEmpty {
            let controller = OverlayWindowController(screen: preferred)
            controller.overlayDelegate = self
            controllers = [controller]
        }

        overlayControllers = controllers
        isFinishingOverlay = false
        pendingAutoAction = auto

        for controller in controllers {
            if fullScreen {
                controller.applyFullScreenSelection()
            }
            switch auto {
            case .quickSave: controller.setAutoQuickSaveMode()
            case .ocr: controller.setAutoOCRMode()
            case .none: break
            }
        }

        for controller in controllers { controller.showOverlay() }
        let key = controllers.first { $0.screen === preferred } ?? controllers[0]
        key.makeKey()
        return key
    }

    func beginRecordingSelection(initialFormat: RecordingFormat) {
        let controller = beginOverlay()
        for c in overlayControllers { c.enterRecordingMode() }
        controller.makeKey()
    }

    func beginScrollSelection() {
        _ = beginOverlay()
        for c in overlayControllers { c.setAutoScrollCaptureMode() }
    }

    private func finishOverlay(_ controller: OverlayWindowController) {
        guard !isFinishingOverlay else { return }
        isFinishingOverlay = true
        for c in overlayControllers { c.dismiss() }
        overlayControllers.removeAll()
        if MacShotController.shared.overlayController === controller {
            MacShotController.shared.overlayController = nil
        }
    }

    // MARK: - OverlayWindowControllerDelegate

    func overlayDidCancel(_ controller: OverlayWindowController) {
        finishOverlay(controller)
    }

    func overlayDidConfirm(_ controller: OverlayWindowController,
                           capturedImage: NSImage?, annotationData: CaptureAnnotationData?) {
        let image = capturedImage ?? overlayCrossScreenImage(controller)
        let auto = pendingAutoAction
        finishOverlay(controller)
        guard let image,
              let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        switch auto {
        case .ocr:
            runOCR(on: image)
            return
        default:
            break
        }
        MacShotController.shared.saveCapturedImage(cg, annotationData: annotationData)
    }

    func overlayDidRequestPin(_ controller: OverlayWindowController, image: NSImage,
                              annotationData: CaptureAnnotationData?, source: PinSource?) {
        finishOverlay(controller)
        // 把框选的原始屏幕位置交给钉图窗口，让它落在「在哪里截图的就钉在哪里」。
        showPin(image: image, source: source)
    }

    func overlayDidRequestOCR(_ controller: OverlayWindowController, result: OCRScanResult, image: NSImage?) {
        finishOverlay(controller)
        if let image { runOCR(on: image) }
    }

    func overlayDidRequestUpload(_ controller: OverlayWindowController, image: NSImage, annotationData: CaptureAnnotationData?) {
        finishOverlay(controller)
        MacShotController.shared.showToast("上传功能未启用")
    }

    func overlayDidRequestStartRecording(_ controller: OverlayWindowController, rect: NSRect, screen: NSScreen) {
        // 与上游一致：开始录制后覆盖层立即消失，由 HUD 或倒计时接管。
        let fpsOverride = controller.sessionRecordingFPS
        let delayOverride = controller.sessionRecordingDelay
        let hideHUD = controller.sessionHideRecordingHUD
            ?? UserDefaults.standard.bool(forKey: "hideRecordingHUD")
        let appName = controller.resolvedAppName()
        let delay = delayOverride ?? Int(MacShotController.shared.captureDelay)
        finishOverlay(controller)

        if delay > 0 {
            startCountdown(seconds: delay, rect: rect, screen: screen) {
                MacShotController.shared.beginRecording(
                    target: .area(screen, rect), format: .mp4,
                    fpsOverride: fpsOverride, appName: appName, hideHUD: hideHUD)
            }
        } else {
            MacShotController.shared.beginRecording(
                target: .area(screen, rect), format: .mp4,
                fpsOverride: fpsOverride, appName: appName, hideHUD: hideHUD)
        }
    }

    func overlayDidRequestStopRecording(_ controller: OverlayWindowController) {
        MacShotController.shared.stopRecording()
    }

    func overlayDidRequestScrollCapture(_ controller: OverlayWindowController, rect: NSRect, screen: NSScreen) {
        guard AXIsProcessTrusted() else {
            finishOverlay(controller)
            let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
            AXIsProcessTrustedWithOptions(opts)
            let alert = NSAlert()
            alert.messageText = "滚动截图需要辅助功能权限"
            alert.informativeText = "请在系统设置 → 隐私与安全性 → 辅助功能中授权本应用，然后重试。"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "打开设置")
            alert.addButton(withTitle: "取消")
            if alert.runModal() == .alertFirstButtonReturn {
                openAccessibilitySettings()
            }
            return
        }

        scrollCaptureOverlayController = controller
        let scc = ScrollCaptureController(captureRect: rect, screen: screen)
        scc.excludedWindowIDs = overlayControllers.map { $0.windowNumber }
        scrollCaptureController = scc
        scrollCaptureCopyRequested = false

        let maxHeight = UserDefaults.standard.object(forKey: "scrollMaxHeight") as? Int ?? 30000
        controller.setScrollCaptureState(isActive: true, maxHeight: maxHeight)

        if let preview = ScrollCapturePreviewPanel(captureRect: rect, screen: screen, overlayLevel: 257) {
            preview.orderFront(nil)
            scrollCapturePreviewPanel = preview
        }

        scc.onStripAdded = { [weak self, weak controller] count in
            guard let self, let scc = self.scrollCaptureController else { return }
            controller?.updateScrollCaptureProgress(
                stripCount: count, pixelSize: scc.stitchedPixelSize,
                autoScrolling: scc.autoScrollActive)
        }
        scc.onPreviewUpdated = { [weak self] image in
            self?.scrollCapturePreviewPanel?.updatePreview(image: image)
        }
        scc.onAutoScrollStarted = { [weak self, weak controller] in
            guard let self, let scc = self.scrollCaptureController else { return }
            controller?.updateScrollCaptureProgress(
                stripCount: scc.stripCount, pixelSize: scc.stitchedPixelSize,
                autoScrolling: true)
        }
        scc.onSessionDone = { [weak self] image in
            self?.handleScrollCaptureCompleted(image)
        }
        Task { await scc.startSession() }
    }

    func overlayDidRequestStopScrollCapture(_ controller: OverlayWindowController) {
        scrollCaptureController?.stopSession()
    }

    func overlayDidRequestCopyScrollCapture(_ controller: OverlayWindowController) {
        guard scrollCaptureController != nil else { return }
        scrollCaptureCopyRequested = true
        scrollCaptureController?.stopSession()
    }

    func overlayDidRequestCancelScrollCapture(_ controller: OverlayWindowController) {
        let capture = scrollCaptureController
        scrollCaptureController = nil
        capture?.onStripAdded = nil
        capture?.onPreviewUpdated = nil
        capture?.onAutoScrollStarted = nil
        capture?.onSessionDone = nil
        capture?.cancelSession()
        scrollCapturePreviewPanel?.close()
        scrollCapturePreviewPanel = nil
        scrollCaptureOverlayController?.setScrollCaptureState(isActive: false)
        scrollCaptureOverlayController = nil
        finishOverlay(controller)
    }

    func overlayDidRequestToggleAutoScroll(_ controller: OverlayWindowController) {
        scrollCaptureController?.toggleAutoScroll()
    }

    private func handleScrollCaptureCompleted(_ image: NSImage?) {
        scrollCapturePreviewPanel?.close()
        scrollCapturePreviewPanel = nil
        scrollCaptureOverlayController?.setScrollCaptureState(isActive: false)
        scrollCaptureOverlayController = nil
        scrollCaptureController = nil
        let copyRequested = scrollCaptureCopyRequested
        scrollCaptureCopyRequested = false
        let controller = overlayControllers.first
        if let controller { finishOverlay(controller) }
        guard let image,
              let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        if copyRequested || MacShotController.shared.copyToClipboard {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.writeObjects([image])
        }
        MacShotController.shared.saveCapturedImage(cg, annotationData: nil)
    }

    private func openAccessibilitySettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    func overlayDidRequestAccessibilityPermission(_ controller: OverlayWindowController) {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    func overlayDidRequestInputMonitoringPermission(_ controller: OverlayWindowController) {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!)
    }

    func overlayDidBeginSelection(_ controller: OverlayWindowController) {
        // 从这块屏幕开始新选区时，清掉其他屏幕的镜像选区。
        for other in overlayControllers where other !== controller {
            other.clearSelection()
            other.setRemoteSelection(.zero)
        }
    }

    func overlayDidChangeSelection(_ controller: OverlayWindowController, globalRect: NSRect) {
        lastSelectionRect = globalRect
        for other in overlayControllers where other !== controller {
            let otherOrigin = other.screen.frame.origin
            let localRect = NSRect(x: globalRect.origin.x - otherOrigin.x,
                                   y: globalRect.origin.y - otherOrigin.y,
                                   width: globalRect.width, height: globalRect.height)
            let clipped = localRect.intersection(NSRect(origin: .zero, size: other.screen.frame.size))
            other.setRemoteSelection(clipped.isEmpty ? .zero : clipped, fullRect: localRect)
        }
    }

    func overlayDidRemoteResizeSelection(_ controller: OverlayWindowController, globalRect: NSRect) {
        let others = overlayControllers.filter { $0 !== controller }
        guard let primary = others.first(where: { $0.selectionRect.width >= 1 }) else { return }
        let primaryOrigin = primary.screen.frame.origin
        let primaryLocal = NSRect(x: globalRect.origin.x - primaryOrigin.x,
                                  y: globalRect.origin.y - primaryOrigin.y,
                                  width: globalRect.width, height: globalRect.height)
        primary.applySelection(primaryLocal)

        for other in overlayControllers where other !== controller && other !== primary {
            let otherOrigin = other.screen.frame.origin
            let localRect = NSRect(x: globalRect.origin.x - otherOrigin.x,
                                   y: globalRect.origin.y - otherOrigin.y,
                                   width: globalRect.width, height: globalRect.height)
            let clipped = localRect.intersection(NSRect(origin: .zero, size: other.screen.frame.size))
            other.setRemoteSelection(clipped.isEmpty ? .zero : clipped, fullRect: localRect)
        }
    }

    func overlayDidFinishRemoteResize(_ controller: OverlayWindowController, globalRect: NSRect) {
        overlayDidRemoteResizeSelection(controller, globalRect: globalRect)
    }

    func overlayCrossScreenImage(_ controller: OverlayWindowController) -> NSImage? {
        // 收集参与截图的屏幕：发起屏 + 任何有实际选区的其他屏。
        var participants: [(controller: OverlayWindowController, global: NSRect)] = []
        for c in overlayControllers {
            let origin = c.screen.frame.origin
            let local = c === controller ? c.selectionRect : c.remoteSelectionRect
            guard local.width >= 1, local.height >= 1 else { continue }
            let global = NSRect(x: local.minX + origin.x, y: local.minY + origin.y,
                                width: local.width, height: local.height)
            participants.append((c, global))
        }
        guard participants.count > 1,
              let primary = participants.first(where: { $0.controller === controller }) ?? participants.first
        else { return nil }

        let union = participants.dropFirst().reduce(primary.global) { $0.union($1.global) }
        let scale: CGFloat
        if let cg = primary.controller.screenshotImage?.cgImage(forProposedRect: nil, context: nil, hints: nil),
           let size = primary.controller.screenshotImage?.size, size.width > 0 {
            scale = CGFloat(cg.width) / size.width
        } else {
            scale = primary.controller.screen.backingScaleFactor
        }
        let pixelW = Int(union.width * scale)
        let pixelH = Int(union.height * scale)
        guard pixelW > 0, pixelH > 0 else { return nil }

        let colorSpace = primary.controller.screenshotImage?
            .cgImage(forProposedRect: nil, context: nil, hints: nil)?.colorSpace
            ?? CGColorSpace(name: CGColorSpace.sRGB)!
        guard let ctx = CGContext(data: nil, width: pixelW, height: pixelH,
                                  bitsPerComponent: 8, bytesPerRow: pixelW * 4,
                                  space: colorSpace,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.scaleBy(x: scale, y: scale)
        ctx.clip(to: CGRect(origin: .zero, size: union.size))

        for c in overlayControllers where c.screenshotImage != nil {
            let screenFrame = c.screen.frame
            let drawRect = NSRect(x: screenFrame.minX - union.minX,
                                  y: screenFrame.minY - union.minY,
                                  width: screenFrame.width, height: screenFrame.height)
            ctx.saveGState()
            let nsContext = NSGraphicsContext(cgContext: ctx, flipped: false)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = nsContext
            c.screenshotImage?.draw(in: drawRect, from: .zero, operation: .copy, fraction: 1.0)
            NSGraphicsContext.restoreGraphicsState()
            ctx.restoreGState()
        }

        guard let cgImage = ctx.makeImage() else { return nil }
        return NSImage(cgImage: cgImage, size: union.size)
    }

    func overlayDidChangeSnapMode(_ controller: OverlayWindowController) {
        for other in overlayControllers where other !== controller {
            other.refreshSnapMode()
        }
    }

    func overlayDidRequestRestoreLastSelection(_ controller: OverlayWindowController) {
        if let rect = lastSelectionRect { controller.applySelection(rect) }
    }

    // MARK: - 录屏倒计时

    private func startCountdown(seconds: Int, rect: NSRect, screen: NSScreen, completion: @escaping () -> Void) {
        endCountdown()

        let size = NSSize(width: 140, height: 140)
        let origin = NSPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2)
        let window = NSWindow(contentRect: NSRect(origin: origin, size: size),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let view = CountdownView(frame: NSRect(origin: .zero, size: size))
        view.remaining = seconds
        window.contentView = view
        window.makeKeyAndOrderFront(nil)
        countdownWindow = window

        let border = SelectionBorderOverlay(screen: screen)
        border.setSelectionRect(rect)
        border.orderFrontRegardless()
        countdownBorder = border

        countdownEscMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return event }
            self?.endCountdown()
            return nil
        }

        var remaining = seconds
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            remaining -= 1
            guard let self else { timer.invalidate(); return }
            if remaining <= 0 {
                self.endCountdown()
                completion()
            } else {
                view.remaining = remaining
                view.needsDisplay = true
            }
        }
    }

    private func endCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        countdownWindow?.orderOut(nil)
        countdownWindow = nil
        countdownBorder?.orderOut(nil)
        countdownBorder = nil
        if let monitor = countdownEscMonitor {
            NSEvent.removeMonitor(monitor)
            countdownEscMonitor = nil
        }
    }

    // MARK: - OverlayHost

    func showFailureToast(_ message: String) {
        MacShotController.shared.showToast(message)
    }

    func returnFocusIfNeeded() {
        NSApp.activate(ignoringOtherApps: true)
    }

    func refreshThumbnail(for id: String, image: NSImage, annotationData: CaptureAnnotationData?) {
        for tc in thumbnailControllers where tc.historyEntryID == id {
            tc.updateImage(image, annotationData: annotationData)
        }
    }

    func showFloatingThumbnail(image: NSImage, annotationData: CaptureAnnotationData?, historyEntryID: String?) {
        let enabled = UserDefaults.standard.object(forKey: "showFloatingThumbnail") as? Bool ?? true
        guard enabled else { return }
        guard let screen = NSScreen.preferred else { return }
        let frame = screen.visibleFrame
        let corner = FloatingThumbnailCorner(rawValue: UserDefaults.standard.string(forKey: "thumbnailCorner") ?? "") ?? .bottomRight
        let padding: CGFloat = 16, gap: CGFloat = 8
        let size = FloatingThumbnailController.currentThumbnailSize()
        let x = corner.isLeft ? frame.minX + padding : frame.maxX - size.width - padding
        let y: CGFloat = {
            guard let top = thumbnailControllers.last(where: { !$0.isSuspended }) else {
                return corner.isTop ? frame.maxY - size.height - padding : frame.minY + padding
            }
            let topFrame = top.windowFrame
            return corner.isTop ? topFrame.minY - size.height - gap : topFrame.maxY + gap
        }()

        let controller = FloatingThumbnailController(image: image)
        controller.historyEntryID = historyEntryID
        controller.annotationData = annotationData
        controller.onDismiss = { [weak self] in
            self?.thumbnailControllers.removeAll { $0 === controller }
        }
        controller.onCopy = { [weak controller] in
            guard let image = controller?.image else { return }
            ImageEncoder.copyToClipboard(image)
        }
        controller.onSave = { [weak self, weak controller] in
            guard let self, let image = controller?.image else { return }
            ImageSaveService.save(image, panelLevel: .floating, activateApp: true) { success in
                if success { CaptureSound.shared.play() }
                _ = self
            }
        }
        controller.onSaveAs = { [weak controller] in
            guard let image = controller?.image else { return }
            ImageSaveService.showSavePanel(for: image, panelLevel: .floating, activateApp: true) { _ in }
        }
        controller.onPin = { [weak self, weak controller] in
            guard let self, let image = controller?.image else { return }
            self.showPin(image: image)
        }
        thumbnailControllers.append(controller)
        controller.show(at: NSPoint(x: x, y: y), corner: corner)
    }

    func showPin(image: NSImage) {
        showPin(image: image, source: nil)
    }

    /// 区域截图钉图带上原始框选位置；其他来源（历史、编辑器、缩略图）没有来源位置，居中显示。
    func showPin(image: NSImage, source: PinSource?) {
        let pin = PinWindowController(image: image, source: source)
        pin.delegate = self
        pin.show()
        pins.append(pin)
    }

    func pinWindowDidClose(_ controller: PinWindowController) {
        pins.removeAll { $0 === controller }
    }

    func uploadImage(_ image: NSImage) {
        MacShotController.shared.showToast("上传功能未启用")
    }

    func confirmClearHistory() {
        ScreenshotHistory.shared.clear()
        NotificationCenter.default.post(name: Notification.Name("historyDidChange"), object: nil)
    }

    func runOCR(on image: NSImage) {
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            VisionOCR.performTextAndQRCodeRecognition(cgImage: cg) { result in
                DispatchQueue.main.async {
                    let shouldCopy = true
                    if shouldCopy, !result.copyText.isEmpty {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(result.copyText, forType: .string)
                    }
                    self.ocrController?.close()
                    let ocr = OCRResultController(text: result.text, image: image, qrCodes: result.qrCodes)
                    ocr.onClose = { [weak self, weak ocr] in
                        if self?.ocrController === ocr { self?.ocrController = nil }
                    }
                    self.ocrController = ocr
                    ocr.show()
                    MacShotController.shared.showToast("已识别并复制文本")
                }
            }
        }
    }
}

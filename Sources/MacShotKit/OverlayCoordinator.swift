import AppKit

/// 上游 `OverlayWindowControllerDelegate` 的宿主实现：
/// 把覆盖层的确认/钉图/OCR/录制/滚动等动作接到本应用既有链路。
@MainActor
final class OverlayCoordinator: NSObject, OverlayWindowControllerDelegate, PinWindowControllerDelegate {
    static let shared = OverlayCoordinator()

    private var thumbnailControllers: [FloatingThumbnailController] = []
    private var ocrController: OCRResultController?
    private var pins: [PinWindowController] = []
    private var lastSelectionRect: NSRect?

    enum AutoAction { case none, quickSave, ocr }
    var pendingAutoAction: AutoAction = .none

    // MARK: - Overlay lifecycle

    @discardableResult
    func beginOverlay(screen: NSScreen? = nil, auto: AutoAction = .none,
                      fullScreen: Bool = false) -> OverlayWindowController {
        let screen = screen ?? NSScreen.preferred ?? NSScreen.main ?? NSScreen.screens.first!
        let controller = OverlayWindowController(screen: screen)
        controller.overlayDelegate = self
        pendingAutoAction = auto
        controller.showOverlay()
        if fullScreen {
            controller.applyFullScreenSelection()
            controller.setAutoConfirmMode()
        }
        switch auto {
        case .quickSave: controller.setAutoQuickSaveMode()
        case .ocr: controller.setAutoOCRMode()
        case .none: break
        }
        controller.makeKey()
        return controller
    }

    func beginRecordingSelection(initialFormat: RecordingFormat) {
        let controller = beginOverlay()
        controller.enterRecordingMode()
    }

    func beginScrollSelection() {
        _ = beginOverlay()
    }

    private func finishOverlay(_ controller: OverlayWindowController) {
        controller.dismiss()
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
        defer { finishOverlay(controller) }
        guard let image = capturedImage,
              let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        switch pendingAutoAction {
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
        showPin(image: image)
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
        MacShotController.shared.beginRecording(target: .area(screen, rect), format: .mp4)
    }

    func overlayDidRequestStopRecording(_ controller: OverlayWindowController) {
        MacShotController.shared.stopRecording()
    }

    func overlayDidRequestScrollCapture(_ controller: OverlayWindowController, rect: NSRect, screen: NSScreen) {
        finishOverlay(controller)
        LegacyScrollCaptureController.shared.run(screen: screen, rect: rect)
    }

    func overlayDidRequestStopScrollCapture(_ controller: OverlayWindowController) {
        LegacyScrollCaptureController.shared.requestStop()
    }

    func overlayDidRequestCancelScrollCapture(_ controller: OverlayWindowController) {
        LegacyScrollCaptureController.shared.requestStop()
    }

    func overlayDidRequestToggleAutoScroll(_ controller: OverlayWindowController) {
        LegacyScrollCaptureController.shared.toggleAutoScroll()
    }

    func overlayDidRequestAccessibilityPermission(_ controller: OverlayWindowController) {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    func overlayDidRequestInputMonitoringPermission(_ controller: OverlayWindowController) {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!)
    }

    func overlayDidBeginSelection(_ controller: OverlayWindowController) {}
    func overlayDidChangeSelection(_ controller: OverlayWindowController, globalRect: NSRect) {
        lastSelectionRect = globalRect
    }
    func overlayDidRemoteResizeSelection(_ controller: OverlayWindowController, globalRect: NSRect) {}
    func overlayDidFinishRemoteResize(_ controller: OverlayWindowController, globalRect: NSRect) {}
    func overlayCrossScreenImage(_ controller: OverlayWindowController) -> NSImage? { nil }
    func overlayDidChangeSnapMode(_ controller: OverlayWindowController) {}
    func overlayDidRequestRestoreLastSelection(_ controller: OverlayWindowController) {
        if let rect = lastSelectionRect { controller.applySelection(rect) }
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
        let pin = PinWindowController(image: image)
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

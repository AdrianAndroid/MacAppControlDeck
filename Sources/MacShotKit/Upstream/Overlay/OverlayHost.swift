import AppKit

/// 上游通过 `NSApp.delegate as? AppDelegate` 调用的宿主能力，
/// 在本仓库由 `MacShotController` 实现并通过 `overlayHost` 注入。
@MainActor protocol OverlayHost: AnyObject {
    func showFailureToast(_ message: String)
    func returnFocusIfNeeded()
    func refreshThumbnail(for id: String, image: NSImage, annotationData: CaptureAnnotationData?)
    func showFloatingThumbnail(image: NSImage, annotationData: CaptureAnnotationData?, historyEntryID: String?)
    func showPin(image: NSImage)
    func uploadImage(_ image: NSImage)
    func confirmClearHistory()
    func runOCR(on image: NSImage)
}

@MainActor var overlayHost: OverlayHost?

extension OverlayHost {
    func showFloatingThumbnail(image: NSImage) {
        showFloatingThumbnail(image: image, annotationData: nil, historyEntryID: nil)
    }
}

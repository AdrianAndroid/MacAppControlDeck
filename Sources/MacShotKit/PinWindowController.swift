import AppKit
import SwiftUI

final class PinWindowController {
    static let shared = PinWindowController()

    private var pins: [NSWindow] = []

    func pin(_ image: CGImage) {
        let imageSize = CGSize(width: image.width, height: image.height)
        let maxSize = CGSize(width: 720, height: 520)
        let scale = min(1, min(maxSize.width / imageSize.width,
                               maxSize.height / imageSize.height))
        let displaySize = CGSize(width: imageSize.width * scale,
                                 height: imageSize.height * scale)

        let view = PinImageView(image: image,
                                displaySize: displaySize,
                                onClose: { [weak self] in self?.closeLast() })
        let window = NSPanel(contentRect: CGRect(origin: .zero, size: displaySize),
                             styleMask: [.borderless, .nonactivatingPanel],
                             backing: .buffered, defer: false)
        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.contentView = NSHostingView(rootView: view)
        window.isReleasedWhenClosed = false
        window.isMovableByWindowBackground = true

        let mouse = NSEvent.mouseLocation
        let visible = (NSScreen.main?.visibleFrame ?? .zero)
        let origin = CGPoint(x: min(max(mouse.x - displaySize.width / 2, visible.minX + 20),
                                    visible.maxX - displaySize.width - 20),
                             y: min(max(mouse.y - displaySize.height / 2, visible.minY + 20),
                                    visible.maxY - displaySize.height - 20))
        window.setFrameOrigin(origin)
        window.orderFrontRegardless()
        pins.append(window)
    }

    private func closeLast() {
        pins.popLast()?.close()
    }
}

private struct PinImageView: View {
    let image: CGImage
    let displaySize: CGSize
    let onClose: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(nsImage: NSImage(cgImage: image,
                                   size: NSSize(width: image.width, height: image.height)))
                .resizable()
                .frame(width: displaySize.width, height: displaySize.height)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.6)))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.white, .black.opacity(0.65))
            }
            .buttonStyle(.plain)
            .padding(6)
        }
    }
}

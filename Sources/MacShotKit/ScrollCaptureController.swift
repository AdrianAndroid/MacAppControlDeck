import AppKit
import CoreGraphics
import CoreImage

/// 滚动截图：自动向下滚动选区，抓取多帧后按重叠区域拼接成一张长图。
/// 只在截图模块内部使用，不涉及手机遥控。
final class ScrollCaptureController {
    static let shared = ScrollCaptureController()

    private var isRunning = false

    func begin() {
        guard !isRunning else { return }
        guard CGPreflightScreenCaptureAccess() else {
            _ = MacShotController.shared.ensurePermission()
            return
        }
        AreaSelectionController.shared.begin { [weak self] screen, rect in
            self?.run(screen: screen, rect: rect)
        }
    }

    private func run(screen: NSScreen, rect: CGRect) {
        isRunning = true
        let topLeftCenter = CaptureGeometry.globalTopLeftPoint(
            fromScreenPoint: NSPoint(x: rect.midX, y: rect.midY))
        let savedMouse = NSEvent.mouseLocation
        CGWarpMouseCursorPosition(topLeftCenter)

        var frames: [CGImage] = []
        let maxSteps = 6
        let scrollAmount = Int32(max(80, rect.height * 0.65))

        func finish() {
            CGWarpMouseCursorPosition(CaptureGeometry.globalTopLeftPoint(
                fromScreenPoint: savedMouse))
            isRunning = false
            guard !frames.isEmpty else {
                MacShotController.shared.showAlert("滚动截图失败", "没有采集到画面。")
                return
            }
            guard let stitched = ScrollStitcher.stitch(frames: frames) else {
                MacShotController.shared.showAlert("滚动截图失败", "拼接图片失败。")
                return
            }
            MacShotController.shared.saveEditedImage(stitched)
        }

        func step(_ index: Int) {
            guard index < maxSteps else {
                finish()
                return
            }
            if let image = ScreenCaptureService.capture(area: rect, on: screen) {
                frames.append(image)
            }
            guard index > 0 else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    self.postScroll(amount: scrollAmount, at: topLeftCenter)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                        step(index + 1)
                    }
                }
                return
            }
            self.postScroll(amount: scrollAmount, at: topLeftCenter)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                step(index + 1)
            }
        }

        DispatchQueue.main.async {
            step(0)
        }
    }

    private func postScroll(amount: Int32, at point: NSPoint) {
        guard let event = CGEvent(scrollWheelEvent2Source: nil,
                                  units: .pixel,
                                  wheelCount: 1,
                                  wheel1: -amount,
                                  wheel2: 0,
                                  wheel3: 0) else { return }
        event.location = point
        event.post(tap: .cghidEventTap)
    }
}

enum ScrollStitcher {
    static func stitch(frames: [CGImage]) -> CGImage? {
        guard let first = frames.first else { return nil }
        let width = first.width
        var overlaps: [Int] = []
        for index in 1..<frames.count {
            overlaps.append(findOverlap(previous: frames[index - 1], next: frames[index]))
        }

        let totalHeight = frames.enumerated().reduce(0) { partial, item in
            let overlap = item.offset == 0 ? 0 : overlaps[item.offset - 1]
            return partial + item.element.height - overlap
        }
        guard totalHeight > 0 else { return nil }
        let fullRect = CGRect(x: 0, y: 0,
                              width: CGFloat(width), height: CGFloat(totalHeight))
        var canvas = CIImage(color: CIColor.clear).cropped(to: fullRect)
        var y: CGFloat = 0

        // 倒序拼：最后一帧在最底部，第一帧在最顶部；每帧只保留下方新增部分。
        for index in stride(from: frames.count - 1, through: 0, by: -1) {
            let frame = frames[index]
            let overlap = index == 0 ? 0 : overlaps[index - 1]
            let pieceHeight = frame.height - overlap
            guard pieceHeight > 0 else { continue }
            let piece = CIImage(cgImage: frame)
                .cropped(to: CGRect(x: 0, y: 0,
                                    width: CGFloat(width),
                                    height: CGFloat(pieceHeight)))
                .transformed(by: CGAffineTransform(translationX: 0, y: y))
            canvas = piece.composited(over: canvas)
            y += CGFloat(pieceHeight)
        }

        guard let output = CIContext().createCGImage(canvas, from: fullRect) else { return nil }
        return output
    }

    private static func findOverlap(previous: CGImage, next: CGImage) -> Int {
        let height = min(previous.height, next.height)
        let width = min(previous.width, next.width)
        guard let prev = grayBuffer(previous, width: width, height: height),
              let nextBuf = grayBuffer(next, width: width, height: height)
        else { return max(20, height / 4) }

        let strip = min(36, height / 5)
        guard strip > 4 else { return max(20, height / 4) }
        var bestOffset = max(20, height / 3)
        var bestScore = Int.max
        for offset in stride(from: 8, through: height - strip, by: 2) {
            var score = 0
            for row in 0..<strip {
                let prevRow = (height - strip + row) * width
                let nextRow = (offset + row) * width
                for x in stride(from: 0, to: width, by: 3) {
                    score += abs(Int(prev[prevRow + x]) - Int(nextBuf[nextRow + x]))
                }
            }
            if score < bestScore {
                bestScore = score
                bestOffset = offset
            }
        }
        let samples = max(1, strip * (width / 3))
        let average = bestScore / samples
        return average <= 18 ? bestOffset : max(20, height / 3)
    }

    private static func grayBuffer(_ image: CGImage, width: Int, height: Int) -> [UInt8]? {
        guard let context = CGContext(data: nil,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: width,
                                      space: CGColorSpaceCreateDeviceGray(),
                                      bitmapInfo: CGImageAlphaInfo.none.rawValue)
        else { return nil }
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let data = context.data else { return nil }
        let buffer = data.assumingMemoryBound(to: UInt8.self)
        return Array(UnsafeBufferPointer(start: buffer, count: width * height))
    }
}

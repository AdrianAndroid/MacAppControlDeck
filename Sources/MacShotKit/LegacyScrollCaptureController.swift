import AppKit
import CoreGraphics
import CoreImage

/// 滚动截图：自动向下滚动选区，抓取多帧后按重叠区域拼接成一张长图。
/// 只在截图模块内部使用，不涉及手机遥控。
@MainActor final class LegacyScrollCaptureController {
    static let shared = LegacyScrollCaptureController()

    private var isRunning = false
    private var shouldStop = false

    func requestStop() { shouldStop = true }

    func toggleAutoScroll() { /* 由覆盖层的自动滚动控制 */ }
    private let hud = ScrollCaptureHUD()

    func begin() {
        MacShotController.shared.scrollCapture()
    }

    private func legacyBegin() {
        guard !isRunning else { return }
        guard CGPreflightScreenCaptureAccess() else {
            _ = MainActor.assumeIsolated { MacShotController.shared.ensurePermission() }
            return
        }
    }

    func run(screen: NSScreen, rect: CGRect) {
        isRunning = true
        shouldStop = false
        let topLeftCenter = CaptureGeometry.globalTopLeftPoint(
            fromScreenPoint: NSPoint(x: rect.midX, y: rect.midY))
        let savedMouse = NSEvent.mouseLocation
        CGWarpMouseCursorPosition(topLeftCenter)

        var frames: [CGImage] = []
        let maxSteps = 25
        let scrollAmount = Int32(max(80, rect.height * 0.65))

        hud.show { [weak self] in self?.shouldStop = true }
        hud.update(frames: 0)

        func finish() {
            CGWarpMouseCursorPosition(CaptureGeometry.globalTopLeftPoint(
                fromScreenPoint: savedMouse))
            hud.hide()
            isRunning = false
            guard !frames.isEmpty else {
                MacShotController.shared.showAlert("滚动截图失败", "没有采集到画面。")
                return
            }
            guard let stitched = LegacyScrollStitcher.stitch(frames: frames) else {
                MacShotController.shared.showAlert("滚动截图失败", "拼接图片失败。")
                return
            }
            MacShotController.shared.saveEditedImage(stitched)
        }

        func step(_ index: Int) {
            guard !shouldStop else {
                finish()
                return
            }
            guard index < maxSteps else {
                finish()
                return
            }
            if let image = LegacyScreenCaptureService.capture(area: rect, on: screen) {
                if let last = frames.last, LegacyScrollFrameComparator.isSame(last, image) {
                    // 页面已到底：不再追加重复帧，直接拼接。
                    finish()
                    return
                }
                frames.append(image)
                hud.update(frames: frames.count)
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

enum LegacyScrollStitcher {
    static func stitch(frames: [CGImage]) -> CGImage? {
        guard let first = frames.first else { return nil }
        let width = first.width
        let staticRanges = staticColumns(frames)
        var overlaps: [Int] = []
        for index in 1..<frames.count {
            overlaps.append(findOverlap(previous: frames[index - 1], next: frames[index],
                                        ignoring: staticRanges))
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

        // 固定侧栏：用第一帧的列向下平铺，避免每帧拼接处重复出现侧栏。
        if !staticRanges.isEmpty, frames.count > 1 {
            let firstCI = CIImage(cgImage: first)
            for range in staticRanges {
                let column = firstCI.cropped(to: CGRect(x: range.lowerBound, y: 0,
                                                        width: range.count,
                                                        height: first.height))
                var ty: CGFloat = 0
                while ty < CGFloat(totalHeight) {
                    canvas = column.transformed(by: CGAffineTransform(translationX: 0, y: ty))
                        .composited(over: canvas)
                    ty += CGFloat(first.height)
                }
            }
        }

        guard let output = CIContext().createCGImage(canvas, from: fullRect) else { return nil }
        return output
    }

    /// 找出在所有帧中内容不变的列（固定侧栏 / 固定工具栏），返回像素列范围。
    static func staticColumns(_ frames: [CGImage]) -> [Range<Int>] {
        guard frames.count >= 2, let first = frames.first, let last = frames.last,
              first.width == last.width, first.height == last.height,
              let a = grayBuffer(first, width: first.width, height: first.height),
              let b = grayBuffer(last, width: last.width, height: last.height) else { return [] }
        let width = first.width
        var staticCols: [Bool] = Array(repeating: true, count: width)
        let rowStep = max(8, first.height / 32)
        for x in 0..<width {
            var diff = 0
            var samples = 0
            for y in stride(from: 0, to: first.height, by: rowStep) {
                diff += abs(Int(a[y * width + x]) - Int(b[y * width + x]))
                samples += 1
            }
            staticCols[x] = samples > 0 && diff / samples <= 2
        }
        var ranges: [Range<Int>] = []
        var start: Int?
        for x in 0..<width {
            if staticCols[x] {
                if start == nil { start = x }
            } else if let s = start {
                if x - s >= 6 { ranges.append(s..<x) }
                start = nil
            }
        }
        if let s = start, width - s >= 6 { ranges.append(s..<width) }
        return ranges
    }

    private static func findOverlap(previous: CGImage, next: CGImage,
                                    ignoring staticRanges: [Range<Int>]) -> Int {
        let height = min(previous.height, next.height)
        let width = min(previous.width, next.width)
        guard let prev = grayBuffer(previous, width: width, height: height),
              let nextBuf = grayBuffer(next, width: width, height: height)
        else { return max(20, height / 4) }

        let strip = min(36, height / 5)
        guard strip > 4 else { return max(20, height / 4) }
        let ignore = Set(staticRanges.flatMap { Array($0) })

        func score(offset: Int, step: Int) -> Int {
            var total = 0
            var samples = 0
            for row in 0..<strip {
                let prevRow = (height - strip + row) * width
                let nextRow = (offset + row) * width
                for x in stride(from: 0, to: width, by: step) where !ignore.contains(x) {
                    total += abs(Int(prev[prevRow + x]) - Int(nextBuf[nextRow + x]))
                    samples += 1
                }
            }
            return samples > 0 ? total / samples : Int.max
        }

        let maxOffset = height - strip
        var bestOffset = max(20, height / 3)
        var bestScore = Int.max
        var coarse = 8
        while coarse <= maxOffset {
            let value = score(offset: coarse, step: 6)
            if value < bestScore {
                bestScore = value
                bestOffset = coarse
            }
            coarse += 4
        }
        // 细搜：在粗搜最优附近 ±4px 再逐像素确认。
        for offset in max(8, bestOffset - 4)...min(maxOffset, bestOffset + 4) {
            let value = score(offset: offset, step: 3)
            if value < bestScore {
                bestScore = value
                bestOffset = offset
            }
        }
        return bestScore <= 18 ? bestOffset : max(20, height / 3)
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


/// 快速判断两帧是否相同（页面已经滚动到底）。
enum LegacyScrollFrameComparator {
    static func isSame(_ a: CGImage, _ b: CGImage) -> Bool {
        let size = 32
        guard let ga = gray(a, size: size), let gb = gray(b, size: size) else { return false }
        var diff = 0
        for i in 0..<(size * size) { diff += abs(Int(ga[i]) - Int(gb[i])) }
        return diff / (size * size) <= 2
    }

    private static func gray(_ image: CGImage, size: Int) -> [UInt8]? {
        guard let context = CGContext(data: nil, width: size, height: size,
                                      bitsPerComponent: 8, bytesPerRow: size,
                                      space: CGColorSpaceCreateDeviceGray(),
                                      bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        context.interpolationQuality = .low
        context.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))
        guard let data = context.data else { return nil }
        return Array(UnsafeBufferPointer(start: data.assumingMemoryBound(to: UInt8.self),
                                         count: size * size))
    }
}

/// 滚动截图 HUD：显示已捕获帧数与停止按钮。
final class ScrollCaptureHUD {
    private var panel: NSPanel?
    private var label = NSTextField(labelWithString: "滚动截图中…")
    private var onStop: (() -> Void)?

    func show(onStop: @escaping () -> Void) {
        self.onStop = onStop
        hide()

        let size = CGSize(width: 210, height: 40)
        let panel = NSPanel(contentRect: CGRect(origin: .zero, size: size),
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isReleasedWhenClosed = false

        let content = NSView(frame: CGRect(origin: .zero, size: size))
        content.wantsLayer = true
        content.layer?.cornerRadius = 10
        content.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.8).cgColor

        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .white
        label.frame = CGRect(x: 14, y: 12, width: 110, height: 16)
        content.addSubview(label)

        let stop = NSButton(title: "停止", target: self, action: #selector(stopTapped))
        stop.bezelStyle = .rounded
        stop.controlSize = .small
        stop.frame = CGRect(x: 134, y: 7, width: 62, height: 26)
        content.addSubview(stop)

        panel.contentView = content
        if let screen = NSScreen.main {
            panel.setFrameOrigin(CGPoint(x: screen.frame.midX - size.width / 2,
                                         y: screen.visibleFrame.maxY - size.height - 16))
        }
        panel.orderFrontRegardless()
        self.panel = panel
    }

    func update(frames: Int) {
        label.stringValue = "滚动截图中… 已捕获 \(frames) 帧"
    }

    func hide() {
        panel?.orderOut(nil)
        panel = nil
    }

    @objc private func stopTapped() {
        onStop?()
    }
}

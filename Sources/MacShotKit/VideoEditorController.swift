import AppKit
import AVFoundation
import AVKit
import CoreImage
import SwiftUI

final class VideoEditorController {
    static let shared = VideoEditorController()
    private var window: NSWindow?

    func present(_ url: URL) {
        let view = VideoEditorView(url: url,
                                   onClose: { [weak self] in self?.window?.close(); self?.window = nil })
        if window == nil {
            let hosting = NSHostingController(rootView: view)
            let w = NSWindow(contentViewController: hosting)
            w.title = "录屏编辑"
            w.styleMask = [.titled, .closable, .resizable]
            w.isReleasedWhenClosed = false
            w.setContentSize(NSSize(width: 860, height: 640))
            w.center()
            window = w
        } else if let h = window?.contentViewController as? NSHostingController<VideoEditorView> {
            h.rootView = view
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

struct VideoCutRange: Identifiable, Equatable {
    var id = UUID()
    var start: Double
    var end: Double
}

struct VideoTextOverlay: Identifiable, Equatable {
    var id = UUID()
    var text: String
    var start: Double
    var end: Double
}

struct VideoEditSpec {
    var trimStart: Double
    var trimEnd: Double
    var cuts: [VideoCutRange]
    var speed: Double
    var texts: [VideoTextOverlay]

    /// 源时间 → 输出时间（扣除剪切区间并除以倍速）。
    func outputTime(for sourceTime: Double) -> Double {
        let clamped = min(max(sourceTime, trimStart), trimEnd)
        var keptBefore: Double = 0
        for cut in cuts where cut.end > trimStart {
            let s = max(cut.start, trimStart)
            let e = min(cut.end, clamped)
            if e > s { keptBefore += e - s }
        }
        let inTrim = max(0, clamped - trimStart) - keptBefore
        return inTrim / max(speed, 0.01)
    }
}

private struct VideoEditorView: View {
    let url: URL
    let onClose: () -> Void

    @State private var player = AVPlayer()
    @State private var duration: Double = 1
    @State private var trimStart: Double = 0
    @State private var trimEnd: Double = 1
    @State private var cuts: [VideoCutRange] = []
    @State private var speed: Double = 1
    @State private var texts: [VideoTextOverlay] = []
    @State private var newText = ""
    @State private var keepSystemAudio = true
    @State private var keepMicAudio = true
    @State private var systemVolume: Double = 1
    @State private var micVolume: Double = 1
    @State private var exporting = false
    @State private var progress: Double = 0
    @State private var exportSession: AVAssetExportSession?
    @State private var progressTimer: Timer?

    private var spec: VideoEditSpec {
        VideoEditSpec(trimStart: trimStart, trimEnd: trimEnd,
                      cuts: cuts.sorted { $0.start < $1.start },
                      speed: speed, texts: texts)
    }

    var body: some View {
        VStack(spacing: 10) {
            PlayerLayerView(player: player)
                .frame(minHeight: 300)
                .background(Color.black)

            timeline
                .padding(.horizontal, 12)

            HStack(spacing: 16) {
                Label("\(time(trimStart)) – \(time(trimEnd))", systemImage: "scissors")
                    .font(.system(size: 11, design: .monospaced))
                Text("倍速")
                Picker("", selection: $speed) {
                    Text("0.5×").tag(0.5)
                    Text("1×").tag(1.0)
                    Text("1.5×").tag(1.5)
                    Text("2×").tag(2.0)
                    Text("4×").tag(4.0)
                }
                .labelsHidden()
                .frame(width: 80)
                Button("剪切当前 ±1 秒") { addCutAroundPlayhead() }
                Spacer()
            }
            .padding(.horizontal, 12)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("保留系统声音", isOn: $keepSystemAudio)
                    HStack {
                        Image(systemName: "speaker.wave.2")
                        Slider(value: $systemVolume, in: 0...1).frame(width: 90)
                        Text("\(Int(systemVolume * 100))%")
                            .font(.system(size: 10, design: .monospaced))
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("保留麦克风旁白", isOn: $keepMicAudio)
                    HStack {
                        Image(systemName: "mic")
                        Slider(value: $micVolume, in: 0...1).frame(width: 90)
                        Text("\(Int(micVolume * 100))%")
                            .font(.system(size: 10, design: .monospaced))
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 12)

            HStack(spacing: 10) {
                TextField("字幕文字", text: $newText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
                Button("在当前位置添加字幕") { addTextAtPlayhead() }
                if !texts.isEmpty {
                    Text("\(texts.count) 条字幕").font(.caption).foregroundStyle(.secondary)
                    Button("清空字幕") { texts = [] }
                }
                Spacer()
            }
            .padding(.horizontal, 12)

            if !texts.isEmpty || !cuts.isEmpty {
                editLists
                    .padding(.horizontal, 12)
            }

            HStack(spacing: 12) {
                if exporting {
                    ProgressView(value: progress)
                        .frame(width: 160)
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 11, design: .monospaced))
                    Button("取消") { cancelExport() }
                }
                Spacer()
                Button("导出 GIF…") { exportGIF() }
                    .disabled(exporting)
                Button("在 Finder 显示") {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
                Button(exporting ? "导出中…" : "另存为 MP4…") { saveAs() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(exporting)
                Button("关闭", action: onClose)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .onAppear {
            player.replaceCurrentItem(with: AVPlayerItem(url: url))
            Task {
                if let d = try? await AVURLAsset(url: url).load(.duration) {
                    let seconds = CMTimeGetSeconds(d)
                    if seconds.isFinite && seconds > 0 {
                        duration = seconds
                        trimEnd = seconds
                    }
                }
            }
        }
        .onDisappear { progressTimer?.invalidate() }
    }

    private var timeline: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.18))
                    let total = max(trimEnd - trimStart, 0.1)
                    ForEach(cuts) { cut in
                        let start = max(cut.start, trimStart)
                        let end = min(cut.end, trimEnd)
                        if end > start {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.red.opacity(0.65))
                                .frame(width: geo.size.width * (end - start) / total)
                                .offset(x: geo.size.width * (start - trimStart) / total)
                        }
                    }
                }
            }
            .frame(height: 18)

            HStack {
                Text(time(trimStart)).font(.system(size: 11, design: .monospaced))
                Slider(value: $trimStart, in: 0...max(duration - 0.1, 0.1))
                    .onChange(of: trimStart) { _, v in
                        if trimEnd <= v + 0.1 { trimEnd = min(v + 0.1, duration) }
                        player.seek(to: CMTime(seconds: v, preferredTimescale: 600))
                    }
                Slider(value: $trimEnd, in: 0...duration)
                    .onChange(of: trimEnd) { _, v in
                        if trimStart >= v - 0.1 { trimStart = max(v - 0.1, 0) }
                    }
                Text(time(trimEnd)).font(.system(size: 11, design: .monospaced))
            }
        }
    }

    private var editLists: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(cuts) { cut in
                    HStack {
                        Image(systemName: "scissors").font(.caption)
                        Text("剪切 \(time(cut.start)) – \(time(cut.end))")
                            .font(.system(size: 11, design: .monospaced))
                        Spacer()
                        Button {
                            cuts.removeAll { $0.id == cut.id }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                        }
                        .buttonStyle(.plain)
                    }
                }
                ForEach(texts) { overlay in
                    HStack {
                        Image(systemName: "textformat").font(.caption)
                        Text("\(overlay.text)  \(time(overlay.start)) – \(time(overlay.end))")
                            .font(.system(size: 11))
                            .lineLimit(1)
                        Spacer()
                        Button {
                            texts.removeAll { $0.id == overlay.id }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 78)
    }

    private func time(_ s: Double) -> String {
        String(format: "%02d:%05.2f", Int(s) / 60, s.truncatingRemainder(dividingBy: 60))
    }

    private var playhead: Double {
        let t = CMTimeGetSeconds(player.currentTime())
        return t.isFinite ? max(trimStart, min(t, trimEnd)) : trimStart
    }

    private func addCutAroundPlayhead() {
        let start = max(trimStart, playhead - 1)
        let end = min(trimEnd, playhead + 1)
        guard end - start >= 0.2 else { return }
        cuts.append(VideoCutRange(start: start, end: end))
        cuts.sort { $0.start < $1.start }
    }

    private func addTextAtPlayhead() {
        let value = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        let start = playhead
        texts.append(VideoTextOverlay(text: value, start: start, end: min(trimEnd, start + 3)))
        newText = ""
    }

    private func saveAs() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.mpeg4Movie]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = url.deletingPathExtension().lastPathComponent + " edited.mp4"
        NSApp.activate(ignoringOtherApps: true)
        panel.begin { response in
            guard response == .OK, let dest = panel.url else { return }
            startExport(dest: dest)
        }
    }

    private func startExport(dest: URL) {
        exporting = true
        progress = 0
        let spec = self.spec
        let options = VideoExportOptions(keepSystemAudio: keepSystemAudio,
                                         keepMicAudio: keepMicAudio,
                                         systemVolume: Float(systemVolume),
                                         micVolume: Float(micVolume))
        VideoEditorExporter.export(source: url, spec: spec, options: options, to: dest,
                                   onSession: { session in
            exportSession = session
            startProgressTimer()
        }) { result in
            DispatchQueue.main.async {
                exporting = false
                exportSession = nil
                progressTimer?.invalidate()
                if case .failure(let error) = result {
                    let alert = NSAlert()
                    alert.messageText = "导出失败"
                    alert.informativeText = error.localizedDescription
                    alert.runModal()
                }
            }
        }
    }

    private func startProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { _ in
            Task { @MainActor in
                if let session = exportSession, session.status == .exporting {
                    progress = Double(session.progress)
                }
            }
        }
    }

    private func cancelExport() {
        exportSession?.cancelExport()
        exporting = false
        progressTimer?.invalidate()
    }

    private func exportGIF() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.gif]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = url.deletingPathExtension().lastPathComponent + ".gif"
        NSApp.activate(ignoringOtherApps: true)
        panel.begin { response in
            guard response == .OK, let dest = panel.url else { return }
            exporting = true
            progress = 0
            VideoEditorExporter.exportGIF(source: url, spec: spec, to: dest) { result in
                DispatchQueue.main.async {
                    exporting = false
                    if case .failure(let error) = result {
                        let alert = NSAlert()
                        alert.messageText = "GIF 导出失败"
                        alert.informativeText = error.localizedDescription
                        alert.runModal()
                    }
                }
            }
        }
    }
}

private struct PlayerLayerView: NSViewRepresentable {
    let player: AVPlayer
    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        v.wantsLayer = true
        let layer = AVPlayerLayer(player: player)
        layer.videoGravity = .resizeAspect
        layer.frame = v.bounds
        layer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        v.layer?.addSublayer(layer)
        return v
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

struct VideoExportOptions {
    var keepSystemAudio: Bool
    var keepMicAudio: Bool
    var systemVolume: Float
    var micVolume: Float
}

enum VideoEditorExporter {
    static func export(source: URL,
                       spec: VideoEditSpec,
                       options: VideoExportOptions,
                       to dest: URL,
                       onSession: ((AVAssetExportSession) -> Void)? = nil,
                       completion: @escaping (Result<Void, Error>) -> Void) {
        let asset = AVURLAsset(url: source)
        let composition = AVMutableComposition()
        let kept = keptRanges(spec: spec)
        guard !kept.isEmpty else {
            completion(.failure(exportError("没有可导出的片段"))); return
        }
        guard let videoTrack = asset.tracks(withMediaType: .video).first,
              let compVideo = composition.addMutableTrack(withMediaType: .video,
                                                          preferredTrackID: kCMPersistentTrackID_Invalid)
        else {
            completion(.failure(exportError("没有视频轨道"))); return
        }

        var cursor = CMTime.zero
        var params: [AVMutableAudioMixInputParameters] = []
        let audioTracks = asset.tracks(withMediaType: .audio)
        var compAudios: [(AVMutableCompositionTrack, Int)] = []
        for (index, _) in audioTracks.prefix(2).enumerated() {
            let keep = index == 0 ? options.keepSystemAudio : options.keepMicAudio
            if keep, let compAudio = composition.addMutableTrack(
                withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
                compAudios.append((compAudio, index))
            }
        }

        do {
            for range in kept {
                let cmRange = CMTimeRange(start: CMTime(seconds: range.lowerBound, preferredTimescale: 600),
                                          end: CMTime(seconds: range.upperBound, preferredTimescale: 600))
                try compVideo.insertTimeRange(cmRange, of: videoTrack, at: cursor)
                for (track, index) in compAudios where index < audioTracks.count {
                    try? track.insertTimeRange(cmRange, of: audioTracks[index], at: cursor)
                }
                cursor = CMTimeAdd(cursor, cmRange.duration)
            }

            if spec.speed != 1, cursor > .zero {
                let target = CMTimeMultiplyByFloat64(cursor, multiplier: 1 / spec.speed)
                composition.scaleTimeRange(CMTimeRange(start: .zero, duration: cursor),
                                           toDuration: target)
            }

            for (track, index) in compAudios {
                let param = AVMutableAudioMixInputParameters(track: track)
                param.setVolume(index == 0 ? options.systemVolume : options.micVolume, at: .zero)
                params.append(param)
            }
        } catch {
            completion(.failure(error)); return
        }

        guard let session = AVAssetExportSession(asset: composition,
                                                 presetName: AVAssetExportPresetHighestQuality) else {
            completion(.failure(exportError("无法创建导出会话"))); return
        }

        if !spec.texts.isEmpty {
            session.videoComposition = makeVideoComposition(asset: composition, texts: spec.texts)
        }
        if !params.isEmpty {
            let mix = AVMutableAudioMix()
            mix.inputParameters = params
            session.audioMix = mix
        }
        session.outputURL = dest
        session.outputFileType = .mp4
        session.shouldOptimizeForNetworkUse = true
        onSession?(session)
        session.exportAsynchronously {
            switch session.status {
            case .completed: completion(.success(()))
            case .cancelled: completion(.failure(exportError("已取消")))
            case .failed:
                completion(.failure(session.error ?? exportError("导出失败")))
            default: break
            }
        }
    }

    static func exportGIF(source: URL, spec: VideoEditSpec, to dest: URL,
                          completion: @escaping (Result<Void, Error>) -> Void) {
        let asset = AVURLAsset(url: source)
        let kept = keptRanges(spec: spec)
        guard !kept.isEmpty else {
            completion(.failure(exportError("没有可导出的片段"))); return
        }
        let composition = AVMutableComposition()
        guard let videoTrack = asset.tracks(withMediaType: .video).first,
              let compVideo = composition.addMutableTrack(withMediaType: .video,
                                                          preferredTrackID: kCMPersistentTrackID_Invalid)
        else {
            completion(.failure(exportError("没有视频轨道"))); return
        }
        do {
            var cursor = CMTime.zero
            for range in kept {
                let cmRange = CMTimeRange(start: CMTime(seconds: range.lowerBound, preferredTimescale: 600),
                                          end: CMTime(seconds: range.upperBound, preferredTimescale: 600))
                try compVideo.insertTimeRange(cmRange, of: videoTrack, at: cursor)
                cursor = CMTimeAdd(cursor, cmRange.duration)
            }
            if spec.speed != 1, cursor > .zero {
                composition.scaleTimeRange(CMTimeRange(start: .zero, duration: cursor),
                                           toDuration: CMTimeMultiplyByFloat64(cursor,
                                                                               multiplier: 1 / spec.speed))
            }
        } catch {
            completion(.failure(error)); return
        }

        let fps: Int32 = 10
        let generator = AVAssetImageGenerator(asset: composition)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        generator.maximumSize = CGSize(width: 900, height: 900)

        var frames: [(CGImage, CMTime)] = []
        let duration = CMTimeGetSeconds(composition.duration)
        guard duration.isFinite, duration > 0 else {
            completion(.failure(exportError("视频时长为空"))); return
        }
        var t: Double = 0
        let limit = min(duration, 120)
        while t <= limit {
            let time = CMTime(seconds: t, preferredTimescale: 600)
            if let cg = try? generator.copyCGImage(at: time, actualTime: nil) {
                frames.append((cg, time))
            }
            t += 1.0 / Double(fps)
        }
        guard !frames.isEmpty else {
            completion(.failure(exportError("没有采集到画面"))); return
        }
        do {
            try GIFEncoder.write(frames: frames, maxWidth: 900, to: dest)
            completion(.success(()))
        } catch {
            completion(.failure(error))
        }
    }

    static func keptRanges(spec: VideoEditSpec) -> [ClosedRange<Double>] {
        let start = max(0, spec.trimStart)
        let end = max(start + 0.1, spec.trimEnd)
        var kept: [ClosedRange<Double>] = [start...end]
        for cut in spec.cuts.sorted(by: { $0.start < $1.start }) {
            guard cut.end > cut.start else { continue }
            var next: [ClosedRange<Double>] = []
            for range in kept {
                if cut.end <= range.lowerBound || cut.start >= range.upperBound {
                    next.append(range)
                    continue
                }
                if cut.start > range.lowerBound {
                    next.append(range.lowerBound...min(cut.start, range.upperBound))
                }
                if cut.end < range.upperBound {
                    next.append(max(cut.end, range.lowerBound)...range.upperBound)
                }
            }
            kept = next
        }
        return kept.filter { $0.upperBound - $0.lowerBound >= 0.08 }
    }

    static func makeVideoComposition(asset: AVAsset,
                                     texts: [VideoTextOverlay]) -> AVMutableVideoComposition {
        let renders: [(CGImage, Double, Double)] = texts.compactMap { overlay in
            guard let image = renderText(overlay.text) else { return nil }
            return (image, overlay.start, overlay.end)
        }
        return AVMutableVideoComposition(asset: asset) { request in
            var image = request.sourceImage
            let extent = image.extent
            let current = CMTimeGetSeconds(request.compositionTime)
            for (cg, start, end) in renders where current >= start && current <= end {
                let ci = CIImage(cgImage: cg)
                let scale = min(1, extent.width * 0.9 / max(ci.extent.width, 1))
                let width = ci.extent.width * scale
                let height = ci.extent.height * scale
                let x = extent.minX + (extent.width - width) / 2
                let y = extent.minY + extent.height * 0.06
                let placed = ci.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
                    .transformed(by: CGAffineTransform(translationX: x, y: y))
                image = placed.composited(over: image)
            }
            request.finish(with: image.cropped(to: extent), context: nil)
        }
    }

    private static func renderText(_ text: String) -> CGImage? {
        let font = NSFont.systemFont(ofSize: 44, weight: .semibold)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white,
            .strokeColor: NSColor.black.withAlphaComponent(0.8),
            .strokeWidth: -3.0
        ]
        let size = (text as NSString).size(withAttributes: attrs)
        let canvas = NSSize(width: size.width + 32, height: size.height + 20)
        let image = NSImage(size: canvas)
        image.lockFocus()
        NSColor.black.withAlphaComponent(0.45).setFill()
        NSBezierPath(roundedRect: CGRect(origin: .zero, size: canvas),
                     xRadius: 10, yRadius: 10).fill()
        (text as NSString).draw(at: CGPoint(x: 16, y: 10), withAttributes: attrs)
        image.unlockFocus()
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.cgImage
    }

    private static func exportError(_ message: String) -> NSError {
        NSError(domain: "MacShotKit", code: 10,
                userInfo: [NSLocalizedDescriptionKey: message])
    }
}

import AppKit
import AVFoundation
import AVKit
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
            w.setContentSize(NSSize(width: 760, height: 560))
            w.center()
            window = w
        } else if let h = window?.contentViewController as? NSHostingController<VideoEditorView> {
            h.rootView = view
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

private struct VideoEditorView: View {
    let url: URL
    let onClose: () -> Void

    @State private var player = AVPlayer()
    @State private var duration: Double = 1
    @State private var trimStart: Double = 0
    @State private var trimEnd: Double = 1
    @State private var keepSystemAudio = true
    @State private var keepMicAudio = true
    @State private var systemVolume: Double = 1
    @State private var micVolume: Double = 1
    @State private var exporting = false

    var body: some View {
        VStack(spacing: 12) {
            PlayerLayerView(player: player)
                .frame(minHeight: 260)
                .background(Color.black)

            HStack {
                Text(time(trimStart)).font(.system(size: 11, design: .monospaced))
                Slider(value: $trimStart, in: 0...max(duration - 0.1, 0.1))
                    .onChange(of: trimStart) { _, v in
                        if trimEnd <= v + 0.1 { trimEnd = v + 0.1 }
                        player.seek(to: CMTime(seconds: v, preferredTimescale: 600))
                    }
                Text(time(trimEnd)).font(.system(size: 11, design: .monospaced))
                Slider(value: $trimEnd, in: 0...duration)
                    .onChange(of: trimEnd) { _, v in
                        if trimStart >= v - 0.1 { trimStart = v - 0.1 }
                    }
            }
            .padding(.horizontal, 12)

            HStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("保留系统声音", isOn: $keepSystemAudio)
                    if keepSystemAudio {
                        HStack {
                            Image(systemName: "speaker.wave.2")
                            Slider(value: $systemVolume, in: 0...1).frame(width: 90)
                            Text("\(Int(systemVolume * 100))%")
                                .font(.system(size: 10, design: .monospaced))
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("保留麦克风旁白", isOn: $keepMicAudio)
                    if keepMicAudio {
                        HStack {
                            Image(systemName: "mic")
                            Slider(value: $micVolume, in: 0...1).frame(width: 90)
                            Text("\(Int(micVolume * 100))%")
                                .font(.system(size: 10, design: .monospaced))
                        }
                    }
                }
                Spacer()
                Button("在 Finder 显示") {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
                Button(exporting ? "导出中…" : "另存为…") { saveAs() }
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
    }

    private func time(_ s: Double) -> String {
        String(format: "%02d:%05.2f", Int(s) / 60, s.truncatingRemainder(dividingBy: 60))
    }

    private func saveAs() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.mpeg4Movie]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = url.deletingPathExtension().lastPathComponent + " edited.mp4"
        NSApp.activate(ignoringOtherApps: true)
        panel.begin { response in
            guard response == .OK, let dest = panel.url else { return }
            exporting = true
            VideoEditorExporter.export(source: url,
                                       start: trimStart,
                                       end: trimEnd,
                                       keepSystemAudio: keepSystemAudio,
                                       keepMicAudio: keepMicAudio,
                                       systemVolume: Float(systemVolume),
                                       micVolume: Float(micVolume),
                                       to: dest) { result in
                DispatchQueue.main.async {
                    exporting = false
                    if case .failure(let error) = result {
                        let alert = NSAlert()
                        alert.messageText = "导出失败"
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

enum VideoEditorExporter {
    static func export(source: URL,
                       start: Double,
                       end: Double,
                       keepSystemAudio: Bool,
                       keepMicAudio: Bool,
                       systemVolume: Float = 1,
                       micVolume: Float = 1,
                       to dest: URL,
                       completion: @escaping (Result<Void, Error>) -> Void) {
        let asset = AVURLAsset(url: source)
        let composition = AVMutableComposition()
        var audioMix: AVMutableAudioMix?
        guard let videoTrack = asset.tracks(withMediaType: .video).first,
              let compVideo = composition.addMutableTrack(withMediaType: .video,
                                                          preferredTrackID: kCMPersistentTrackID_Invalid)
        else {
            completion(.failure(NSError(domain: "MacShotKit", code: 1,
                                        userInfo: [NSLocalizedDescriptionKey: "没有视频轨道"])))
            return
        }
        let range = CMTimeRange(start: CMTime(seconds: max(0, start), preferredTimescale: 600),
                                end: CMTime(seconds: max(start + 0.1, end), preferredTimescale: 600))
        do {
            try compVideo.insertTimeRange(range, of: videoTrack, at: .zero)
            let audioTracks = asset.tracks(withMediaType: .audio)
            var params: [AVMutableAudioMixInputParameters] = []
            for (i, track) in audioTracks.prefix(2).enumerated() {
                let keep = i == 0 ? keepSystemAudio : keepMicAudio
                if keep, let compAudio = composition.addMutableTrack(
                    withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
                    try? compAudio.insertTimeRange(range, of: track, at: .zero)
                    let param = AVMutableAudioMixInputParameters(track: compAudio)
                    param.setVolume(i == 0 ? systemVolume : micVolume, at: .zero)
                    params.append(param)
                }
            }
            if !params.isEmpty {
                let mix = AVMutableAudioMix()
                mix.inputParameters = params
                audioMix = mix
            }
        } catch {
            completion(.failure(error)); return
        }
        guard let session = AVAssetExportSession(asset: composition,
                                                 presetName: AVAssetExportPresetHighestQuality)
        else {
            completion(.failure(NSError(domain: "MacShotKit", code: 2,
                                        userInfo: [NSLocalizedDescriptionKey: "无法创建导出会话"])))
            return
        }
        session.outputURL = dest
        session.outputFileType = .mp4
        if let audioMix { session.audioMix = audioMix }
        session.shouldOptimizeForNetworkUse = true
        session.exportAsynchronously {
            switch session.status {
            case .completed: completion(.success(()))
            case .failed, .cancelled:
                completion(.failure(session.error ?? NSError(domain: "MacShotKit", code: 3)))
            default: break
            }
        }
    }
}

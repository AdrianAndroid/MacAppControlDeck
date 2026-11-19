import AppKit
import Vision
import SwiftUI

final class OCRResultController {
    static let shared = OCRResultController()

    private var window: NSWindow?

    func recognize(_ image: CGImage, autoCopy: Bool = false) {
        let request = VNRecognizeTextRequest { [weak self] request, error in
            DispatchQueue.main.async {
                if let error {
                    self?.present(text: "OCR 失败：\(error.localizedDescription)")
                    return
                }
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let lines = observations
                    .sorted { $0.boundingBox.maxY > $1.boundingBox.maxY }
                    .compactMap { $0.topCandidates(1).first?.string }
                let text = lines.joined(separator: "\n")
                if autoCopy, !text.isEmpty {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                }
                self?.present(text: text)
            }
        }
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["zh-Hans", "en-US"]
        request.usesLanguageCorrection = true

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
            } catch {
                DispatchQueue.main.async {
                    self.present(text: "OCR 失败：\(error.localizedDescription)")
                }
            }
        }
    }

    private func present(text: String) {
        if window == nil {
            let hosting = NSHostingController(rootView: OCRResultView(text: text,
                                                                      onClose: { [weak self] in
                                                                          self?.window?.close()
                                                                          self?.window = nil
                                                                      }))
            let window = NSWindow(contentViewController: hosting)
            window.title = "OCR 识别结果"
            window.styleMask = [.titled, .closable, .resizable]
            window.isReleasedWhenClosed = false
            window.setContentSize(NSSize(width: 520, height: 360))
            window.center()
            self.window = window
        } else if let hosting = window?.contentViewController as? NSHostingController<OCRResultView> {
            hosting.rootView = OCRResultView(text: text,
                                             onClose: { [weak self] in
                                                 self?.window?.close()
                                                 self?.window = nil
                                             })
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

private struct OCRResultView: View {
    let text: String
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("识别结果").font(.headline)
                Spacer()
                Button("复制") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                }
                Button("关闭", action: onClose)
            }
            ScrollView {
                Text(text.isEmpty ? "未识别到文字" : text)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
        }
        .padding(12)
    }
}

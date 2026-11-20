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

final class QRResultController {
    static let shared = QRResultController()
    private var window: NSWindow?

    func detect(_ image: CGImage) {
        let request = VNDetectBarcodesRequest { [weak self] request, error in
            DispatchQueue.main.async {
                if let error {
                    self?.present(values: ["识别失败：\(error.localizedDescription)"])
                    return
                }
                let results = request.results as? [VNBarcodeObservation] ?? []
                let values = results.compactMap { $0.payloadStringValue }
                self?.present(values: values.isEmpty ? ["未识别到二维码或条形码"] : values)
            }
        }
        request.symbologies = [.qr, .code128, .code39, .ean13, .ean8, .pdf417, .aztec, .dataMatrix]
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
            } catch {
                DispatchQueue.main.async { self.present(values: ["识别失败：\(error.localizedDescription)"]) }
            }
        }
    }

    private func present(values: [String]) {
        let view = QRResultView(values: values)
        if window == nil {
            let hosting = NSHostingController(rootView: view)
            let w = NSWindow(contentViewController: hosting)
            w.title = "二维码 / 条形码"
            w.styleMask = [.titled, .closable, .resizable]
            w.isReleasedWhenClosed = false
            w.setContentSize(NSSize(width: 520, height: 320))
            w.center()
            window = w
        } else if let hosting = window?.contentViewController as? NSHostingController<QRResultView> {
            hosting.rootView = view
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

private struct QRResultView: View {
    let values: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("识别结果").font(.headline)
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(values, id: \.self) { value in
                        HStack(alignment: .top, spacing: 8) {
                            Text(value).textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Button("复制") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(value, forType: .string)
                            }
                            if let url = URL(string: value),
                               ["http", "https"].contains(url.scheme?.lowercased() ?? "") {
                                Button("打开") { NSWorkspace.shared.open(url) }
                            }
                        }
                        Divider()
                    }
                }
                .padding(8)
            }
        }
        .padding(12)
    }
}

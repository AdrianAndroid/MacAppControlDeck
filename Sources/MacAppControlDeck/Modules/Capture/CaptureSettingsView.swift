import AppKit
import MacShotKit
import SwiftUI

struct CaptureSettingsView: View {
    @ObservedObject private var prefs = CapturePreferences.shared
    @ObservedObject private var registry = ModuleRegistry.shared
    @State private var permissionGranted = CGPreflightScreenCaptureAccess()
    @State private var recording = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                moduleStateCard
                if registry.isEnabled(CaptureModule.id) {
                    outputCard
                    recordingCard
                    permissionCard
                    testCard
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onChange(of: prefs.saveDirectory) { _, _ in syncDirectories() }
        .onChange(of: prefs.recordingDirectory) { _, _ in syncDirectories() }
        .onAppear { syncDirectories() }
    }

    private var moduleStateCard: some View {
        GroupBox {
            HStack(spacing: 10) {
                Circle()
                    .fill(registry.isEnabled(CaptureModule.id) ? Color.green : Color.orange)
                    .frame(width: 10, height: 10)
                VStack(alignment: .leading, spacing: 2) {
                    Text(registry.isEnabled(CaptureModule.id) ? "截图与录屏已启用" : "截图与录屏已关闭")
                        .font(.headline)
                    Text("开关在「模块」页统一管理；本模块只负责 Mac 本机截图/录屏，不经过手机。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(4)
        } label: {
            Text("模块状态").font(.headline)
        }
    }

    private var outputCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("截图后保存文件", isOn: $prefs.saveToFile)
                Toggle("截图后复制到剪贴板", isOn: $prefs.copyToClipboard)
                Toggle("截图快门音", isOn: $prefs.shutterSound)
                Toggle("保存后显示悬浮缩略图", isOn: $prefs.showFloatingThumbnail)
                HStack {
                    Text("文件名模板")
                    TextField("Screenshot {date} at {time}", text: $prefs.filenameTemplate)
                        .textFieldStyle(.roundedBorder)
                }
                Text("可用：{date} {time} {timestamp} {unix} {window} {app} {index} {random} {yyyy} {MM} {dd} {HH} {mm} {ss} {ms}；用 / 分文件夹。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Text("图片格式")
                    Picker("", selection: $prefs.imageFormat) {
                        ForEach(CaptureImageFormat.allCases) { format in
                            Text(format.title).tag(format)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 120)
                    Spacer()
                    Text("画质")
                    Slider(value: $prefs.imageQuality, in: 0.1...1.0)
                        .frame(width: 120)
                    Text(String(format: "%.0f%%", prefs.imageQuality * 100))
                        .font(.caption.monospacedDigit())
                        .frame(width: 38)
                }
                HStack {
                    Text("截图延时")
                    Picker("", selection: $prefs.captureDelay) {
                        Text("无").tag(0)
                        Text("3 秒").tag(3)
                        Text("5 秒").tag(5)
                        Text("10 秒").tag(10)
                        Text("30 秒").tag(30)
                    }
                    .labelsHidden()
                    .frame(width: 100)
                    Spacer()
                }
                directoryRow("截图保存目录", path: prefs.saveDirectory) {
                    chooseDirectory(start: prefs.directoryURL) { prefs.saveDirectory = $0.path }
                }
                Text("编辑器点“保存”会按所选格式写入目录；复制始终写 PNG 到剪贴板。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(4)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Text("截图输出").font(.headline)
        }
    }

    private var recordingCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                directoryRow("录屏保存目录", path: prefs.recordingDirectory) {
                    chooseDirectory(start: prefs.recordingDirectoryURL) { prefs.recordingDirectory = $0.path }
                }
                HStack {
                    Text("录屏文件名模板")
                    TextField("Recording {date} at {time}", text: $prefs.recordingFilenameTemplate)
                        .textFieldStyle(.roundedBorder)
                }
                Toggle("录屏包含系统声音", isOn: $prefs.recordingSystemAudio)
                Toggle("录屏包含鼠标指针", isOn: $prefs.recordingCursor)
                Toggle("录屏包含麦克风旁白", isOn: $prefs.recordingMicrophone)
                HStack {
                    Text("MP4 帧率")
                    Picker("", selection: $prefs.recordingFPS) {
                        Text("15").tag(15)
                        Text("30").tag(30)
                        Text("60").tag(60)
                        Text("120").tag(120)
                    }
                    .labelsHidden()
                    .frame(width: 80)
                    Spacer()
                    Text("GIF 帧率")
                    Picker("", selection: $prefs.gifFPS) {
                        Text("5").tag(5)
                        Text("10").tag(10)
                        Text("15").tag(15)
                    }
                    .labelsHidden()
                    .frame(width: 70)
                }
                HStack(spacing: 8) {
                    Button("录制区域") {
                        recording = true
                        MacShotController.shared.startRecording(format: .mp4, target: .area)
                    }
                    Button("录制全屏") {
                        recording = true
                        MacShotController.shared.startRecording(format: .mp4, target: .fullScreen)
                    }
                    Button("录制 GIF") {
                        recording = true
                        MacShotController.shared.startRecording(format: .gif, target: .area)
                    }
                    Button("停止") {
                        MacShotController.shared.stopRecording()
                        recording = false
                    }
                    .disabled(!recording)
                }
                Text("MP4 使用 H.264；GIF 默认 10 帧/秒、最长约 90 秒。停止按钮也会出现在屏幕顶部。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(4)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Text("录屏与 GIF").font(.headline)
        }
    }

    private var permissionCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(permissionGranted ? Color.green : Color.orange)
                        .frame(width: 10, height: 10)
                    Text(permissionGranted ? "屏幕录制：已授权" : "屏幕录制：未授权")
                        .font(.subheadline)
                    Spacer()
                    Button(permissionGranted ? "刷新" : "去授权") {
                        if !permissionGranted {
                            _ = CGRequestScreenCaptureAccess()
                        }
                        permissionGranted = CGPreflightScreenCaptureAccess()
                    }
                }
                Text("首次截图/录屏时 macOS 会弹窗请求权限；授权后必须重启应用。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(4)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Text("权限").font(.headline)
        }
    }

    private var testCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Button("全屏截图") { MacShotController.shared.captureFullScreen() }
                        .buttonStyle(.borderedProminent)
                    Button("区域截图") { MacShotController.shared.captureArea() }
                    Button("窗口截图") { MacShotController.shared.captureWindow() }
                    Spacer()
                    Button("打开截图目录") {
                        NSWorkspace.shared.open(prefs.directoryURL)
                    }
                }
                Text("快捷键：F1 直接打开区域截图；⌘⇧X 同样可用。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("截图后会打开标注编辑器：矩形、椭圆、直线、箭头、画笔、荧光笔、文字、序号、马赛克、裁剪。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(4)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Text("截图").font(.headline)
        }
    }

    private func directoryRow(_ title: String, path: String, choose: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Text(title).frame(width: 88, alignment: .leading)
            Text(path)
                .font(.system(size: 12, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
            Spacer(minLength: 8)
            Button("选择…", action: choose)
        }
    }

    private func chooseDirectory(start: URL, completion: @escaping (URL) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = start
        if panel.runModal() == .OK, let url = panel.url {
            completion(url)
        }
    }

    private func syncDirectories() {
        MacShotController.shared.outputDirectory = prefs.directoryURL
        MacShotController.shared.recordingDirectory = prefs.recordingDirectoryURL
    }
}

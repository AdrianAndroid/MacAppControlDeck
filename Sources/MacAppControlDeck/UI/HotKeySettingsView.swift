import AppKit
import SwiftUI

// MARK: - 设置页

struct HotKeySettingsView: View {
    @ObservedObject private var hotKeys = GlobalHotKeys.shared
    @State private var editing: GlobalHotKeyDefinition?
    @State private var errorText = ""
    @State private var confirmingResetAll = false

    var body: some View {
        Form {
            Section {
                Toggle("启用全局快捷键", isOn: Binding(
                    get: { hotKeys.masterEnabled },
                    set: { hotKeys.setMasterEnabled($0) }))
                Text("关闭后只停用系统级快捷键；菜单栏、手机面板和按钮内的快捷键注入不受影响。首次安装与恢复默认后，下面每一项都是关闭的，按需打开即可。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("全局快捷键") {
                if allDisabled {
                    Text("当前没有任何全局快捷键生效。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ForEach(hotKeys.definitions) { definition in
                    row(definition)
                }
            }

            Section {
                if !errorText.isEmpty {
                    Text(errorText)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                Button("全部恢复默认…") { confirmingResetAll = true }
                Text("F1 常与键盘亮度键、其他截图工具冲突：可单独关闭这一项或点「修改」换组合。若 Apple 键盘把 F1 当亮度键，请在「系统设置 → 键盘」开启「将 F1、F2 等键用作标准功能键」。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .sheet(item: $editing) { definition in
            HotKeyRecorderSheet(definition: definition)
        }
        .confirmationDialog("把所有快捷键恢复为默认组合并关闭？",
                            isPresented: $confirmingResetAll) {
            Button("恢复默认并关闭", role: .destructive) {
                hotKeys.resetAll()
                errorText = ""
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("已修改的组合会被覆盖；所有快捷键会回到默认组合并全部关闭，总开关状态保持不变。")
        }
    }

    private func row(_ definition: GlobalHotKeyDefinition) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(definition.title)
                Text(definition.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(statusLabel(for: definition))
                .font(.caption)
                .foregroundStyle(statusColor(for: definition))
            Text(hotKeys.combo(for: definition.id).symbol)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(hotKeys.isEnabled(definition.id) ? Color.primary : Color.secondary)
                .frame(minWidth: 64, alignment: .trailing)
            Button("修改") { editing = definition }
                .disabled(!hotKeys.masterEnabled)
            Toggle("", isOn: Binding(
                get: { hotKeys.isEnabled(definition.id) },
                set: { enabled in
                    let result = hotKeys.setEnabled(definition.id, enabled)
                    errorText = result.message ?? ""
                }))
                .labelsHidden()
                .toggleStyle(.switch)
                .disabled(!hotKeys.masterEnabled)
        }
    }

    private var allDisabled: Bool {
        hotKeys.definitions.allSatisfy { !hotKeys.isEnabled($0.id) }
    }

    private func statusLabel(for definition: GlobalHotKeyDefinition) -> String {
        guard let status = hotKeys.status(for: definition.id) else { return "" }
        return status.label
    }

    private func statusColor(for definition: GlobalHotKeyDefinition) -> Color {
        switch hotKeys.status(for: definition.id) {
        case .registered: return .green
        case .conflict, .duplicate: return .orange
        default: return .secondary
        }
    }
}

// MARK: - 录制弹窗

struct HotKeyRecorderSheet: View {
    let definition: GlobalHotKeyDefinition
    @ObservedObject private var hotKeys = GlobalHotKeys.shared
    @Environment(\.dismiss) private var dismiss

    @State private var combo: ShortcutCombo
    @State private var recording = false
    @State private var monitor: Any?
    @State private var errorText = ""

    init(definition: GlobalHotKeyDefinition) {
        self.definition = definition
        _combo = State(initialValue: GlobalHotKeys.shared.combo(for: definition.id))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("修改快捷键").font(.headline)
                Spacer()
                Button("关闭") { close() }
            }

            Text("\(definition.title) · \(definition.detail)")
                .font(.callout)
                .foregroundStyle(.secondary)

            HStack(alignment: .center, spacing: 16) {
                Text(combo.symbol)
                    .font(.system(size: 28, weight: .semibold, design: .monospaced))
                    .frame(minWidth: 120, alignment: .leading)
                Spacer()
                Button(recording ? "请按组合键…" : "录制按键") { startRecording() }
                    .disabled(recording)
            }

            Text("默认：\(definition.defaultCombo.symbol)　·　F1–F12 可单独使用，其他键需要至少一个修饰键")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(errorText.isEmpty ? " " : errorText)
                .font(.caption)
                .foregroundStyle(.red)
                .frame(height: 16)

            HStack {
                Button("恢复默认组合") { combo = definition.defaultCombo }
                Spacer()
                Button("取消") { close() }
                Button("保存") { save() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(18)
        .frame(width: 440)
        .overlay {
            if recording { recordingOverlay }
        }
        .onAppear { hotKeys.suspend() }
        .onDisappear {
            stopMonitor()
            hotKeys.resume()
        }
    }

    private var recordingOverlay: some View {
        ZStack {
            Color.black.opacity(0.55)
            VStack(spacing: 10) {
                Text("请按下新的全局快捷键…").font(.headline)
                Text("已识别：\(combo.symbol)")
                    .font(.system(size: 22, weight: .semibold, design: .monospaced))
                Text("录制期间其他全局快捷键已暂停；Esc 取消")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(24)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color(nsColor: .windowBackgroundColor)))
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func startRecording() {
        guard monitor == nil else { return }
        recording = true
        errorText = ""
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if event.keyCode == 53 {  // Esc 取消录制
                stopMonitor()
                return nil
            }
            let pureModifierKeys: Set<UInt16> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63]
            if pureModifierKeys.contains(event.keyCode) { return nil }

            var modifiers: [ShortcutModifier] = []
            if flags.contains(.command) { modifiers.append(.command) }
            if flags.contains(.control) { modifiers.append(.control) }
            if flags.contains(.option) { modifiers.append(.option) }
            if flags.contains(.shift) { modifiers.append(.shift) }
            if flags.contains(.function) { modifiers.append(.function) }
            combo = ShortcutCombo(modifiers: modifiers.sorted(),
                                  keyCode: event.keyCode,
                                  keyLabel: ShortcutKeys.label(for: event.keyCode) ?? "KEY\(event.keyCode)")
            if GlobalHotKeyRules.needsModifier(combo) {
                errorText = GlobalHotKeyValidation.needsModifier.message ?? ""
            }
            stopMonitor()
            return nil
        }
    }

    private func stopMonitor() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        recording = false
    }

    private func save() {
        let result = hotKeys.setCombo(definition.id, combo)
        if let message = result.message {
            errorText = message
            return
        }
        close()
    }

    private func close() {
        stopMonitor()
        dismiss()
    }
}

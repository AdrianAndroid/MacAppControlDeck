import SwiftUI
import AppKit

struct ShortcutSheet: View {
    @ObservedObject var state: DeckState
    var editing: ButtonConfig?
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var modifiers: Set<ShortcutModifier> = []
    @State private var keyCode: UInt16 = 8
    @State private var keyLabel: String = ""
    @State private var recording = false
    @State private var monitor: Any?
    @State private var errorText: String = ""

    private var isEditing: Bool { editing != nil }

    private var combo: ShortcutCombo? {
        guard !keyLabel.isEmpty else { return nil }
        return ShortcutCombo(modifiers: Array(modifiers), keyCode: keyCode, keyLabel: keyLabel)
    }

    private var preview: String { combo?.symbol ?? "—" }

    private var duplicated: Bool {
        guard let combo else { return false }
        return state.buttons.contains { button in
            button.id != editing?.id && button.kind == .shortcut && button.shortcut == combo.normalized
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(isEditing ? "编辑快捷操作" : "添加快捷操作").font(.headline)
                Spacer()
                Button("关闭") { close() }
            }

            HStack(alignment: .top, spacing: 16) {
                if !isEditing {
                    presetsColumn
                    Divider()
                }
                customColumn
            }
            .frame(maxHeight: 420)

            Text(errorText.isEmpty ? (duplicated ? "与已有快捷操作重复" : " ") : errorText)
                .font(.caption)
                .foregroundStyle(errorText.isEmpty && !duplicated ? Color.secondary : Color.red)
                .frame(height: 16)

            HStack {
                Spacer()
                Button("取消") { close() }
                Button(isEditing ? "保存" : "创建") { save() }
                    .buttonStyle(.borderedProminent)
                    .disabled(combo == nil || duplicated || (isEditing && name.isEmpty))
            }
        }
        .padding(16)
        .frame(width: isEditing ? 420 : 720)
        .overlay {
            if recording { recordingOverlay }
        }
        .onAppear {
            // 录制期间暂停全局快捷键，避免 F1 等被系统级热键吞掉。
            GlobalHotKeys.shared.suspend()
            loadInitial()
        }
        .onDisappear {
            stopMonitor()
            GlobalHotKeys.shared.resume()
        }
    }

    private var presetsColumn: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                Text("预设（单击即创建）").font(.caption).foregroundStyle(.secondary)
                ForEach(ShortcutPresets.all) { preset in
                    Button {
                        state.addShortcut(name: preset.name, combo: preset.combo)
                        close()
                    } label: {
                        HStack {
                            Text(preset.combo.symbol)
                                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                                .frame(width: 64, alignment: .leading)
                            Text(preset.name).font(.callout)
                            Spacer()
                        }
                        .padding(.vertical, 3)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(width: 260, alignment: .leading)
        }
    }

    private var customColumn: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(isEditing ? "组合" : "自定义组合").font(.caption).foregroundStyle(.secondary)

            HStack(spacing: 6) {
                ForEach(ShortcutModifier.allCases, id: \.self) { modifier in
                    Button(modifier.symbol) {
                        if modifiers.contains(modifier) { modifiers.remove(modifier) } else { modifiers.insert(modifier) }
                    }
                    .buttonStyle(.bordered)
                    .tint(modifiers.contains(modifier) ? .accentColor : nil)
                }
            }

            HStack {
                Text("主键")
                Picker("", selection: Binding(
                    get: { keyCode },
                    set: { newValue in
                        keyCode = newValue
                        keyLabel = ShortcutKeys.label(for: newValue) ?? ""
                    })) {
                    if keyLabel.isEmpty { Text("请选择").tag(UInt16.max) }
                    ForEach(ShortcutKeys.all, id: \.keyCode) { key in
                        Text("\(key.label)  (\(key.keyCode))").tag(key.keyCode)
                    }
                }
                .labelsHidden()
                .frame(width: 180)
            }

            HStack {
                Text("预览").foregroundStyle(.secondary)
                Text(preview).font(.system(size: 20, weight: .semibold, design: .monospaced))
                Spacer()
                Button(recording ? "录制中…" : "录制按键") { startRecording() }
                    .disabled(recording)
            }

            HStack {
                Text("名称")
                TextField("如：构建", text: $name)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    private var recordingOverlay: some View {
        ZStack {
            Color.black.opacity(0.55)
            VStack(spacing: 10) {
                Text("请按下要发送的组合键…").font(.headline)
                Text("已识别：\(preview)")
                    .font(.system(size: 22, weight: .semibold, design: .monospaced))
                Text("Esc 取消").font(.caption).foregroundStyle(.secondary)
            }
            .padding(24)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color(nsColor: .windowBackgroundColor)))
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func loadInitial() {
        if let editing {
            name = editing.name
            if let shortcut = editing.shortcut {
                modifiers = Set(shortcut.modifiers)
                keyCode = shortcut.keyCode
                keyLabel = shortcut.keyLabel
            }
        }
    }

    private func startRecording() {
        guard monitor == nil else { return }
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if event.keyCode == 53 {  // Esc 取消
                stopMonitor()
                return nil
            }
            let pureModifierKeys: Set<UInt16> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63]
            if pureModifierKeys.contains(event.keyCode) { return nil }
            var newModifiers: Set<ShortcutModifier> = []
            if flags.contains(.command) { newModifiers.insert(.command) }
            if flags.contains(.control) { newModifiers.insert(.control) }
            if flags.contains(.option) { newModifiers.insert(.option) }
            if flags.contains(.shift) { newModifiers.insert(.shift) }
            if flags.contains(.function) { newModifiers.insert(.function) }
            modifiers = newModifiers
            keyCode = event.keyCode
            keyLabel = ShortcutKeys.label(for: event.keyCode) ?? "KEY\(event.keyCode)"
            if name.isEmpty { name = keyLabel }
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
        guard let combo else { errorText = "请选择主键"; return }
        if let editing {
            state.updateShortcut(id: editing.id,
                                 name: name.isEmpty ? nil : name,
                                 combo: combo)
        } else {
            state.addShortcut(name: name.isEmpty ? combo.symbol : name, combo: combo)
        }
        close()
    }

    private func close() {
        stopMonitor()
        dismiss()
    }
}

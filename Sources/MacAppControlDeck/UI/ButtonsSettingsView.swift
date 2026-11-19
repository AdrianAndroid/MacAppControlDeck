import SwiftUI
import AppKit

/// 按钮管理：应用的配置入口都在设置窗口里，菜单栏只负责触发。
struct ButtonsSettingsView: View {
    @ObservedObject private var state = DeckState.shared

    @State private var showAddSheet = false
    @State private var showShortcutSheet = false
    @State private var showCommandSheet = false
    @State private var editingShortcut: ButtonConfig?
    @State private var pendingDelete: ButtonConfig?
    @State private var pendingRename: ButtonConfig?
    @State private var renameText = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Menu("添加按钮") {
                                Button("添加应用按钮…") {
                                    state.installedApps = AppEnumerator.installedApps()
                                    showAddSheet = true
                                }
                                Button("添加快捷操作…") {
                                    showShortcutSheet = true
                                }
                                Button("添加命令按钮…") {
                                    showCommandSheet = true
                                }
                            }
                            .menuStyle(.borderlessButton)
                            .fixedSize()
                            Spacer()
                            Text("共 \(state.buttons.count) 个")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if state.buttons.isEmpty {
                            Text("还没有按钮。添加应用按钮、快捷操作或命令后，菜单栏和手机面板都会同步出现。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 6)
                        } else {
                            if !state.appButtons.isEmpty {
                                sectionHeader("应用")
                                ForEach(Array(state.appButtons.enumerated()), id: \.element.id) { index, button in
                                    buttonRow(button,
                                              canMoveUp: index > 0,
                                              canMoveDown: index < state.appButtons.count - 1)
                                    Divider()
                                }
                            }
                            if !state.quickButtons.isEmpty {
                                sectionHeader("快捷操作")
                                ForEach(Array(state.quickButtons.enumerated()), id: \.element.id) { index, button in
                                    let canUp = index > 0
                                    let canDown = index < state.quickButtons.count - 1
                                    if button.kind == .command {
                                        commandRow(button, canMoveUp: canUp, canMoveDown: canDown)
                                    } else {
                                        shortcutRow(button, canMoveUp: canUp, canMoveDown: canDown)
                                    }
                                    Divider()
                                }
                            }
                        }
                    }
                    .padding(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                } label: {
                    Text("按钮").font(.headline)
                }

                Text("按钮顺序会同时影响菜单栏与手机面板；参数与命令只保存在本机。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
        }
        .sheet(isPresented: $showAddSheet) {
            AddButtonSheet(state: state)
        }
        .sheet(isPresented: $showShortcutSheet) {
            ShortcutSheet(state: state, editing: nil)
        }
        .sheet(item: $editingShortcut) { button in
            ShortcutSheet(state: state, editing: button)
        }
        .sheet(isPresented: $showCommandSheet) {
            CommandSheet(state: state)
        }
        .confirmationDialog("确定删除按钮「\(pendingDelete?.name ?? "")」？", isPresented: Binding(
            get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }), titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                if let button = pendingDelete { state.delete(button) }
                pendingDelete = nil
            }
            Button("取消", role: .cancel) { pendingDelete = nil }
        }
        .alert("重命名按钮", isPresented: Binding(
            get: { pendingRename != nil }, set: { if !$0 { pendingRename = nil } })) {
            TextField("按钮名称", text: $renameText)
            Button("保存") {
                if let button = pendingRename, !renameText.isEmpty {
                    state.rename(button, to: renameText)
                }
                pendingRename = nil
            }
            Button("取消", role: .cancel) { pendingRename = nil }
        }
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.top, 4)
    }

    private func buttonRow(_ button: ButtonConfig, canMoveUp: Bool, canMoveDown: Bool) -> some View {
        let installed = state.isInstalled(button)
        return HStack(spacing: 12) {
            AppIconView(path: button.appPath)
                .frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(button.name).font(.callout).lineLimit(1)
                Text(installed ? button.bundleID : "应用缺失：\(button.bundleID)")
                    .font(.caption2)
                    .foregroundStyle(installed ? Color.secondary : Color.orange)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 8)
            Button { state.move(button, offset: -1) } label: { Image(systemName: "arrow.up") }
                .help("上移")
                .disabled(!canMoveUp)
            Button { state.move(button, offset: 1) } label: { Image(systemName: "arrow.down") }
                .help("下移")
                .disabled(!canMoveDown)
            Menu {
                Button("重命名…") {
                    pendingRename = button
                    renameText = button.name
                }
                Button("删除…") { pendingDelete = button }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(.vertical, 4)
    }

    private func commandRow(_ button: ButtonConfig, canMoveUp: Bool, canMoveDown: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "terminal")
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 64, height: 32)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .quaternaryLabelColor).opacity(0.25)))
            VStack(alignment: .leading, spacing: 2) {
                Text(button.name).font(.callout).lineLimit(1)
                Text("命令 · \((button.appPath as NSString).lastPathComponent) \((button.commandArguments ?? []).joined(separator: " "))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Button { state.move(button, offset: -1) } label: { Image(systemName: "arrow.up") }
                .help("上移")
                .disabled(!canMoveUp)
            Button { state.move(button, offset: 1) } label: { Image(systemName: "arrow.down") }
                .help("下移")
                .disabled(!canMoveDown)
            Menu {
                Button("重命名…") {
                    pendingRename = button
                    renameText = button.name
                }
                Button("删除…") { pendingDelete = button }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(.vertical, 4)
    }

    private func shortcutRow(_ button: ButtonConfig, canMoveUp: Bool, canMoveDown: Bool) -> some View {
        HStack(spacing: 12) {
            Text(button.displaySymbol ?? "—")
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .frame(width: 64, height: 32)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .quaternaryLabelColor).opacity(0.25)))
            VStack(alignment: .leading, spacing: 2) {
                Text(button.name).font(.callout).lineLimit(1)
                Text("快捷操作 · \(button.displaySymbol ?? "")")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Button { state.move(button, offset: -1) } label: { Image(systemName: "arrow.up") }
                .help("上移")
                .disabled(!canMoveUp)
            Button { state.move(button, offset: 1) } label: { Image(systemName: "arrow.down") }
                .help("下移")
                .disabled(!canMoveDown)
            Menu {
                Button("重命名…") {
                    pendingRename = button
                    renameText = button.name
                }
                Button("编辑组合…") { editingShortcut = button }
                Button("删除…") { pendingDelete = button }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 共用小视图

struct AppIconView: View {
    var path: String
    var size: CGFloat = 34

    var body: some View {
        if FileManager.default.fileExists(atPath: path) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                .resizable()
                .frame(width: size, height: size)
        } else {
            RoundedRectangle(cornerRadius: 6).fill(Color.gray.opacity(0.35))
                .overlay(Image(systemName: "app.dashed").foregroundStyle(.secondary))
                .frame(width: size, height: size)
        }
    }
}

enum UIPasteboardLike {
    static func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

struct AddButtonSheet: View {
    @ObservedObject var state: DeckState
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("选择要绑定的应用").font(.headline)
                Spacer()
                Button("完成") { dismiss() }
            }.padding(12)
            TextField("搜索应用名称", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 12)
            List(filteredApps) { app in
                HStack {
                    AppIconView(path: app.path, size: 30).frame(width: 30, height: 30)
                    VStack(alignment: .leading) {
                        Text(app.name).font(.callout)
                        Text(app.bundleID).font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if state.buttons.contains(where: { $0.bundleID == app.bundleID }) {
                        Text("已添加").font(.caption).foregroundStyle(.secondary)
                    } else {
                        Button("添加") { state.addInstalledApp(app) }.buttonStyle(.bordered)
                    }
                }
            }
            .listStyle(.inset)
        }
        .frame(width: 480, height: 500)
    }

    private var filteredApps: [InstalledApp] {
        searchText.isEmpty ? state.installedApps
            : state.installedApps.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
}

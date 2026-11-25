import SwiftUI
import AppKit

struct SystemToolSettingsView: View {
    @ObservedObject private var statusBar = StatusBarRegistry.shared
    @AppStorage("systemTool.cleaning.largeFileThreshold") private var thresholdMB = 100
    @AppStorage("systemTool.cleaning.oldFileMonths") private var oldMonths = 12

    @State private var excludedPaths: [String] = CleanupExclusions.paths()
    @State private var largeRoots: [String] = UserDefaults.standard
        .stringArray(forKey: "systemTool.cleaning.largeFileRoots") ?? []
    @State private var duplicateRoot: String = UserDefaults.standard
        .string(forKey: "systemTool.cleaning.duplicateScanRoot") ?? NSHomeDirectory()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // ① 状态栏展示信息
                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("勾选要在菜单栏显示的项目；改动即时生效，无需重启。")
                            .font(.caption).foregroundStyle(.secondary)
                        HStack(spacing: 12) {
                            StatusInfoCard(title: "CPU 占用", sample: "29%", label: "CPU",
                                           tint: .blue, checked: showCPUBinding)
                            StatusInfoCard(title: "内存占用", sample: "45%", label: "MEM",
                                           tint: .purple, checked: showMEMBinding)
                            StatusInfoCard(title: "实时网速", sample: "K/s", label: "↑↓ 上传下载",
                                           tint: .green, checked: showNetBinding)
                        }
                        HStack(alignment: .top, spacing: 5) {
                            Image(systemName: "info.circle").font(.caption2)
                            Text("这三项分别控制菜单栏上的三个独立状态项（CPU / MEM / 网速），每个都可单独点击打开 PureMac。它们不是总开关。总开关是「设置 → 模块 → PureMac」的模块启用开关；模块关闭时状态项全部消失，勾选状态会保留，重新启用后按勾选恢复。三项都不勾选时状态项也会消失。")
                                .font(.caption2).foregroundStyle(.tertiary)
                        }
                        Text("卡片中的数值/K/s 为形态示意，实际由菜单栏实时采样显示；网速按 K/s → M/s 自动切档，零 TCC 权限。")
                            .font(.caption2).foregroundStyle(.quaternary)
                    }
                    .padding(10)
                } label: {
                    Label("状态栏展示信息设置", systemImage: "menubar.rectangle")
                        .font(.headline)
                }

                // ② 扫描设置
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        SettingRow(label: "大文件阈值", hint: "超过该大小的文件进入结果") {
                            Picker("", selection: $thresholdMB) {
                                Text("> 50 MB").tag(50)
                                Text("> 100 MB").tag(100)
                                Text("> 500 MB").tag(500)
                                Text("> 1 GB").tag(1024)
                            }
                            .labelsHidden().frame(width: 150)
                        }

                        SettingRow(label: "文件时间", hint: "超过该时长的较大文件也纳入") {
                            Picker("", selection: $oldMonths) {
                                Text("> 6 个月").tag(6)
                                Text("> 1 年").tag(12)
                                Text("> 2 年").tag(24)
                            }
                            .labelsHidden().frame(width: 150)
                        }

                        SettingRow(label: "默认扫描目录", hint: "大文件扫描的根目录；留空则用下载 / 文稿 / 桌面") {
                            HStack(spacing: 6) {
                                Text(largeRootLabel)
                                    .font(.caption).foregroundStyle(.secondary)
                                    .lineLimit(1).truncationMode(.middle)
                                    .frame(maxWidth: 220, alignment: .leading)
                                Button("选择…") { chooseLargeRoot() }.controlSize(.small)
                                if !largeRoots.isEmpty {
                                    Button("恢复默认") {
                                        largeRoots = []
                                        UserDefaults.standard.removeObject(forKey: "systemTool.cleaning.largeFileRoots")
                                    }
                                    .controlSize(.small)
                                }
                            }
                        }

                        SettingRow(label: "重复文件扫描根", hint: "按内容哈希查找重复文件时的起点") {
                            HStack(spacing: 6) {
                                Text((duplicateRoot as NSString).abbreviatingWithTildeInPath)
                                    .font(.caption).foregroundStyle(.secondary)
                                    .lineLimit(1).truncationMode(.middle)
                                    .frame(maxWidth: 220, alignment: .leading)
                                Button("选择…") { chooseDuplicateRoot() }.controlSize(.small)
                            }
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 7) {
                            HStack {
                                Text("排除路径").font(.subheadline).fontWeight(.semibold)
                                Text("扫描与清理都会跳过这些路径及其子路径")
                                    .font(.caption2).foregroundStyle(.secondary)
                                Spacer()
                                Button {
                                    addExclusion()
                                } label: {
                                    Label("添加路径", systemImage: "plus")
                                }
                                .controlSize(.small)
                            }
                            if excludedPaths.isEmpty {
                                Text("暂无排除路径")
                                    .font(.caption).foregroundStyle(.secondary)
                                    .padding(.vertical, 4)
                            } else {
                                VStack(spacing: 0) {
                                    ForEach(excludedPaths, id: \.self) { path in
                                        HStack(spacing: 6) {
                                            Image(systemName: "folder.badge.minus")
                                                .foregroundStyle(.secondary)
                                            Text(path)
                                                .font(.caption).lineLimit(1).truncationMode(.middle)
                                            Spacer(minLength: 6)
                                            Button("移除") { removeExclusion(path) }
                                                .buttonStyle(.borderless)
                                                .font(.caption)
                                        }
                                        .padding(.horizontal, 8).padding(.vertical, 5)
                                        Divider()
                                    }
                                }
                                .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .textBackgroundColor)))
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(nsColor: .separatorColor), lineWidth: 0.5))
                            }
                        }
                    }
                    .padding(10)
                } label: {
                    Label("扫描设置", systemImage: "magnifyingglass")
                        .font(.headline)
                }

                // ③ 模块说明
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "trash.fill")
                                .foregroundStyle(Color.accentColor)
                            Text("PureMac").font(.callout).fontWeight(.semibold)
                            Spacer()
                            if let url = URL(string: "https://github.com/momenbasel/PureMac") {
                                Link("上游仓库", destination: url).font(.caption)
                            }
                        }
                        Text("清理引擎精选移植自 PureMac（MIT License，Copyright © 2026 PureMac Contributors）；"
                             + "扫描、清理、哈希、进程与应用发现的底层文件保留上游版权头，完整许可见 THIRD_PARTY_NOTICES.md。")
                            .font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Divider()
                        VStack(alignment: .leading, spacing: 4) {
                            Label("默认零选中 · 先看后删 · 删除前逐项确认", systemImage: "checkmark.shield")
                            Label("优先移入废纸篓；永久删除需单独二次确认", systemImage: "trash")
                            Label("系统 / root / 受保护进程的退出按钮不可用", systemImage: "lock.shield")
                            Label("未获得完全磁盘访问时结果标注为不完整，不阻断扫描", systemImage: "exclamationmark.triangle")
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
                    .padding(10)
                } label: {
                    Label("模块说明", systemImage: "info.circle")
                        .font(.headline)
                }
            }
            .padding()
        }
        .onAppear(perform: reloadFromDefaults)
    }

    // 状态栏开关统一走公共注册中心（与 设置 → 状态栏 同一份数据）。
    private var showCPUBinding: Binding<Bool> { statusBinding("systemTool.cpu") }
    private var showMEMBinding: Binding<Bool> { statusBinding("systemTool.mem") }
    private var showNetBinding: Binding<Bool> { statusBinding("systemTool.net") }

    private func statusBinding(_ entryID: String) -> Binding<Bool> {
        Binding(
            get: { statusBar.isVisible(entryID) },
            set: { statusBar.setVisible($0, entryID: entryID) }
        )
    }

    private var largeRootLabel: String {
        guard let first = largeRoots.first, !first.isEmpty else {
            return "下载 / 文稿 / 桌面（默认）"
        }
        return (first as NSString).abbreviatingWithTildeInPath
    }

    private func reloadFromDefaults() {
        excludedPaths = CleanupExclusions.paths()
        largeRoots = UserDefaults.standard.stringArray(forKey: "systemTool.cleaning.largeFileRoots") ?? []
        duplicateRoot = UserDefaults.standard.string(forKey: "systemTool.cleaning.duplicateScanRoot") ?? NSHomeDirectory()
    }

    private func chooseLargeRoot() {
        guard let url = chooseDirectory(prompt: "选择", message: "选择大文件扫描目录") else { return }
        largeRoots = [url.path]
        UserDefaults.standard.set(largeRoots, forKey: "systemTool.cleaning.largeFileRoots")
    }

    private func chooseDuplicateRoot() {
        guard let url = chooseDirectory(prompt: "选择", message: "选择重复文件扫描根目录") else { return }
        duplicateRoot = url.path
        UserDefaults.standard.set(url.path, forKey: "systemTool.cleaning.duplicateScanRoot")
    }

    private func addExclusion() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.prompt = "添加"
        panel.message = "选择要排除的文件或目录"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        CleanupExclusions.add(url.path)
        excludedPaths = CleanupExclusions.paths()
    }

    private func removeExclusion(_ path: String) {
        var next = excludedPaths
        next.removeAll { $0 == path }
        UserDefaults.standard.set(next, forKey: CleanupExclusions.defaultsKey)
        excludedPaths = next
    }

    private func chooseDirectory(prompt: String, message: String) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.prompt = prompt
        panel.message = message
        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }
}

private struct StatusInfoCard: View {
    let title: String
    let sample: String
    let label: String
    let tint: Color
    @Binding var checked: Bool

    var body: some View {
        VStack(spacing: 5) {
            HStack {
                Spacer()
                Image(systemName: checked ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(checked ? tint : Color.secondary)
            }
            Text(sample)
                .font(.system(size: 22, weight: .medium, design: .rounded))
                .monospacedDigit()
            Text(label)
                .font(.caption2).fontWeight(.semibold)
                .foregroundStyle(.secondary)
            Divider().padding(.vertical, 2)
            Text(title).font(.caption2)
        }
        .frame(width: 126, height: 122)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(checked ? tint.opacity(0.55) : Color(nsColor: .separatorColor),
                        lineWidth: checked ? 1.2 : 0.5)
        )
        .contentShape(Rectangle())
        .onTapGesture { checked.toggle() }
    }
}

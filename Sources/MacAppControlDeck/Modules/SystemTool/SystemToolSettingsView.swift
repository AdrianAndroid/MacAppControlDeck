import SwiftUI

struct SystemToolSettingsView: View {
    @AppStorage("systemTool.menubar.showCPU") private var showCPU = true
    @AppStorage("systemTool.menubar.showMEM") private var showMEM = true
    @AppStorage("systemTool.cleaning.largeFileThreshold") private var thresholdMB = 100
    @AppStorage("systemTool.cleaning.oldFileMonths") private var oldMonths = 12
    @State private var excludedPaths: [String] = CleanupExclusions.paths()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                GroupBox("状态栏展示信息设置") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("勾选要在菜单栏显示的项目，改动即时生效、无需重启。")
                            .font(.caption).foregroundStyle(.secondary)
                        HStack(spacing: 16) {
                            StatusInfoCard(title: "CPU 占用", sample: "29%", label: "CPU", checked: $showCPU)
                            StatusInfoCard(title: "内存占用", sample: "45%", label: "MEM", checked: $showMEM)
                        }
                        Text("这里的勾选只控制各自状态项；总开关在「设置 → 模块 → PureMac」。")
                            .font(.caption2).foregroundStyle(.tertiary)
                    }
                    .padding(8)
                }

                GroupBox("扫描设置") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("大文件阈值")
                            Picker("", selection: $thresholdMB) {
                                Text("> 50 MB").tag(50)
                                Text("> 100 MB").tag(100)
                                Text("> 500 MB").tag(500)
                                Text("> 1 GB").tag(1024)
                            }.frame(width: 140)
                        }
                        HStack {
                            Text("文件时间")
                            Picker("", selection: $oldMonths) {
                                Text("> 6 个月").tag(6)
                                Text("> 1 年").tag(12)
                                Text("> 2 年").tag(24)
                            }.frame(width: 140)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text("排除路径").font(.subheadline)
                            ForEach(excludedPaths, id: \.self) { path in
                                HStack {
                                    Text(path).font(.caption).lineLimit(1).truncationMode(.middle)
                                    Spacer()
                                    Button("移除") {
                                        var next = excludedPaths
                                        next.removeAll { $0 == path }
                                        UserDefaults.standard.set(next, forKey: "systemTool.cleaning.excludedPaths")
                                        excludedPaths = next
                                    }.buttonStyle(.borderless)
                                }
                            }
                            if excludedPaths.isEmpty {
                                Text("暂无排除路径").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(8)
                }

                GroupBox("模块说明") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("清理引擎移植自 PureMac (MIT, momenbasel)，许可证声明见 THIRD_PARTY_NOTICES.md。")
                            .font(.caption)
                        Text("清理默认移入废纸篓；系统进程不可退出；未获得完全磁盘访问时结果可能不完整。")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(8)
                }
            }
            .padding()
        }
        .onChange(of: showCPU) { _, _ in notifyStatusChange() }
        .onChange(of: showMEM) { _, _ in notifyStatusChange() }
    }

    private func notifyStatusChange() {
        NotificationCenter.default.post(name: .systemToolStatusPreferenceChanged, object: nil)
    }
}

private struct StatusInfoCard: View {
    let title: String
    let sample: String
    let label: String
    @Binding var checked: Bool

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Spacer()
                Image(systemName: checked ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(checked ? Color.accentColor : Color.secondary)
                    .onTapGesture { checked.toggle() }
            }
            Text(sample).font(.title2).fontWeight(.medium)
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(title).font(.caption2)
        }
        .frame(width: 120, height: 110)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(nsColor: .separatorColor), lineWidth: 0.5))
        .contentShape(Rectangle())
        .onTapGesture { checked.toggle() }
    }
}

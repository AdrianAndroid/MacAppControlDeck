import SwiftUI
import AppKit

// MARK: - Confirm dialogs

struct ConfirmCleanView: View {
    let items: [CleanableItem]
    @Binding var permanent: Bool
    let confirm: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("确认清理").font(.headline)
            Text("将 \(items.count) 项（共 \(ByteCountFormatter.string(fromByteCount: items.reduce(0) { $0 + $1.size }, countStyle: .file))）移入废纸篓？")
            ScrollView {
                ForEach(items.prefix(10)) { item in
                    Text(item.path).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
                if items.count > 10 { Text("… 以及另外 \(items.count - 10) 项").font(.caption2) }
            }.frame(maxHeight: 140)
            Toggle("永久删除（不进废纸篓，不可恢复）", isOn: $permanent)
            HStack {
                Spacer()
                Button("取消") { dismiss() }
                Button(permanent ? "永久删除" : "确认移入废纸篓") {
                    confirm(); dismiss()
                }.buttonStyle(.borderedProminent)
            }
        }
        .padding(20).frame(width: 440)
    }
}

// MARK: - Uninstall

struct UninstallTab: View {
    @ObservedObject var state: SystemToolState
    @State private var apps: [AppPathFinder.AppInfo] = []
    @State private var selectedApp: AppPathFinder.AppInfo?
    @State private var residuals: [URL] = []
    @State private var checkedResiduals: Set<URL> = []
    @State private var scanningResiduals = false

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("应用列表（已安装）").font(.headline)
                Spacer()
                Button("扫描残留") { scanResiduals() }.disabled(selectedApp == nil || scanningResiduals)
            }
            List(apps, id: \.path) { app in
                HStack {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: app.path.path)).resizable().frame(width: 24, height: 24)
                    VStack(alignment: .leading) {
                        Text(app.appName)
                        Text(app.bundleIdentifier).font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(app.path.path).font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
                }
                .contentShape(Rectangle())
                .onTapGesture { selectedApp = app; residuals = [] }
                .background(selectedApp?.path == app.path ? Color.accentColor.opacity(0.1) : Color.clear)
            }
            .onAppear(perform: loadApps)
            .frame(minHeight: 120)

            if let app = selectedApp {
                Text("\(app.appName) 的关联文件").font(.subheadline)
                if scanningResiduals { ProgressView().controlSize(.small) }
                List(residuals, id: \.self) { url in
                    HStack {
                        Toggle("", isOn: Binding(
                            get: { checkedResiduals.contains(url) },
                            set: { on in if on { checkedResiduals.insert(url) } else { checkedResiduals.remove(url) } }
                        )).toggleStyle(.checkbox)
                        Text(url.path).font(.caption).lineLimit(1)
                        Spacer()
                        Text(labelForResidual(url)).font(.caption2).foregroundStyle(OrphanSafetyPolicy.isSafeCandidate(url) ? .green : .orange)
                    }
                }
                HStack {
                    Spacer()
                    Button("卸载应用并移残留入废纸篓") { uninstall() }
                        .disabled(checkedResiduals.isEmpty)
                }
            }
        }
        .padding()
    }

    private func labelForResidual(_ url: URL) -> String {
        OrphanSafetyPolicy.isSafeCandidate(url) ? "高置信" : "需人工核对"
    }

    private func loadApps() {
        let urls = (try? FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: "/Applications"), includingPropertiesForKeys: nil)) ?? []
        apps = urls.filter { $0.pathExtension == "app" }.compactMap { url in
            guard let dict = NSDictionary(contentsOf: url.appendingPathComponent("Contents/Info.plist")),
                  let bid = dict["CFBundleIdentifier"] as? String else { return nil }
            let name = dict["CFBundleName"] as? String ?? url.deletingPathExtension().lastPathComponent
            return AppPathFinder.AppInfo(appName: name, bundleIdentifier: bid, path: url, entitlements: nil, teamIdentifier: nil)
        }.sorted { $0.appName < $1.appName }
    }

    private func scanResiduals() {
        guard let app = selectedApp else { return }
        scanningResiduals = true
        let finder = AppPathFinder(appInfo: app)
        let found = finder.findPaths().filter { $0.path != app.path.path }
        residuals = found.sorted { $0.path < $1.path }
        checkedResiduals = Set(found.filter { OrphanSafetyPolicy.isSafeCandidate($0) })
        scanningResiduals = false
    }

    private func uninstall() {
        guard let app = selectedApp else { return }
        Task {
            _ = await state.clean(items: checkedResiduals.map {
                CleanableItem(name: $0.lastPathComponent, path: $0.path, size: 0, category: .userCache, isSelected: true, lastModified: nil)
            })
            var resulting: NSURL?
            try? FileManager.default.trashItem(at: app.path, resultingItemURL: &resulting)
            await MainActor.run { residuals.removeAll(); checkedResiduals.removeAll(); selectedApp = nil }
        }
    }
}

// MARK: - Large files

struct LargeFilesTab: View {
    @ObservedObject var state: SystemToolState
    @State private var showConfirm = false

    var selected: [CleanableItem] { state.largeFiles.filter { $0.isSelected } }

    var body: some View {
        VStack(spacing: 8) {
            if !state.hasFullDiskAccess { FDABanner() }
            HStack {
                Text("结果默认全不选中").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("扫描") { Task { await state.scanLargeFiles() } }
                Button("取消") { state.cancelScan() }.disabled(!state.isScanning)
            }
            List(state.largeFiles.indices, id: \.self) { i in
                let item = state.largeFiles[i]
                HStack {
                    Toggle("", isOn: Binding(
                        get: { state.largeFiles[i].isSelected },
                        set: { state.largeFiles[i].isSelected = $0 }
                    )).toggleStyle(.checkbox)
                    VStack(alignment: .leading) {
                        Text(item.name)
                        Text(item.path).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer()
                    Text(item.formattedSize).font(.caption)
                }
            }
            HStack {
                Text("已选 \(selected.count) 项").font(.caption)
                Spacer()
                Button("清理选中 → 废纸篓") { showConfirm = true }.disabled(selected.isEmpty)
            }.padding(.horizontal)
            .sheet(isPresented: $showConfirm) {
                ConfirmCleanView(items: selected, permanent: .constant(false)) {
                    Task { await state.clean(items: selected) }
                }
            }
        }
    }
}

// MARK: - Duplicate (uses DuplicateFinder)

struct DuplicateTab: View {
    @State private var result: DuplicateScanResult?
    @State private var selectedIDs: Set<URL> = []
    @State private var scanning = false
    @State private var showConfirm = false

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("扫描根：用户目录").font(.caption)
                Spacer()
                Button("扫描") { scan() }.disabled(scanning)
                Button("取消") {}.disabled(!scanning)
            }
            if scanning { ProgressView("扫描中…").controlSize(.small) }
            if let result {
                Text("\(result.groups.count) 组 · 可释放 \(ByteCountFormatter.string(fromByteCount: result.reclaimableSize, countStyle: .file))")
                    .font(.caption)
                if result.filesInspected >= 500 { Text("已达扫描上限，结果可能不完整").font(.caption2).foregroundStyle(.orange) }
                List(result.groups) { group in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("单份 \(ByteCountFormatter.string(fromByteCount: group.fileSize, countStyle: .file))")
                            Text("\(group.files.count) 个文件").font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Text("可释放 \(ByteCountFormatter.string(fromByteCount: group.reclaimableSize, countStyle: .file))").font(.caption2)
                        }
                        ForEach(group.files, id: \.url) { file in
                            HStack {
                                if file.url == group.keeper.url {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                    Text("保留").font(.caption2).foregroundStyle(.green)
                                } else {
                                    Toggle("", isOn: Binding(
                                        get: { selectedIDs.contains(file.url) },
                                        set: { on in if on { selectedIDs.insert(file.url) } else { selectedIDs.remove(file.url) } }
                                    )).toggleStyle(.checkbox)
                                }
                                Text(file.url.path).font(.caption2).lineLimit(1)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                HStack {
                    Spacer()
                    Button("移选中入废纸篓") { showConfirm = true }.disabled(selectedIDs.isEmpty)
                }
            } else if !scanning {
                Spacer()
                Text("点「扫描」查找重复文件").foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding()
        .sheet(isPresented: $showConfirm) {
            VStack(spacing: 12) {
                Text("确认移入废纸篓").font(.headline)
                Text("将 \(selectedIDs.count) 个重复文件移入废纸篓，保留每组的一份。")
                HStack { Spacer(); Button("取消") { showConfirm = false }; Button("确认") { trashSelected(); showConfirm = false }.buttonStyle(.borderedProminent) }
            }.padding(20).frame(width: 380)
        }
    }

    private func scan() {
        scanning = true
        let finder = DuplicateFinder()
        Task {
            let r = try? await finder.scan(folder: FileManager.default.homeDirectoryForCurrentUser)
            await MainActor.run { result = r; selectedIDs = []; scanning = false }
        }
    }

    private func trashSelected() {
        guard let result else { return }
        let finder = DuplicateFinder()
        for group in result.groups where !selectedIDs.isDisjoint(with: Set(group.files.map { $0.url })) {
            try? finder.moveToTrash(group: group, selectedIDs: selectedIDs)
        }
        selectedIDs.removeAll()
    }
}

// MARK: - Processes

struct ProcessesTab: View {
    @ObservedObject var state: SystemToolState
    @State private var search = ""
    @State private var sort: ProcessResourceSort = .memory
    @State private var confirmForce: ProcessResourceConsumer?
    @State private var notice: String?

    private var monitor: ProcessResourceMonitor { state.processMonitorObject }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass")
                TextField("搜索进程", text: $search).textFieldStyle(.roundedBorder)
                Picker("排序", selection: $sort) {
                    Text("内存").tag(ProcessResourceSort.memory)
                    Text("CPU").tag(ProcessResourceSort.cpu)
                }.frame(width: 100)
                Text("CPU \(state.sampler.cpuPercentText) · MEM \(state.sampler.memoryPercentText)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            List(ProcessResourceMath.sorted(monitor.consumers, by: sort, search: search), id: \.id) { consumer in
                HStack {
                    if let icon = monitor.icon(for: consumer) {
                        Image(nsImage: icon).resizable().frame(width: 20, height: 20)
                    } else {
                        Image(systemName: "app.fill").frame(width: 20, height: 20)
                    }
                    Text(consumer.name)
                    Spacer()
                    Text(ByteCountFormatter.string(fromByteCount: Int64(consumer.residentBytes), countStyle: .memory)).font(.caption)
                    if isSystemProcess(consumer) {
                        Text("系统进程不可退出").font(.caption2).foregroundStyle(.tertiary)
                    } else {
                        Button("退出") { terminate(consumer, force: false) }.buttonStyle(.borderless)
                        Button("强退") { confirmForce = consumer }.buttonStyle(.borderless)
                            .foregroundStyle(.red)
                    }
                }
            }
            Text("helper 进程归组到宿主应用 · 系统进程不可退出时按钮置灰")
                .font(.caption2).foregroundStyle(.tertiary)
            if let notice { Text(notice).font(.caption).foregroundStyle(.orange) }
        }
        .padding()
        .onAppear { state.setProcessMonitoring(true) }
        .onDisappear { state.setProcessMonitoring(false) }
        .sheet(item: $confirmForce) { consumer in
            VStack(spacing: 12) {
                Text("强制退出 \(consumer.name)？").font(.headline)
                Text("未保存的内容会丢失。确定继续？")
                HStack { Spacer(); Button("取消") { confirmForce = nil }; Button("强制退出") { terminate(consumer, force: true); confirmForce = nil }.buttonStyle(.borderedProminent) }
            }.padding(20).frame(width: 360)
        }
    }

    private func isSystemProcess(_ consumer: ProcessResourceConsumer) -> Bool {
        guard let path = consumer.applicationPath else { return true }
        // /System、/usr、内核等不属于 /Applications 或用户目录的视为系统进程
        return !path.hasPrefix("/Applications") && !path.contains("/Applications/")
            && !path.hasPrefix(NSHomeDirectory())
    }

    private func terminate(_ consumer: ProcessResourceConsumer, force: Bool) {
        guard let path = consumer.applicationPath, !isSystemProcess(consumer) else {
            notice = "系统进程不可退出"
            return
        }
        let running = NSWorkspace.shared.runningApplications.first { $0.bundleURL?.path == path }
        guard let app = running else { notice = "系统进程不可退出"; return }
        let ok = force ? app.forceTerminate() : app.terminate()
        if !ok { notice = "无法退出该进程（可能受系统保护）" }
    }
}

// MARK: - Bottom status bar

struct StatusBar: View {
    @ObservedObject var state: SystemToolState

    var body: some View {
        HStack {
            if state.isScanning {
                Text("扫描中 \(Int(state.scanProgress * 100))%").font(.caption)
                ProgressView(value: state.scanProgress).frame(width: 100)
                Button("取消") {}.disabled(true)
            } else {
                Text(state.statusMessage).font(.caption).foregroundStyle(.secondary)
                if let date = state.lastScanDate {
                    Text("· 上次扫描 \(date.formatted(.relative(presentation: .named)))").font(.caption2).foregroundStyle(.tertiary)
                }
            }
            Spacer()
            Text("温度/网速不做").font(.caption2).foregroundStyle(.quaternary)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .frame(height: 32)
    }
}

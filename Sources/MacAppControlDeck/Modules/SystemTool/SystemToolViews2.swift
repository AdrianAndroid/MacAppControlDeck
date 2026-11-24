import SwiftUI
import AppKit

// MARK: - 应用卸载

struct UninstallTab: View {
    @ObservedObject var state: SystemToolState
    let onRequestUninstall: () -> Void

    private var checkedCount: Int { state.checkedHigh.count + state.checkedReview.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("已安装应用").font(.headline)
                    Text("选中应用后先扫描关联文件，再逐项确认要清理的残留")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    state.scanResiduals()
                } label: {
                    Label("扫描残留", systemImage: "magnifyingglass")
                }
                .controlSize(.small)
                .buttonStyle(.borderedProminent)
                .disabled(state.selectedApp == nil || state.scanningResiduals)
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)

            if let result = state.lastCleanResult {
                CleanResultBar(result: result) { state.lastCleanResult = nil }
                    .padding(.horizontal, 12)
            }

            HStack(alignment: .top, spacing: 12) {
                // 左：应用列表
                VStack(spacing: 0) {
                    HStack {
                        Text("应用").font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                        Spacer()
                        Text("\(state.installedApps.count) 个")
                            .font(.caption2).foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color(nsColor: .windowBackgroundColor).opacity(0.75))
                    Divider()
                    List(state.installedApps, id: \.path) { app in
                        HStack(spacing: 8) {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: app.path.path))
                                .resizable().frame(width: 24, height: 24)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(app.appName).font(.callout).lineLimit(1)
                                Text(app.bundleIdentifier)
                                    .font(.caption2).foregroundStyle(.secondary)
                                    .lineLimit(1).truncationMode(.middle)
                            }
                            Spacer(minLength: 4)
                            if state.selectedApp?.path == app.path, state.selectedAppSize > 0 {
                                Text(systemToolByteText(state.selectedAppSize))
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 3)
                        .contentShape(Rectangle())
                        .onTapGesture { state.selectApp(app) }
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(state.selectedApp?.path == app.path
                                      ? Color.accentColor.opacity(0.14) : Color.clear)
                        )
                    }
                    .listStyle(.inset(alternatesRowBackgrounds: true))
                }
                .frame(width: 236)
                .clipShape(RoundedRectangle(cornerRadius: SystemToolUI.corner))
                .overlay(RoundedRectangle(cornerRadius: SystemToolUI.corner).stroke(Color(nsColor: .separatorColor), lineWidth: 0.5))

                // 右：关联文件分级
                VStack(alignment: .leading, spacing: 10) {
                    if let app = state.selectedApp {
                        HStack {
                            Text("\(app.appName) 的关联文件")
                                .font(.subheadline).fontWeight(.semibold)
                            Spacer()
                            Text("已勾选 \(checkedCount) 项")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    } else {
                        Text("关联文件").font(.subheadline).fontWeight(.semibold)
                    }

                    if state.scanningResiduals {
                        HStack {
                            ProgressView().controlSize(.small)
                            Text("正在扫描关联文件…").font(.caption).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if state.selectedApp == nil {
                        EmptyStateView(
                            icon: "app.badge",
                            title: "请先选择一个应用",
                            message: "从左侧列表选择要卸载的应用，然后点「扫描残留」。"
                        )
                    } else if state.highConfidenceResiduals.isEmpty && state.reviewResiduals.isEmpty {
                        EmptyStateView(
                            icon: "checkmark.circle",
                            title: "尚未发现关联文件",
                            message: "点「扫描残留」查找该应用的缓存、偏好设置与容器目录。",
                            actionTitle: "扫描残留",
                            action: { state.scanResiduals() }
                        )
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 10) {
                                if !state.highConfidenceResiduals.isEmpty {
                                    ResidualGroup(
                                        title: "高置信残留",
                                        subtitle: "可批量勾选 · \(state.highConfidenceResiduals.count) 项",
                                        tint: .green,
                                        urls: state.highConfidenceResiduals,
                                        checked: state.checkedHigh,
                                        allowsBatch: true,
                                        onToggle: { url, value in
                                            if value { state.checkedHigh.insert(url) } else { state.checkedHigh.remove(url) }
                                        },
                                        onBatch: { select in
                                            state.checkedHigh = select
                                                ? Set(state.highConfidenceResiduals.filter { !isBlocked($0) })
                                                : []
                                        }
                                    )
                                }
                                if !state.reviewResiduals.isEmpty {
                                    ResidualGroup(
                                        title: "需人工核对",
                                        subtitle: "只能逐项勾选 · \(state.reviewResiduals.count) 项",
                                        tint: .orange,
                                        urls: state.reviewResiduals,
                                        checked: state.checkedReview,
                                        allowsBatch: false,
                                        onToggle: { url, value in
                                            if value { state.checkedReview.insert(url) } else { state.checkedReview.remove(url) }
                                        },
                                        onBatch: nil
                                    )
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: SystemToolUI.cardCorner).fill(Color(nsColor: .controlBackgroundColor)))
                .overlay(RoundedRectangle(cornerRadius: SystemToolUI.cardCorner).stroke(Color(nsColor: .separatorColor), lineWidth: 0.5))
            }
            .padding(.horizontal, 12)

            HStack(spacing: 6) {
                Image(systemName: "info.circle").font(.caption2)
                Text("应用包与勾选的残留都先移入废纸篓；系统路径与符号链接项不可勾选")
                    .font(.caption2).foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { if state.installedApps.isEmpty { state.loadInstalledApps() } }
    }

    private func isBlocked(_ url: URL) -> Bool {
        FileProtection.isProtectedFromDeletion(path: url.path)
    }
}

private struct ResidualGroup: View {
    let title: String
    let subtitle: String
    let tint: Color
    let urls: [URL]
    let checked: Set<URL>
    let allowsBatch: Bool
    let onToggle: (URL, Bool) -> Void
    let onBatch: ((Bool) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle().fill(tint).frame(width: 7, height: 7)
                Text(title).font(.callout).fontWeight(.semibold)
                Text(subtitle).font(.caption2).foregroundStyle(.secondary)
                Spacer()
                if allowsBatch, let onBatch {
                    Button(checked.count == urls.count ? "全不选" : "全选") {
                        onBatch(checked.count != urls.count)
                    }
                    .buttonStyle(.borderless).font(.caption)
                }
            }
            VStack(spacing: 0) {
                ForEach(urls, id: \.self) { url in
                    let blocked = FileProtection.isProtectedFromDeletion(path: url.path)
                    HStack(spacing: 6) {
                        Toggle("", isOn: Binding(
                            get: { checked.contains(url) },
                            set: { onToggle(url, $0) }
                        ))
                        .toggleStyle(.checkbox)
                        .labelsHidden()
                        .disabled(blocked)
                        Text((url.path as NSString).abbreviatingWithTildeInPath)
                            .font(.caption).lineLimit(1).truncationMode(.middle)
                        Spacer(minLength: 4)
                        if blocked {
                            Text("系统路径").font(.caption2).foregroundStyle(.red)
                        } else {
                            Text(residualSize(url))
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 8).padding(.vertical, 5)
                    .opacity(blocked ? 0.55 : 1)
                    Divider()
                }
            }
            .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .textBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(nsColor: .separatorColor), lineWidth: 0.5))
        }
    }

    private func residualSize(_ url: URL) -> String {
        guard let size = try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey]).totalFileAllocatedSize else {
            return "—"
        }
        return systemToolByteText(Int64(size))
    }
}

// MARK: - 卸载确认弹窗

struct UninstallConfirmSheet: View {
    @ObservedObject var state: SystemToolState
    @Environment(\.dismiss) private var dismiss

    private var residualPaths: [String] {
        (Array(state.checkedHigh) + Array(state.checkedReview)).map { ($0.path as NSString).abbreviatingWithTildeInPath }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "app.badge.checkmark")
                    .font(.title2).foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("确认卸载 \(state.selectedApp?.appName ?? "应用")？").font(.headline)
                    Text("应用包与勾选的关联文件将移入废纸篓，可在需要时恢复。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(16)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "app.fill").foregroundStyle(Color.accentColor).frame(width: 16)
                    Text(state.selectedApp?.path.path ?? "—")
                        .font(.caption).lineLimit(1).truncationMode(.middle)
                    Spacer(minLength: 6)
                    Text(state.selectedAppSize > 0 ? systemToolByteText(state.selectedAppSize) : "应用包")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Text("应用包（先移入废纸篓）")
                    .font(.caption2).foregroundStyle(.tertiary)
                    .padding(.leading, 24)

                Divider()

                HStack {
                    Text("勾选的关联文件 · \(residualPaths.count) 项")
                        .font(.caption).fontWeight(.semibold)
                    Spacer()
                    Text("未勾选的会保留")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                if residualPaths.isEmpty {
                    Text("（未勾选任何残留，只卸载应用包）")
                        .font(.caption2).foregroundStyle(.tertiary)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(residualPaths.prefix(10), id: \.self) { path in
                                HStack(spacing: 6) {
                                    Image(systemName: "doc").foregroundStyle(.secondary).frame(width: 14)
                                    Text(path).font(.caption).lineLimit(1).truncationMode(.middle)
                                }
                            }
                            if residualPaths.count > 10 {
                                Text("… 以及另外 \(residualPaths.count - 10) 项")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(maxHeight: 160)
                }
            }
            .padding(16)

            Divider()

            HStack {
                Text("此操作不会删除系统文件；受保护路径会自动跳过")
                    .font(.caption2).foregroundStyle(.tertiary)
                Spacer(minLength: 8)
                Button("取消") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("确认卸载") {
                    dismiss()
                    Task { await state.uninstallSelectedApp() }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
            .padding(16)
        }
        .frame(width: 520)
    }
}

// MARK: - 大文件

struct LargeFilesTab: View {
    @ObservedObject var state: SystemToolState
    @AppStorage("systemTool.cleaning.largeFileThreshold") private var thresholdMB = 100
    @AppStorage("systemTool.cleaning.oldFileMonths") private var oldMonths = 12
    @State private var roots: [String] = UserDefaults.standard.stringArray(forKey: "systemTool.cleaning.largeFileRoots") ?? []
    // v3：分类 tab 与分组折叠（借鉴柠檬大文件结果页）
    private enum FileKind: String, CaseIterable { case all, document, video, audio, package, other
        var label: String {
            switch self {
            case .all: return "全部"; case .document: return "文档"; case .video: return "视频"
            case .audio: return "音频"; case .package: return "安装包"; case .other: return "其他"
            }
        }
    }
    @State private var fileKind: FileKind = .all
    @State private var collapsedSizeGroups: Set<String> = []

    /// 按扩展名映射柠檬式分类；纯展示分组，不影响扫描/选中逻辑。
    private func kind(of item: CleanableItem) -> FileKind {
        let ext = (item.path as NSString).pathExtension.lowercased()
        if ["pages", "numbers", "key", "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt", "md", "rtf", "csv"].contains(ext) { return .document }
        if ["mp4", "mov", "m4v", "avi", "mkv", "wmv", "flv"].contains(ext) { return .video }
        if ["mp3", "m4a", "aac", "flac", "wav", "aiff", "ogg"].contains(ext) { return .audio }
        if ["dmg", "pkg", "zip", "tar", "gz", "rar", "7z", "app"].contains(ext) { return .package }
        return .other
    }
    private var filteredLargeFiles: [CleanableItem] {
        fileKind == .all ? state.largeFiles : state.largeFiles.filter { kind(of: $0) == fileKind }
    }
    /// 按大小分桶，对齐柠檬「1 GB 以上 / 100 MB–1 GB / …」。
    private func sizeBucket(_ item: CleanableItem) -> String {
        if item.size >= 1024 * 1024 * 1024 { return "1 GB 以上" }
        if item.size >= 500 * 1024 * 1024 { return "500 MB – 1 GB" }
        if item.size >= 100 * 1024 * 1024 { return "100 MB – 500 MB" }
        return "其他大小"
    }
    private var sizeBuckets: [(String, [CleanableItem])] {
        let order = ["1 GB 以上", "500 MB – 1 GB", "100 MB – 500 MB", "其他大小"]
        let grouped = Dictionary(grouping: filteredLargeFiles, by: sizeBucket)
        return order.compactMap { key in
            guard let items = grouped[key], !items.isEmpty else { return nil }
            return (key, items.sorted { $0.size > $1.size })
        }
    }

    private var rootLabel: String {
        if let first = roots.first, !first.isEmpty {
            return (first as NSString).abbreviatingWithTildeInPath
        }
        return "默认：下载 / 文稿 / 桌面"
    }
    private var allSelected: Bool {
        !state.largeFiles.isEmpty && state.largeFiles.allSatisfy { $0.isSelected }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !state.hasFullDiskAccess { FDABanner().padding(.horizontal, 12).padding(.top, 10) }
            if let result = state.lastCleanResult {
                CleanResultBar(result: result) { state.lastCleanResult = nil }
                    .padding(.horizontal, 12)
            }

            SystemToolCard(title: "筛选条件", subtitle: "修改后重新扫描生效") {
                VStack(spacing: 8) {
                    HStack(spacing: 12) {
                        Text("大小阈值").font(.caption).frame(width: 62, alignment: .leading)
                        Picker("", selection: $thresholdMB) {
                            Text("> 50 MB").tag(50)
                            Text("> 100 MB").tag(100)
                            Text("> 500 MB").tag(500)
                            Text("> 1 GB").tag(1024)
                        }
                        .labelsHidden().frame(width: 130)
                        Text("修改时间").font(.caption).frame(width: 62, alignment: .leading)
                        Picker("", selection: $oldMonths) {
                            Text("> 6 个月").tag(6)
                            Text("> 1 年").tag(12)
                            Text("> 2 年").tag(24)
                        }
                        .labelsHidden().frame(width: 130)
                        Spacer()
                    }
                    HStack(spacing: 8) {
                        Image(systemName: "folder").foregroundStyle(.secondary)
                        Text("扫描目录").font(.caption)
                        Text(rootLabel)
                            .font(.caption).foregroundStyle(.secondary)
                            .lineLimit(1).truncationMode(.middle)
                        Spacer(minLength: 6)
                        Button("选择…") { chooseRoot() }.controlSize(.small)
                        if !roots.isEmpty {
                            Button("恢复默认") {
                                roots = []
                                UserDefaults.standard.removeObject(forKey: "systemTool.cleaning.largeFileRoots")
                            }
                            .controlSize(.small)
                        }
                    }
                }
            }
            .padding(.horizontal, 12)

            HStack(spacing: 10) {
                Label("共 \(state.largeFiles.count) 项", systemImage: "doc")
                Label("已选 \(state.selectedItems.count) 项", systemImage: "checkmark.circle")
                Label("可清理 \(systemToolByteText(state.selectedSize))", systemImage: "externaldrive")
                Spacer()
                Button {
                    Task { await state.scanLargeFiles() }
                } label: {
                    Label("扫描", systemImage: "magnifyingglass")
                }
                .controlSize(.small)
                .buttonStyle(.borderedProminent)
                .disabled(state.phase != .idle)
                Button("取消") { state.requestCancelScan() }
                    .controlSize(.small)
                    .disabled(state.phase != .scanning)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)

            if state.largeFiles.isEmpty {
                if state.phase == .scanning {
                    ScanningStateView(
                        title: "正在扫描大文件",
                        currentPath: state.currentPath,
                        detail: "遍历扫描目录，结果默认不选中",
                        onCancel: { state.requestCancelScan() }
                    )
                } else {
                    EmptyScanState(
                        icon: "doc",
                        title: "尚未扫描大文件",
                        message: "按大小与时间筛选。结果默认全部不选中，确认路径与大小后再勾选。",
                        actionTitle: "开始扫描",
                        action: { Task { await state.scanLargeFiles() } }
                    )
                }
            } else {
                // v3：分类 tab（对齐柠檬「全部/音频/视频/文档/安装包/其他」）
                HStack(spacing: 4) {
                    ForEach(FileKind.allCases, id: \.self) { kind in
                        Button(kind.label) { fileKind = kind }
                            .buttonStyle(.borderless)
                            .font(.caption)
                            .foregroundStyle(fileKind == kind ? Color.accentColor : Color.secondary)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(fileKind == kind ? Color.accentColor.opacity(0.12) : Color.clear)
                            .cornerRadius(6)
                    }
                    Spacer(minLength: 6)
                    Text("按大小").font(.caption2).foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 12)

                if filteredLargeFiles.isEmpty {
                    EmptyStateView(icon: "doc", title: "该分类下没有文件", message: "切换到「全部」查看其他结果。")
                } else {
                    FileTable(
                        allSelected: allSelected,
                        selectAll: { state.setLargeFilesSelected(!allSelected) }
                    ) {
                        ForEach(sizeBuckets, id: \.0) { bucket, items in
                            CollapsibleGroupHeader(
                                title: bucket,
                                count: items.count,
                                sizeText: systemToolByteText(items.reduce(0) { $0 + $1.size }),
                                collapsed: Binding(
                                    get: { collapsedSizeGroups.contains(bucket) },
                                    set: { if $0 { collapsedSizeGroups.insert(bucket) } else { collapsedSizeGroups.remove(bucket) } }
                                ),
                                allSelected: items.allSatisfy { $0.isSelected },
                                onToggleAll: {
                                    let select = !items.allSatisfy { $0.isSelected }
                                    for item in items { state.setLargeFileSelected(item.id, value: select) }
                                }
                            ) {
                                EmptyView()
                            }
                            Divider()
                            if !collapsedSizeGroups.contains(bucket) {
                                ForEach(items) { item in
                                    CleanableRow(
                                        item: item,
                                        selected: item.isSelected,
                                        onToggle: { state.setLargeFileSelected(item.id, value: $0) },
                                        onExclude: { CleanupExclusions.add($0) }
                                    )
                                    Divider()
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                }
            }

            HStack(spacing: 6) {
                Image(systemName: "info.circle").font(.caption2)
                Text("隐藏文件与包内容默认跳过；受保护路径不会出现在结果中")
                    .font(.caption2).foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12).padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            roots = UserDefaults.standard.stringArray(forKey: "systemTool.cleaning.largeFileRoots") ?? []
        }
    }

    private func chooseRoot() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "选择"
        panel.message = "选择大文件扫描目录"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        roots = [url.path]
        UserDefaults.standard.set(roots, forKey: "systemTool.cleaning.largeFileRoots")
    }
}

// MARK: - 重复文件

struct DuplicateTab: View {
    @ObservedObject var state: SystemToolState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !state.hasFullDiskAccess { FDABanner().padding(.horizontal, 12).padding(.top, 10) }

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("扫描根目录").font(.caption).fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    PathPickerButton(path: state.duplicateRoot.path) { state.setDuplicateRoot($0) }
                }
                Spacer()
                if state.duplicateScanning, let progress = state.duplicateProgress {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("已检查 \(progress.filesInspected) 个文件")
                            .font(.caption2).foregroundStyle(.secondary)
                        if let fraction = progress.fractionCompleted {
                            ProgressView(value: fraction).frame(width: 120)
                        }
                    }
                }
                Button {
                    state.scanDuplicates()
                } label: {
                    Label("扫描", systemImage: "magnifyingglass")
                }
                .controlSize(.small)
                .buttonStyle(.borderedProminent)
                .disabled(state.duplicateScanning || state.phase != .idle)
                Button("取消") { state.requestCancelScan() }
                    .controlSize(.small)
                    .disabled(!state.duplicateScanning)
            }
            .padding(.horizontal, 12).padding(.top, 10)

            if let result = state.lastCleanResult {
                CleanResultBar(result: result) { state.lastCleanResult = nil }
                    .padding(.horizontal, 12)
            }

            if let error = state.duplicateError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.red)
                    Text("扫描失败：\(error)").font(.caption)
                    Spacer()
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 7).fill(Color.red.opacity(0.08)))
                .padding(.horizontal, 12)
            }

            if let result = state.duplicateResult {
                HStack(spacing: 14) {
                    Label("\(result.groups.count) 组", systemImage: "square.on.square")
                    Label("\(result.duplicateFileCount) 个文件", systemImage: "doc.on.doc")
                    Label("可释放 \(systemToolByteText(result.reclaimableSize))", systemImage: "externaldrive")
                    Label("已选 \(state.duplicateSelected.count) 项", systemImage: "checkmark.circle")
                    Spacer()
                }
                .font(.caption).foregroundStyle(.secondary)
                .padding(.horizontal, 12)

                if result.filesInspected >= 500 {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                        Text("已达到扫描上限，结果可能不完整；已找到的分组仍可查看和操作")
                            .font(.caption2)
                        Spacer()
                    }
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 7).fill(Color.orange.opacity(0.10)))
                    .padding(.horizontal, 12)
                }

                if !result.skippedFiles.isEmpty {
                    Menu {
                        ForEach(result.skippedFiles.prefix(20)) { skipped in
                            Text("\(skipped.url.lastPathComponent) · \(skipped.reason.label)")
                                .font(.caption)
                        }
                    } label: {
                        Label("跳过 \(result.skippedFiles.count) 个文件（符号链接 / 包 / 云占位等）", systemImage: "info.circle")
                            .font(.caption2)
                    }
                    .controlSize(.small)
                    .padding(.horizontal, 12)
                }

                if result.groups.isEmpty {
                    EmptyStateView(
                        icon: "checkmark.circle",
                        title: "未发现重复文件",
                        message: "可以换一个扫描根目录再试。",
                        actionTitle: "重新扫描",
                        action: { state.scanDuplicates() }
                    )
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 10) {
                            ForEach(result.groups) { group in
                                DuplicateGroupCard(group: group, state: state)
                            }
                        }
                        .padding(.horizontal, 12)
                    }
                }
            } else if state.duplicateScanning {
                ScanningStateView(
                    title: "正在查找重复文件",
                    currentPath: state.currentPath,
                    detail: {
                        if let p = state.duplicateProgress {
                            return "已检查 \(p.filesInspected) 个文件"
                        }
                        return "按内容哈希比对，结果默认不选中"
                    }(),
                    onCancel: { state.requestCancelScan() }
                )
            } else {
                EmptyScanState(
                    icon: "doc.on.doc",
                    title: "按内容查找重复文件",
                    message: "先选择扫描根目录。每组默认保留一份（keeper），其余默认不选中，勾选并确认后才移入废纸篓。",
                    actionTitle: "开始扫描",
                    action: { state.scanDuplicates() }
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { state.refreshDuplicateRoot() }
    }
}

private struct DuplicateGroupCard: View {
    let group: DuplicateGroup
    @ObservedObject var state: SystemToolState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "doc.on.doc.fill").foregroundStyle(.pink)
                Text("单份 \(systemToolByteText(group.fileSize))")
                    .font(.callout).fontWeight(.semibold)
                Text("\(group.files.count) 个文件")
                    .font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Text("可释放 \(systemToolByteText(group.reclaimableSize))")
                    .font(.caption).foregroundStyle(.green)
            }
            VStack(spacing: 0) {
                ForEach(group.files) { file in
                    let isKeeper = file.url == group.keeper.url
                    HStack(spacing: 6) {
                        if isKeeper {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .frame(width: 20)
                            Text("保留").font(.caption2).foregroundStyle(.green)
                                .frame(width: 32, alignment: .leading)
                        } else {
                            Toggle("", isOn: Binding(
                                get: { state.duplicateSelected.contains(file.url) },
                                set: { on in
                                    if on { state.duplicateSelected.insert(file.url) }
                                    else { state.duplicateSelected.remove(file.url) }
                                }
                            ))
                            .toggleStyle(.checkbox).labelsHidden()
                            .frame(width: 20)
                            Spacer().frame(width: 32)
                        }
                        Text((file.url.path as NSString).abbreviatingWithTildeInPath)
                            .font(.caption).lineLimit(1).truncationMode(.middle)
                        Spacer(minLength: 6)
                        if let modified = file.modifiedAt {
                            Text(modified.formatted(.relative(presentation: .named)))
                                .font(.caption2).foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.horizontal, 8).padding(.vertical, 5)
                    .opacity(isKeeper ? 0.75 : 1)
                    Divider()
                }
            }
            .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .textBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(nsColor: .separatorColor), lineWidth: 0.5))
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: SystemToolUI.cardCorner).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: SystemToolUI.cardCorner).stroke(Color(nsColor: .separatorColor), lineWidth: 0.5))
    }
}

// MARK: - 进程

struct ProcessesTab: View {
    @ObservedObject var state: SystemToolState
    @State private var search = ""
    @State private var sort: ProcessResourceSort = .memory
    @State private var confirmForce: ProcessResourceConsumer?
    @State private var notice: String?

    private var monitor: ProcessResourceMonitor { state.processMonitorObject }
    private var rows: [ProcessResourceConsumer] {
        ProcessResourceMath.sorted(monitor.consumers, by: sort, search: search)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                HStack(spacing: 5) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("搜索进程", text: $search)
                        .textFieldStyle(.roundedBorder)
                }
                .frame(width: 180)
                Picker("排序", selection: $sort) {
                    Text("按内存").tag(ProcessResourceSort.memory)
                    Text("按 CPU").tag(ProcessResourceSort.cpu)
                }
                .labelsHidden().frame(width: 100)
                Spacer()
                HStack(spacing: 5) {
                    Circle()
                        .fill(monitor.isSampling ? Color.green : Color.orange)
                        .frame(width: 6, height: 6)
                    Text(monitor.isSampling ? "采样中 · 每 2 秒" : "采样未启动")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Text("CPU \(state.sampler.cpuPercentText) · MEM \(state.sampler.memoryPercentText)")
                    .font(.caption).monospacedDigit().foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12).padding(.top, 10)

            HStack(spacing: 6) {
                Spacer().frame(width: 24)
                Text("进程名称")
                    .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                Spacer(minLength: 8)
                Text("状态")
                    .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                    .frame(width: 72, alignment: .leading)
                Text("CPU")
                    .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                    .frame(width: 56, alignment: .trailing)
                Text("内存")
                    .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                    .frame(width: 82, alignment: .trailing)
                Text("操作")
                    .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                    .frame(width: 132, alignment: .trailing)
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Color(nsColor: .windowBackgroundColor).opacity(0.75))

            if rows.isEmpty {
                if monitor.samplingFailed {
                    EmptyStateView(
                        icon: "exclamationmark.triangle",
                        title: "进程采样失败",
                        message: "无法读取进程资源信息，请稍后重试或重新打开本页。"
                    )
                } else if monitor.isWarmingUp {
                    EmptyStateView(
                        icon: "cpu",
                        title: "正在采集进程数据",
                        message: "首次加载需要几秒，之后每 2 秒刷新。"
                    )
                } else {
                    EmptyStateView(
                        icon: "cpu",
                        title: "没有匹配的进程",
                        message: "换个关键词或排序方式再试。"
                    )
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(rows) { consumer in
                            ProcessRow(
                                consumer: consumer,
                                icon: monitor.icon(for: consumer),
                                canTerminate: canTerminate(consumer),
                                onQuit: { terminate(consumer, force: false) },
                                onForce: { confirmForce = consumer }
                            )
                            Divider()
                        }
                    }
                }
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: SystemToolUI.corner))
                .overlay(RoundedRectangle(cornerRadius: SystemToolUI.corner).stroke(Color(nsColor: .separatorColor), lineWidth: 0.5))
                .padding(.horizontal, 12)
            }

            HStack(spacing: 6) {
                Image(systemName: "info.circle").font(.caption2)
                Text("helper 进程已归组到宿主应用（显示 ×N）；系统 / root / 受保护进程的退出按钮不可用")
                    .font(.caption2).foregroundStyle(.secondary)
                Spacer()
                if let notice {
                    Text(notice).font(.caption2).foregroundStyle(.orange)
                }
            }
            .padding(.horizontal, 12).padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { state.setProcessMonitoring(true) }
        .onDisappear { state.setProcessMonitoring(false) }
        .sheet(item: $confirmForce) { consumer in
            ForceQuitConfirmSheet(consumer: consumer) {
                terminate(consumer, force: true)
                confirmForce = nil
            } onCancel: {
                confirmForce = nil
            }
        }
    }

    private func canTerminate(_ consumer: ProcessResourceConsumer) -> Bool {
        guard let path = consumer.applicationPath else { return false }
        return path.hasPrefix("/Applications")
            || path.contains("/Applications/")
            || path.hasPrefix(NSHomeDirectory())
    }

    private func terminate(_ consumer: ProcessResourceConsumer, force: Bool) {
        guard canTerminate(consumer), let path = consumer.applicationPath else {
            notice = "系统进程不可退出"
            return
        }
        let running = NSWorkspace.shared.runningApplications.first { $0.bundleURL?.path == path }
        guard let app = running else {
            notice = "未找到对应的运行中应用"
            return
        }
        let ok = force ? app.forceTerminate() : app.terminate()
        if !ok { notice = "无法退出该进程（可能受系统保护）" }
        else { notice = nil }
    }
}

private struct ProcessRow: View {
    let consumer: ProcessResourceConsumer
    let icon: NSImage?
    let canTerminate: Bool
    let onQuit: () -> Void
    let onForce: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            if let icon {
                Image(nsImage: icon).resizable().frame(width: 20, height: 20)
            } else {
                Image(systemName: "app.fill")
                    .foregroundStyle(.secondary)
                    .frame(width: 20, height: 20)
            }
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 5) {
                    Text(consumer.name).font(.callout).lineLimit(1)
                    if consumer.processCount > 1 {
                        Text("×\(consumer.processCount)")
                            .font(.caption2).foregroundStyle(.secondary)
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background(Capsule().fill(Color.secondary.opacity(0.15)))
                    }
                }
                Text(consumer.applicationPath ?? "系统进程")
                    .font(.caption2).foregroundStyle(.tertiary)
                    .lineLimit(1).truncationMode(.middle)
            }
            Spacer(minLength: 8)
            // v3：状态胶囊（借鉴柠檬启动项），系统进程置灰
            StatusCapsule(
                text: canTerminate ? "正常" : "系统进程",
                tone: canTerminate ? .normal : .system
            )
            .frame(width: 72, alignment: .leading)
            if let cpu = consumer.cpuFraction {
                Text("\(Int((cpu * 100).rounded()))%")
                    .font(.caption).monospacedDigit()
                    .frame(width: 56, alignment: .trailing)
            } else {
                Text("—").font(.caption).foregroundStyle(.tertiary)
                    .frame(width: 56, alignment: .trailing)
            }
            Text(ByteCountFormatter.string(fromByteCount: Int64(consumer.residentBytes), countStyle: .memory))
                .font(.caption).monospacedDigit()
                .frame(width: 82, alignment: .trailing)
            HStack(spacing: 6) {
                if canTerminate {
                    Button("退出") { onQuit() }
                        .buttonStyle(.borderless).font(.caption)
                    Button("强退") { onForce() }
                        .buttonStyle(.borderless).font(.caption)
                        .foregroundStyle(.red)
                } else {
                    Button("退出") {}.disabled(true)
                        .buttonStyle(.borderless).font(.caption)
                    Button("强退") {}.disabled(true)
                        .buttonStyle(.borderless).font(.caption)
                    Text("系统进程").font(.caption2).foregroundStyle(.tertiary)
                }
            }
            .frame(width: 132, alignment: .trailing)
        }
        .padding(.horizontal, 10)
        .frame(height: 40)
    }
}

private struct ForceQuitConfirmSheet: View {
    let consumer: ProcessResourceConsumer
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.octagon.fill")
                    .font(.title2).foregroundStyle(.red)
                Text("强制退出 \(consumer.name)？").font(.headline)
            }
            Text("未保存的内容会丢失，应用不会有机会提示保存。确定继续？")
                .font(.callout).foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("取消", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("强制退出", action: onConfirm)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
            }
        }
        .padding(20)
        .frame(width: 380)
    }
}

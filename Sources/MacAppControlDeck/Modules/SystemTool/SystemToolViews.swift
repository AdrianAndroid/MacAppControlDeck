import SwiftUI
import AppKit

enum SystemToolTab: String, CaseIterable, Identifiable {
    case overview, junk, uninstall, large, duplicate, processes
    var id: String { rawValue }
    var title: String {
        switch self {
        case .overview: return "概览"
        case .junk: return "垃圾清理"
        case .uninstall: return "应用卸载"
        case .large: return "大文件"
        case .duplicate: return "重复文件"
        case .processes: return "进程"
        }
    }
    var icon: String {
        switch self {
        case .overview: return "square.grid.2x2"
        case .junk: return "gearshape.fill"
        case .uninstall: return "app.badge"
        case .large: return "doc.fill"
        case .duplicate: return "doc.on.doc.fill"
        case .processes: return "cpu.fill"
        }
    }
}

extension CleaningCategory {
    /// 界面用的中文短名（上游 rawValue 是英文，不直接展示给用户）。
    var displayName: String {
        switch self {
        case .systemJunk: return "系统垃圾"
        case .userCache: return "用户缓存"
        case .trashBins: return "废纸篓"
        case .largeFiles: return "大文件"
        case .xcodeJunk: return "Xcode 缓存"
        case .brewCache: return "Homebrew 缓存"
        case .nodeCache: return "Node 缓存"
        case .devToolCaches: return "开发缓存"
        }
    }
}

// MARK: - 主窗口

struct SystemToolRootView: View {
    @StateObject private var state: SystemToolState
    @State private var tab: SystemToolTab = .overview
    @State private var showCleanConfirm = false
    @State private var showUninstallConfirm = false

    init(sampler: SystemSampler) {
        _state = StateObject(wrappedValue: SystemToolState(sampler: sampler))
    }

    var body: some View {
        VStack(spacing: 0) {
            SystemToolTabBar(selection: $tab)
            Divider()

            ZStack {
                switch tab {
                case .overview:
                    OverviewTab(state: state, goTo: { tab = $0 })
                case .junk:
                    JunkTab(state: state)
                case .uninstall:
                    UninstallTab(state: state, onRequestUninstall: { showUninstallConfirm = true })
                case .large:
                    LargeFilesTab(state: state)
                case .duplicate:
                    DuplicateTab(state: state)
                case .processes:
                    ProcessesTab(state: state)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()
            SystemToolStatusBar(
                state: state,
                onClean: { showCleanConfirm = true },
                onUninstall: { showUninstallConfirm = true }
            )
        }
        .frame(minWidth: 640, minHeight: 520)
        .onAppear { state.activeTab = tab }
        .onChange(of: tab) { _, newValue in state.activeTab = newValue }
        .sheet(isPresented: $showCleanConfirm) {
            ConfirmCleanSheet(items: state.selectedItems) { permanent in
                state.cleanSelected(permanent: permanent)
            }
        }
        .sheet(isPresented: $showUninstallConfirm) {
            UninstallConfirmSheet(state: state)
        }
    }
}

// MARK: - 页签栏

private struct SystemToolTabBar: View {
    @Binding var selection: SystemToolTab

    var body: some View {
        HStack(spacing: 2) {
            ForEach(SystemToolTab.allCases) { item in
                Button { selection = item } label: {
                    HStack(spacing: 6) {
                        Image(systemName: item.icon).font(.caption)
                        Text(item.title).font(.callout)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(selection == item ? Color.accentColor.opacity(0.14) : Color.clear)
                    .foregroundStyle(selection == item ? Color.accentColor : Color.secondary)
                    .cornerRadius(7)
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: - 底部状态栏（三态）

struct SystemToolStatusBar: View {
    @ObservedObject var state: SystemToolState
    let onClean: () -> Void
    let onUninstall: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            switch state.phase {
            case .idle:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green).font(.caption)
                Text(state.statusMessage)
                    .font(.caption).lineLimit(1)
                if let date = state.lastScanDate {
                    Text("· 上次扫描 \(date.formatted(.relative(presentation: .named)))")
                        .font(.caption2).foregroundStyle(.tertiary)
                }
            case .scanning:
                ProgressView()
                    .controlSize(.small)
                Text("扫描中 \(Int(state.scanProgress * 100))%")
                    .font(.caption).fontWeight(.medium)
                if !state.currentPath.isEmpty {
                    Text(state.currentPath)
                        .font(.caption2).foregroundStyle(.tertiary)
                        .lineLimit(1).truncationMode(.middle)
                        .frame(maxWidth: 190)
                }
                Button("取消") { state.cancelScan() }
                    .controlSize(.small)
            case .cleaning:
                ProgressView(value: state.scanProgress)
                    .frame(width: 90)
                Text("清理中…").font(.caption).fontWeight(.medium)
                Button("停止") { state.stopCleaning() }
                    .controlSize(.small)
            }

            Spacer(minLength: 8)

            if state.activeTab == .uninstall {
                let count = state.checkedHigh.count + state.checkedReview.count
                Text("已选 \(count) 项残留")
                    .font(.caption).foregroundStyle(.secondary)
                Button("卸载应用…") { onUninstall() }
                    .controlSize(.small)
                    .disabled(state.selectedApp == nil || state.phase != .idle)
            } else {
                Text("已选 \(state.selectedItems.count) 项 · \(systemToolByteText(state.selectedSize))")
                    .font(.caption).foregroundStyle(.secondary)
                Button("全不选") { state.clearSelection() }
                    .controlSize(.small)
                    .disabled(state.selectedItems.isEmpty)
                Button("清理选中 (\(state.selectedItems.count) 项)") { onClean() }
                    .controlSize(.small)
                    .buttonStyle(.borderedProminent)
                    .disabled(!state.canCleanSelection)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .frame(height: 40)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: - 概览

struct OverviewTab: View {
    @ObservedObject var state: SystemToolState
    let goTo: (SystemToolTab) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SystemToolUI.gap) {
                if !state.hasFullDiskAccess { FDABanner() }

                if let result = state.lastCleanResult {
                    CleanResultBar(result: result) { state.lastCleanResult = nil }
                }

                let disk = state.diskInfo()
                SystemToolCard(title: "磁盘空间", subtitle: state.volumeName()) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("已用 \(disk.formattedUsed)")
                                .font(.title3).fontWeight(.semibold)
                            Spacer()
                            Text("共 \(disk.formattedTotal) · 可用 \(disk.formattedFree)")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        ProgressView(value: disk.usedPercentage)
                            .tint(disk.usedPercentage > 0.85 ? Color.red : Color.accentColor)
                        HStack {
                            Text("\(Int(disk.usedPercentage * 100))% 已使用")
                            Spacer()
                            Text("\(Int(disk.freePercentage * 100))% 可用")
                        }
                        .font(.caption2).foregroundStyle(.secondary)
                    }
                }

                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("分类扫描").font(.headline)
                        Text("点卡片进入对应页签；数值来自最近一次扫描")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        let categories = CleaningCategory.allCases.filter { $0 != .largeFiles }
                        Task { await state.scanJunk(categories: categories) }
                    } label: {
                        Label("一键扫描全部", systemImage: "sparkles")
                    }
                    .controlSize(.small)
                    .buttonStyle(.borderedProminent)
                    .disabled(state.phase != .idle)
                }

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: SystemToolUI.gap), count: 3),
                    spacing: SystemToolUI.gap
                ) {
                    ForEach(SystemToolOverviewCard.allCases) { card in
                        Button { goTo(card.target) } label: {
                            OverviewCardView(card: card, summary: state.overviewSummary(for: card))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
        }
    }
}

private struct OverviewCardView: View {
    let card: SystemToolOverviewCard
    let summary: SystemToolOverviewSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Image(systemName: card.icon)
                    .font(.title3)
                    .foregroundStyle(card.color)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.quaternary)
            }
            Text(card.title).font(.callout).fontWeight(.medium)
            if summary.scanned {
                Text(systemToolByteText(summary.size))
                    .font(.title3).fontWeight(.semibold).monospacedDigit()
                Text("\(summary.count) 项 · 已扫描")
                    .font(.caption2).foregroundStyle(.secondary)
            } else {
                Text("待扫描").font(.caption).foregroundStyle(.tertiary)
                Text("尚未获取结果").font(.caption2).foregroundStyle(.quaternary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 108, alignment: .leading)
        .padding(SystemToolUI.gap)
        .background(RoundedRectangle(cornerRadius: SystemToolUI.cardCorner).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: SystemToolUI.cardCorner).stroke(Color(nsColor: .separatorColor), lineWidth: 0.5))
    }
}

// MARK: - 垃圾清理

struct JunkTab: View {
    @ObservedObject var state: SystemToolState

    private let groups: [(String, [CleaningCategory])] = [
        ("系统垃圾", [.systemJunk]),
        ("用户缓存", [.userCache]),
        ("开发缓存", [.xcodeJunk, .brewCache, .nodeCache, .devToolCaches]),
        ("废纸篓", [.trashBins]),
    ]
    @State private var enabledGroups: Set<String> = ["系统垃圾", "用户缓存", "开发缓存", "废纸篓"]
    @State private var exclusionNotice: String?

    private var activeCategories: [CleaningCategory] {
        groups.filter { enabledGroups.contains($0.0) }.flatMap { $0.1 }
    }
    private var totalCount: Int { state.junkResults.reduce(0) { $0 + $1.itemCount } }
    private var allSelected: Bool {
        let items = state.junkResults.flatMap { $0.items }
        return !items.isEmpty && items.allSatisfy { $0.isSelected || $0.selectOnlyByHand }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !state.hasFullDiskAccess { FDABanner().padding(.horizontal, 12).padding(.top, 10) }

            if let result = state.lastCleanResult {
                CleanResultBar(result: result) { state.lastCleanResult = nil }
                    .padding(.horizontal, 12)
            }

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("分类筛选").font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 5) {
                        ForEach(groups, id: \.0) { name, _ in
                            Toggle(isOn: Binding(
                                get: { enabledGroups.contains(name) },
                                set: { on in if on { enabledGroups.insert(name) } else { enabledGroups.remove(name) } }
                            )) {
                                Text(name).font(.caption)
                            }
                            .toggleStyle(.checkbox)
                        }
                    }
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 6) {
                    HStack(spacing: 8) {
                        Button {
                            Task { await state.scanJunk(categories: activeCategories) }
                        } label: {
                            Label("扫描", systemImage: "magnifyingglass")
                        }
                        .controlSize(.small)
                        .buttonStyle(.borderedProminent)
                        .disabled(state.phase != .idle || activeCategories.isEmpty)
                        Button("取消") { state.cancelScan() }
                            .controlSize(.small)
                            .disabled(state.phase != .scanning)
                    }
                    Text("阈值与排除路径在「设置 → PureMac」")
                        .font(.caption2).foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 12)

            HStack(spacing: 14) {
                Label("共 \(totalCount) 项", systemImage: "list.bullet")
                Label("已选 \(state.selectedItems.count) 项", systemImage: "checkmark.circle")
                Label("可清理 \(systemToolByteText(state.selectedSize))", systemImage: "externaldrive")
                Spacer()
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)

            if state.junkResults.isEmpty {
                if state.phase == .scanning {
                    EmptyStateView(
                        icon: "magnifyingglass",
                        title: "正在扫描…",
                        message: state.currentPath.isEmpty
                            ? "正在统计各分类的可清理项目，请稍候。"
                            : state.currentPath
                    )
                } else {
                    EmptyStateView(
                        icon: "trash",
                        title: "尚未扫描",
                        message: "选择要扫描的分类后点「扫描」。结果中的每一项默认都不选中，清理前会再次确认。",
                        actionTitle: "开始扫描",
                        action: { Task { await state.scanJunk(categories: activeCategories) } }
                    )
                }
            } else {
                FileTable(
                    allSelected: allSelected,
                    selectAll: {
                        let select = !allSelected
                        for result in state.junkResults {
                            state.toggleJunkCategory(result.category, selected: select)
                        }
                    }
                ) {
                    ForEach(state.junkResults) { result in
                        HStack(spacing: 8) {
                            Image(systemName: result.category.icon)
                                .foregroundStyle(result.category.color)
                            Text(result.category.displayName)
                                .font(.callout).fontWeight(.semibold)
                            Text("\(result.itemCount) 项 · \(systemToolByteText(result.totalSize))")
                                .font(.caption2).foregroundStyle(.secondary)
                            Spacer()
                            Button(result.items.allSatisfy { $0.isSelected || $0.selectOnlyByHand } ? "全不选" : "全选") {
                                let select = !result.items.allSatisfy { $0.isSelected || $0.selectOnlyByHand }
                                state.toggleJunkCategory(result.category, selected: select)
                            }
                            .buttonStyle(.borderless)
                            .font(.caption)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.accentColor.opacity(0.06))
                        Divider()

                        ForEach(result.items) { item in
                            CleanableRow(
                                item: item,
                                selected: item.isSelected,
                                disabled: item.selectOnlyByHand,
                                onToggle: { state.setJunkItemSelected(item.id, value: $0) },
                                onExclude: { path in
                                    CleanupExclusions.add(path)
                                    exclusionNotice = "已加入排除路径：\((path as NSString).abbreviatingWithTildeInPath)（下次扫描生效）"
                                }
                            )
                            Divider()
                        }
                    }
                }
                .padding(.horizontal, 12)
            }

            HStack(spacing: 6) {
                Image(systemName: "info.circle").font(.caption2)
                Text("受保护路径、符号链接与排除路径会自动跳过，不会出现在结果中")
                    .font(.caption2).foregroundStyle(.secondary)
                if let last = state.lastCleanResult, !last.skippedPaths.isEmpty {
                    Text("· 上次清理跳过 \(last.skippedPaths.count) 项")
                        .font(.caption2).foregroundStyle(.orange)
                }
                Spacer()
                if let notice = exclusionNotice {
                    Text(notice).font(.caption2).foregroundStyle(.green)
                        .lineLimit(1).truncationMode(.middle)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

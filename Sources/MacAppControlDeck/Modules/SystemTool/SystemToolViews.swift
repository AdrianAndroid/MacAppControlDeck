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

struct SystemToolRootView: View {
    @StateObject private var state: SystemToolState
    @State private var tab: SystemToolTab = .overview

    init(sampler: SystemSampler) {
        _state = StateObject(wrappedValue: SystemToolState(sampler: sampler))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                ForEach(SystemToolTab.allCases) { item in
                    Button {
                        tab = item
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: item.icon)
                            Text(item.title).font(.caption2)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(tab == item ? Color.accentColor.opacity(0.12) : Color.clear)
                        .foregroundStyle(tab == item ? Color.accentColor : Color.secondary)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12).padding(.top, 8)

            Divider()

            ZStack {
                switch tab {
                case .overview: OverviewTab(state: state, goTo: { tab = $0 })
                case .junk: JunkTab(state: state)
                case .uninstall: UninstallTab(state: state)
                case .large: LargeFilesTab(state: state)
                case .duplicate: DuplicateTab()
                case .processes: ProcessesTab(state: state)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()
            StatusBar(state: state)
        }
    }
}

// MARK: - FDA banner

struct FDABanner: View {
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            Text("部分目录未授权，结果不完整")
            Spacer()
            Button("打开系统设置") { SystemPermissionGate.openFullDiskAccessSettings() }
        }
        .font(.caption)
        .padding(8)
        .background(Color.orange.opacity(0.12))
        .cornerRadius(6)
    }
}

// MARK: - Overview

struct OverviewTab: View {
    @ObservedObject var state: SystemToolState
    let goTo: (SystemToolTab) -> Void

    private let cards: [(String, String, SystemToolTab)] = [
        ("gearshape.fill", "系统垃圾", .junk),
        ("internaldrive.fill", "用户缓存", .junk),
        ("wrench.and.screwdriver.fill", "开发缓存", .junk),
        ("doc.fill", "大文件", .large),
        ("doc.on.doc.fill", "重复文件", .duplicate),
        ("trash.fill", "废纸篓", .junk),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !state.hasFullDiskAccess { FDABanner() }

                let disk = state.diskInfo()
                GroupBox("磁盘") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Macintosh HD")
                            Spacer()
                            Text("已用 \(disk.formattedUsed) / 共 \(disk.formattedTotal)")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        ProgressView(value: disk.usedPercentage)
                        Text("\(Int(disk.usedPercentage * 100))% 已使用").font(.caption2).foregroundStyle(.secondary)
                    }
                    .padding(8)
                }

                HStack {
                    Text("分类扫描").font(.headline)
                    Spacer()
                    Button("一键扫描全部") {
                        Task { await state.scanJunk(categories: CleaningCategory.allCases) }
                    }
                }
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(cards, id: \.1) { icon, name, target in
                        Button { goTo(target) } label: {
                            VStack(spacing: 8) {
                                Image(systemName: icon).font(.title2)
                                Text(name).font(.caption)
                                Text("待扫描").font(.caption2).foregroundStyle(.tertiary)
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 18)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .cornerRadius(8)
                        }.buttonStyle(.plain)
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Junk

struct JunkTab: View {
    @ObservedObject var state: SystemToolState
    @State private var selectedCategories: Set<CleaningCategory> = Set(CleaningCategory.allCases)
    @State private var showConfirm = false
    @State private var permanentDelete = false

    var selectedItems: [CleanableItem] {
        state.junkResults.flatMap { $0.items.filter { $0.isSelected } }
    }
    var selectedSize: Int64 { selectedItems.reduce(0) { $0 + $1.size } }

    var body: some View {
        VStack(spacing: 8) {
            if !state.hasFullDiskAccess { FDABanner() }
            HStack {
                Text("分类：").font(.caption)
                ForEach(CleaningCategory.allCases) { cat in
                    Toggle(cat.rawValue, isOn: Binding(
                        get: { selectedCategories.contains(cat) },
                        set: { on in if on { selectedCategories.insert(cat) } else { selectedCategories.remove(cat) } }
                    )).toggleStyle(.checkbox).font(.caption2)
                }
                Spacer()
                Button("扫描") { Task { await state.scanJunk(categories: Array(selectedCategories)) } }
                Button("取消") { state.cancelScan() }.disabled(!state.isScanning)
            }

            HStack {
                Text("结果 共 \(state.junkResults.reduce(0) { $0 + $1.itemCount }) 项")
                Text("已选 \(selectedItems.count) 项")
                Text("可清理 \(ByteCountFormatter.string(fromByteCount: selectedSize, countStyle: .file))")
                Spacer()
            }.font(.caption).foregroundStyle(.secondary)

            List {
                ForEach(state.junkResults.indices, id: \.self) { rIdx in
                    let result = state.junkResults[rIdx]
                    Section(header: HStack {
                        Text(result.category.rawValue)
                        Spacer()
                        Button(result.items.allSatisfy { $0.isSelected } ? "全不选" : "全选") {
                            state.selectAll(in: result.category, selected: !result.items.allSatisfy { $0.isSelected })
                        }.buttonStyle(.borderless).font(.caption)
                    }) {
                        ForEach(result.items.indices, id: \.self) { i in
                            let item = result.items[i]
                            HStack {
                                Toggle("", isOn: Binding(
                                    get: { state.junkResults[rIdx].items[i].isSelected },
                                    set: { state.junkResults[rIdx].items[i].isSelected = $0 }
                                )).toggleStyle(.checkbox).disabled(item.selectOnlyByHand)
                                VStack(alignment: .leading) {
                                    Text(item.name)
                                    Text(item.path).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                                }
                                Spacer()
                                Text(item.formattedSize).font(.caption)
                            }
                            .contextMenu {
                                Button("加入排除路径") {
                                    CleanupExclusions.add(item.path)
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))

            HStack {
                Text(state.statusMessage).font(.caption).foregroundStyle(.secondary)
                if state.isScanning { ProgressView(value: state.scanProgress).frame(width: 120) }
                if let last = state.lastCleanResult {
                    Text("上次：成功 \(last.itemsCleaned) · 跳过 \(last.skippedPaths.count + last.protectedPaths.count) · 失败 \(last.errors.count)")
                        .font(.caption2).foregroundStyle(.tertiary)
                }
                Spacer()
                Button("清理选中 (\(selectedItems.count) 项)") { showConfirm = true }
                    .disabled(selectedItems.isEmpty)
            }
            .padding(.horizontal)
            .sheet(isPresented: $showConfirm) {
                ConfirmCleanView(items: selectedItems, permanent: $permanentDelete) {
                    let paths = permanentDelete ? Set(selectedItems.map { $0.path }) : []
                    Task { await state.clean(items: selectedItems, permanently: paths) }
                }
            }
        }
    }
}

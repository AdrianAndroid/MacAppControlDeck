import SwiftUI
import AppKit

// MARK: - 视觉规范

enum SystemToolUI {
    static let checkWidth: CGFloat = 26
    static let iconWidth: CGFloat = 22
    static let sizeWidth: CGFloat = 82
    static let dateWidth: CGFloat = 92
    static let rowHeight: CGFloat = 38
    static let corner: CGFloat = 8
    static let cardCorner: CGFloat = 10
    static let gap: CGFloat = 12
}

func systemToolByteText(_ bytes: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
}

private let systemToolRelativeFormatter: RelativeDateTimeFormatter = {
    let f = RelativeDateTimeFormatter()
    f.unitsStyle = .abbreviated
    return f
}()

extension CleanableItem {
    var modifiedText: String {
        guard let date = lastModified else { return "—" }
        return systemToolRelativeFormatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - 未授权横幅

struct FDABanner: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("部分目录未授权，结果不完整")
                    .font(.callout).fontWeight(.semibold)
                Text("可继续扫描当前可访问的范围；授予完全磁盘访问后重新扫描即可获得完整结果。")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Button {
                SystemPermissionGate.openFullDiskAccessSettings()
            } label: {
                Label("打开系统设置", systemImage: "gearshape")
            }
            .controlSize(.small)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: SystemToolUI.cardCorner).fill(Color.orange.opacity(0.10)))
        .overlay(RoundedRectangle(cornerRadius: SystemToolUI.cardCorner).stroke(Color.orange.opacity(0.28), lineWidth: 0.5))
    }
}

// MARK: - 空态

struct EmptyStateView: View {
    let icon: String
    let title: String
    var message: String = ""
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.tertiary)
            Text(title).font(.headline)
            if !message.isEmpty {
                Text(message)
                    .font(.caption).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 340)
            }
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .controlSize(.small)
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}

// MARK: - v3 统一入口卡（对齐柠檬「标题 + 副标题 + 单主按钮」）
// 与 EmptyStateView 并存：EmptyStateView 用于「无结果/失败」的内部空态，
// EmptyScanState 用于各功能页「尚未扫描」的入口态，二者语义不同。

struct EmptyScanState: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String
    let action: () -> Void
    var disabled: Bool = false

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(Color.accentColor.opacity(0.75))
            Text(title)
                .font(.title3).fontWeight(.semibold)
            Text(message)
                .font(.caption).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
            Button(action: action) {
                Label(actionTitle, systemImage: "magnifyingglass")
            }
            .controlSize(.regular)
            .buttonStyle(.borderedProminent)
            .disabled(disabled)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}

// MARK: - v3 统一扫描态（对齐柠檬：当前路径 + 不定长进度条 + 取消，无百分比）

struct ScanningStateView: View {
    let title: String
    let currentPath: String
    let detail: String
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)
            Text(title)
                .font(.headline)
            if !currentPath.isEmpty {
                Text(currentPath)
                    .font(.caption).foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle)
                    .frame(maxWidth: 420)
            }
            // 柠檬式不定长进度条：不显示百分比，用循环动画表达「进行中」。
            ProgressView()
                .progressViewStyle(.linear)
                .frame(width: 260)
            if !detail.isEmpty {
                Text(detail)
                    .font(.caption2).foregroundStyle(.tertiary)
            }
            Button("取消", action: onCancel)
                .controlSize(.small)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}

// MARK: - v3 状态胶囊（借鉴柠檬启动项的「全部开启/部分开启/全部关闭」）

struct StatusCapsule: View {
    enum Tone { case normal, system, accent }
    let text: String
    var tone: Tone = .normal

    private var color: Color {
        switch tone {
        case .normal: return .green
        case .system: return .secondary
        case .accent: return .accentColor
        }
    }

    var body: some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, 7).padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.14)))
            .foregroundStyle(color)
    }
}

// MARK: - v3 可折叠分组头（对齐柠檬「1 GB 以上文件：共 13 项」）

struct CollapsibleGroupHeader<Trailing: View>: View {
    let title: String
    let count: Int
    let sizeText: String
    @Binding var collapsed: Bool
    var allSelected: Bool = false
    var onToggleAll: (() -> Void)? = nil
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 8) {
            Button { collapsed.toggle() } label: {
                Image(systemName: collapsed ? "chevron.right" : "chevron.down")
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(width: 14)
            }
            .buttonStyle(.plain)
            Image(systemName: allSelected ? "checkmark.square.fill" : "square")
                .foregroundStyle(allSelected ? Color.accentColor : Color.secondary)
                .onTapGesture { onToggleAll?() }
                .frame(width: 20)
            Text(title).font(.callout).fontWeight(.semibold)
            Text("\(count) 项 · \(sizeText)")
                .font(.caption2).foregroundStyle(.secondary)
            Spacer(minLength: 6)
            trailing
            if let onToggleAll {
                Button(allSelected ? "全不选" : "全选", action: onToggleAll)
                    .buttonStyle(.borderless).font(.caption)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Color.accentColor.opacity(0.06))
        .contentShape(Rectangle())
    }
}

// MARK: - 卡片容器

struct SystemToolCard<Content: View>: View {
    var title: String? = nil
    var subtitle: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(title).font(.headline)
                    if let subtitle {
                        Text(subtitle).font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
            content
        }
        .padding(SystemToolUI.gap)
        .background(RoundedRectangle(cornerRadius: SystemToolUI.cardCorner).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: SystemToolUI.cardCorner).stroke(Color(nsColor: .separatorColor), lineWidth: 0.5))
    }
}

// MARK: - 结果表格（列头 + 行）

struct FileTableHeader: View {
    var allSelected: Bool = false
    var selectAll: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 6) {
            if let selectAll {
                Button(action: selectAll) {
                    Image(systemName: allSelected ? "checkmark.square.fill" : "square")
                        .foregroundStyle(allSelected ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.plain)
                .frame(width: SystemToolUI.checkWidth)
                .help(allSelected ? "全不选" : "全选")
            } else {
                Spacer().frame(width: SystemToolUI.checkWidth)
            }
            Spacer().frame(width: SystemToolUI.iconWidth)
            Text("名称与路径")
                .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text("大小")
                .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                .frame(width: SystemToolUI.sizeWidth, alignment: .trailing)
            Text("修改时间")
                .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                .frame(width: SystemToolUI.dateWidth, alignment: .trailing)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.75))
    }
}

struct CleanableRow: View {
    let item: CleanableItem
    let selected: Bool
    var disabled: Bool = false
    var onToggle: (Bool) -> Void
    var onExclude: ((String) -> Void)? = nil

    var body: some View {
        HStack(spacing: 6) {
            Toggle("", isOn: Binding(get: { selected }, set: { onToggle($0) }))
                .toggleStyle(.checkbox)
                .labelsHidden()
                .disabled(disabled)
                .frame(width: SystemToolUI.checkWidth)
            Image(systemName: item.category.icon)
                .foregroundStyle(item.category.color)
                .frame(width: SystemToolUI.iconWidth)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.name).font(.callout).lineLimit(1)
                Text(item.path)
                    .font(.caption2).foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle)
            }
            Spacer(minLength: 8)
            Text(item.formattedSize)
                .font(.caption).monospacedDigit()
                .frame(width: SystemToolUI.sizeWidth, alignment: .trailing)
            Text(item.modifiedText)
                .font(.caption2).foregroundStyle(.secondary)
                .frame(width: SystemToolUI.dateWidth, alignment: .trailing)
        }
        .frame(height: SystemToolUI.rowHeight)
        .padding(.horizontal, 10)
        .contentShape(Rectangle())
        .onTapGesture { if !disabled { onToggle(!selected) } }
        .contextMenu {
            Button("在 Finder 中显示") {
                NSWorkspace.shared.selectFile(item.path, inFileViewerRootedAtPath: "")
            }
            if let onExclude {
                Divider()
                Button("将「\(item.name)」加入排除路径") { onExclude(item.path) }
            }
        }
        .opacity(disabled ? 0.5 : 1)
    }
}

/// 结果表格：列头 + 交替行背景 + 轻分隔线。用 ScrollView 自绘以便列对齐。
struct FileTable<Rows: View>: View {
    var allSelected: Bool = false
    var selectAll: (() -> Void)? = nil
    @ViewBuilder var rows: Rows

    var body: some View {
        VStack(spacing: 0) {
            FileTableHeader(allSelected: allSelected, selectAll: selectAll)
            Divider()
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: []) {
                    rows
                }
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: SystemToolUI.corner))
        .overlay(RoundedRectangle(cornerRadius: SystemToolUI.corner).stroke(Color(nsColor: .separatorColor), lineWidth: 0.5))
    }
}

// MARK: - 清理结果条

struct CleanResultBar: View {
    let result: TrashResult
    let onDismiss: () -> Void

    var body: some View {
        let ok = result.errors.isEmpty
        let skipped = result.skippedPaths.count + result.protectedPaths.count
        return HStack(spacing: 12) {
            Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(ok ? Color.green : Color.orange)
            Text("已清理 \(result.itemsCleaned) 项 · 释放 \(systemToolByteText(result.freedSpace))")
                .font(.caption).fontWeight(.medium)
            Label("跳过 \(skipped)", systemImage: "slash.circle")
                .font(.caption).foregroundStyle(Color.secondary)
            Label("失败 \(result.errors.count)", systemImage: "xmark.circle")
                .font(.caption)
                .foregroundStyle(ok ? Color.secondary : Color.red)
            Spacer(minLength: 8)
            if !ok {
                Menu("查看失败原因") {
                    ForEach(result.errors, id: \.self) { Text($0).font(.caption) }
                }
                .font(.caption).controlSize(.small)
            }
            Button("知道了", action: onDismiss).controlSize(.small)
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 7).fill(Color.green.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.green.opacity(0.22), lineWidth: 0.5))
    }
}

// MARK: - 设置行 / 路径选择

struct SettingRow<Content: View>: View {
    let label: String
    var hint: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(.callout)
                if let hint {
                    Text(hint).font(.caption2).foregroundStyle(.secondary)
                }
            }
            .frame(width: 140, alignment: .leading)
            content
            Spacer(minLength: 0)
        }
    }
}

struct PathPickerButton: View {
    let path: String
    let onChange: (URL) -> Void

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "folder")
                .foregroundStyle(.secondary)
            Text(abbreviated)
                .font(.caption).lineLimit(1).truncationMode(.middle)
                .frame(maxWidth: 210, alignment: .leading)
            Button("选择…") { choose() }.controlSize(.small)
        }
    }

    private var abbreviated: String { (path as NSString).abbreviatingWithTildeInPath }

    private func choose() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.directoryURL = URL(fileURLWithPath: path)
        panel.prompt = "选择"
        panel.message = "选择要扫描的目录"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        onChange(url)
    }
}

// MARK: - 统一清理确认弹窗（含永久删除二次确认）

struct ConfirmCleanSheet: View {
    let items: [CleanableItem]
    @State private var permanent = false
    @State private var showPermanentWarning = false
    let onConfirm: (Set<String>) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: permanent ? "trash.slash.fill" : "trash.fill")
                    .font(.title2)
                    .foregroundStyle(permanent ? .red : Color.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(permanent ? "确认永久删除" : "确认移入废纸篓").font(.headline)
                    Text(permanent
                         ? "这些文件将直接删除，无法从废纸篓恢复。"
                         : "删除前请再次核对路径；移入废纸篓后仍可恢复。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(16)

            Divider()

            HStack(spacing: 16) {
                Label("\(items.count) 项", systemImage: "number")
                Label(systemToolByteText(totalSize), systemImage: "externaldrive")
                Spacer()
            }
            .font(.callout)
            .padding(.horizontal, 16).padding(.vertical, 9)

            ScrollView {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(items.prefix(12)) { item in
                        HStack(spacing: 6) {
                            Image(systemName: item.category.icon)
                                .foregroundStyle(item.category.color)
                                .frame(width: 16)
                            Text(item.path)
                                .font(.caption).lineLimit(1).truncationMode(.middle)
                            Spacer(minLength: 6)
                            Text(item.formattedSize)
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    if items.count > 12 {
                        Text("… 以及另外 \(items.count - 12) 项")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 16)
            }
            .frame(maxHeight: 180)

            Divider()

            Toggle(isOn: Binding(
                get: { permanent },
                set: { value in
                    if value { showPermanentWarning = true } else { permanent = false }
                }
            )) {
                Text("永久删除（不进废纸篓，不可恢复）").font(.callout)
            }
            .padding(.horizontal, 16).padding(.vertical, 10)

            Divider()

            HStack {
                Text(permanent
                     ? "此操作不可撤销"
                     : "废纸篓中的文件仍占用空间，清空废纸篓后才会真正释放")
                    .font(.caption2).foregroundStyle(.tertiary)
                Spacer(minLength: 8)
                Button("取消") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(permanent ? "永久删除" : "确认移入废纸篓") {
                    onConfirm(permanent ? Set(items.map(\.path)) : [])
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .tint(permanent ? Color.red : Color.accentColor)
            }
            .padding(16)
        }
        .frame(width: 500)
        .alert("再次确认永久删除", isPresented: $showPermanentWarning) {
            Button("取消", role: .cancel) { }
            Button("仍要永久删除", role: .destructive) { permanent = true }
        } message: {
            Text("勾选后将跳过废纸篓，直接删除这 \(items.count) 项，删除后无法恢复。确定继续？")
        }
    }

    private var totalSize: Int64 { items.reduce(0) { $0 + $1.size } }
}

/// 未授权时的整块占位：不展示任何不完整结果，只给一句话与授权入口。
struct FullDiskAccessGate: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.shield")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(.secondary)
            Text("需要「完全磁盘访问权限」")
                .font(.headline)
            Text("未授权时只能读到部分目录，因此这里不展示不完整的扫描结果。\n授权后重新打开本页即可看到完整内容。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                SystemPermissionGate.openFullDiskAccessSettings()
            } label: {
                Label("打开系统设置授权", systemImage: "gearshape")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

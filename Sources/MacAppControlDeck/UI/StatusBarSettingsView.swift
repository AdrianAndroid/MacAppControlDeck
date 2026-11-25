import SwiftUI

/// 设置 → 状态栏：所有模块注册的状态栏条目集中管理。
/// 模块关闭时开关置灰但保留勾选，状态栏同步移除对应格子。
struct StatusBarSettingsView: View {
    @ObservedObject private var registry = StatusBarRegistry.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("状态栏")
                    .font(.title2).fontWeight(.semibold)
                Text("同一组的条目渲染成一条状态项，组内顺序固定；点击每格可打开不同菜单或窗口。模块关闭时该模块的条目置灰并从状态栏移除，重新启用后按原勾选恢复。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if registry.snapshots.isEmpty {
                    EmptyStateViewLike(text: "还没有模块注册状态栏条目")
                }

                ForEach(registry.snapshots) { group in
                    GroupBox {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(group.entries) { entry in
                                HStack(alignment: .firstTextBaseline, spacing: 10) {
                                    Toggle(isOn: binding(for: entry)) {
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(entry.title)
                                            Text(entry.subtitle)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .disabled(!entry.available)
                                    Spacer(minLength: 8)
                                    if !entry.available {
                                        Text("模块已关闭")
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                            }
                        }
                        .padding(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    } label: {
                        Label("\(group.moduleTitle)（\(group.moduleID)）", systemImage: "menubar.rectangle")
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func binding(for entry: StatusBarEntryInfo) -> Binding<Bool> {
        Binding(
            get: { registry.isVisible(entry.id) },
            set: { registry.setVisible($0, entryID: entry.id) }
        )
    }
}

private struct EmptyStateViewLike: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 24)
    }
}

import SwiftUI

/// 菜单定制：一级菜单按模块排序，模块内命令可显示/隐藏、排序、置顶到「常用」。
struct MenuSettingsView: View {
    @ObservedObject private var registry = ModuleRegistry.shared
    @ObservedObject private var customization = MenuCustomization.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                let modules = customization.orderedModules(registry.modules)
                ForEach(Array(modules.enumerated()), id: \.element.id) { index, module in
                    moduleCard(module, index: index, total: modules.count)
                }
                if modules.isEmpty {
                    Text("没有已启用的模块。先到「模块」页开启功能。")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(24)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("菜单栏一级菜单由各功能模块组成；星标命令会直接显示在下拉菜单顶部，点开即可使用。")
                .font(.headline)
            Text("显示开关控制命令是否出现在模块子菜单里；上下箭头调整顺序；星标把命令平铺到下拉菜单顶部。新增模块会自动出现在这里。")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private func moduleCard(_ module: any FeatureModule, index: Int, total: Int) -> some View {
        let commands = customization.commands(for: module)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: module.systemImage)
                    .foregroundStyle(.tint)
                Text(module.title).font(.title3.bold())
                Spacer()
                Text("\(commands.count) 个命令").font(.caption).foregroundStyle(.secondary)
                Button { customization.moveModule(module.id, offset: -1, among: registry.modules) } label: {
                    Image(systemName: "chevron.up")
                }
                .buttonStyle(.borderless)
                .disabled(index == 0)
                Button { customization.moveModule(module.id, offset: 1, among: registry.modules) } label: {
                    Image(systemName: "chevron.down")
                }
                .buttonStyle(.borderless)
                .disabled(index == total - 1)
            }
            .padding(.vertical, 10)

            Divider()

            ForEach(Array(commands.enumerated()), id: \.element.id) { offset, command in
                commandRow(command, moduleID: module.id, allIDs: commands.map(\.id),
                           index: offset, total: commands.count)
                if offset < commands.count - 1 { Divider().padding(.leading, 26) }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)))
    }

    private func commandRow(_ command: MenuCommandInfo, moduleID: String, allIDs: [String],
                            index: Int, total: Int) -> some View {
        let visible = Binding(
            get: { !customization.isHidden(command.id, moduleID: moduleID) },
            set: { customization.setHidden(!$0, commandID: command.id, moduleID: moduleID) }
        )
        return HStack(spacing: 10) {
            Toggle("", isOn: visible).labelsHidden().toggleStyle(.checkbox)
            if let image = command.image {
                Image(nsImage: image).resizable().frame(width: 16, height: 16)
            }
            Text(command.title)
            if command.isSubmenu {
                Text("子菜单").font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            Button { customization.togglePin(command.id) } label: {
                Image(systemName: customization.isPinned(command.id) ? "star.fill" : "star")
                    .foregroundStyle(customization.isPinned(command.id) ? Color.orange : Color.secondary)
            }
            .buttonStyle(.borderless)
            .help("置顶到下拉菜单顶部")
            Button { customization.moveCommand(command.id, offset: -1, allIDs: allIDs, moduleID: moduleID) } label: {
                Image(systemName: "chevron.up")
            }
            .buttonStyle(.borderless)
            .disabled(index == 0)
            Button { customization.moveCommand(command.id, offset: 1, allIDs: allIDs, moduleID: moduleID) } label: {
                Image(systemName: "chevron.down")
            }
            .buttonStyle(.borderless)
            .disabled(index == total - 1)
        }
        .padding(.vertical, 6)
        .opacity(visible.wrappedValue ? 1 : 0.45)
    }
}

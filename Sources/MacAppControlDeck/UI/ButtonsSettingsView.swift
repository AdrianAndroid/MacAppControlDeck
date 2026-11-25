import SwiftUI
import AppKit

/// 按钮管理：卡片网格 + 点击选中 + 长按拖动排序。
/// 应用与快捷操作各自排序，顺序仍由同一个 buttons 数组持久化。
struct ButtonsSettingsView: View {
    @ObservedObject private var state = DeckState.shared

    @State private var showAddSheet = false
    @State private var showShortcutSheet = false
    @State private var showCommandSheet = false
    @State private var editingShortcut: ButtonConfig?
    @State private var pendingDelete: ButtonConfig?
    @State private var pendingRename: ButtonConfig?
    @State private var renameText = ""

    @State private var selectedID: String?
    @State private var hoveredID: String?
    @State private var searchText = ""
    @State private var collapsedGroups: Set<ButtonGridGroup> = []

    @State private var frames: [String: CGRect] = [:]
    @State private var pressingID: String?
    @State private var invalidatedPressID: String?
    @State private var armedID: String?
    @State private var longPressTask: Task<Void, Never>?

    @State private var dragButton: ButtonConfig?
    @State private var dragGroup: ButtonGridGroup?
    @State private var dragFrames: [String: CGRect] = [:]
    @State private var dropIndex: Int?
    @State private var dragBlocked = false
    @State private var dragLocation: CGPoint = .zero
    @State private var dragGrabOffset: CGSize = .zero
    @State private var dragCardSize: CGSize = .zero

    private let cardHeight: CGFloat = 118
    private let gridSpacing: CGFloat = 12
    private let coordinateSpaceName = "buttonsGridRoot"

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(minimum: 96, maximum: 180), spacing: gridSpacing, alignment: .top),
              count: 4)
    }

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var showsSearchField: Bool {
        state.buttons.count > 12 || isSearching
    }

    private var selectedButton: ButtonConfig? {
        guard let selectedID else { return nil }
        return state.buttons.first { $0.id == selectedID }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                toolbar

                if showsSearchField {
                    searchBar
                }

                if state.buttons.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 16, pinnedViews: [.sectionHeaders]) {
                            ForEach(ButtonGridGroup.allCases) { group in
                                section(for: group)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 18)
                    }
                    .onPreferenceChange(ButtonCardFramePreferenceKey.self) { frames = $0 }
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        selectionBar
                    }
                }

                footnote
            }

            if let dragButton {
                dragGhost(for: dragButton)
            }
        }
        .coordinateSpace(name: coordinateSpaceName)
        .onDisappear {
            longPressTask?.cancel()
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
                if let button = pendingDelete {
                    state.delete(button)
                    if selectedID == button.id { selectedID = nil }
                }
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

    private var toolbar: some View {
        HStack(spacing: 10) {
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
                Menu("添加内置操作") {
                    ForEach(BuiltinActions.all) { preset in
                        Button("\(preset.symbol)  \(preset.name)") {
                            state.addBuiltin(name: preset.name, action: preset.id)
                        }
                    }
                }
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Spacer()

            Text("共 \(state.buttons.count) 个")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, isSearching || showsSearchField ? 8 : 12)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("搜索名称、Bundle ID 或快捷键", text: $searchText)
                .textFieldStyle(.plain)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("清除搜索")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.5))
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(.secondary)
            Text("还没有按钮")
                .font(.headline)
            Text("添加应用、快捷操作或命令后，菜单栏和手机面板都会同步出现。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footnote: some View {
        VStack(alignment: .leading, spacing: 3) {
            Divider()
            Text("点击卡片选中；按住 0.5 秒后拖动可排序；右键可重命名、上移、下移或删除。")
            Text("按钮顺序会同时影响菜单栏与手机面板；参数与命令只保存在本机。")
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var selectionBar: some View {
        if let selectedButton {
            HStack(spacing: 10) {
                Image(systemName: iconName(for: selectedButton))
                    .foregroundStyle(.secondary)
                Text("已选 \(selectedButton.name)")
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                Spacer(minLength: 8)
                Button("重命名…") { startRename(selectedButton) }
                if selectedButton.kind == .shortcut {
                    Button("编辑组合…") { editingShortcut = selectedButton }
                }
                Button("删除…", role: .destructive) { pendingDelete = selectedButton }
                Button {
                    selectedID = nil
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
                .help("取消选中")
            }
            .buttonStyle(.bordered)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(.bar)
            .overlay(alignment: .top) { Divider() }
        }
    }

    @ViewBuilder
    private func section(for group: ButtonGridGroup) -> some View {
        let all = groupButtons(for: group)
        let visible = filteredButtons(all)

        Section {
            if !isCollapsed(group) {
                if visible.isEmpty {
                    Text(isSearching ? "没有匹配的按钮" : "这一组还没有按钮")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 4)
                } else {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: gridSpacing) {
                        ForEach(entries(for: visible, group: group)) { entry in
                            switch entry {
                            case .button(let button):
                                card(for: button)
                            case .placeholder:
                                ButtonGridPlaceholder()
                                    .frame(minHeight: cardHeight, maxHeight: cardHeight)
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.bottom, 4)
                }
            }
        } header: {
            groupHeader(group, total: all.count, visible: visible.count)
        }
    }

    private func groupHeader(_ group: ButtonGridGroup, total: Int, visible: Int) -> some View {
        HStack(spacing: 8) {
            Text(group.title)
                .font(.system(size: 12, weight: .semibold))
            Text("· \(total)")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(.secondary)
            if isSearching && visible != total {
                Text("命中 \(visible)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.accentColor)
            }
            Spacer()
            Button {
                toggleCollapsed(group)
            } label: {
                Image(systemName: isCollapsed(group) ? "chevron.right" : "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 18, height: 18)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(isCollapsed(group) ? "展开\(group.title)" : "收起\(group.title)")
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.35))
        )
        .padding(.top, 2)
        .zIndex(1)
    }

    private func card(for button: ButtonConfig) -> some View {
        let installed = state.isInstalled(button)
        let selected = selectedID == button.id
        let armed = armedID == button.id
        let group = group(for: button)
        let canUp = canMove(button, offset: -1, in: group)
        let canDown = canMove(button, offset: 1, in: group)

        return ButtonGridCard(
            button: button,
            installed: installed,
            isSelected: selected,
            isArmed: armed,
            isHovered: hoveredID == button.id
        )
        .frame(maxWidth: .infinity, minHeight: cardHeight, maxHeight: cardHeight)
        .background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: ButtonCardFramePreferenceKey.self,
                    value: [button.id: proxy.frame(in: .named(coordinateSpaceName))]
                )
            }
        )
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .gesture(pressGesture(for: button))
        .onHover { hovering in
            if hovering {
                hoveredID = button.id
            } else if hoveredID == button.id {
                hoveredID = nil
            }
        }
        .contextMenu {
            Button("重命名…") { startRename(button) }
            if button.kind == .shortcut {
                Button("编辑组合…") { editingShortcut = button }
            }
            Divider()
            Button("上移") { state.move(button, offset: -1) }
                .disabled(!canUp)
            Button("下移") { state.move(button, offset: 1) }
                .disabled(!canDown)
            Divider()
            Button("删除…", role: .destructive) { pendingDelete = button }
        }
        .help(helpText(for: button))
        .accessibilityLabel("\(button.name)，\(kindLabel(for: button))")
        .accessibilityValue(selected ? "已选中" : "")
        .accessibilityAction(named: Text("重命名")) { startRename(button) }
        .accessibilityAction(named: Text("删除")) { pendingDelete = button }
        .zIndex(armed ? 2 : 0)
    }

    private func pressGesture(for button: ButtonConfig) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(coordinateSpaceName))
            .onChanged { value in
                handlePressChanged(button, value: value)
            }
            .onEnded { value in
                handlePressEnded(button, value: value)
            }
    }

    private func handlePressChanged(_ button: ButtonConfig, value: DragGesture.Value) {
        if dragButton?.id == button.id {
            updateDrag(value.location)
            return
        }
        if invalidatedPressID == button.id {
            return
        }

        if pressingID != button.id {
            beginPress(button, value: value)
        }
        guard pressingID == button.id else { return }

        let distance = hypot(value.translation.width, value.translation.height)
        if armedID == button.id {
            if distance > 4 {
                beginDrag(button, value: value)
            }
        } else if distance > 8 {
            invalidatePress()
        }
    }

    private func beginPress(_ button: ButtonConfig, value: DragGesture.Value) {
        longPressTask?.cancel()
        pressingID = button.id
        invalidatedPressID = nil
        armedID = nil
        selectedID = button.id
        dragLocation = value.location

        guard !isSearching else { return }

        let group = group(for: button)
        longPressTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            guard pressingID == button.id,
                  invalidatedPressID != button.id,
                  dragButton == nil,
                  armedID == nil,
                  !isSearching else { return }
            armedID = button.id
            dragGroup = group
            dragFrames = visibleFrames(for: group)
            dropIndex = nil
        }
    }

    private func invalidatePress() {
        longPressTask?.cancel()
        longPressTask = nil
        if let pressingID {
            invalidatedPressID = pressingID
        }
        armedID = nil
    }

    private func beginDrag(_ button: ButtonConfig, value: DragGesture.Value) {
        guard !isSearching, dragButton == nil else { return }
        if dragGroup == nil { dragGroup = group(for: button) }
        let frame = frames[button.id] ?? CGRect(x: value.startLocation.x - 64,
                                                y: value.startLocation.y - cardHeight / 2,
                                                width: 128,
                                                height: cardHeight)
        dragButton = button
        dragCardSize = frame.size
        dragGrabOffset = CGSize(width: value.startLocation.x - frame.midX,
                                height: value.startLocation.y - frame.midY)
        dragLocation = value.location
        updateDrag(value.location)
    }

    private func updateDrag(_ location: CGPoint) {
        dragLocation = location
        guard let dragButton, let dragGroup else {
            dropIndex = nil
            dragBlocked = false
            return
        }

        guard let groupRect = unionRect(for: dragGroup),
              groupRect.insetBy(dx: -28, dy: -36).contains(location) else {
            dropIndex = nil
            dragBlocked = true
            return
        }

        // 拖到另一组卡片上方时明确判为不可放置，避免边界处误排进原组。
        for other in ButtonGridGroup.allCases where other != dragGroup {
            if let otherRect = unionRect(for: other),
               otherRect.insetBy(dx: -8, dy: -8).contains(location) {
                dropIndex = nil
                dragBlocked = true
                return
            }
        }

        dragBlocked = false
        let order = groupButtons(for: dragGroup)
            .filter { $0.id != dragButton.id }
            .map(\.id)
        dropIndex = ButtonGridReorder.targetIndex(pointer: location,
                                                  frames: dragFrames,
                                                  order: order)
    }

    private func handlePressEnded(_ button: ButtonConfig, value: DragGesture.Value) {
        longPressTask?.cancel()
        longPressTask = nil

        if dragButton?.id == button.id {
            updateDrag(value.location)
            let target = dropIndex
            let targetGroup = dragGroup
            resetPressState()
            if let target, let targetGroup, targetGroup.contains(button) {
                state.moveToIndex(button, toIndex: target)
            }
            return
        }

        resetPressState()
    }

    private func resetPressState() {
        pressingID = nil
        invalidatedPressID = nil
        armedID = nil
        dragButton = nil
        dragGroup = nil
        dragFrames = [:]
        dropIndex = nil
        dragBlocked = false
        dragGrabOffset = .zero
        dragCardSize = .zero
    }

    private func dragGhost(for button: ButtonConfig) -> some View {
        ButtonGridCard(button: button,
                       installed: state.isInstalled(button),
                       isSelected: false,
                       isArmed: true,
                       isGhost: true,
                       isBlocked: dragBlocked)
            .frame(width: max(dragCardSize.width, 96),
                   height: max(dragCardSize.height, cardHeight))
            .position(x: dragLocation.x - dragGrabOffset.width,
                      y: dragLocation.y - dragGrabOffset.height)
            .allowsHitTesting(false)
            .zIndex(100)
    }

    private func entries(for buttons: [ButtonConfig], group: ButtonGridGroup) -> [ButtonGridEntry] {
        guard let dragButton,
              dragGroup == group,
              !isSearching,
              let dropIndex else {
            return buttons.map(ButtonGridEntry.button)
        }

        var result = buttons
            .filter { $0.id != dragButton.id }
            .map(ButtonGridEntry.button)
        result.insert(.placeholder, at: min(max(0, dropIndex), result.count))
        return result
    }

    private func groupButtons(for group: ButtonGridGroup) -> [ButtonConfig] {
        switch group {
        case .apps: return state.appButtons
        case .quick: return state.quickButtons
        }
    }

    private func filteredButtons(_ buttons: [ButtonConfig]) -> [ButtonConfig] {
        guard isSearching else { return buttons }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return buttons.filter { button in
            let fields = [
                button.name,
                button.bundleID,
                button.displaySymbol ?? "",
                button.builtinAction ?? "",
                kindLabel(for: button)
            ]
            return fields.contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    private func group(for button: ButtonConfig) -> ButtonGridGroup {
        button.kind == .app ? .apps : .quick
    }

    private func visibleFrames(for group: ButtonGridGroup) -> [String: CGRect] {
        let ids = Set(groupButtons(for: group).map(\.id))
        return frames.filter { ids.contains($0.key) }
    }

    private func unionRect(for group: ButtonGridGroup) -> CGRect? {
        let rects = visibleFrames(for: group).map(\.value)
        guard !rects.isEmpty else { return nil }
        return rects.reduce(CGRect.null) { $0.union($1) }
    }

    private func canMove(_ button: ButtonConfig, offset: Int, in group: ButtonGridGroup) -> Bool {
        let groupButtons = groupButtons(for: group)
        guard let index = groupButtons.firstIndex(where: { $0.id == button.id }) else { return false }
        let target = index + offset
        return groupButtons.indices.contains(target)
    }

    private func isCollapsed(_ group: ButtonGridGroup) -> Bool {
        !isSearching && collapsedGroups.contains(group)
    }

    private func toggleCollapsed(_ group: ButtonGridGroup) {
        if collapsedGroups.contains(group) {
            collapsedGroups.remove(group)
        } else {
            collapsedGroups.insert(group)
        }
    }

    private func startRename(_ button: ButtonConfig) {
        pendingRename = button
        renameText = button.name
    }

    private func iconName(for button: ButtonConfig) -> String {
        switch button.kind {
        case .app: return "app"
        case .shortcut: return "keyboard"
        case .command: return "terminal"
        case .builtin: return "square.grid.2x2"
        }
    }

    private func kindLabel(for button: ButtonConfig) -> String {
        switch button.kind {
        case .app: return state.isInstalled(button) ? "应用" : "应用缺失"
        case .shortcut: return "快捷操作"
        case .command: return "命令"
        case .builtin: return "内置"
        }
    }

    private func helpText(for button: ButtonConfig) -> String {
        switch button.kind {
        case .app:
            let status = state.isInstalled(button) ? button.bundleID : "应用缺失：\(button.bundleID)"
            return "\(button.name)\n\(status)\n按住 0.5 秒后拖动可排序；右键可编辑。"
        case .shortcut:
            return "\(button.name)\n\(button.displaySymbol ?? "")\n按住 0.5 秒后拖动可排序；右键可编辑。"
        case .command:
            return "\(button.name)\n命令\n按住 0.5 秒后拖动可排序；右键可编辑。"
        case .builtin:
            return "\(button.name)\n内置操作\n按住 0.5 秒后拖动可排序；右键可编辑。"
        }
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

import AppKit
import SwiftUI

/// MacShot chrome metrics, copied from the upstream sources:
/// ToolbarLayout.defaultBgColor / accentColor, ToolbarButtonView.size = 32,
/// ToolbarStripView padding 4 + spacing 2 + radius 6, EditorTopBarView height 32,
/// ToolOptionsRowView height 34, editor content insets 40/40/84/50.
private enum ShotUI {
    static let bg = Color(white: 0.12)
    static let canvas = Color(white: 0.15)
    static let icon = Color.white
    static let accent = Color(.sRGB, red: 0.55, green: 0.30, blue: 0.85, opacity: 1)
    static let radius: CGFloat = 6
    static let button: CGFloat = 32
    static let buttonSpacing: CGFloat = 2
    static let stripPadding: CGFloat = 4
    static let topBarHeight: CGFloat = 32
    static let optionsHeight: CGFloat = 34
}

struct CaptureEditorView: View {
    @ObservedObject var model: CaptureEditorModel
    let onSave: (CGImage) -> Void
    let onCopy: (CGImage) -> Void
    let onPin: (CGImage) -> Void
    let onOCR: (CGImage) -> Void
    let onQR: (CGImage) -> Void
    let onClose: () -> Void

    @State private var pendingTextPoint: CGPoint?
    @State private var textValue = ""
    @State private var showingText = false
    @State private var selectDragging = false
    @State private var resizeOriginal: CaptureAnnotation?
    @State private var resizeStartBounds: CGRect?
    @State private var editingText = false
    @State private var showingEffects = false
    @State private var zoom: CGFloat = 1
    @State private var zoomGestureBase: CGFloat = 1
    @State private var rotationStart: CGFloat?
    @State private var rotationOffset: CGFloat = 0

    private var bottomTools: [CaptureTool] {
        [.select, .pen, .line, .arrow, .rectangle, .ellipse, .marker,
         .text, .number, .pixelate, .blur, .highlight, .measure,
         .loupe, .stamp, .eyedropper, .crop]
    }

    /// 13 tools + color + undo + redo, same arithmetic as ToolbarStripView.layoutButtons().
    private var bottomStripWidth: CGFloat {
        let count = CGFloat(bottomTools.count + 4)
        return count * ShotUI.button
            + max(0, count - 1) * ShotUI.buttonSpacing
            + ShotUI.stripPadding * 2
    }

    private var showsOptionsRow: Bool {
        switch model.tool {
        case .select, .pen, .marker, .line, .arrow, .rectangle, .filledRectangle,
             .ellipse, .text, .number, .measure, .loupe, .stamp, .crop:
            return true
        case .pixelate, .blur, .highlight, .eyedropper, .image:
            return false
        }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            canvasArea
            VStack(spacing: 0) {
                topBar
                Spacer(minLength: 0)
            }
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                rightStrip
                    .padding(.top, 36)
                    .padding(.trailing, 20)
            }
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                bottomDock
                    .padding(.bottom, 20)
            }
            .frame(maxWidth: .infinity)

            if model.tool == .eyedropper {
                colorReadout
                    .padding(.top, 40)
                    .padding(.leading, 12)
            }
        }
        .background(ShotUI.canvas)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
        .frame(minWidth: 800, minHeight: 400)
        .onChange(of: model.selectedID) { _ in syncSelectionOptions() }
        .onChange(of: model.color) { _ in applySelectionStyle() }
        .onChange(of: model.lineWidth) { _ in applySelectionStyle() }
        .onChange(of: model.arrowStyle) { _ in applySelectionStyle() }
        .onChange(of: model.arrowReversed) { _ in applySelectionStyle() }
        .onChange(of: model.fillMode) { _ in applySelectionStyle() }
        .onChange(of: model.cornerRadius) { _ in applySelectionStyle() }
        .onChange(of: model.textBold) { _ in applySelectionStyle() }
        .onChange(of: model.textItalic) { _ in applySelectionStyle() }
        .onChange(of: model.textUnderline) { _ in applySelectionStyle() }
        .onChange(of: model.textStrikethrough) { _ in applySelectionStyle() }
        .onChange(of: model.textAlign) { _ in applySelectionStyle() }
        .onChange(of: model.textBackground) { _ in applySelectionStyle() }
        .onChange(of: model.textOutline) { _ in applySelectionStyle() }
        .onChange(of: model.censorMode) { _ in applySelectionStyle() }
        .onChange(of: model.numberFormat) { _ in applySelectionStyle() }
        .onChange(of: model.measureUnit) { _ in applySelectionStyle() }
        .onChange(of: model.spotlightDim) { _ in applySelectionStyle() }
        .sheet(isPresented: $showingEffects) {
            effectsPanel
        }
        .sheet(isPresented: $showingText) {
            VStack(alignment: .leading, spacing: 12) {
                Text("添加文字").font(.headline)
                TextField("输入文字", text: $textValue)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 320)
                    .onSubmit { commitText() }
                HStack {
                    Spacer()
                    Button("取消") { cancelText() }
                    Button("添加") { commitText() }
                        .keyboardShortcut(.defaultAction)
                }
            }
            .padding(20)
        }
    }

    // MARK: - Top bar (EditorTopBarView, 32pt)

    private var topBar: some View {
        HStack(spacing: 0) {
            Text(model.outputWidth > 0
                 ? "\(model.outputWidth) × \(model.outputHeight)"
                 : "\(Int(model.imageWidth)) × \(Int(model.imageHeight))")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.45))
                .padding(.leading, 12)

            ChromeButton(symbol: "crop", title: "裁剪", size: 24, iconSize: 13, radius: 5) {
                model.tool = model.tool == .crop ? .rectangle : .crop
                if model.tool != .crop { model.cropRect = nil }
            }
            .padding(.leading, 16)

            ChromeButton(symbol: "arrow.left.and.right.righttriangle.left.righttriangle.right",
                         title: "水平翻转", size: 24, iconSize: 13, radius: 5) {
                model.flipHorizontally()
            }
            .padding(.leading, 4)

            ChromeButton(symbol: "arrow.up.and.down.righttriangle.up.righttriangle.down",
                         title: "垂直翻转", size: 24, iconSize: 13, radius: 5) {
                model.flipVertically()
            }
            .padding(.leading, 4)

            Menu {
                Button("原始尺寸") { model.outputWidth = 0; model.outputHeight = 0 }
                Button("1920 × 1080（16:9）") { model.outputWidth = 1920; model.outputHeight = 1080 }
                Button("1440 × 1080（4:3）") { model.outputWidth = 1440; model.outputHeight = 1080 }
                Button("1080 × 1080（1:1）") { model.outputWidth = 1080; model.outputHeight = 1080 }
                Button("1080 × 1920（9:16）") { model.outputWidth = 1080; model.outputHeight = 1920 }
                Button("2560 × 1440（16:9）") { model.outputWidth = 2560; model.outputHeight = 1440 }
            } label: {
                Text("尺寸")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.8))
                    .padding(.horizontal, 6)
                    .frame(height: 22)
                    .background(RoundedRectangle(cornerRadius: 5).fill(Color.white.opacity(0.08)))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .padding(.leading, 4)

            Menu {
                Button("Retina 2x（原始）") { model.outputScale = 2 }
                Button("1x（缩小文件）") { model.outputScale = 1 }
            } label: {
                Text(model.outputScale < 1.5 ? "1x" : "2x")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.8))
                    .padding(.horizontal, 6)
                    .frame(height: 22)
                    .background(RoundedRectangle(cornerRadius: 5).fill(Color.white.opacity(0.08)))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .padding(.leading, 4)

            Menu {
                Button("50%") { zoom = 0.5 }
                Button("100%") { zoom = 1 }
                Button("200%") { zoom = 2 }
                Button("400%") { zoom = 4 }
                Divider()
                Button("放大 (+)，快捷键 ⌘+") { zoom = min(8, zoom * 1.25) }
                Button("缩小 (-)，快捷键 ⌘-") { zoom = max(0.1, zoom / 1.25) }
                Button("重置 (⌘0)") { zoom = 1 }
            } label: {
                Text(zoom == 1 ? "缩放" : "\(Int(zoom * 100))%")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.8))
                    .padding(.horizontal, 6)
                    .frame(height: 22)
                    .background(RoundedRectangle(cornerRadius: 5).fill(Color.white.opacity(0.08)))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .padding(.leading, 4)

            ChromeButton(symbol: "photo.badge.plus", title: "添加图片", size: 24, iconSize: 13, radius: 5) {
                addImageFromFile()
            }
            .padding(.leading, 4)

            ChromeButton(symbol: "doc.on.clipboard", title: "粘贴图片", size: 24, iconSize: 13, radius: 5) {
                if let cg = CaptureEditorWindowController.pasteboardImage() {
                    model.addImage(cg)
                }
            }
            .padding(.leading, 4)

            ChromeButton(symbol: "wand.and.stars", title: "美化与滤镜",
                         size: 24, iconSize: 13, radius: 5) {
                showingEffects = true
            }
            .padding(.leading, 4)

            Spacer(minLength: 8)

            dragHandle
                .padding(.trailing, 10)

            ChromeButton(symbol: "xmark", title: "关闭", size: 24, iconSize: 12, radius: 5,
                         action: onClose)
                .padding(.trailing, 10)
        }
        .frame(maxWidth: .infinity)
        .frame(height: ShotUI.topBarHeight)
        .background(ShotUI.bg)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(white: 0.25))
                .frame(height: 0.5)
        }
    }

    private var dragHandle: some View {
        ZStack {
            HStack(spacing: 4) {
                GripDots()
                Image(systemName: "photo")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.85))
                GripDots()
            }
            WindowDragHandle()
        }
        .frame(width: 40, height: 22)
        .help("拖动标题区域移动窗口")
    }

    // MARK: - Right strip (right toolbar, 32pt buttons)

    private var rightStrip: some View {
        VStack(spacing: ShotUI.buttonSpacing) {
            ChromeButton(symbol: "doc.on.doc", title: "复制") {
                if let image = model.render() { onCopy(image) }
            }
            ChromeButton(symbol: "square.and.arrow.down.fill", title: "保存") {
                if let image = model.render() { onSave(image) }
            }
            .keyboardShortcut("s", modifiers: .command)
            ChromeButton(symbol: "pin.fill", title: "钉图") {
                if let image = model.render() { onPin(image) }
            }
            ChromeButton(symbol: "doc.text.viewfinder", title: "OCR") {
                if let image = model.render() { onOCR(image) }
            }
            ChromeButton(symbol: "qrcode.viewfinder", title: "识别二维码") {
                if let image = model.render() { onQR(image) }
            }
            ChromeButton(symbol: "xmark", title: "关闭", action: onClose)
                .keyboardShortcut(.cancelAction)
        }
        .padding(ShotUI.stripPadding)
        .background(
            RoundedRectangle(cornerRadius: ShotUI.radius, style: .continuous)
                .fill(ShotUI.bg)
        )
    }

    // MARK: - Bottom dock (options row + bottom toolbar)

    private var bottomDock: some View {
        VStack(spacing: 2) {
            if showsOptionsRow {
                optionsRow
                    .frame(width: bottomStripWidth, height: ShotUI.optionsHeight)
            }
            HStack(spacing: ShotUI.buttonSpacing) {
                ForEach(bottomTools) { tool in
                    EditorToolButton(tool: tool, selected: model.tool == tool) {
                        model.tool = tool
                        if tool != .crop { model.cropRect = nil }
                    }
                }

                colorSwatch
                paletteMenu

                ChromeButton(symbol: "arrow.uturn.backward", title: "撤销",
                             disabled: !model.canUndo) {
                    model.undo()
                }
                ChromeButton(symbol: "arrow.uturn.forward", title: "重做",
                             disabled: !model.canRedo) {
                    model.redo()
                }
            }
            .padding(ShotUI.stripPadding)
            .background(
                RoundedRectangle(cornerRadius: ShotUI.radius, style: .continuous)
                    .fill(ShotUI.bg)
            )
        }
    }

    private var optionsRow: some View {
        HStack(spacing: 4) {
            if model.tool == .crop {
                Text("裁剪区域")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.4))
                Spacer(minLength: 8)
                Button { model.applyCrop() } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 28, height: 22)
                }
                .buttonStyle(.plain)
                .foregroundStyle(model.cropRect == nil ? ShotUI.accent.opacity(0.35) : ShotUI.accent)
                .disabled(model.cropRect == nil)
                .help("应用裁剪")
                Button { model.resetCrop() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 28, height: 22)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.white.opacity(0.85))
                .disabled(model.cropRect == nil)
                .help("取消裁剪")
            } else if model.tool == .select {
                if model.selectedAnnotation != nil {
                    Text("粗细").font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.4))
                    Slider(value: $model.lineWidth, in: 1...30)
                        .frame(width: 86).controlSize(.small).tint(ShotUI.accent)
                    optionMenu("箭头", selection: $model.arrowStyle,
                               items: ArrowStyle.allCases.map { ($0.title, $0) })
                    optionMenu("填充", selection: $model.fillMode,
                               items: ShapeFillMode.allCases.map { ($0.title, $0) })
                    alignMenu
                    styleToggle("B", active: $model.textBold)
                    styleToggle("I", active: $model.textItalic)
                    styleToggle("U", active: $model.textUnderline)
                    styleToggle("S", active: $model.textStrikethrough)
                    if model.selectedAnnotation?.tool == .text {
                        ChromeButton(symbol: "pencil.line", title: "重新编辑文字",
                                     size: 26, iconSize: 12) {
                            textValue = model.selectedAnnotation?.text ?? ""
                            showingText = true
                            editingText = true
                        }
                    }
                    ChromeButton(symbol: "trash", title: "删除选中", size: 26, iconSize: 12) {
                        model.deleteSelected()
                    }
                } else {
                    Text("点击画布上的标注进行选中，拖动可移动，拖角点可缩放")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.45))
                    Spacer(minLength: 8)
                }
            } else {
                Text(model.tool == .text ? "字号" : "粗细")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.4))
                Slider(value: $model.lineWidth, in: 1...30)
                    .frame(width: 90).controlSize(.small).tint(ShotUI.accent)
                Text("\(Int(model.lineWidth))px")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.6))
                    .frame(width: 28, alignment: .trailing)
                if model.tool == .arrow {
                    optionMenu("箭头", selection: $model.arrowStyle,
                               items: ArrowStyle.allCases.map { ($0.title, $0) })
                    styleToggle("↔", active: $model.arrowReversed, help: "反转箭头方向")
                }
                if model.tool == .rectangle || model.tool == .ellipse || model.tool == .filledRectangle {
                    optionMenu("填充", selection: $model.fillMode,
                               items: ShapeFillMode.allCases.map { ($0.title, $0) })
                    Text("圆角").font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.4))
                    Slider(value: $model.cornerRadius, in: 0...40)
                        .frame(width: 60).controlSize(.small).tint(ShotUI.accent)
                }
                if model.tool == .stamp {
                    emojiMenu
                }
                if model.tool == .loupe {
                    Text("倍率").font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.4))
                    Slider(value: $model.loupeZoom, in: 1.5...4)
                        .frame(width: 70).controlSize(.small).tint(ShotUI.accent)
                }
                if model.tool == .pixelate || model.tool == .blur {
                    optionMenu("打码", selection: $model.censorMode,
                               items: CensorMode.allCases.map { ($0.title, $0) })
                }
                if model.tool == .number {
                    optionMenu("编号", selection: $model.numberFormat,
                               items: NumberFormat.allCases.map { ($0.title, $0) })
                }
                if model.tool == .measure {
                    optionMenu("单位", selection: $model.measureUnit,
                               items: MeasureUnit.allCases.map { ($0.title, $0) })
                }
                if model.tool == .highlight {
                    Text("压暗").font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.4))
                    Slider(value: $model.spotlightDim, in: 0.2...0.9)
                        .frame(width: 70).controlSize(.small).tint(ShotUI.accent)
                }
                if model.tool == .text {
                    styleToggle("B", active: $model.textBold)
                    styleToggle("I", active: $model.textItalic)
                    styleToggle("U", active: $model.textUnderline)
                    styleToggle("S", active: $model.textStrikethrough)
                    alignMenu
                    styleToggle("▧", active: $model.textBackground, help: "文字底色")
                    styleToggle("O", active: $model.textOutline, help: "文字描边")
                }
                Spacer(minLength: 4)
            }
        }
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: ShotUI.radius, style: .continuous)
                .fill(ShotUI.bg)
        )
    }

    private func optionMenu<T: Hashable>(_ title: String, selection: Binding<T>,
                                         items: [(String, T)]) -> some View {
        Menu {
            ForEach(items, id: \.1) { item in
                Button(item.0) { selection.wrappedValue = item.1 }
            }
        } label: {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.8))
                .padding(.horizontal, 6)
                .frame(height: 22)
                .background(RoundedRectangle(cornerRadius: 5).fill(Color.white.opacity(0.08)))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var emojiMenu: some View {
        Menu {
            ForEach(["😀","😁","😂","🤣","😊","😍","🤔","😎","😱","😡","👍","👎","👏","🙏","🔥","⭐️","✅","❌","❗️","❓","💡"], id: \.self) { e in
                Button(e) { model.stampEmoji = e }
            }
        } label: {
            Text(model.stampEmoji).font(.system(size: 15))
                .frame(width: 26, height: 22)
                .background(RoundedRectangle(cornerRadius: 5).fill(Color.white.opacity(0.08)))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var alignMenu: some View {
        Menu {
            ForEach(TextAlign.allCases) { a in
                Button(a.title) { model.textAlign = a }
            }
        } label: {
            Image(systemName: "text.alignleft")
                .font(.system(size: 11))
                .foregroundStyle(Color.white.opacity(0.8))
                .frame(width: 24, height: 22)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private func styleToggle(_ label: String, active: Binding<Bool>,
                             help: String = "") -> some View {
        Button { active.wrappedValue.toggle() } label: {
            Text(label)
                .font(.system(size: label.count > 1 ? 12 : 11, weight: .bold))
                .frame(width: 22, height: 22)
                .background(RoundedRectangle(cornerRadius: 5)
                    .fill(active.wrappedValue ? ShotUI.accent : Color.white.opacity(0.08)))
                .foregroundStyle(Color.white.opacity(0.9))
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private var effectsPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("图像效果").font(.headline)
                Spacer()
                Button("完成") { showingEffects = false }
                    .keyboardShortcut(.defaultAction)
            }
            Picker("预设", selection: $model.effectPreset) {
                ForEach(ImageEffectPreset.allCases) { p in
                    Text(p.title).tag(p)
                }
            }
            .pickerStyle(.segmented)

            sliderRow("亮度", value: $model.brightness, range: -1...1)
            sliderRow("对比度", value: $model.contrast, range: 0.5...2)
            sliderRow("饱和度", value: $model.saturation, range: 0...2)
            sliderRow("锐度", value: $model.sharpness, range: 0...2)

            Divider()

            Toggle("Beautify 窗口美化", isOn: $model.beautifyEnabled)
                .font(.subheadline.weight(.semibold))
            sliderRow("留白", value: Binding(
                get: { Double(model.beautifyPadding) },
                set: { model.beautifyPadding = CGFloat($0) }), range: 0...120)
            sliderRow("圆角", value: Binding(
                get: { Double(model.beautifyCorner) },
                set: { model.beautifyCorner = CGFloat($0) }), range: 0...40)
            HStack {
                Toggle("阴影", isOn: $model.beautifyShadow)
                Spacer()
                Toggle("窗口标题栏", isOn: $model.beautifyWindowChrome)
            }
            HStack(spacing: 8) {
                Text("背景").font(.caption).foregroundStyle(.secondary)
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(30), spacing: 6), count: 10), spacing: 6) {
                ForEach(BeautifyComposer.gradients.indices, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(colors: BeautifyComposer.gradients[i].map { Color(nsColor: $0) },
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 30, height: 22)
                        .overlay(RoundedRectangle(cornerRadius: 4)
                            .stroke(model.beautifyGradient == i ? Color.accentColor : Color.clear,
                                    lineWidth: 2))
                        .onTapGesture { model.beautifyGradient = i }
                    }
                }
            }
        }
        .padding(20)
        .frame(width: 460)
    }

    private func sliderRow(_ title: String, value: Binding<Double>,
                           range: ClosedRange<Double>) -> some View {
        HStack {
            Text(title).font(.caption).frame(width: 52, alignment: .leading)
            Slider(value: value, in: range).controlSize(.small)
            Text(String(format: "%.2f", value.wrappedValue))
                .font(.system(size: 10, design: .monospaced))
                .frame(width: 40, alignment: .trailing)
        }
    }

    private var colorSwatch: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(model.color)
                .padding(6)
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(Color.white.opacity(0.4), lineWidth: 0.5)
                .padding(6)
            ColorPicker("", selection: $model.color, supportsOpacity: false)
                .labelsHidden()
                .opacity(0.02)
        }
        .frame(width: ShotUI.button, height: ShotUI.button)
        .contentShape(Rectangle())
        .help("颜色")
    }

    private var paletteMenu: some View {
        Menu {
            ForEach([Color.red, .orange, .yellow, .green, .blue, .purple,
                     .pink, .black, .white, Color(white: 0.5)], id: \.self) { c in
                Button {
                    model.color = c
                } label: {
                    Label {
                        Text(c == .black ? "黑" : c == .white ? "白" : "")
                    } icon: {
                        Circle().fill(c)
                    }
                }
            }
        } label: {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 12))
                .frame(width: 26, height: 26)
                .foregroundStyle(Color.white.opacity(0.8))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("常用颜色")
    }

    private var colorReadout: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 4)
                .fill(model.color)
                .frame(width: 22, height: 22)
            Text(model.pickedColorText ?? "点击画布取色")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.9))
            if model.pickedColorText != nil {
                Button("复制 HEX") { model.copyHexFromPicked() }
                    .buttonStyle(.plain)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(ShotUI.accent)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 32)
        .background(RoundedRectangle(cornerRadius: 6).fill(ShotUI.bg.opacity(0.92)))
    }

    private func syncSelectionOptions() {
        guard let a = model.selectedAnnotation else { return }
        model.color = Color(nsColor: a.color)
        model.lineWidth = a.lineWidth
        model.arrowStyle = a.arrowStyle
        model.arrowReversed = a.arrowReversed
        model.fillMode = a.fillMode
        model.cornerRadius = a.cornerRadius
        model.textBold = a.textBold
        model.textItalic = a.textItalic
        model.textUnderline = a.textUnderline
        model.textStrikethrough = a.textStrikethrough
        model.textAlign = a.textAlign
        model.textBackground = a.textBackground
        model.textBackgroundColor = Color(nsColor: a.textBackgroundColor)
        model.textOutline = a.textOutline
        model.censorMode = a.censorMode
        model.numberFormat = a.numberFormat
        model.measureUnit = a.measureUnit
        model.spotlightDim = a.spotlightDim
    }

    private func applySelectionStyle() {
        guard model.selectedAnnotation != nil else { return }
        model.mutateSelectedWithoutUndo { a in
            a.color = model.nsColor
            a.lineWidth = model.lineWidth
            a.arrowStyle = model.arrowStyle
            a.arrowReversed = model.arrowReversed
            a.fillMode = model.fillMode
            a.cornerRadius = model.cornerRadius
            a.textBold = model.textBold
            a.textItalic = model.textItalic
            a.textUnderline = model.textUnderline
            a.textStrikethrough = model.textStrikethrough
            a.textAlign = model.textAlign
            a.textBackground = model.textBackground
            a.textBackgroundColor = model.nsColor == .clear ? a.textBackgroundColor : NSColor(model.textBackgroundColor)
            a.textOutline = model.textOutline
            a.censorMode = model.censorMode
            a.numberFormat = model.numberFormat
            a.measureUnit = model.measureUnit
            a.spotlightDim = model.spotlightDim
            if a.tool == .text { a.fontSize = max(18, model.lineWidth * 7) }
            if a.tool == .stamp { a.fontSize = max(24, model.lineWidth * 8) }
        }
    }

    // MARK: - Canvas

    private var canvasArea: some View {
        GeometryReader { proxy in
            ZStack {
                ShotUI.canvas
                imageAndCanvas(size: proxy.size)
            }
            .clipped()
        }
        .onReceive(NotificationCenter.default.publisher(for: .captureEditorZoomIn)) { _ in
            zoom = min(8, zoom * 1.25)
        }
        .onReceive(NotificationCenter.default.publisher(for: .captureEditorZoomOut)) { _ in
            zoom = max(0.1, zoom / 1.25)
        }
        .onReceive(NotificationCenter.default.publisher(for: .captureEditorResetZoom)) { _ in
            zoom = 1
        }
    }

    private func imageAndCanvas(size: CGSize) -> some View {
        // DetachedEditorWindowController uses contentInsets bottom 84 / right 50
        // plus OverlayView.editorDocumentMargin = 40 around the image.
        let container = CGRect(x: 40, y: 40,
                               width: max(size.width - 40 - 60, 1),
                               height: max(size.height - 40 - 84, 1))
        let base = fitRect(imageSize: CGSize(width: model.imageWidth, height: model.imageHeight),
                           in: container)
        let fit: CGRect
        if zoom == 1 {
            fit = base
        } else {
            let w = base.width * zoom
            let h = base.height * zoom
            fit = CGRect(x: base.midX - w / 2, y: base.midY - h / 2, width: w, height: h)
        }
        return ZStack(alignment: .topLeading) {
            Image(nsImage: NSImage(cgImage: model.previewBaseImage(),
                                   size: NSSize(width: model.imageWidth, height: model.imageHeight)))
                .resizable()
                .interpolation(.high)
                .frame(width: fit.width, height: fit.height)
                .position(x: fit.midX, y: fit.midY)

            Canvas { context, _ in
                drawAnnotations(context: &context, fit: fit)
            }
            .frame(width: size.width, height: size.height)
            .contentShape(Rectangle())
            .gesture(drawingGesture(fit: fit))
            .simultaneousGesture(
                MagnificationGesture()
                    .onChanged { value in
                        if zoomGestureBase == 0 { zoomGestureBase = zoom }
                        zoom = min(8, max(0.1, zoomGestureBase * value))
                    }
                    .onEnded { _ in zoomGestureBase = 0 }
            )

            if model.tool == .select, let selected = model.selectedAnnotation {
                selectionHandles(for: selected, fit: fit)
            }
        }
    }

    private func selectionHandles(for annotation: CaptureAnnotation,
                                  fit: CGRect) -> some View {
        let b = annotation.boundingRect
        let scaleX = fit.width / max(model.imageWidth, 1)
        let scaleY = fit.height / max(model.imageHeight, 1)
        let r = CGRect(x: fit.minX + b.minX * scaleX,
                       y: fit.minY + b.minY * scaleY,
                       width: b.width * scaleX, height: b.height * scaleY)
        let points: [(SelectionHandle, CGPoint)] = [
            (.tl, CGPoint(x: r.minX, y: r.minY)), (.tm, CGPoint(x: r.midX, y: r.minY)),
            (.tr, CGPoint(x: r.maxX, y: r.minY)), (.ml, CGPoint(x: r.minX, y: r.midY)),
            (.mr, CGPoint(x: r.maxX, y: r.midY)), (.bl, CGPoint(x: r.minX, y: r.maxY)),
            (.bm, CGPoint(x: r.midX, y: r.maxY)), (.br, CGPoint(x: r.maxX, y: r.maxY))
        ]
        return ZStack {
            Rectangle()
                .stroke(ShotUI.accent, lineWidth: 1.5)
                .frame(width: max(r.width, 1), height: max(r.height, 1))
                .position(x: r.midX, y: r.midY)
                .allowsHitTesting(false)
            ForEach(points, id: \.0) { item in
                Circle()
                    .fill(ShotUI.accent)
                    .frame(width: 9, height: 9)
                    .overlay(Circle().stroke(.white.opacity(0.9), lineWidth: 1))
                    .position(item.1)
                    .gesture(resizeGesture(handle: item.0, fit: fit))
            }
            Circle()
                .fill(Color.white)
                .frame(width: 11, height: 11)
                .overlay(Circle().stroke(ShotUI.accent, lineWidth: 1.5))
                .position(x: r.midX, y: r.minY - 22)
                .gesture(rotateGesture(center: CGPoint(x: r.midX, y: r.midY)))
        }
    }

    private func rotateGesture(center: CGPoint) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                guard let selected = model.selectedAnnotation else { return }
                if rotationStart == nil { rotationStart = selected.rotation }
                let angle = atan2(value.location.y - center.y, value.location.x - center.x)
                    * 180 / .pi + 90
                var target = angle
                if NSEvent.modifierFlags.contains(.shift) {
                    target = (target / 90).rounded() * 90
                }
                model.updateSelected { $0.rotation = target }
            }
            .onEnded { _ in rotationStart = nil }
    }

    private func addImageFromFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .tiff, .heic, .gif]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url,
           let image = NSImage(contentsOf: url),
           let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            model.addImage(cg)
        }
    }

    private func resizeGesture(handle: SelectionHandle, fit: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                guard let selected = model.selectedAnnotation else { return }
                if resizeOriginal == nil {
                    resizeOriginal = selected
                    resizeStartBounds = selected.boundingRect
                }
                guard let start = resizeStartBounds else { return }
                let p = imagePoint(from: value.location, fit: fit)
                let newRect = handle.adjusted(start, to: p)
                model.resizeSelected(original: resizeOriginal!, to: newRect)
            }
            .onEnded { _ in
                resizeOriginal = nil
                resizeStartBounds = nil
            }
    }

    private func drawingGesture(fit: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                let point = imagePoint(from: value.location, fit: fit)
                switch model.tool {
                case .select:
                    if !selectDragging {
                        selectDragging = true
                        model.select(at: point)
                    } else {
                        model.dragSelected(to: point)
                    }
                case .eyedropper:
                    model.pickColor(at: point)
                case .crop:
                    let start = imagePoint(from: value.startLocation, fit: fit)
                    if model.cropRect == nil { model.beginDraft(at: start) }
                    model.updateDraft(to: point)
                default:
                    let start = imagePoint(from: value.startLocation, fit: fit)
                    if model.draft == nil { model.beginDraft(at: start) }
                    model.updateDraft(to: point)
                }
            }
            .onEnded { value in
                let point = imagePoint(from: value.location, fit: fit)
                switch model.tool {
                case .select:
                    model.selectEnded()
                    selectDragging = false
                case .eyedropper:
                    break
                case .text:
                    pendingTextPoint = point
                    textValue = ""
                    showingText = true
                    model.draft = nil
                default:
                    model.commitDraft()
                }
            }
    }

    private func imagePoint(from viewPoint: CGPoint, fit: CGRect) -> CGPoint {
        guard fit.width > 0, fit.height > 0 else { return .zero }
        let x = (viewPoint.x - fit.minX) / fit.width * model.imageWidth
        let y = (viewPoint.y - fit.minY) / fit.height * model.imageHeight
        return CGPoint(x: min(max(x, 0), model.imageWidth),
                       y: min(max(y, 0), model.imageHeight))
    }

    private func drawAnnotations(context: inout GraphicsContext, fit: CGRect) {
        let scaleX = fit.width / max(model.imageWidth, 1)
        let scaleY = fit.height / max(model.imageHeight, 1)

        var transformed = context
        transformed.translateBy(x: fit.minX, y: fit.minY)
        transformed.scaleBy(x: scaleX, y: scaleY)

        let all = model.annotations + (model.draft.map { [$0] } ?? [])
        for annotation in all {
            draw(annotation, context: &transformed)
        }

        if let crop = model.cropRect {
            let scaled = CGRect(x: fit.minX + crop.minX * scaleX,
                                y: fit.minY + crop.minY * scaleY,
                                width: crop.width * scaleX,
                                height: crop.height * scaleY)
            context.fill(Path(CGRect(x: 0, y: 0, width: fit.minX, height: fit.height)),
                         with: .color(.black.opacity(0.28)))
            context.fill(Path(CGRect(x: fit.maxX, y: 0, width: 10000, height: 10000)),
                         with: .color(.black.opacity(0.28)))
            context.fill(Path(CGRect(x: fit.minX, y: fit.minY, width: fit.width, height: max(scaled.minY - fit.minY, 0))),
                         with: .color(.black.opacity(0.28)))
            context.fill(Path(CGRect(x: fit.minX, y: scaled.maxY, width: fit.width, height: max(fit.maxY - scaled.maxY, 0))),
                         with: .color(.black.opacity(0.28)))
            context.stroke(Path(scaled), with: .color(ShotUI.accent), lineWidth: 2)
        }
    }

    private func draw(_ annotation: CaptureAnnotation, context: inout GraphicsContext) {
        let color = Color(nsColor: annotation.color)
        let lineWidth = annotation.lineWidth
        var ctx = context
        if annotation.rotation != 0 {
            let b = annotation.unrotatedBounds
            let c = CGPoint(x: b.midX, y: b.midY)
            ctx.translateBy(x: c.x, y: c.y)
            ctx.rotate(by: .radians(Double(annotation.rotation)))
            ctx.translateBy(x: -c.x, y: -c.y)
        }
        context = ctx

        switch annotation.tool {
        case .select, .eyedropper, .crop:
            break
        case .image:
            if let cg = annotation.image {
                let rect = normRect(annotation.start, annotation.end)
                context.draw(Image(decorative: cg, scale: 1), in: rect)
                context.stroke(Path(rect), with: .color(ShotUI.accent.opacity(0.5)), lineWidth: 1)
            }
        case .rectangle, .filledRectangle, .ellipse:
            let rect = normRect(annotation.start, annotation.end)
            let path: Path
            if annotation.tool == .ellipse {
                path = Path(ellipseIn: rect)
            } else if annotation.cornerRadius > 0 {
                path = Path(roundedRect: rect, cornerRadius: annotation.cornerRadius)
            } else {
                path = Path(rect)
            }
            let mode: ShapeFillMode = annotation.tool == .filledRectangle
                ? (annotation.fillMode == .stroke ? .fill : annotation.fillMode)
                : annotation.fillMode
            if mode == .fill || mode == .strokeAndFill {
                context.fill(path, with: .color(color.opacity(0.9)))
            }
            if mode == .stroke || mode == .strokeAndFill {
                context.stroke(path, with: .color(color), lineWidth: lineWidth)
            }
        case .line:
            var path = Path()
            path.move(to: annotation.start); path.addLine(to: annotation.end)
            context.stroke(path, with: .color(color), lineWidth: lineWidth)
        case .arrow:
            drawArrow(annotation, context: &context, color: color)
        case .pen, .marker:
            let points = annotation.points.isEmpty
                ? [annotation.start, annotation.end] : annotation.points
            guard let first = points.first else { return }
            var path = Path()
            path.move(to: first)
            for point in points.dropFirst() { path.addLine(to: point) }
            context.stroke(path,
                           with: .color(annotation.tool == .marker ? color.opacity(0.35) : color),
                           lineWidth: annotation.tool == .marker ? lineWidth * 2.5 : lineWidth)
        case .text:
            let text = previewText(annotation, color: color)
            if annotation.textBackground {
                let size = AnnotationRenderer.textSize(annotation.text ?? "", annotation: annotation)
                let bg = CGRect(x: annotation.start.x - 4, y: annotation.start.y - 2,
                                width: size.width + 8, height: size.height + 4)
                context.fill(Path(roundedRect: bg, cornerRadius: 4),
                             with: .color(Color(nsColor: annotation.textBackgroundColor).opacity(0.72)))
            }
            context.draw(text, at: annotation.start, anchor: .topLeading)
        case .number:
            let radius = max(14, annotation.fontSize * 0.9)
            let rect = CGRect(x: annotation.start.x - radius, y: annotation.start.y - radius,
                              width: radius * 2, height: radius * 2)
            context.fill(Path(ellipseIn: rect), with: .color(color))
            let label = Text("\(annotation.number ?? 1)")
                .font(.system(size: annotation.fontSize, weight: .bold))
                .foregroundColor(.white)
            context.draw(label, at: CGPoint(x: rect.midX, y: rect.midY), anchor: .center)
        case .pixelate:
            let rect = normRect(annotation.start, annotation.end)
            context.fill(Path(rect), with: .color(.gray.opacity(0.55)))
            var x = rect.minX
            while x < rect.maxX {
                var y = rect.minY
                while y < rect.maxY {
                    let block = CGRect(x: x, y: y, width: min(10, rect.maxX - x),
                                       height: min(10, rect.maxY - y))
                    context.stroke(Path(block), with: .color(.black.opacity(0.12)), lineWidth: 0.5)
                    y += 10
                }
                x += 10
            }
        case .blur:
            context.fill(Path(normRect(annotation.start, annotation.end)),
                         with: .color(.gray.opacity(0.65)))
        case .highlight:
            let region = normRect(annotation.start, annotation.end)
            context.fill(Path(CGRect(x: 0, y: 0, width: 10000, height: 10000)),
                         with: .color(.black.opacity(0.35)))
            context.blendMode = .destinationOut
            context.fill(Path(region), with: .color(.white))
            context.blendMode = .normal
            context.stroke(Path(region), with: .color(.white.opacity(0.8)), lineWidth: 1.5)
        case .measure:
            var path = Path()
            path.move(to: annotation.start); path.addLine(to: annotation.end)
            context.stroke(path, with: .color(color), lineWidth: max(1, lineWidth))
            let dx = abs(annotation.end.x - annotation.start.x)
            let dy = abs(annotation.end.y - annotation.start.y)
            let text = Text("\(Int(dx)) × \(Int(dy)) px")
                .font(.system(size: max(11, annotation.fontSize * 0.55), weight: .medium))
                .foregroundColor(.white)
            context.draw(text,
                         at: CGPoint(x: (annotation.start.x + annotation.end.x) / 2,
                                     y: (annotation.start.y + annotation.end.y) / 2),
                         anchor: .bottom)
        case .loupe:
            let radius = max(24, min(hypot(annotation.end.x - annotation.start.x,
                                           annotation.end.y - annotation.start.y), 160))
            let dest = CGRect(x: annotation.start.x - radius, y: annotation.start.y - radius,
                              width: radius * 2, height: radius * 2)
            let sampleRadius = radius / max(annotation.loupeZoom, 0.1)
            let sample = CGRect(x: annotation.start.x - sampleRadius,
                                y: annotation.start.y - sampleRadius,
                                width: sampleRadius * 2, height: sampleRadius * 2)
            if let crop = model.baseImage.cropping(to: sample.integral) {
                let img = Image(nsImage: NSImage(cgImage: crop, size: dest.size))
                context.draw(img, in: dest)
            }
            context.stroke(Path(ellipseIn: dest), with: .color(.white.opacity(0.9)), lineWidth: 2)
        case .stamp:
            let text = Text(annotation.stampEmoji)
                .font(.system(size: max(20, annotation.fontSize * 1.6)))
            context.draw(text, at: annotation.start, anchor: .center)
        }
    }

    private func previewText(_ annotation: CaptureAnnotation, color: Color) -> Text {
        var text = Text(annotation.text ?? "")
            .font(.system(size: annotation.fontSize,
                          weight: annotation.textBold ? .semibold : .regular))
            .foregroundColor(color)
        if annotation.textItalic { text = text.italic() }
        if annotation.textUnderline { text = text.underline() }
        if annotation.textStrikethrough { text = text.strikethrough() }
        return text
    }

    private func drawArrow(_ annotation: CaptureAnnotation,
                           context: inout GraphicsContext, color: Color) {
        let from = annotation.arrowReversed ? annotation.end : annotation.start
        let to = annotation.arrowReversed ? annotation.start : annotation.end
        let width = annotation.lineWidth
        switch annotation.arrowStyle {
        case .single, .tail:
            strokeLine(annotation.start, annotation.end, width: width, color: color, context: &context)
            fillHead(from: from, to: to, width: width, color: color, context: &context)
            if annotation.arrowStyle == .tail {
                let dx = to.x - from.x, dy = to.y - from.y
                let len = max(hypot(dx, dy), 1)
                let ux = dx / len, uy = dy / len
                let base = CGPoint(x: from.x + ux * min(18, len * 0.4),
                                   y: from.y + uy * min(18, len * 0.4))
                let w = width * 3
                strokeLine(from, CGPoint(x: base.x - uy * w, y: base.y + ux * w),
                           width: width, color: color, context: &context)
                strokeLine(from, CGPoint(x: base.x + uy * w, y: base.y - ux * w),
                           width: width, color: color, context: &context)
            }
        case .thick:
            let dx = to.x - from.x, dy = to.y - from.y
            let len = max(hypot(dx, dy), 1)
            let ux = dx / len, uy = dy / len
            let half = max(width * 2.2, 5)
            let headLen = min(max(width * 6, 16), len * 0.45)
            let headHalf = half * 2.1
            let base = CGPoint(x: to.x - ux * headLen, y: to.y - uy * headLen)
            var p = Path()
            p.move(to: to)
            p.addLine(to: CGPoint(x: base.x - uy * headHalf, y: base.y + ux * headHalf))
            p.addLine(to: CGPoint(x: base.x - uy * half, y: base.y + ux * half))
            p.addLine(to: CGPoint(x: from.x - uy * half, y: from.y + ux * half))
            p.addLine(to: CGPoint(x: from.x + uy * half, y: from.y - ux * half))
            p.addLine(to: CGPoint(x: base.x + uy * half, y: base.y - ux * half))
            p.addLine(to: CGPoint(x: base.x + uy * headHalf, y: base.y - ux * headHalf))
            p.closeSubpath()
            context.fill(p, with: .color(color))
        case .double:
            strokeLine(annotation.start, annotation.end, width: width, color: color, context: &context)
            fillHead(from: annotation.start, to: annotation.end, width: width, color: color, context: &context)
            fillHead(from: annotation.end, to: annotation.start, width: width, color: color, context: &context)
        case .open:
            strokeLine(annotation.start, annotation.end, width: width, color: color, context: &context)
            let head = openHead(from: from, to: to, width: width)
            strokeLine(to, head[0], width: width * 0.8, color: color, context: &context)
            strokeLine(to, head[1], width: width * 0.8, color: color, context: &context)
        }
    }

    private func strokeLine(_ a: CGPoint, _ b: CGPoint, width: CGFloat,
                            color: Color, context: inout GraphicsContext) {
        var p = Path(); p.move(to: a); p.addLine(to: b)
        context.stroke(p, with: .color(color), lineWidth: width)
    }

    private func fillHead(from: CGPoint, to: CGPoint, width: CGFloat,
                          color: Color, context: inout GraphicsContext) {
        var p = Path()
        let pts = arrowHead(from: from, to: to, width: width)
        guard let first = pts.first else { return }
        p.move(to: first)
        for q in pts.dropFirst() { p.addLine(to: q) }
        p.closeSubpath()
        context.fill(p, with: .color(color))
    }

    private func openHead(from: CGPoint, to: CGPoint, width: CGFloat) -> [CGPoint] {
        let dx = to.x - from.x, dy = to.y - from.y
        let len = max(hypot(dx, dy), 1)
        let ux = dx / len, uy = dy / len
        let hl = min(max(width * 4.5, 12), len * 0.6)
        let hw = hl * 0.62
        let base = CGPoint(x: to.x - ux * hl, y: to.y - uy * hl)
        return [CGPoint(x: base.x - uy * hw, y: base.y + ux * hw),
                CGPoint(x: base.x + uy * hw, y: base.y - ux * hw)]
    }

    private func normRect(_ a: CGPoint, _ b: CGPoint) -> CGRect {
        CGRect(x: min(a.x, b.x), y: min(a.y, b.y),
               width: abs(a.x - b.x), height: abs(a.y - b.y))
    }

    private func arrowHead(from start: CGPoint, to end: CGPoint, width: CGFloat) -> [CGPoint] {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = max(hypot(dx, dy), 1)
        let ux = dx / length
        let uy = dy / length
        let headLength = min(max(width * 4.5, 12), length * 0.6)
        let headWidth = headLength * 0.62
        let base = CGPoint(x: end.x - ux * headLength, y: end.y - uy * headLength)
        return [end,
                CGPoint(x: base.x - uy * headWidth, y: base.y + ux * headWidth),
                CGPoint(x: base.x + uy * headWidth, y: base.y - ux * headWidth)]
    }

    private func commitText() {
        if editingText {
            model.updateSelectedText(textValue)
        } else if let point = pendingTextPoint {
            model.addText(textValue, at: point)
        }
        showingText = false
        pendingTextPoint = nil
        editingText = false
    }

    private func cancelText() {
        showingText = false
        pendingTextPoint = nil
        editingText = false
    }

    private func fitRect(imageSize: CGSize, in container: CGRect) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0,
              container.width > 0, container.height > 0 else { return .zero }
        let scale = min(1, min(container.width / imageSize.width,
                               container.height / imageSize.height))
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(x: container.midX - size.width / 2,
                      y: container.midY - size.height / 2,
                      width: size.width, height: size.height)
    }
}

private struct GripDots: View {
    var body: some View {
        Canvas { context, _ in
            let dot: CGFloat = 2
            let gap: CGFloat = 2
            for column in 0..<2 {
                for row in 0..<3 {
                    let rect = CGRect(x: CGFloat(column) * (dot + gap),
                                      y: CGFloat(row) * (dot + gap),
                                      width: dot, height: dot)
                    context.fill(Path(ellipseIn: rect),
                                 with: .color(.white.opacity(0.4)))
                }
            }
        }
        .frame(width: 6, height: 10)
    }
}

private struct WindowDragHandle: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        DragView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class DragView: NSView {
        override var mouseDownCanMoveWindow: Bool { true }

        override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }
    }
}

private struct ChromeButton: View {
    let symbol: String
    let title: String
    var size: CGFloat = ShotUI.button
    var iconSize: CGFloat = 14
    var radius: CGFloat = ShotUI.radius
    var disabled: Bool = false
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: iconSize, weight: .medium))
                .frame(width: size, height: size)
                .background(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(hovering && !disabled ? Color.white.opacity(0.12) : Color.clear)
                )
                .foregroundStyle(ShotUI.icon.opacity(disabled ? 0.3 : 0.9))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .help(title)
        .onHover { hovering = $0 }
    }
}

private struct EditorToolButton: View {
    let tool: CaptureTool
    let selected: Bool
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            glyph
                .frame(width: ShotUI.button, height: ShotUI.button)
                .background(
                    RoundedRectangle(cornerRadius: ShotUI.radius, style: .continuous)
                        .fill(selected
                              ? ShotUI.accent
                              : (hovering ? Color.white.opacity(0.12) : Color.clear))
                )
                .foregroundStyle(ShotUI.icon.opacity(selected ? 1 : 0.9))
        }
        .buttonStyle(.plain)
        .help(tool.title)
        .onHover { hovering = $0 }
    }

    @ViewBuilder
    private var glyph: some View {
        switch tool {
        case .text:
            // ToolbarButtonView.textIcon: 17pt bold "T".
            Text("T")
                .font(.system(size: 17, weight: .bold))
        case .pixelate:
            CheckerboardGlyph()
        case .number:
            Image(systemName: "1.circle.fill")
                .font(.system(size: 14, weight: .medium))
        default:
            Image(systemName: tool.symbol)
                .font(.system(size: 14, weight: .medium))
        }
    }
}

private struct CheckerboardGlyph: View {
    var body: some View {
        Canvas { context, _ in
            let side: CGFloat = 16
            let cell = side / 4
            let clip = Path(roundedRect: CGRect(x: 0, y: 0, width: side, height: side),
                            cornerRadius: 3)
            context.clip(to: clip)
            for row in 0..<4 {
                for column in 0..<4 {
                    let rect = CGRect(x: CGFloat(column) * cell,
                                      y: CGFloat(row) * cell,
                                      width: cell, height: cell)
                    let dark = (row + column) % 2 == 0
                    context.fill(Path(rect),
                                 with: .color(.white.opacity(dark ? 1 : 0.35)))
                }
            }
        }
        .frame(width: 16, height: 16)
    }
}


private enum SelectionHandle: Hashable {
    case tl, tm, tr, ml, mr, bl, bm, br

    func adjusted(_ start: CGRect, to p: CGPoint) -> CGRect {
        var minX = start.minX, minY = start.minY
        var maxX = start.maxX, maxY = start.maxY
        switch self {
        case .tl: minX = p.x; minY = p.y
        case .tm: minY = p.y
        case .tr: maxX = p.x; minY = p.y
        case .ml: minX = p.x
        case .mr: maxX = p.x
        case .bl: minX = p.x; maxY = p.y
        case .bm: maxY = p.y
        case .br: maxX = p.x; maxY = p.y
        }
        if maxX - minX < 8 { maxX = minX + 8 }
        if maxY - minY < 8 { maxY = minY + 8 }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}

import AppKit
import SwiftUI

/// 窗口、点击穿透、拖拽、右键菜单与位置恢复。
@MainActor
final class PetPanelController {
    let settings: PetSettings
    let state: PetStateMachine
    private let panel: PetPanel
    private let hostingView: NSHostingView<PetSceneView>
    private let menuHost = PetMenuHost()

    var onOpenSettings: (() -> Void)?
    var onHide: (() -> Void)?

    private var hoverTimer: Timer?
    private var hovering = false
    private var dragging = false
    private var dragStartMouse: CGPoint = .zero
    private var dragStartOrigin: CGPoint = .zero
    private var currentScreenID: String?
    private var cachedPath: CGPath?
    private var cachedSkinID: String?
    private var cachedSize: PetSize?
    private var hoverStartedAt: TimeInterval?
    private var lastPetAt: TimeInterval = 0
    private var lastMousePoint: CGPoint = .zero
    private var hasMousePoint = false

    var isOpen: Bool { panel.isVisible }
    var window: NSWindow { panel }

    init(settings: PetSettings, state: PetStateMachine) {
        self.settings = settings
        self.state = state
        panel = PetPanel()
        hostingView = NSHostingView(rootView: PetSceneView(state: state))
        panel.contentView = hostingView
        hostingView.autoresizingMask = [.width, .height]
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
        configurePanel()
        configureActions()
        updateCollectionBehavior()
        restoreFrame()
    }

    func show() {
        if panel.frame.size != PetGeometry.windowSize(for: settings.size) {
            restoreFrame()
        }
        panel.ignoresMouseEvents = settings.clickThrough
        panel.orderFrontRegardless()
        startHoverTracking()
    }

    func hide() {
        stopHoverTracking()
        panel.orderOut(nil)
    }

    func shutdown() {
        stopHoverTracking()
        settings.saveCurrentPositionIfNeeded(frame: panel.frame)
        panel.orderOut(nil)
        panel.contentView = nil
        panel.close()
    }

    func refresh() {
        if panel.frame.size != PetGeometry.windowSize(for: settings.size) {
            resize(to: settings.size, animated: true)
        } else {
            updateCollectionBehavior()
            updateHitCache()
        }
        panel.ignoresMouseEvents = settings.clickThrough || !hovering
    }

    func resize(to size: PetSize, animated: Bool) {
        guard size != settings.size || panel.frame.size != PetGeometry.windowSize(for: size) else { return }
        let anchor = CGPoint(x: panel.frame.midX, y: panel.frame.minY)
        let screen = screen(containing: panel.frame)
        let target = PetGeometry.clamp(
            PetGeometry.frame(anchor: anchor, size: size),
            to: screen.visibleFrame
        )
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().setFrame(target, display: true)
            }
        } else {
            panel.setFrame(target, display: true)
        }
        updateHitCache()
        saveCurrentPosition()
    }

    func resetPosition() {
        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return }
        let anchor = PetGeometry.defaultAnchor(in: screen.visibleFrame, size: settings.size)
        let frame = PetGeometry.frame(anchor: anchor, size: settings.size)
        panel.setFrame(frame, display: true)
        settings.savePosition(
            PetGeometry.normalizedPosition(of: frame, in: screen.visibleFrame),
            for: PetGeometry.screenID(for: screen)
        )
        updateHitCache()
    }

    func handleScreenChange() {
        let frame = panel.frame
        guard !frame.isEmpty else { return }
        let screen = screen(containing: frame)
        let normalized = PetGeometry.normalizedPosition(of: frame, in: screen.visibleFrame)
        let newFrame = PetGeometry.frame(
            normalizedPosition: normalized,
            in: screen.visibleFrame,
            size: settings.size
        )
        panel.setFrame(newFrame, display: true)
        updateHitCache()
    }

    func normalizedMousePosition() -> CGPoint {
        let mouse = NSEvent.mouseLocation
        let visual = visualBounds
        guard visual.width > 0, visual.height > 0 else { return .zero }
        let frame = panel.frame
        return CGPoint(
            x: min(max((mouse.x - frame.midX) / (visual.width / 2), -1), 1),
            y: min(max((frame.midY - mouse.y) / (visual.height / 2), -1), 1)
        )
    }

    private func configurePanel() {
        panel.onLeftMouseDown = { [weak self] point in
            self?.handleMouseDown(point)
        }
        panel.onLeftMouseDragged = { [weak self] point in
            self?.handleMouseDragged(point)
        }
        panel.onLeftMouseUp = { [weak self] point in
            self?.handleMouseUp(point)
        }
        panel.onRightMouseDown = { [weak self] point in
            self?.handleRightMouseDown(point)
        }
        panel.onScroll = { [weak self] _ in
            self?.state.handleScroll()
            self?.state.tick()
        }
    }

    private func configureActions() {
        menuHost.actions["pet.settings"] = { [weak self] in self?.onOpenSettings?() }
        menuHost.actions["pet.pause"] = { [weak self] in
            guard let self else { return }
            self.settings.paused.toggle()
        }
        menuHost.actions["pet.lock"] = { [weak self] in self?.settings.locked.toggle() }
        menuHost.actions["pet.clickThrough"] = { [weak self] in
            guard let self else { return }
            self.settings.clickThrough.toggle()
            self.refresh()
        }
        for size in PetSize.allCases {
            menuHost.actions["pet.size.\(size.rawValue)"] = { [weak self] in
                guard let self else { return }
                self.settings.size = size
                self.state.size = size
                self.resize(to: size, animated: true)
            }
        }
        for skin in PetSkinCatalog.all {
            menuHost.actions["pet.skin.\(skin.id)"] = { [weak self] in
                guard let self else { return }
                self.settings.chooseSkin(skin.id)
                self.state.skin = skin
                self.state.keyboardTheme = skin.defaultKeyboardTheme
                self.updateHitCache()
            }
        }
        menuHost.actions["pet.resetPosition"] = { [weak self] in self?.resetPosition() }
        menuHost.actions["pet.hide"] = { [weak self] in self?.onHide?() }
    }

    private func restoreFrame() {
        let screen = screen(containing: panel.frame)
        let screenID = PetGeometry.screenID(for: screen)
        currentScreenID = screenID
        let frame: CGRect
        if let saved = settings.savedPosition(for: screenID) {
            frame = PetGeometry.frame(
                normalizedPosition: saved,
                in: screen.visibleFrame,
                size: settings.size
            )
        } else {
            let anchor = PetGeometry.defaultAnchor(in: screen.visibleFrame, size: settings.size)
            frame = PetGeometry.frame(anchor: anchor, size: settings.size)
        }
        panel.setFrame(frame, display: false)
        settings.savePosition(
            PetGeometry.normalizedPosition(of: frame, in: screen.visibleFrame),
            for: screenID
        )
        updateHitCache()
    }

    private func updateCollectionBehavior() {
        var behavior: NSWindow.CollectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        if settings.allowFullScreen {
            behavior.insert(.fullScreenAuxiliary)
        }
        panel.collectionBehavior = behavior
        panel.level = settings.allowFullScreen ? .statusBar : .floating
    }

    private func startHoverTracking() {
        guard hoverTimer == nil else { return }
        updateHitCache()
        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.updateHoverState()
            }
        }
        hoverTimer = timer
        RunLoop.main.add(timer, forMode: .common)
        updateHoverState()
    }

    private func stopHoverTracking() {
        hoverTimer?.invalidate()
        hoverTimer = nil
        hovering = false
    }

    private func updateHoverState() {
        guard panel.isVisible, !dragging else { return }
        if settings.clickThrough {
            panel.ignoresMouseEvents = true
            return
        }
        let mouse = NSEvent.mouseLocation
        if !hasMousePoint || hypot(mouse.x - lastMousePoint.x, mouse.y - lastMousePoint.y) > 1.5 {
            lastMousePoint = mouse
            hasMousePoint = true
            let normalized = normalizedMousePosition()
            state.handleMouseMoved(normalizedX: normalized.x, normalizedY: normalized.y)
        }
        let local = hostingView.convert(panel.convertPoint(fromScreen: mouse), from: nil)
        let visual = visualBounds
        guard let path = hitPath else {
            panel.ignoresMouseEvents = true
            return
        }
        let insideBase = path.contains(local)
        let insideExpanded = expandedPath(for: path).contains(local)
        if insideBase || (hovering && insideExpanded) {
            if !hovering {
                hoverStartedAt = ProcessInfo.processInfo.systemUptime
            }
            hovering = true
            panel.ignoresMouseEvents = false
            maybePetOnHover()
        } else {
            hovering = false
            hoverStartedAt = nil
            panel.ignoresMouseEvents = true
        }
    }

    private func maybePetOnHover() {
        guard settings.hoverPetting, !settings.paused else { return }
        let now = ProcessInfo.processInfo.systemUptime
        guard let start = hoverStartedAt, now - start > 1.4 else { return }
        guard now - lastPetAt > 1.8 else { return }
        lastPetAt = now
        state.hoverPet()
    }

    private var visualBounds: CGRect {
        hostingView.bounds.insetBy(dx: PetGeometry.windowPadding, dy: PetGeometry.windowPadding)
    }

    private var hitPath: CGPath? {
        if cachedSkinID != state.skin.id || cachedSize != state.size {
            updateHitCache()
        }
        return cachedPath
    }

    private func updateHitCache() {
        cachedSkinID = state.skin.id
        cachedSize = state.size
        cachedPath = PetGeometry.hitPath(for: state.skin, in: visualBounds)
    }

    private func expandedPath(for path: CGPath) -> CGPath {
        path.copy(strokingWithWidth: 8, lineCap: .round, lineJoin: .round, miterLimit: 8)
    }

    private func handleMouseDown(_ point: NSPoint) {
        guard !settings.clickThrough else { return }
        let local = hostingView.convert(point, from: nil)
        let part = PetGeometry.part(at: local, skin: state.skin, in: visualBounds)
        guard part != .transparent else { return }
        state.handleMouseDown(part: part)
        state.tick()
        guard !settings.locked else { return }
        dragging = true
        dragStartMouse = panel.convertPoint(toScreen: point)
        dragStartOrigin = panel.frame.origin
        state.setDragging(true)
        panel.ignoresMouseEvents = false
    }

    private func handleMouseDragged(_ point: NSPoint) {
        guard dragging else { return }
        let current = panel.convertPoint(toScreen: point)
        let delta = CGPoint(x: current.x - dragStartMouse.x, y: current.y - dragStartMouse.y)
        let candidate = CGRect(
            origin: CGPoint(x: dragStartOrigin.x + delta.x, y: dragStartOrigin.y + delta.y),
            size: panel.frame.size
        )
        let screen = screen(containing: candidate)
        let clamped = PetGeometry.clamp(candidate, to: screen.visibleFrame)
        panel.setFrameOrigin(clamped.origin)
        currentScreenID = PetGeometry.screenID(for: screen)
        updateHitCache()
    }

    private func handleMouseUp(_ point: NSPoint) {
        guard dragging else { return }
        dragging = false
        state.setDragging(false)
        state.tick()
        saveCurrentPosition()
    }

    private func handleRightMouseDown(_ point: NSPoint) {
        guard !settings.clickThrough else { return }
        let menu = menuHost.menu(settings: settings, state: state)
        let screenPoint = panel.convertPoint(toScreen: point)
        menu.popUp(positioning: nil, at: screenPoint, in: nil)
    }

    private func saveCurrentPosition() {
        let screen = screen(containing: panel.frame)
        currentScreenID = PetGeometry.screenID(for: screen)
        settings.savePosition(
            PetGeometry.normalizedPosition(of: panel.frame, in: screen.visibleFrame),
            for: currentScreenID ?? PetGeometry.screenID(for: screen)
        )
    }

    private func screen(containing frame: CGRect) -> NSScreen {
        if frame.isEmpty, let main = NSScreen.main {
            if let saved = currentScreenID,
               let match = NSScreen.screens.first(where: { PetGeometry.screenID(for: $0) == saved }) {
                return match
            }
            return main
        }
        let center = CGPoint(x: frame.midX, y: frame.midY)
        return NSScreen.screens.first(where: { $0.frame.contains(center) })
            ?? NSScreen.screens.max(by: { lhs, rhs in
                lhs.frame.intersection(frame).area < rhs.frame.intersection(frame).area
            })
            ?? NSScreen.main
            ?? NSScreen.screens[0]
    }
}

private extension CGRect {
    var area: CGFloat {
        isEmpty ? 0 : width * height
    }
}

private extension PetSettings {
    func saveCurrentPositionIfNeeded(frame: CGRect) {
        guard !frame.isEmpty else { return }
        let screen = NSScreen.screens.first(where: { $0.frame.contains(CGPoint(x: frame.midX, y: frame.midY)) })
            ?? NSScreen.main
        guard let screen else { return }
        savePosition(
            PetGeometry.normalizedPosition(of: frame, in: screen.visibleFrame),
            for: PetGeometry.screenID(for: screen)
        )
    }
}

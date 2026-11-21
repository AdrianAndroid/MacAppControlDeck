import AppKit

/// 透明、无边框、不抢焦点的浮层。
final class PetPanel: NSPanel {
    var onLeftMouseDown: ((NSPoint) -> Void)?
    var onLeftMouseDragged: ((NSPoint) -> Void)?
    var onLeftMouseUp: ((NSPoint) -> Void)?
    var onRightMouseDown: ((NSPoint) -> Void)?
    var onScroll: ((NSPoint) -> Void)?

    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .floating
        isMovable = false
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        animationBehavior = .none
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        ignoresMouseEvents = true
        acceptsMouseMovedEvents = true
        becomesKeyOnlyIfNeeded = true
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown:
            onLeftMouseDown?(event.locationInWindow)
        case .leftMouseDragged:
            onLeftMouseDragged?(event.locationInWindow)
        case .leftMouseUp:
            onLeftMouseUp?(event.locationInWindow)
        case .rightMouseDown:
            onRightMouseDown?(event.locationInWindow)
        case .scrollWheel:
            onScroll?(event.locationInWindow)
        default:
            super.sendEvent(event)
        }
    }
}

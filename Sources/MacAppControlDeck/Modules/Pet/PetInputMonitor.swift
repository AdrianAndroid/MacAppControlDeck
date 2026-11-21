import AppKit
import CoreGraphics

enum PetRawEvent {
    case keyDown(UInt16, isRepeat: Bool)
    case keyUp(UInt16)
    case flagsChanged(UInt16, isDown: Bool)
    case mouseMoved
    case scroll
}

/// 只读监听。不做键盘内容记录，不写日志。
final class PetInputMonitor {
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var lastMouseDispatch: TimeInterval = 0
    var onEvent: ((PetRawEvent) -> Void)?
    var onTapDisabled: (() -> Void)?

    var isRunning: Bool { tap != nil }

    func start() -> Bool {
        guard tap == nil else { return true }
        guard CGPreflightListenEventAccess() else { return false }
        let mask = Self.eventMask()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: petEventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }
        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        runLoopSource = nil
        tap = nil
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            onTapDisabled?()
        case .keyDown:
            let code = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
            let repeatFlag = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
            onEvent?(.keyDown(code, isRepeat: repeatFlag))
        case .keyUp:
            let code = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
            onEvent?(.keyUp(code))
        case .flagsChanged:
            let code = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
            let flags = event.flags
            let down: Bool
            switch code {
            case 56, 60: down = flags.contains(.maskShift)
            case 59, 62: down = flags.contains(.maskControl)
            case 58, 61: down = flags.contains(.maskAlternate)
            case 55, 54: down = flags.contains(.maskCommand)
            case 63: down = flags.contains(.maskSecondaryFn)
            default: down = false
            }
            onEvent?(.flagsChanged(code, isDown: down))
        case .mouseMoved:
            let now = ProcessInfo.processInfo.systemUptime
            guard now - lastMouseDispatch >= 1.0 / 30.0 else { return }
            lastMouseDispatch = now
            onEvent?(.mouseMoved)
        case .scrollWheel:
            onEvent?(.scroll)
        default:
            break
        }
    }

    private static func eventMask() -> CGEventMask {
        let types: [CGEventType] = [.keyDown, .keyUp, .flagsChanged, .mouseMoved, .scrollWheel]
        return types.reduce(CGEventMask(0)) { mask, type in
            mask | (CGEventMask(1) << CGEventMask(type.rawValue))
        }
    }
}

private func petEventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    if let userInfo {
        let monitor = Unmanaged<PetInputMonitor>.fromOpaque(userInfo).takeUnretainedValue()
        monitor.handle(type: type, event: event)
    }
    return Unmanaged.passUnretained(event)
}

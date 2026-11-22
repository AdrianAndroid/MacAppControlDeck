import AppKit
import Carbon
import Combine
import Foundation

/// 一个完整桌宠实例。窗口、输入、动画都随 runtime 释放。
@MainActor
final class PetRuntime {
    let settings: PetSettings
    let state: PetStateMachine
    private let clock: PetAnimationClock
    private let panel: PetPanelController
    private let input: PetInputMonitor
    private var cancellables = Set<AnyCancellable>()
    private var observers: [NSObjectProtocol] = []
    private var workspaceObservers: [NSObjectProtocol] = []
    private var distributedObservers: [NSObjectProtocol] = []
    private var lifecycleTimer: Timer?
    private var hasStarted = false
    private var permissionGranted = CGPreflightListenEventAccess()
    private var secureInputActive = false
    private var screenLocked = false
    private var captureActive = false

    var isOpen: Bool { panel.isOpen }
    var isInputActive: Bool { input.isRunning }
    var permissionReady: Bool { permissionGranted }
    var onHidden: (() -> Void)?

    init(settings: PetSettings = .shared) {
        self.settings = settings
        state = PetStateMachine(settings: settings)
        clock = PetAnimationClock(state: state)
        panel = PetPanelController(settings: settings, state: state)
        input = PetInputMonitor()
        panel.onOpenSettings = {
            MenuBarController.shared.openSettings(tab: .pet)
        }
        panel.onHide = { [weak self] in self?.hide() }
    }

    deinit {
        lifecycleTimer?.invalidate()
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
        for observer in workspaceObservers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        for observer in distributedObservers {
            DistributedNotificationCenter.default.removeObserver(observer)
        }
        input.stop()
    }

    func start() {
        guard !hasStarted else {
            updateVisibility()
            return
        }
        hasStarted = true
        clock.start()
        setupBindings()
        setupObservers()
        applySettings()
        updateInputState()
        updateVisibility()
    }

    func show() {
        settings.visible = true
        screenLocked = false
        updateVisibility()
        updateInputState()
    }

    func hide() {
        settings.visible = false
        updateVisibility()
        updateInputState()
        onHidden?()
    }

    func toggle() {
        if isOpen || settings.visible {
            hide()
        } else {
            show()
        }
    }

    func resetPosition() {
        panel.resetPosition()
    }

    func setSize(_ size: PetSize) {
        settings.size = size
        state.size = size
        panel.resize(to: size, animated: true)
        clock.kick()
    }

    func refresh() {
        applySettings()
    }

    func shutdown() {
        input.stop()
        PetLive2DBridge.shared.resetInput()
        clock.stop()
        panel.shutdown()
        settings.visible = false
        cancellables.removeAll()
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
        observers.removeAll()
        for observer in workspaceObservers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        workspaceObservers.removeAll()
        for observer in distributedObservers {
            DistributedNotificationCenter.default.removeObserver(observer)
        }
        distributedObservers.removeAll()
        lifecycleTimer?.invalidate()
        lifecycleTimer = nil
    }

    func requestPermission() {
        _ = CGRequestListenEventAccess()
        permissionGranted = CGPreflightListenEventAccess()
        openInputMonitoringSettings()
        updateInputState()
    }

    func openInputMonitoringSettings() {
        DeckState.shared.openInputMonitoringSettings()
    }

    private func setupBindings() {
        settings.objectWillChange
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.applySettings()
                }
            }
            .store(in: &cancellables)
    }

    private func setupObservers() {
        guard observers.isEmpty else { return }
        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.panel.handleScreenChange() }
        })
        observers.append(center.addObserver(
            forName: .captureRecordingDidStart,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.captureActive = true
                self.applySettings()
            }
        })
        observers.append(center.addObserver(
            forName: .captureRecordingDidStop,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.captureActive = false
                self.applySettings()
            }
        })

        let workspace = NSWorkspace.shared.notificationCenter
        workspaceObservers.append(workspace.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.applyAccessibilityOptions() }
        })
        workspaceObservers.append(workspace.addObserver(
            forName: NSWorkspace.screensDidSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.setScreenLocked(true) }
        })
        workspaceObservers.append(workspace.addObserver(
            forName: NSWorkspace.screensDidWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.setScreenLocked(false) }
        })
        workspaceObservers.append(workspace.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.setScreenLocked(true) }
        })
        workspaceObservers.append(workspace.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.setScreenLocked(false) }
        })

        let distributed = DistributedNotificationCenter.default()
        for name in ["com.apple.screenIsLocked", "com.apple.screenIsUnlocked"] {
            distributedObservers.append(distributed.addObserver(
                forName: Notification.Name(name),
                object: nil,
                queue: .main
            ) { [weak self] notification in
                let locked = notification.name.rawValue.hasSuffix("Locked")
                MainActor.assumeIsolated { self?.setScreenLocked(locked) }
            })
        }

        lifecycleTimer?.invalidate()
        let timer = Timer(timeInterval: 1.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.pollSystemState()
            }
        }
        lifecycleTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func pollSystemState() {
        let permission = CGPreflightListenEventAccess()
        if permission != permissionGranted {
            permissionGranted = permission
            updateInputState()
        }
        let secure = IsSecureEventInputEnabled()
        if secure != secureInputActive {
            secureInputActive = secure
            updateInputState()
        }
        clock.lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        applyAccessibilityOptions()
    }

    private func applyAccessibilityOptions() {
        state.reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    private func setScreenLocked(_ locked: Bool) {
        guard screenLocked != locked else { return }
        screenLocked = locked
        applySettings()
    }

    private func applySettings() {
        state.apply(settings: settings)
        panel.refresh()
        updateVisibility()
        updateInputState()
        clock.kick()
    }

    private func updateVisibility() {
        let shouldShow = settings.visible
            && !screenLocked
            && !(settings.hideDuringCapture && captureActive)
        if shouldShow {
            panel.show()
        } else {
            panel.hide()
        }
    }

    private func updateInputState() {
        let shouldRun = settings.visible
            && !settings.paused
            && !secureInputActive
            && !screenLocked
            && !(settings.hideDuringCapture && captureActive)
        guard shouldRun else {
            input.stop()
            PetLive2DBridge.shared.resetInput()
            return
        }
        permissionGranted = CGPreflightListenEventAccess()
        guard permissionGranted else {
            input.stop()
            PetLive2DBridge.shared.resetInput()
            return
        }
        guard !input.isRunning else { return }
        input.onEvent = { [weak self] event in
            MainActor.assumeIsolated {
                self?.handleRawEvent(event)
            }
        }
        input.onTapDisabled = { [weak self] in
            MainActor.assumeIsolated {
                PetLive2DBridge.shared.resetInput()
                self?.clock.kick()
            }
        }
        _ = input.start()
    }

    private func handleRawEvent(_ event: PetRawEvent) {
        guard settings.visible, !settings.paused else { return }
        PetLive2DBridge.shared.handleInput(event)
        clock.kick()
        switch event {
        case .keyDown(let code, let isRepeat):
            state.handleKeyDown(code, isRepeat: isRepeat)
        case .keyUp(let code):
            state.handleKeyUp(code)
        case .flagsChanged(let code, let isDown):
            if isDown {
                state.handleKeyDown(code)
            } else {
                state.handleKeyUp(code)
            }
        case .mouseMoved:
            guard settings.followMouse else { return }
            let normalized = panel.normalizedMousePosition()
            state.handleMouseMoved(normalizedX: normalized.x, normalizedY: normalized.y)
            state.tick()
        case .scroll:
            state.handleScroll()
            state.tick()
        case .mouseDown:
            state.handleClick(isDown: true)
            state.tick()
        case .mouseUp:
            break
        }
    }
}

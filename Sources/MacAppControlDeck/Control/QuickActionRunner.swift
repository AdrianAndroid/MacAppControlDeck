import AppKit
import Foundation

/// 菜单栏点击按钮时的执行器：与 HTTP 接口共用同一套底层能力，
/// 但用独立串行队列保证连续点击（比如连续切桌面）不互相打乱。
final class QuickActionRunner {
    static let shared = QuickActionRunner()

    private let queue = DispatchQueue(label: "deck.menubar.quickaction")
    private let injector = KeyInjector()
    private let activator = AppControl()

    /// completion 在主线程回调；nil 表示成功，非 nil 是给用户看的原因。
    func run(_ button: ButtonConfig, completion: @escaping (String?) -> Void) {
        switch button.kind {
        case .app:
            Task {
                let outcome = await activator.activate(bundleID: button.bundleID)
                let failure: String?
                switch outcome.status {
                case .activated, .launched, .sent:
                    failure = nil
                default:
                    failure = outcome.message
                }
                await MainActor.run { completion(failure) }
            }
        case .shortcut:
            guard let combo = button.shortcut else {
                completion("快捷操作配置不完整，请在设置里重新编辑")
                return
            }
            queue.sync {
                let result = injector.inject(combo)
                let failure = result.sent ? nil : result.message
                DispatchQueue.main.async { completion(failure) }
            }
        case .builtin:
            guard let action = button.builtinAction else {
                completion("内置操作配置不完整，请在设置里重新编辑")
                return
            }
            let result = BuiltinActions.run(action)
            completion(result.ok ? nil : result.message)
        case .command:
            guard !button.appPath.isEmpty else {
                completion("命令按钮配置不完整，请在设置里重新编辑")
                return
            }
            queue.sync {
                let result = CommandRunner.run(appPath: button.appPath,
                                               arguments: button.commandArguments ?? [])
                let failure = result.ok ? nil : result.message
                DispatchQueue.main.async { completion(failure) }
            }
        }
    }
}

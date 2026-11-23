import Foundation

/// 通知副屏“该刷新了”。页面用长轮询等待 revision 变化，避免设置后等 30 秒。
actor ScreenEventHub {
    static let shared = ScreenEventHub()

    private var revision = 0
    private var waiters: [UUID: CheckedContinuation<Int, Never>] = [:]

    func currentRevision() -> Int { revision }

    func wait(for since: Int, timeout: TimeInterval) async -> Int {
        if revision != since { return revision }
        let id = UUID()
        return await withCheckedContinuation { continuation in
            waiters[id] = continuation
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(max(timeout, 1) * 1_000_000_000))
                guard !Task.isCancelled else { return }
                await self?.expire(id)
            }
        }
    }

    func publish() {
        revision += 1
        let current = revision
        let pending = waiters
        waiters.removeAll()
        pending.values.forEach { $0.resume(returning: current) }
    }

    private func expire(_ id: UUID) {
        guard let continuation = waiters.removeValue(forKey: id) else { return }
        continuation.resume(returning: revision)
    }

    /// 可从任意线程调用：通知所有等待中的副屏页面。
    nonisolated static func notifyChange() {
        Task { await shared.publish() }
    }
}

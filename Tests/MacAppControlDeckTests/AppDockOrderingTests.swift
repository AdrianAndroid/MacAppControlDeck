import AppKit
import XCTest
@testable import MacAppControlDeck

@MainActor
final class AppDockOrderingTests: XCTestCase {
    private let base = Date(timeIntervalSince1970: 1_700_000_000)
    private var suite = ""
    private var defaults: UserDefaults!
    private var settings: PetDockSettings!
    private var stats: PetDockStats!

    private var apps: [ButtonConfig] {
        [
            ButtonConfig(id: "a", name: "A", bundleID: "com.a", sortOrder: 0),
            ButtonConfig(id: "b", name: "B", bundleID: "com.b", sortOrder: 1),
            ButtonConfig(id: "c", name: "C", bundleID: "com.c", sortOrder: 2)
        ]
    }

    override func setUp() {
        super.setUp()
        suite = "app-dock-ordering-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
        settings = PetDockSettings(defaults: defaults, notifiesCenter: false)
        stats = PetDockStats(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        defaults = nil
        settings = nil
        stats = nil
        super.tearDown()
    }

    private func makeOrdering(holdDuration: TimeInterval = 5) -> AppDockOrdering {
        let apps = self.apps
        let fixed = base
        return AppDockOrdering(settings: settings,
                               stats: stats,
                               appsProvider: { apps },
                               now: { fixed },
                               holdDuration: holdDuration)
    }

    private func ids(_ buttons: [ButtonConfig]) -> [String] { buttons.map(\.id) }

    func testManualKeepsConfiguredOrder() {
        settings.sortMode = .manual
        stats.record(bundleID: "com.c", at: base)
        let ordering = makeOrdering()
        XCTAssertEqual(ids(ordering.orderedApps(from: apps)), ["a", "b", "c"])
    }

    func testFrequencyPutsMostClickedFirst() {
        settings.sortMode = .frequency
        stats.record(bundleID: "com.c", at: base)
        stats.record(bundleID: "com.c", at: base.addingTimeInterval(60))
        let ordering = makeOrdering()
        XCTAssertEqual(ids(ordering.orderedApps(from: apps)).first, "c")
    }

    func testRecentUsesLastClick() {
        settings.sortMode = .recent
        stats.record(bundleID: "com.a", at: base)
        stats.record(bundleID: "com.c", at: base.addingTimeInterval(600))
        let ordering = makeOrdering()
        XCTAssertEqual(ids(ordering.orderedApps(from: apps)), ["c", "a", "b"])
    }

    func testTiesKeepConfiguredOrder() {
        settings.sortMode = .frequency
        let ordering = makeOrdering()
        XCTAssertEqual(ids(ordering.orderedApps(from: apps)), ["a", "b", "c"])
    }

    func testClickFreezesOrderUntilHoldExpires() async throws {
        settings.sortMode = .frequency
        let ordering = makeOrdering(holdDuration: 0.15)

        ordering.recordClick(bundleID: "com.c")
        XCTAssertTrue(ordering.isHoldingOrder)
        XCTAssertEqual(ids(ordering.orderedApps(from: apps)), ["a", "b", "c"])

        try await Task.sleep(nanoseconds: 400_000_000)

        XCTAssertFalse(ordering.isHoldingOrder)
        XCTAssertEqual(ids(ordering.orderedApps(from: apps)).first, "c")
        XCTAssertEqual(ordering.revision, 1)
    }

    func testNewAppAppendsWhileFrozen() {
        settings.sortMode = .frequency
        let ordering = makeOrdering()
        let original = apps
        ordering.recordClick(bundleID: "com.a")

        stats.record(bundleID: "com.d", at: base.addingTimeInterval(60))
        let extended = original + [ButtonConfig(id: "d", name: "D", bundleID: "com.d", sortOrder: 3)]
        XCTAssertEqual(ids(ordering.orderedApps(from: extended)), ["a", "b", "c", "d"])
    }

    func testDeletedAppDropsFromFrozenOrder() {
        settings.sortMode = .frequency
        let ordering = makeOrdering()
        ordering.recordClick(bundleID: "com.b")

        let remaining = [apps[0], apps[2]]
        XCTAssertEqual(ids(ordering.orderedApps(from: remaining)), ["a", "c"])
    }

    func testChangingModeClearsHoldImmediately() {
        settings.sortMode = .frequency
        let ordering = makeOrdering()
        ordering.recordClick(bundleID: "com.c")
        XCTAssertTrue(ordering.isHoldingOrder)

        settings.sortMode = .manual
        XCTAssertFalse(ordering.isHoldingOrder)
        XCTAssertEqual(ids(ordering.orderedApps(from: apps)), ["a", "b", "c"])
    }

    func testChangingHalfLifeResortsImmediately() {
        settings.sortMode = .frequency
        let ordering = makeOrdering()
        ordering.recordClick(bundleID: "com.c")
        XCTAssertTrue(ordering.isHoldingOrder)

        settings.halfLifeDays = 14
        XCTAssertFalse(ordering.isHoldingOrder)
    }
}

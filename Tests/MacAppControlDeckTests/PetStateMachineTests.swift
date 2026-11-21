import XCTest
@testable import MacAppControlDeck

@MainActor
final class PetStateMachineTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "pet-state-tests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    private func settings() -> PetSettings {
        PetSettings(defaults: defaults)
    }

    func testLeftKeyMovesLeftPawOnly() {
        let state = PetStateMachine(settings: settings())
        state.handleKeyDown(12) // Q
        XCTAssertGreaterThan(state.snapshot.pawLeft, 0.9)
        XCTAssertEqual(state.snapshot.pawRight, 0)
        XCTAssertTrue(state.snapshot.activeZones.contains(.left))

        state.handleKeyUp(12)
        state.tick()
        XCTAssertEqual(state.snapshot.pawLeft, 0)
    }

    func testSpaceMovesBothPaws() {
        let state = PetStateMachine(settings: settings())
        state.handleKeyDown(49)
        XCTAssertGreaterThan(state.snapshot.pawLeft, 0.9)
        XCTAssertGreaterThan(state.snapshot.pawRight, 0.9)
        XCTAssertTrue(state.snapshot.activeZones.contains(.center))
    }

    func testThreeDistinctKeysTriggerSurprise() {
        let state = PetStateMachine(settings: settings())
        state.handleKeyDown(12)
        state.handleKeyDown(13)
        state.handleKeyDown(14)
        state.tick()
        XCTAssertGreaterThan(state.snapshot.surprised, 0.9)
        XCTAssertGreaterThan(state.snapshot.mouthOpen, 0.4)
    }

    func testRepeatedKeyDoesNotCountAsSurprise() {
        let state = PetStateMachine(settings: settings())
        state.handleKeyDown(12)
        state.handleKeyDown(12, isRepeat: true)
        state.handleKeyDown(12, isRepeat: true)
        state.tick()
        XCTAssertEqual(state.snapshot.surprised, 0)
    }

    func testIdleSleepsAndMouseWakes() {
        var now: TimeInterval = 100
        let state = PetStateMachine(settings: settings(), now: { now })
        now += 6 * 60
        state.tick()
        XCTAssertGreaterThan(state.snapshot.sleeping, 0.9)

        state.handleMouseMoved(normalizedX: 0.2, normalizedY: -0.1)
        state.tick()
        XCTAssertEqual(state.snapshot.sleeping, 0)
    }
}

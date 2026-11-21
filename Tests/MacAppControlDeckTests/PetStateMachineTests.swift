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


    private func makeClockedState() -> (PetStateMachine, () -> TimeInterval, (Double) -> Void) {
        final class Clock { var value: TimeInterval = 100 }
        let clock = Clock()
        let state = PetStateMachine(settings: settings(), now: { clock.value })
        let advance = { (seconds: Double) in
            let frames = max(1, Int(seconds * 30))
            for _ in 0..<frames {
                clock.value += 1.0 / 30.0
                state.tick()
            }
        }
        return (state, { clock.value }, advance)
    }

    func testTypingLandsPawOnKeyAndLooksDown() {
        let (state, _, advance) = makeClockedState()
        state.handleKeyDown(12) // Q, 左半区
        advance(0.8)
        guard let q = PetKeyMap.center(for: 12) else { return XCTFail("missing Q") }
        XCTAssertEqual(state.snapshot.leftPawPoint.x, q.x - 3, accuracy: 3)
        XCTAssertEqual(state.snapshot.leftPawPoint.y, q.y - 1, accuracy: 3)
        XCTAssertGreaterThan(state.snapshot.eyeY, 0.25)
        XCTAssertGreaterThan(state.snapshot.squint, 0.3)
        XCTAssertEqual(state.snapshot.keycaps.count, 1)

        state.handleKeyUp(12)
        advance(1.2)
        XCTAssertLessThan(abs(state.snapshot.eyeY), 0.1)
    }

    func testMouseMovesLeftPawAndGaze() {
        let (state, _, advance) = makeClockedState()
        state.handleMouseMoved(normalizedX: 0.7, normalizedY: -0.5)
        advance(0.8)
        XCTAssertGreaterThan(state.snapshot.eyeX, 0.4)
        XCTAssertLessThan(state.snapshot.eyeY, -0.25)
        XCTAssertEqual(state.snapshot.leftPawPoint.x, PetRigLayout.mouseCenter.x + 9 + 4, accuracy: 3)
        XCTAssertEqual(state.snapshot.leftPawPoint.y, PetRigLayout.mouseCenter.y - 4 + 4, accuracy: 3)
        XCTAssertGreaterThan(state.snapshot.headYaw, 1)
    }

    func testKeycapsAreCappedAtSixAndUseDistinctSlots() {
        let (state, _, advance) = makeClockedState()
        for code: UInt16 in [12, 13, 14, 0, 1, 2, 3, 4, 5] {
            state.handleKeyDown(code)
            advance(0.05)
        }
        advance(0.05)
        XCTAssertLessThanOrEqual(state.snapshot.keycaps.count, 6)
        XCTAssertEqual(Set(state.snapshot.keycaps.map(\.slot)).count, state.snapshot.keycaps.count)
    }

    func testKeyboardLayoutMapsAllLogicalKeysInsideFrame() {
        for code in PetKeyMap.allCodes {
            guard let key = PetKeyMap.key(for: code), let center = PetKeyMap.center(for: code) else {
                return XCTFail("missing key \(code)")
            }
            let frame = PetKeyboardLayout.frame(row: key.row, column: key.column)
            XCTAssertEqual(center.x, frame.midX)
            XCTAssertEqual(center.y, frame.midY)
            XCTAssertGreaterThan(center.x, PetKeyboardLayout.origin.x)
            XCTAssertLessThan(center.x, PetKeyboardLayout.origin.x + PetKeyboardLayout.width)
            XCTAssertGreaterThan(center.y, PetKeyboardLayout.origin.y)
            XCTAssertLessThan(center.y, PetKeyboardLayout.origin.y + PetKeyboardLayout.height)
        }
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
        XCTAssertGreaterThan(state.snapshot.pawLeft, 0.8)
        XCTAssertGreaterThan(state.snapshot.pawRight, 0.8)
        XCTAssertTrue(state.snapshot.activeZones.contains(.center))
    }

    func testThreeDistinctKeysTriggerSurprise() {
        let state = PetStateMachine(settings: settings())
        state.handleKeyDown(12)
        state.handleKeyDown(13)
        state.handleKeyDown(14)
        state.tick()
        XCTAssertGreaterThan(state.snapshot.surprised, 0.9)
        XCTAssertGreaterThan(state.snapshot.mouthOpen, 0.35)
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

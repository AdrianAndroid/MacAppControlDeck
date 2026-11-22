import Foundation
import XCTest
@testable import MacAppControlDeck

/// 光栅桌宠共用状态机测试：不依赖任何一版桌宠图层资产。
final class PetRasterStateTests: XCTestCase {

    @MainActor
    func testIdleFrameHasNeutralExtras() {
        let frame = PetRasterFrame.idle
        XCTAssertEqual(frame.blink, 0)
        XCTAssertEqual(frame.pawL, 0)
        XCTAssertEqual(frame.pawR, 0)
        XCTAssertEqual(frame.pawMouse, 0)
        XCTAssertEqual(frame.tailDeg, 0)
        XCTAssertEqual(frame.earDeg, 0)
        XCTAssertEqual(frame.breath, 0)
    }

    @MainActor
    func testBlinkIsSharedByBothEyes() {
        var frame = PetRasterFrame.idle
        frame.blink = 0.7
        XCTAssertGreaterThan(frame.blink, 0.02)
    }

    @MainActor
    func testPawPressesFollowLeftRightZones() throws {
        let suite = "pet-raster-tests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        final class Clock { var value: TimeInterval = 200 }
        let clock = Clock()
        let state = PetStateMachine(settings: PetSettings(defaults: defaults), now: { clock.value })
        let leftKey = try XCTUnwrap((0..<200).compactMap { PetKeyMap.key(for: UInt16($0)) }
            .first { $0.zone == .left })
        state.handleKeyDown(leftKey.code)
        for _ in 0..<20 { clock.value += 1.0 / 30.0; state.tick() }
        XCTAssertGreaterThan(state.rasterFrame.pawL, 0.05)
        XCTAssertLessThan(state.rasterFrame.pawR, 0.05)
        state.handleKeyUp(leftKey.code)
    }

    @MainActor
    func testKeycapCarriesRealKeyPosition() throws {
        let suite = "pet-raster-tests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        final class Clock { var value: TimeInterval = 400 }
        let clock = Clock()
        let state = PetStateMachine(settings: PetSettings(defaults: defaults), now: { clock.value })
        let key = try XCTUnwrap(PetKeyMap.key(for: 40))
        state.handleKeyDown(key.code)
        clock.value += 0.1
        state.tick()
        let cap = try XCTUnwrap(state.rasterFrame.keycaps.first)
        XCTAssertEqual(cap.label, key.label)
        XCTAssertEqual(cap.row, key.row)
        XCTAssertEqual(cap.column, key.column)
        XCTAssertGreaterThan(cap.progress, 0)
    }

    @MainActor
    func testHeadYawStaysWithinSixDegrees() throws {
        let suite = "pet-raster-tests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        final class Clock { var value: TimeInterval = 300 }
        let clock = Clock()
        let state = PetStateMachine(settings: PetSettings(defaults: defaults), now: { clock.value })
        state.handleMouseMoved(normalizedX: 1, normalizedY: 0.5)
        for _ in 0..<90 { clock.value += 1.0 / 30.0; state.tick() }
        XCTAssertLessThanOrEqual(abs(state.rasterFrame.headYaw), 6.5)
    }
}

import XCTest
@testable import MacAppControlDeck

@MainActor
final class CalendarPreferencesTests: XCTestCase {
    func testFestivalDisplayDefaultsToCompact() {
        let suite = "calendar-preferences-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else { return XCTFail("defaults") }
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
        let preferences = CalendarPreferences(defaults: defaults)
        XCTAssertEqual(preferences.festivalDisplay, .compact)
    }

    func testFestivalDisplayPersists() {
        let suite = "calendar-preferences-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else { return XCTFail("defaults") }
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
        let preferences = CalendarPreferences(defaults: defaults)
        preferences.festivalDisplay = .full
        let reloaded = CalendarPreferences(defaults: defaults)
        XCTAssertEqual(reloaded.festivalDisplay, .full)
    }
}

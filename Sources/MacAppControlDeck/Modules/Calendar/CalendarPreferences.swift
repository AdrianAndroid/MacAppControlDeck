import Combine
import Foundation

/// 万年历偏好。默认非常驻，避免打开过的日历一直占用内存。
@MainActor
final class CalendarPreferences: ObservableObject {
    static let shared = CalendarPreferences()

    private enum Key {
        static let resident = "calendar.resident"
        static let weekStartsOnMonday = "calendar.weekStartsOnMonday"
    }

    private let defaults: UserDefaults

    @Published var resident: Bool {
        didSet { defaults.set(resident, forKey: Key.resident) }
    }

    @Published var weekStartsOnMonday: Bool {
        didSet { defaults.set(weekStartsOnMonday, forKey: Key.weekStartsOnMonday) }
    }

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        resident = defaults.object(forKey: Key.resident) as? Bool ?? false
        weekStartsOnMonday = defaults.object(forKey: Key.weekStartsOnMonday) as? Bool ?? true
    }
}

import Combine
import Foundation

enum CalendarFestivalDisplay: String, CaseIterable, Identifiable {
    case off
    case compact
    case full

    var id: String { rawValue }

    var title: String {
        switch self {
        case .off: return "关"
        case .compact: return "精简"
        case .full: return "全显示"
        }
    }
}

/// 万年历偏好。默认非常驻，避免打开过的日历一直占用内存。
@MainActor
final class CalendarPreferences: ObservableObject {
    static let shared = CalendarPreferences()

    private enum Key {
        static let resident = "calendar.resident"
        static let weekStartsOnMonday = "calendar.weekStartsOnMonday"
        static let festivalDisplay = "calendar.festivalDisplay"
    }

    private let defaults: UserDefaults

    @Published var resident: Bool {
        didSet { defaults.set(resident, forKey: Key.resident) }
    }

    @Published var weekStartsOnMonday: Bool {
        didSet { defaults.set(weekStartsOnMonday, forKey: Key.weekStartsOnMonday) }
    }

    @Published var festivalDisplay: CalendarFestivalDisplay {
        didSet { defaults.set(festivalDisplay.rawValue, forKey: Key.festivalDisplay) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        resident = defaults.object(forKey: Key.resident) as? Bool ?? false
        weekStartsOnMonday = defaults.object(forKey: Key.weekStartsOnMonday) as? Bool ?? true
        festivalDisplay = CalendarFestivalDisplay(
            rawValue: defaults.string(forKey: Key.festivalDisplay) ?? ""
        ) ?? .compact
    }
}

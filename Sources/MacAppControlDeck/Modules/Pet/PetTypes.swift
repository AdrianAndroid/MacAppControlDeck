import AppKit
import SwiftUI

enum PetSize: String, CaseIterable, Identifiable {
    case small
    case medium
    case large

    var id: String { rawValue }

    var label: String {
        switch self {
        case .small: return "小"
        case .medium: return "中"
        case .large: return "大"
        }
    }

    var scale: CGFloat {
        switch self {
        case .small: return 0.75
        case .medium: return 1.0
        case .large: return 1.35
        }
    }

    var detail: PetDetailLevel {
        switch self {
        case .small: return .compact
        case .medium: return .standard
        case .large: return .full
        }
    }
}

enum PetDetailLevel {
    case compact
    case standard
    case full

    var showsKeyLabels: Bool { self != .compact }
    var showsShadow: Bool { self != .compact }
    var whiskerCount: Int { self == .compact ? 2 : 3 }
}

enum PetKeyboardTheme: String, CaseIterable, Identifiable {
    case cream
    case dark
    case macaron

    var id: String { rawValue }

    var label: String {
        switch self {
        case .cream: return "奶油白"
        case .dark: return "深色"
        case .macaron: return "马卡龙"
        }
    }

    var body: PetColor {
        switch self {
        case .cream: return PetColor(hex: "FFFDF7")
        case .dark: return PetColor(hex: "34302C")
        case .macaron: return PetColor(hex: "FFF7F4")
        }
    }

    var keycap: PetColor {
        switch self {
        case .cream: return PetColor(hex: "F3EBDD")
        case .dark: return PetColor(hex: "4A443E")
        case .macaron: return PetColor(hex: "FFD7DE")
        }
    }

    var stroke: PetColor {
        switch self {
        case .cream: return PetColor(hex: "D8CBB8")
        case .dark: return PetColor(hex: "211E1B")
        case .macaron: return PetColor(hex: "D9BFC2")
        }
    }

    var highlight: PetColor {
        switch self {
        case .cream: return PetColor(hex: "F3B7B7")
        case .dark: return PetColor(hex: "86CC72")
        case .macaron: return PetColor(hex: "9ED9C8")
        }
    }
}

struct PetColor: Hashable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double

    init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    init(hex: String, alpha: Double = 1) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let value = UInt64(cleaned, radix: 16) ?? 0
        if cleaned.count == 6 {
            self.red = Double((value >> 16) & 0xFF) / 255
            self.green = Double((value >> 8) & 0xFF) / 255
            self.blue = Double(value & 0xFF) / 255
        } else {
            self.red = 0
            self.green = 0
            self.blue = 0
        }
        self.alpha = alpha
    }

    var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }

    var nsColor: NSColor {
        NSColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }

    func withAlpha(_ value: Double) -> PetColor {
        PetColor(red: red, green: green, blue: blue, alpha: value)
    }
}

struct PetPoint: Hashable {
    var x: CGFloat
    var y: CGFloat

    init(_ x: CGFloat, _ y: CGFloat) {
        self.x = x
        self.y = y
    }

    var cgPoint: CGPoint { CGPoint(x: x, y: y) }

    func scaled(to size: CGSize) -> CGPoint {
        CGPoint(x: x * size.width, y: y * size.height)
    }
}

struct PetSnapshot: Equatable {
    var pawLeft: CGFloat = 0
    var pawRight: CGFloat = 0
    var blink: CGFloat = 0
    var eyeX: CGFloat = 0
    var eyeY: CGFloat = 0
    var bodyBounce: CGFloat = 0
    var tailWag: CGFloat = 0
    var earTwitch: CGFloat = 0
    var surprised: CGFloat = 0
    var sleeping: CGFloat = 0
    var mouthOpen: CGFloat = 0
    var blush: CGFloat = 0
    var dragging: CGFloat = 0
    var activeZones: Set<PetKeyZone> = []

    static let idle = PetSnapshot()
}

enum PetKeyZone: String, CaseIterable, Hashable {
    case left
    case right
    case center
    case function
    case none

    static var interactive: [PetKeyZone] {
        [.left, .right, .center, .function]
    }

    var label: String {
        switch self {
        case .left: return "左区"
        case .right: return "右区"
        case .center: return "中间"
        case .function: return "功能键"
        case .none: return ""
        }
    }
}

enum PetPart: Equatable {
    case body
    case head
    case leftPaw
    case rightPaw
    case keyboard
    case transparent
}

enum PetPauseReason: String, CaseIterable, Hashable {
    case user
    case secureInput
    case screenLocked
    case screenAsleep
    case permission
    case capture
}

struct PetRenderConfiguration: Equatable {
    var skinID: String
    var keyboardTheme: PetKeyboardTheme
    var size: PetSize
}

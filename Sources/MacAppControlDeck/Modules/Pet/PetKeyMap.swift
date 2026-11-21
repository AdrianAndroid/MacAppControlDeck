import Carbon.HIToolbox
import Foundation

struct PetKeyInfo: Equatable {
    let code: UInt16
    let label: String
    let row: Int
    let column: Int
    let isModifier: Bool

    var zone: PetKeyZone {
        if label == "space" { return .center }
        if label == "esc" || label == "fn" { return .function }
        return column < 7 ? .left : .right
    }
}

enum PetKeyboardLayout {
    /// 视觉网格按参考视频做成高窄键帽：20 列 × 4 行。
    /// 逻辑键位仍是 14×4，`frame(row:column:)` 会映射到视觉网格上。
    static let origin = CGPoint(x: 34, y: 262)
    static let keySize = CGSize(width: 9.9, height: 20.0)
    static let gap: CGFloat = 0.65
    static let columnCount = 20
    static let rowCount = 4
    static let logicalColumnCount = 14
    static let logicalRowCount = 4

    static let rowLabels: [[String]] = [
        ["esc", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "=", "⌫"],
        ["⇥", "Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P", "[", "]", "\\"],
        ["⇪", "A", "S", "D", "F", "G", "H", "J", "K", "L", ";", "'", "⏎", ""],
        ["⇧", "Z", "X", "C", "V", "B", "N", "M", ",", ".", "/", "⇧", "fn", "⌘"]
    ]

    static var width: CGFloat {
        CGFloat(columnCount) * keySize.width + CGFloat(columnCount - 1) * gap
    }

    static var height: CGFloat {
        CGFloat(rowCount) * keySize.height + CGFloat(rowCount - 1) * gap
    }

    static func frame(row: Int, column: Int) -> CGRect {
        let visualRow = Int((CGFloat(row) / CGFloat(logicalRowCount - 1) * CGFloat(rowCount - 1)).rounded())
        let visualColumn = Int((CGFloat(column) / CGFloat(logicalColumnCount - 1) * CGFloat(columnCount - 1)).rounded())
        return visualFrame(row: visualRow, column: visualColumn)
    }

    static func visualFrame(row: Int, column: Int) -> CGRect {
        CGRect(
            x: origin.x + CGFloat(column) * (keySize.width + gap),
            y: origin.y + CGFloat(row) * (keySize.height + gap),
            width: keySize.width,
            height: keySize.height
        )
    }

    static func center(row: Int, column: Int) -> PetPoint {
        let rect = frame(row: row, column: column)
        return PetPoint(rect.midX, rect.midY)
    }

    static func label(row: Int, column: Int) -> String {
        guard row >= 0, row < rowLabels.count else { return "" }
        let rowLabels = rowLabels[row]
        guard column >= 0, column < rowLabels.count else { return "" }
        return rowLabels[column]
    }
}

enum PetKeyMap {
    private struct LayoutKey {
        let row: Int
        let column: Int
        let label: String
        let modifier: Bool
    }

    private static let layout: [UInt16: LayoutKey] = [
        // 数字行
        18: .init(row: 0, column: 1, label: "1", modifier: false),
        19: .init(row: 0, column: 2, label: "2", modifier: false),
        20: .init(row: 0, column: 3, label: "3", modifier: false),
        21: .init(row: 0, column: 4, label: "4", modifier: false),
        23: .init(row: 0, column: 5, label: "5", modifier: false),
        22: .init(row: 0, column: 6, label: "6", modifier: false),
        26: .init(row: 0, column: 7, label: "7", modifier: false),
        28: .init(row: 0, column: 8, label: "8", modifier: false),
        25: .init(row: 0, column: 9, label: "9", modifier: false),
        29: .init(row: 0, column: 10, label: "0", modifier: false),
        27: .init(row: 0, column: 11, label: "-", modifier: false),
        24: .init(row: 0, column: 12, label: "=", modifier: false),
        51: .init(row: 0, column: 13, label: "⌫", modifier: false),
        53: .init(row: 0, column: 0, label: "esc", modifier: false),
        // 字母上排
        12: .init(row: 1, column: 1, label: "Q", modifier: false),
        13: .init(row: 1, column: 2, label: "W", modifier: false),
        14: .init(row: 1, column: 3, label: "E", modifier: false),
        15: .init(row: 1, column: 4, label: "R", modifier: false),
        17: .init(row: 1, column: 5, label: "T", modifier: false),
        16: .init(row: 1, column: 6, label: "Y", modifier: false),
        32: .init(row: 1, column: 7, label: "U", modifier: false),
        34: .init(row: 1, column: 8, label: "I", modifier: false),
        31: .init(row: 1, column: 9, label: "O", modifier: false),
        35: .init(row: 1, column: 10, label: "P", modifier: false),
        30: .init(row: 1, column: 11, label: "]", modifier: false),
        33: .init(row: 1, column: 12, label: "[", modifier: false),
        42: .init(row: 1, column: 13, label: "\\", modifier: false),
        48: .init(row: 1, column: 0, label: "⇥", modifier: false),
        // 字母中排
        0: .init(row: 2, column: 1, label: "A", modifier: false),
        1: .init(row: 2, column: 2, label: "S", modifier: false),
        2: .init(row: 2, column: 3, label: "D", modifier: false),
        3: .init(row: 2, column: 4, label: "F", modifier: false),
        5: .init(row: 2, column: 5, label: "G", modifier: false),
        4: .init(row: 2, column: 6, label: "H", modifier: false),
        38: .init(row: 2, column: 7, label: "J", modifier: false),
        40: .init(row: 2, column: 8, label: "K", modifier: false),
        37: .init(row: 2, column: 9, label: "L", modifier: false),
        41: .init(row: 2, column: 10, label: ";", modifier: false),
        39: .init(row: 2, column: 11, label: "'", modifier: false),
        36: .init(row: 2, column: 12, label: "⏎", modifier: false),
        57: .init(row: 2, column: 0, label: "⇪", modifier: true),
        // 字母下排与修饰键
        6: .init(row: 3, column: 1, label: "Z", modifier: false),
        7: .init(row: 3, column: 2, label: "X", modifier: false),
        8: .init(row: 3, column: 3, label: "C", modifier: false),
        9: .init(row: 3, column: 4, label: "V", modifier: false),
        11: .init(row: 3, column: 5, label: "B", modifier: false),
        45: .init(row: 3, column: 6, label: "N", modifier: false),
        46: .init(row: 3, column: 7, label: "M", modifier: false),
        43: .init(row: 3, column: 8, label: ",", modifier: false),
        47: .init(row: 3, column: 9, label: ".", modifier: false),
        44: .init(row: 3, column: 10, label: "/", modifier: false),
        56: .init(row: 3, column: 0, label: "⇧", modifier: true),
        60: .init(row: 3, column: 11, label: "⇧", modifier: true),
        63: .init(row: 3, column: 12, label: "fn", modifier: true),
        55: .init(row: 3, column: 13, label: "⌘", modifier: true),
        54: .init(row: 3, column: 13, label: "⌘", modifier: true),
        58: .init(row: 3, column: 12, label: "⌥", modifier: true),
        61: .init(row: 3, column: 12, label: "⌥", modifier: true),
        59: .init(row: 3, column: 0, label: "⌃", modifier: true),
        62: .init(row: 2, column: 12, label: "⌃", modifier: true),
        49: .init(row: 3, column: 6, label: "space", modifier: false),
        123: .init(row: 3, column: 11, label: "←", modifier: false),
        124: .init(row: 3, column: 12, label: "→", modifier: false),
        125: .init(row: 3, column: 13, label: "↓", modifier: false),
        126: .init(row: 3, column: 12, label: "↑", modifier: false)
    ]

    static var allCodes: [UInt16] { Array(layout.keys) }

    static func key(for code: UInt16) -> PetKeyInfo? {
        guard let key = layout[code] else { return nil }
        return PetKeyInfo(
            code: code,
            label: key.label,
            row: key.row,
            column: key.column,
            isModifier: key.modifier
        )
    }

    static func zone(for code: UInt16) -> PetKeyZone {
        key(for: code)?.zone ?? .function
    }

    static func center(for code: UInt16) -> PetPoint? {
        guard let key = key(for: code) else { return nil }
        return PetKeyboardLayout.center(row: key.row, column: key.column)
    }
}

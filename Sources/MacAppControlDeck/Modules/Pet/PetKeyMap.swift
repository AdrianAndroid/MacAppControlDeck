import Carbon.HIToolbox
import Foundation

/// 物理键码到键盘区域。只关心位置，不关心字符。
enum PetKeyMap {
    private static let leftKeys: Set<UInt16> = [
        12, 13, 14, 15, 17, 0, 1, 2, 3, 5, 6, 7, 8, 9, 11,
        18, 19, 20, 21, 23,
        56, 59, 58, 55
    ]

    private static let rightKeys: Set<UInt16> = [
        16, 32, 34, 31, 35, 4, 38, 40, 37, 45, 46, 43, 47, 44,
        22, 26, 28, 25, 29, 27, 24, 33, 30, 39, 41, 42,
        60, 62, 61, 54,
        123, 124, 125, 126,
        115, 116, 119, 121
    ]

    private static let centerKeys: Set<UInt16> = [49, 36, 76]
    private static let functionKeys: Set<UInt16> = [53, 48, 57, 51, 117, 63, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111]

    static func zone(for keyCode: UInt16) -> PetKeyZone {
        if leftKeys.contains(keyCode) { return .left }
        if rightKeys.contains(keyCode) { return .right }
        if centerKeys.contains(keyCode) { return .center }
        if functionKeys.contains(keyCode) { return .function }
        return .none
    }
}

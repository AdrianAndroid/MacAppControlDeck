import Foundation

/// 文件名边界：过滤路径分隔符与控制字符，并按 UTF-8 字节上限截断。
enum FilenameSanitizer {
    static func sanitize(_ value: String, maximumBytes: Int = 200) -> String {
        guard maximumBytes > 0 else { return "" }
        var cleaned = ""
        for scalar in value.unicodeScalars {
            switch scalar {
            case "/", ":", "|", "\0": cleaned.append("-")
            default:
                guard scalar.value >= 0x20, !(0x7F...0x9F).contains(scalar.value) else { continue }
                cleaned.unicodeScalars.append(scalar)
            }
        }
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        var result = ""
        var bytes = 0
        for character in cleaned {
            let length = String(character).utf8.count
            guard length <= maximumBytes - bytes else { break }
            result.append(character)
            bytes += length
        }
        while let last = result.last, last == "." || last.isWhitespace { result.removeLast() }
        return result
    }
}

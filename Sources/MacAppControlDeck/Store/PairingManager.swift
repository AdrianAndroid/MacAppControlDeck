import Foundation
import Security

final class PairingManager {
    static let codeLifetime: TimeInterval = 120
    static let maxAttempts = 3

    private let queue = DispatchQueue(label: "deck.pairing")
    private(set) var activeCode: String?
    private(set) var expiresAt: Date?
    private(set) var failedAttempts = 0

    func newCode() -> String {
        queue.sync {
            let code = String(format: "%06d", Int.random(in: 0...999_999))
            activeCode = code
            expiresAt = Date().addingTimeInterval(Self.codeLifetime)
            failedAttempts = 0
            return code
        }
    }

    enum RedeemResult {
        case ok
        case wrongCode
        case expired
        case locked
        case noActiveCode
    }

    func redeem(_ code: String) -> RedeemResult {
        queue.sync {
            guard let current = activeCode, let expiry = expiresAt else { return .noActiveCode }
            guard Date() < expiry else {
                invalidate()
                return .expired
            }
            guard failedAttempts < Self.maxAttempts else { return .locked }
            guard code == current else {
                failedAttempts += 1
                return .wrongCode
            }
            invalidate()
            return .ok
        }
    }

    func invalidate() {
        activeCode = nil
        expiresAt = nil
        failedAttempts = 0
    }

    static func generateToken() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return bytes.map { String(format: "%02x", $0) }.joined()
    }
}

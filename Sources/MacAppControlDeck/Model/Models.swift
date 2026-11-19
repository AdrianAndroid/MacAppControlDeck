import Foundation

struct ButtonConfig: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var bundleID: String
    var appPath: String
    var sortOrder: Int
}

struct DeviceRecord: Codable, Identifiable, Equatable {
    var token: String
    var name: String
    var pairedAt: Date

    var id: String { token }
}

struct InstalledApp: Identifiable, Equatable {
    var name: String
    var bundleID: String
    var path: String

    var id: String { bundleID }
}

enum ActivateStatus: String, Codable {
    case launched
    case activated
    case unconfirmed
    case appNotFound = "app-not-found"
    case activationFailed = "activation-failed"
    case buttonNotFound = "button-not-found"
}

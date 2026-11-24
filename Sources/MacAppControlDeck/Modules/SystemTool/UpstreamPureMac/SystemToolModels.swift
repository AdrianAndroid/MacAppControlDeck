// PureMac — https://github.com/momenbasel/PureMac
// MIT License — Copyright (c) 2026 PureMac Contributors
// 移植自 Models/Models.swift，保留原版权声明。
// 适配：只保留 CleaningCategory / CleanableItem / CategoryResult / DiskInfo，
// 移除 ScanState / ScheduleInterval / ScheduleConfig（调度与全应用状态耦合），
// CleanableItem 去掉虚拟项(simctl/docker/language/universal)相关字段。

import SwiftUI

// MARK: - Cleaning Category

enum CleaningCategory: String, CaseIterable, Identifiable, Codable {
    case systemJunk = "System Junk"
    case userCache = "User Cache"
    case trashBins = "Trash Bins"
    case largeFiles = "Large & Old Files"
    case xcodeJunk = "Xcode Junk"
    case brewCache = "Brew Cache"
    case nodeCache = "Node Cache"
    case devToolCaches = "Dev Tool Caches"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .systemJunk: return "gearshape.fill"
        case .userCache: return "internaldrive.fill"
        case .trashBins: return "trash.fill"
        case .largeFiles: return "doc.fill"
        case .xcodeJunk: return "hammer.fill"
        case .brewCache: return "mug.fill"
        case .nodeCache: return "leaf.fill"
        case .devToolCaches: return "wrench.and.screwdriver.fill"
        }
    }

    var description: String {
        switch self {
        case .systemJunk: return "System caches, logs, and temporary files"
        case .userCache: return "Application caches and browser data"
        case .trashBins: return "Files in your Trash"
        case .largeFiles: return "Files over 100 MB or older than 1 year"
        case .xcodeJunk: return "Derived data, archives, and simulator runtimes"
        case .brewCache: return "Homebrew download cache"
        case .nodeCache: return "npm, yarn, and pnpm download caches"
        case .devToolCaches: return "Package, build, and download caches of developer tools"
        }
    }

    var color: Color {
        switch self {
        case .systemJunk: return .purple
        case .userCache: return .blue
        case .trashBins: return .red
        case .largeFiles: return .yellow
        case .xcodeJunk: return .cyan
        case .brewCache: return .mint
        case .nodeCache: return .pink
        case .devToolCaches: return .green
        }
    }

    static var scannable: [CleaningCategory] { allCases }
}

// MARK: - Cleanable Item

struct CleanableItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let path: String
    let size: Int64
    let category: CleaningCategory
    var isSelected: Bool
    let lastModified: Date?
    /// 需手动勾选的行（不可批量选中）。适配后保留字段，供大文件/需谨慎项使用。
    var selectOnlyByHand: Bool = false

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: CleanableItem, rhs: CleanableItem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Category Result

struct CategoryResult: Identifiable {
    let id = UUID()
    let category: CleaningCategory
    var items: [CleanableItem]
    var totalSize: Int64

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }

    var itemCount: Int { items.count }
}

// MARK: - Disk Info

struct DiskInfo {
    var totalSpace: Int64 = 0
    var freeSpace: Int64 = 0
    var usedSpace: Int64 = 0
    var purgeableSpace: Int64 = 0

    var usedPercentage: Double {
        guard totalSpace > 0 else { return 0 }
        return Double(usedSpace) / Double(totalSpace)
    }

    var freePercentage: Double {
        guard totalSpace > 0 else { return 0 }
        return Double(freeSpace) / Double(totalSpace)
    }

    var formattedTotal: String {
        ByteCountFormatter.string(fromByteCount: totalSpace, countStyle: .file)
    }

    var formattedFree: String {
        ByteCountFormatter.string(fromByteCount: freeSpace, countStyle: .file)
    }

    var formattedUsed: String {
        ByteCountFormatter.string(fromByteCount: usedSpace, countStyle: .file)
    }

    var formattedPurgeable: String {
        ByteCountFormatter.string(fromByteCount: purgeableSpace, countStyle: .file)
    }
}

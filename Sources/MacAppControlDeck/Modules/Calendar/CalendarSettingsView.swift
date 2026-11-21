import SwiftUI

struct CalendarSettingsView: View {
    @ObservedObject private var preferences = CalendarPreferences.shared
    @ObservedObject private var registry = ModuleRegistry.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                statusCard
                memoryCard
                displayCard
                privacyCard
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var statusCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Circle()
                        .fill(registry.isEnabled(CalendarModule.id) ? Color.green : Color.orange)
                        .frame(width: 9, height: 9)
                    Text(registry.isEnabled(CalendarModule.id) ? "万年历已启用" : "万年历已关闭")
                        .font(.headline)
                    Spacer()
                    Button("打开万年历") {
                        CalendarModule.shared.open()
                    }
                    .buttonStyle(.borderedProminent)
                }
                Text("农历、节气、节日、宜忌与法定节假日；纯本地计算，不联网、不读取系统日历。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(6)
        } label: {
            Label("万年历", systemImage: "calendar")
        }
    }

    private var memoryCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                Toggle("常驻内存", isOn: Binding(
                    get: { preferences.resident },
                    set: { CalendarModule.shared.setResident($0) }
                ))
                .toggleStyle(.switch)

                Text(preferences.resident
                     ? "开启后，关闭日历窗口仍保留历法数据与窗口控制器，再次打开更快。"
                     : "关闭时释放日历窗口、ViewStore 与月历数据；下次打开重新加载。")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Circle()
                        .fill(CalendarModule.shared.isRuntimeLoaded ? Color.green : Color.secondary.opacity(0.35))
                        .frame(width: 8, height: 8)
                    Text(CalendarModule.shared.isRuntimeLoaded ? "当前日历数据已加载" : "当前日历数据未加载")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
            .padding(6)
        } label: {
            Label("内存", systemImage: "memorychip")
        }
    }

    private var displayCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                Toggle("周一作为一周开始", isOn: $preferences.weekStartsOnMonday)
                    .toggleStyle(.switch)
                Text("默认按中文日历习惯周一开头；关闭后改为周日开头。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(6)
        } label: {
            Label("显示", systemImage: "rectangle.grid.3x2")
        }
    }

    private var privacyCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Label("不联网", systemImage: "wifi.slash")
                Label("不读取系统日历与提醒", systemImage: "calendar.badge.minus")
                Label("不申请定位、通讯录、相册权限", systemImage: "hand.raised")
                Text("节假日数据来自 LunarSwift 内置表，按年份由上游维护。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .font(.callout)
            .padding(6)
        } label: {
            Label("隐私", systemImage: "lock.shield")
        }
    }
}

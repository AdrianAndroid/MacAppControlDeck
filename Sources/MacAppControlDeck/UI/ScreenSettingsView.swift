import AppKit
import SwiftUI

struct ScreenSettingsView: View {
    @ObservedObject private var state = DeckState.shared
    @ObservedObject private var weather = WeatherSettings.shared

    @State private var publicKeyPEM = ""
    @State private var copiedKey = false
    @State private var showRegenerateConfirm = false
    @State private var searchQuery = ""
    @State private var cities: [WeatherCity] = []
    @State private var searching = false
    @State private var searchError: String?
    @State private var testing = false
    @State private var testMessage: String?
    @State private var testPassed: Bool?
    @State private var apiKeyDraft = ""
    @State private var hasStoredAPIKey = false
    @State private var keyError: String?
    @State private var locating = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("副屏是只读页面：另一台手机打开地址即可看时钟、月历与天气，不需要配对。")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                addressCard
                weatherCard
                notesCard
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear { loadStoredState() }
        .onChange(of: weather.host) { _, _ in invalidateCache() }
        .onChange(of: weather.authMode) { _, _ in invalidateCache() }
        .onChange(of: weather.issuer) { _, _ in invalidateCache() }
        .onChange(of: weather.projectID) { _, _ in invalidateCache() }
        .onChange(of: weather.keyID) { _, _ in invalidateCache() }
        .alert("重新生成密钥对？", isPresented: $showRegenerateConfirm) {
            Button("取消", role: .cancel) {}
            Button("重新生成", role: .destructive) { regenerateKey() }
        } message: {
            Text("旧公钥会立即失效，需要到和风控制台重新上传新公钥。")
        }
    }

    // MARK: - 地址

    private var addressCard: some View {
        GroupBox {
            HStack {
                Text(state.screenURL?.absoluteString ?? "未获取到局域网地址")
                    .font(.system(size: 13, design: .monospaced))
                    .textSelection(.enabled)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 8)
                Button("复制") { state.copyScreenURL() }
                    .disabled(state.screenURL == nil)
                Button("打开") { state.openScreenInBrowser() }
                    .disabled(state.screenURL == nil)
            }
            .padding(4)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label("副屏地址", systemImage: "rectangle.on.rectangle")
        }
    }

    // MARK: - 天气

    private var weatherCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 14) {
                Toggle("在副屏显示天气", isOn: $weather.enabled)
                    .toggleStyle(.switch)
                Text("未配置时副屏只显示时钟与月历，不会出网。天气由 Mac 请求后转给副屏，手机拿不到凭据与坐标。")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Divider()
                stepHeader("1", "填写和风凭据")
                Text("在[和风控制台](https://console.qweather.com/)「设置」里复制 **专属 API Host**；文档里的示例 Host 不能直接用。")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                    GridRow {
                        Text("API Host").gridColumnAlignment(.trailing)
                        TextField("xxxx.qweatherapi.com", text: $weather.host)
                            .textFieldStyle(.roundedBorder)
                    }
                    if weather.authMode == .jwt {
                        GridRow {
                            Text("开发者 ID（iss）").gridColumnAlignment(.trailing)
                            TextField("Q 开头的 10 位字符", text: $weather.issuer)
                                .textFieldStyle(.roundedBorder)
                        }
                        GridRow {
                            Text("项目 ID（sub）").gridColumnAlignment(.trailing)
                            TextField("项目 ID", text: $weather.projectID)
                                .textFieldStyle(.roundedBorder)
                        }
                        GridRow {
                            Text("凭据 ID（kid）").gridColumnAlignment(.trailing)
                            TextField("凭据 ID", text: $weather.keyID)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                }
                .frame(maxWidth: 520, alignment: .leading)

                if let hostError = weather.config.hostValidationMessage {
                    Text(hostError)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                if weather.authMode == .apiKey {
                    apiKeySection
                    Button("需要长期稳定？改用 JWT 认证…") { weather.authMode = .jwt }
                        .buttonStyle(.link)
                        .font(.caption)
                } else {
                    jwtSection
                    Button("改回 API Key") { weather.authMode = .apiKey }
                        .buttonStyle(.link)
                        .font(.caption)
                }

                Divider()
                stepHeader("2", "选择城市")
                if !weather.cityName.isEmpty {
                    Label("已选择：\(weather.cityName)", systemImage: "checkmark.circle.fill")
                        .font(.callout)
                        .foregroundStyle(.green)
                }

                HStack(spacing: 8) {
                    TextField("搜索城市，例如 北京 / 上海 / 杭州", text: $searchQuery)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { searchCities() }
                    Button(searching ? "搜索中…" : "搜索") { searchCities() }
                        .disabled(searching || searchQuery.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .frame(maxWidth: 520)

                HStack(spacing: 8) {
                    Button(locating ? "定位中…" : "使用当前位置") { locateCity() }
                        .disabled(locating || !credentialsReady)
                        .help("使用 Mac 定位服务自动选择城市；失败时仍可手动搜索")
                    if locating {
                        ProgressView().controlSize(.small)
                    }
                    Spacer()
                }

                if let searchError {
                    Text(searchError)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                if !cities.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(cities) { city in
                            Button {
                                weather.select(city: city)
                                cities = []
                                searchError = nil
                                invalidateCache()
                                ScreenEventHub.notifyChange()
                                if credentialsReady { testConnection() }
                            } label: {
                                HStack {
                                    Text(city.displayName)
                                    Spacer()
                                    Text(String(format: "%.2f, %.2f", city.latitude, city.longitude))
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 6)
                            .background(Color.secondary.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                        }
                    }
                    .frame(maxWidth: 520)
                }

                Divider()
                stepHeader("3", "测试并显示")
                HStack(spacing: 10) {
                    Button(testing ? "测试中…" : "测试连接") { testConnection() }
                        .disabled(testing || !credentialsReady || weather.latitude == nil)
                    if let testMessage {
                        Label(testMessage,
                              systemImage: testPassed == true ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(testPassed == true ? Color.green : Color.orange)
                            .textSelection(.enabled)
                    }
                    Spacer()
                    Link("打开和风控制台", destination: URL(string: "https://console.qweather.com/")!)
                }
                if !credentialsReady || weather.latitude == nil {
                    Text("填好 API Host 与凭据、选择城市后即可测试；测试成功会自动打开天气开关。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(4)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label("天气", systemImage: "cloud.sun")
        }
    }

    private var apiKeySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                SecureField(hasStoredAPIKey ? "已保存（不回显），粘贴新 Key 可替换" : "粘贴和风 API Key",
                            text: $apiKeyDraft)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { saveAPIKey() }
                    .frame(maxWidth: 420)
                Button("保存") { saveAPIKey() }
                    .disabled(apiKeyDraft.trimmingCharacters(in: .whitespaces).isEmpty)
                if hasStoredAPIKey {
                    Button("清除", role: .destructive) { clearAPIKey() }
                }
                Spacer()
            }
            Text(hasStoredAPIKey ? "已保存到本机凭据文件（仅当前用户可读，0600）。" : "Key 保存到本机 0600 凭据文件，不再使用钥匙串。")
                .font(.caption)
                .foregroundStyle(hasStoredAPIKey ? Color.green : Color.secondary)
            if !hasStoredAPIKey {
                Text("从旧版本升级后需要重新粘贴一次 Key；之后只读本机文件，不再弹钥匙串。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let keyError {
                Text(keyError)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    private var jwtSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("在控制台「项目管理 → 添加凭据 → JWT」上传下方公钥，再填好 iss / sub / kid。重新生成密钥对会让旧公钥立即失效。")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                if QWeatherAuth.hasPrivateKey() {
                    Button("重新生成密钥对…") { showRegenerateConfirm = true }
                } else {
                    Button("生成密钥对") { regenerateKey() }
                }
                Button(copiedKey ? "已复制" : "复制公钥") { copyPublicKey() }
                    .disabled(publicKeyPEM.isEmpty)
                Spacer()
            }

            if publicKeyPEM.isEmpty {
                Text("还没有私钥：生成后把公钥上传到和风控制台。")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else {
                Text(publicKeyPEM)
                    .font(.system(size: 11, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(8)
                    .frame(maxWidth: 520, alignment: .leading)
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.25)))
            }
        }
    }

    private var notesCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 6) {
                Text("数据来源：和风天气 QWeather。副屏底部会显示「和风天气」署名。")
                Text("刷新频率：页面每 30 秒轮询；Mac 端缓存 5 分钟；失败时优先显示上次结果并标记已过期。")
                Text("隐私：只向和风发送所选城市坐标；API Key 与私钥存本机 0600 文件，不打日志、不下发手机。")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(4)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label("说明", systemImage: "info.circle")
        }
    }

    private func stepHeader(_ number: String, _ title: String) -> some View {
        HStack(spacing: 8) {
            Text(number)
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 18, height: 18)
                .background(Color.accentColor.opacity(0.12))
                .clipShape(Circle())
            Text(title).font(.headline)
        }
    }

    private var credentialsReady: Bool {
        weather.config.canAuthenticate
    }

    // MARK: - 动作

    private func loadStoredState() {
        publicKeyPEM = (try? QWeatherAuth.publicKeyPEM()) ?? ""
        hasStoredAPIKey = QWeatherAuth.hasAPIKey()
    }

    private func saveAPIKey() {
        do {
            try QWeatherAuth.saveAPIKey(apiKeyDraft)
            apiKeyDraft = ""
            hasStoredAPIKey = QWeatherAuth.hasAPIKey()
            keyError = nil
            testMessage = nil
            testPassed = nil
            invalidateCache()
            ScreenEventHub.notifyChange()
            if credentialsReady, weather.latitude != nil {
                testConnection()
            }
        } catch {
            keyError = error.localizedDescription
        }
    }

    private func clearAPIKey() {
        QWeatherAuth.clearAPIKey()
        hasStoredAPIKey = false
        keyError = nil
        invalidateCache()
    }

    private func regenerateKey() {
        do {
            publicKeyPEM = try QWeatherAuth.regenerateKeyPair()
            copiedKey = false
            invalidateCache()
        } catch {
            testPassed = false
            testMessage = error.localizedDescription
        }
    }

    private func copyPublicKey() {
        guard !publicKeyPEM.isEmpty else { return }
        UIPasteboardLike.copy(publicKeyPEM)
        copiedKey = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copiedKey = false }
    }

    private func invalidateCache() {
        Task { await WeatherService.shared.invalidate() }
    }

    private func locateCity() {
        searchError = nil
        locating = true
        Task { @MainActor in
            defer { locating = false }
            do {
                let location = try await WeatherLocationProvider.shared.currentLocation()
                let lon = String(format: "%.2f",
                                 locale: Locale(identifier: "en_US_POSIX"),
                                 location.coordinate.longitude)
                let lat = String(format: "%.2f",
                                 locale: Locale(identifier: "en_US_POSIX"),
                                 location.coordinate.latitude)
                let result = try await WeatherService.shared.lookupCities(for: weather.config,
                                                                          query: "\(lon),\(lat)")
                guard let city = result.first else { throw WeatherLocationError.noCity }
                weather.select(city: city)
                searchQuery = city.name
                cities = []
                invalidateCache()
            } catch {
                searchError = WeatherLocationProvider.message(for: error)
            }
        }
    }

    private func searchCities() {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        searchError = nil
        searching = true
        Task { @MainActor in
            defer { searching = false }
            do {
                let result = try await WeatherService.shared.lookupCities(for: weather.config, query: query)
                cities = result
                if result.isEmpty { searchError = "没有找到匹配的城市" }
            } catch {
                cities = []
                searchError = WeatherService.friendlyMessage(error)
            }
        }
    }

    private func testConnection() {
        testing = true
        testMessage = nil
        testPassed = nil
        Task { @MainActor in
            await WeatherService.shared.invalidate()
            var config = weather.config
            config.enabled = true
            if !config.canAuthenticate {
                testing = false
                testPassed = false
                testMessage = config.authMode == .apiKey
                    ? "请先填写 API Host 并保存 API Key"
                    : "请先填完 API Host、iss、sub、kid，并生成密钥对"
                return
            }
            if config.latitude == nil || config.longitude == nil {
                testing = false
                testPassed = false
                testMessage = "请先搜索并选择城市"
                return
            }
            let envelope = await WeatherService.shared.snapshot(for: config, force: true)
            testing = false
            if envelope.ok, envelope.stale == true {
                testPassed = false
                testMessage = "使用缓存数据：\(envelope.message ?? "上游请求失败")"
            } else if envelope.ok {
                testPassed = true
                let temp = envelope.now?.temp.map { "\($0)°" } ?? "—"
                let text = envelope.now?.text ?? ""
                testMessage = "成功：\(envelope.city ?? "") \(temp) \(text)；副屏已同步"
                if !weather.enabled { weather.enabled = true }
            } else {
                testPassed = false
                testMessage = envelope.message ?? "请求失败（\(envelope.reason ?? "-")）"
            }
            ScreenEventHub.notifyChange()
        }
    }
}

import CoreLocation
import Foundation

enum WeatherLocationError: LocalizedError {
    case servicesDisabled
    case denied
    case timeout
    case noCity
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .servicesDisabled:
            return "系统定位服务未开启：请到系统设置 → 隐私与安全性 → 定位服务打开"
        case .denied:
            return "未授权定位：请在系统设置 → 隐私与安全性 → 定位服务中允许本应用"
        case .timeout:
            return "定位超时：请检查 Wi-Fi，或直接搜索城市"
        case .noCity:
            return "定位成功，但没有匹配到城市；请手动搜索"
        case let .failed(message):
            return message
        }
    }
}

/// 只取一次公里级坐标，用于把城市自动填进天气设置。
/// 不持续定位、不后台定位、不保存轨迹。
@MainActor
final class WeatherLocationProvider: NSObject, CLLocationManagerDelegate {
    static let shared = WeatherLocationProvider()

    private let manager = CLLocationManager()
    private var authorizationContinuation: CheckedContinuation<CLAuthorizationStatus, Never>?
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?
    private var authorizationTimeout: Task<Void, Never>?
    private var locationTimeout: Task<Void, Never>?

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func currentLocation(timeout: TimeInterval = 12) async throws -> CLLocation {
        guard CLLocationManager.locationServicesEnabled() else {
            throw WeatherLocationError.servicesDisabled
        }
        var status = manager.authorizationStatus
        if status == .notDetermined {
            status = await requestAuthorization()
        }
        guard status == .authorized || status == .authorizedAlways else {
            throw WeatherLocationError.denied
        }

        return try await withCheckedThrowingContinuation { continuation in
            locationContinuation = continuation
            locationTimeout?.cancel()
            locationTimeout = Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(max(timeout, 1) * 1_000_000_000))
                guard !Task.isCancelled else { return }
                self?.finishLocation(.failure(WeatherLocationError.timeout))
            }
            manager.requestLocation()
        }
    }

    static func message(for error: Error) -> String {
        let mapped = map(error)
        if let localized = mapped as? LocalizedError, let description = localized.errorDescription {
            return description
        }
        return WeatherService.friendlyMessage(mapped)
    }

    // MARK: - 授权

    private func requestAuthorization() async -> CLAuthorizationStatus {
        if manager.authorizationStatus != .notDetermined {
            return manager.authorizationStatus
        }
        return await withCheckedContinuation { continuation in
            authorizationContinuation = continuation
            manager.requestWhenInUseAuthorization()
            authorizationTimeout?.cancel()
            authorizationTimeout = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                guard !Task.isCancelled else { return }
                self?.resumeAuthorization(with: self?.manager.authorizationStatus ?? .notDetermined)
            }
        }
    }

    private func resumeAuthorization(with status: CLAuthorizationStatus) {
        guard let continuation = authorizationContinuation else { return }
        authorizationContinuation = nil
        authorizationTimeout?.cancel()
        authorizationTimeout = nil
        continuation.resume(returning: status)
    }

    private func finishLocation(_ result: Result<CLLocation, Error>) {
        locationTimeout?.cancel()
        locationTimeout = nil
        guard let continuation = locationContinuation else { return }
        locationContinuation = nil
        switch result {
        case let .success(location):
            continuation.resume(returning: location)
        case let .failure(error):
            continuation.resume(throwing: error)
        }
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor [weak self] in
            self?.resumeAuthorization(with: status)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let location = locations.last
        Task { @MainActor [weak self] in
            guard let self else { return }
            if let location {
                self.finishLocation(.success(location))
            } else {
                self.finishLocation(.failure(WeatherLocationError.failed("系统没有返回可用坐标")))
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            self?.finishLocation(.failure(WeatherLocationProvider.map(error)))
        }
    }

    private static func map(_ error: Error) -> Error {
        guard let error = error as? CLError else { return error }
        switch error.code {
        case .denied:
            return WeatherLocationError.denied
        case .locationUnknown:
            return WeatherLocationError.failed("系统暂时无法定位，请重试或手动搜索")
        case .network:
            return WeatherLocationError.failed("定位网络不可用")
        default:
            return error
        }
    }
}

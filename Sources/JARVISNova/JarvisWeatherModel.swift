import Foundation
@preconcurrency import CoreLocation
import Combine

@MainActor
final class JarvisWeatherModel: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {
    struct Snapshot {
        let city: String
        let temperature: Int
        let feelsLike: Int
        let description: String
        let humidity: Int
        let wind: Int
        let precipitation: Double
        let symbol: String
        let updatedAt: Date
        let weatherCode: Int
        let isDay: Bool
        var daily: [JarvisWeather.Day] = []
    }

    @Published private(set) var snapshot: Snapshot?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?
    private var locationTask: Task<CLLocation, Error>?
    private var locationRequestID: UUID?
    private var refreshTask: Task<Void, Never>?
    private var refreshTimer: Timer?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func refresh() {
        guard !isLoading else { return }
        refreshTask?.cancel()
        refreshTask = Task { @MainActor in
            isLoading = true
            errorMessage = nil
            defer { isLoading = false }
            do {
                let location = try await requestLocation()
                try Task.checkCancellation()
                let placemarks = try? await geocoder.reverseGeocodeLocation(location)
                let place = placemarks?.first
                let city = place?.locality ?? place?.subAdministrativeArea ?? place?.administrativeArea ?? "Ваше местоположение"
                let report = try await JarvisWeather.current(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    city: city
                )
                try Task.checkCancellation()
                var fresh = Snapshot(
                    city: report.city,
                    temperature: report.temperature,
                    feelsLike: report.apparent,
                    description: report.description,
                    humidity: report.humidity,
                    wind: report.wind,
                    precipitation: report.precipitation,
                    symbol: Self.symbol(for: report.weatherCode),
                    updatedAt: Date(),
                    weatherCode: report.weatherCode,
                    isDay: report.isDay
                )
                fresh.daily = report.daily
                snapshot = fresh
            } catch is CancellationError {
                return
            } catch {
                errorMessage = Self.locationError(error)
            }
        }
    }

    func currentReport() async throws -> Snapshot {
        if let snapshot, Date().timeIntervalSince(snapshot.updatedAt) < 300 {
            return snapshot
        }
        if let refreshTask {
            await refreshTask.value
            if let snapshot, Date().timeIntervalSince(snapshot.updatedAt) < 300 { return snapshot }
        }
        let location = try await requestLocation()
        let placemarks = try? await geocoder.reverseGeocodeLocation(location)
        let city = placemarks?.first?.locality ?? placemarks?.first?.administrativeArea ?? "Ваше местоположение"
        let report = try await JarvisWeather.current(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude, city: city)
        var result = Snapshot(city: report.city, temperature: report.temperature, feelsLike: report.apparent, description: report.description, humidity: report.humidity, wind: report.wind, precipitation: report.precipitation, symbol: Self.symbol(for: report.weatherCode), updatedAt: Date(), weatherCode: report.weatherCode, isDay: report.isDay)
        result.daily = report.daily
        snapshot = result
        return result
    }

    private func requestLocation() async throws -> CLLocation {
        if let location = manager.location,
           Date().timeIntervalSince(location.timestamp) < 300 {
            return location
        }

        // Coalesce concurrent callers into one CoreLocation request. CLLocationManager
        // has one delegate result stream, so overwriting a continuation is unsafe.
        if let locationTask {
            return try await locationTask.value
        }

        let requestID = UUID()
        let task = Task { @MainActor [weak self] () throws -> CLLocation in
            guard let self else { throw CancellationError() }
            return try await self.performLocationRequest()
        }
        locationRequestID = requestID
        locationTask = task

        defer {
            if locationRequestID == requestID {
                locationRequestID = nil
                locationTask = nil
            }
        }
        return try await task.value
    }

    private func performLocationRequest() async throws -> CLLocation {
        switch manager.authorizationStatus {
        case .denied, .restricted:
            throw NSError(domain: "JarvisLocation", code: 1, userInfo: [NSLocalizedDescriptionKey: "Разреши JARVIS доступ к геопозиции в настройках macOS → Конфиденциальность и безопасность → Службы геолокации."])
        case .notDetermined:
            return try await withCheckedThrowingContinuation { continuation in
                locationContinuation = continuation
                manager.requestWhenInUseAuthorization()
            }
        case .authorizedAlways, .authorized:
            return try await withCheckedThrowingContinuation { continuation in
                locationContinuation = continuation
                manager.requestLocation()
            }
        @unknown default:
            throw NSError(domain: "JarvisLocation", code: 2, userInfo: [NSLocalizedDescriptionKey: "Не удалось определить разрешение на геопозицию."])
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard let continuation = locationContinuation else { return }
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorized:
            manager.requestLocation()
        case .denied, .restricted:
            locationContinuation = nil
            continuation.resume(throwing: NSError(domain: "JarvisLocation", code: 1, userInfo: [NSLocalizedDescriptionKey: "Нет доступа к геопозиции. Разреши его в настройках macOS."]))
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let continuation = locationContinuation, let location = locations.last else { return }
        locationContinuation = nil
        continuation.resume(returning: location)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard let continuation = locationContinuation else { return }
        locationContinuation = nil
        continuation.resume(throwing: error)
    }

    private static func locationError(_ error: Error) -> String {
        if let cl = error as? CLError, cl.code == .denied {
            return "Разреши геолокацию JARVIS в настройках macOS."
        }
        return error.localizedDescription
    }

    static func symbol(for code: Int) -> String {
        switch code {
        case 0: return "sun.max.fill"
        case 1, 2: return "cloud.sun.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51...57: return "cloud.drizzle.fill"
        case 61...67, 80...82: return "cloud.rain.fill"
        case 71...77, 85, 86: return "cloud.snow.fill"
        case 95...99: return "cloud.bolt.rain.fill"
        default: return "cloud.fill"
        }
    }
}
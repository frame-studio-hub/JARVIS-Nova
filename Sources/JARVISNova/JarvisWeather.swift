import Foundation

@MainActor
enum JarvisWeather {
    struct Report {
        let city: String
        let temperature: Int
        let apparent: Int
        let description: String
        let humidity: Int
        let wind: Int
        let precipitation: Double
        let weatherCode: Int
        let isDay: Bool
        var daily: [Day] = []
    }

    struct Day: Identifiable {
        let date: Date
        let weatherCode: Int
        let maxTemp: Int
        var id: Date { date }
    }

    private static var cache: [String: (Date, Report)] = [:]

    static func current(for city: String) async throws -> Report {
        let key = city.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        if let cached = cache[key], Date().timeIntervalSince(cached.0) < 300 { return cached.1 }
        var geo = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")!
        geo.queryItems = [URLQueryItem(name: "name", value: city), URLQueryItem(name: "count", value: "1"), URLQueryItem(name: "language", value: "ru"), URLQueryItem(name: "format", value: "json")]
        var req = URLRequest(url: geo.url!)
        req.timeoutInterval = 5
        let data = try await fetchData(for: req)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let first = (json["results"] as? [[String: Any]])?.first,
              let lat = first["latitude"] as? Double, let lon = first["longitude"] as? Double else {
            throw NSError(domain: "JarvisWeather", code: 404, userInfo: [NSLocalizedDescriptionKey: "Не нашёл город «\(city)»."])
        }
        let report = try await current(latitude: lat, longitude: lon, city: (first["name"] as? String) ?? city)
        cache[key] = (Date(), report)
        return report
    }

    static func current(latitude: Double, longitude: Double, city: String) async throws -> Report {
        let key = String(format: "%.2f:%.2f", latitude, longitude)
        if let cached = cache[key], Date().timeIntervalSince(cached.0) < 300 { return cached.1 }
        var forecast = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        forecast.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,weather_code,wind_speed_10m"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "daily", value: "weather_code,temperature_2m_max"),
            URLQueryItem(name: "forecast_days", value: "5")
        ]
        var request = URLRequest(url: forecast.url!)
        request.timeoutInterval = 5
        let data = try await fetchData(for: request)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let current = json["current"] as? [String: Any] else {
            throw NSError(domain: "JarvisWeather", code: 500, userInfo: [NSLocalizedDescriptionKey: "Сервис погоды вернул некорректный ответ."])
        }
        let code = current["weather_code"] as? Int ?? -1
        var days: [Day] = []
        if let daily = json["daily"] as? [String: Any],
           let times = daily["time"] as? [String],
           let codes = daily["weather_code"] as? [Int],
           let temps = daily["temperature_2m_max"] as? [Double] {
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd"
            fmt.timeZone = TimeZone.current
            for index in 0..<min(times.count, codes.count, temps.count) {
                if let date = fmt.date(from: times[index]) {
                    days.append(Day(date: date, weatherCode: codes[index], maxTemp: Int(temps[index].rounded())))
                }
            }
        }
        var report = Report(
            city: city,
            temperature: Int((current["temperature_2m"] as? Double ?? 0).rounded()),
            apparent: Int((current["apparent_temperature"] as? Double ?? 0).rounded()),
            description: description(for: code),
            humidity: Int(current["relative_humidity_2m"] as? Double ?? 0),
            wind: Int((current["wind_speed_10m"] as? Double ?? 0).rounded()),
            precipitation: current["precipitation"] as? Double ?? 0,
            weatherCode: code,
            isDay: (current["is_day"] as? Int ?? 1) == 1
        )
        report.daily = days
        cache[key] = (Date(), report)
        return report
    }

    private static func fetchData(for request: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw NSError(domain: "JarvisWeather", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Сервис погоды вернул неизвестный HTTP-ответ."
            ])
        }
        guard (200...299).contains(http.statusCode) else {
            throw NSError(domain: "JarvisWeather", code: http.statusCode, userInfo: [
                NSLocalizedDescriptionKey: "Сервис погоды временно недоступен (HTTP \(http.statusCode))."
            ])
        }
        return data
    }

    private static func description(for code: Int) -> String {
        switch code {
        case 0: return "ясно"
        case 1: return "преимущественно ясно"
        case 2: return "переменная облачность"
        case 3: return "облачно"
        case 45, 48: return "туман"
        case 51, 53, 55: return "морось"
        case 56, 57: return "ледяная морось"
        case 61, 63, 65: return "дождь"
        case 66, 67: return "ледяной дождь"
        case 71, 73, 75, 77: return "снег"
        case 80, 81, 82: return "ливень"
        case 85, 86: return "снегопад"
        case 95: return "гроза"
        case 96, 99: return "гроза с градом"
        default: return "погодные условия неизвестны"
        }
    }
}
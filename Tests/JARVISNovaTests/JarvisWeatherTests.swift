import XCTest
@testable import JARVISNova

final class JarvisWeatherTests: XCTestCase {
    @MainActor
    func testWeatherSymbolsForKnownCodes() {
        XCTAssertEqual(JarvisWeatherModel.symbol(for: 0), "sun.max.fill")
        XCTAssertEqual(JarvisWeatherModel.symbol(for: 2), "cloud.sun.fill")
        XCTAssertEqual(JarvisWeatherModel.symbol(for: 3), "cloud.fill")
        XCTAssertEqual(JarvisWeatherModel.symbol(for: 61), "cloud.rain.fill")
        XCTAssertEqual(JarvisWeatherModel.symbol(for: 71), "cloud.snow.fill")
        XCTAssertEqual(JarvisWeatherModel.symbol(for: 95), "cloud.bolt.rain.fill")
    }

    @MainActor
    func testUnknownWeatherCodeUsesFallbackSymbol() {
        XCTAssertEqual(JarvisWeatherModel.symbol(for: -1), "cloud.fill")
        XCTAssertEqual(JarvisWeatherModel.symbol(for: 999), "cloud.fill")
    }
}
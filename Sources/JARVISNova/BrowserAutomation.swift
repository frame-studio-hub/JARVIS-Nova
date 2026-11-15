import Foundation
import AppKit

enum BrowserAutomation {

    static func openURL(_ address: String) -> Bool {
        guard let url = URL(string: address),
              let scheme = url.scheme?.lowercased(),
              ["https", "http"].contains(scheme),
              let host = url.host,
              !host.isEmpty else {
            return false
        }

        return NSWorkspace.shared.open(url)
    }

    static func newTab(_ address: String = "https://www.google.com") -> Bool {
        guard let url = URL(string: address),
              let scheme = url.scheme?.lowercased(),
              ["https", "http"].contains(scheme),
              let host = url.host,
              !host.isEmpty else {
            return false
        }

        return NSWorkspace.shared.open(url)
    }

    static func search(_ query: String) -> Bool {
        guard let encoded = query.addingPercentEncoding(
            withAllowedCharacters: .urlQueryAllowed
        ) else {
            return false
        }

        return newTab("https://www.google.com/search?q=\(encoded)")
    }

    private static func escaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }


}
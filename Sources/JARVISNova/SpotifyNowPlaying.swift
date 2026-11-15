import Foundation
import Combine
import AppKit

@MainActor
final class SpotifyNowPlaying: ObservableObject {
    struct Track: Equatable {
        let title: String
        let artist: String
        let album: String
        let state: String
        let artworkURL: String?
        let positionSeconds: Double
        let durationSeconds: Double
        let positionUpdatedAt: Date

        func elapsed(at date: Date = .now) -> Double {
            let live = state == "playing" ? date.timeIntervalSince(positionUpdatedAt) : 0
            return min(max(0, positionSeconds + live), max(0, durationSeconds))
        }
    }

    @Published private(set) var track: Track?
    @Published private(set) var isAvailable = false
    @Published private(set) var isAdvertisementDetected = false

    private var timer: Timer?
    private var isRefreshing = false
    // Prevent an older polling result from undoing a manual seek.
    private var seekGeneration = 0
    private var currentURI: String?
    private let cli = "/Applications/Spotify.app/Contents/MacOS/spotify_cli"

    func start() {
        guard timer == nil else { return }
        refresh()
        // Poll metadata gently; the progress animation itself is interpolated locally.
        timer = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func seek(to seconds: Double) async {
        guard let old = track, old.durationSeconds > 0 else { return }
        let target = min(max(0, seconds), old.durationSeconds)
        // Invalidate polls that began before this seek; otherwise stale data can snap
        // the slider back to its previous position.
        seekGeneration &+= 1
        let generation = seekGeneration
        // Publish the requested position immediately. This prevents the card from
        // falling back to the old TimelineView value while AppleScript is executing.
        track = Track(title: old.title, artist: old.artist, album: old.album,
                      state: old.state, artworkURL: old.artworkURL,
                      positionSeconds: target, durationSeconds: old.durationSeconds,
                      positionUpdatedAt: .now)
        let script = "tell application \"Spotify\" to set player position to \(target)"
        guard await Self.runAppleScript(script) != nil else {
            print("[Spotify] Не удалось переместить позицию воспроизведения")
            return
        }
        let actual = await Self.readPlaybackPosition()
        guard generation == seekGeneration else { return }
        // Spotify can briefly return the previous position immediately after a seek.
        // Keep the user's target unless the readback is close enough to confirm it.
        let confirmed = actual.duration > 0 && abs(actual.position - target) < 2.0
            ? actual.position : target
        track = Track(title: old.title, artist: old.artist, album: old.album,
                      state: old.state, artworkURL: old.artworkURL,
                      positionSeconds: confirmed,
                      durationSeconds: actual.duration > 0 ? actual.duration : old.durationSeconds,
                      positionUpdatedAt: .now)
    }

    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        let refreshGeneration = seekGeneration
        Task {
            defer { isRefreshing = false }
            guard FileManager.default.isExecutableFile(atPath: cli) else {
                isAvailable = false
                return
            }

            guard let raw = await Self.runCLI(["now-playing", "--format", "json"]),
                  let data = raw.data(using: .utf8),
                  let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let playing = root["currently_playing"] as? [String: Any] else {
                if isAvailable { isAvailable = false }
                return
            }

            if !isAvailable { isAvailable = true }
            let uri = playing["uri"] as? String ?? ""
            let description = playing["description"] as? String ?? "Spotify"
            let isPlaying = playing["is_playing"] as? Bool ?? false

            // Detect ad playback and reflect it in the dashboard only.
            // Never mute, skip, terminate, or relaunch Spotify from this monitor.
            if uri.hasPrefix("spotify:ad:") {
                currentURI = uri
                isAdvertisementDetected = true
                if track != nil { track = nil }
                print("[Spotify] Рекламный элемент обнаружен (пассивный мониторинг)")
                return
            }
            guard !uri.isEmpty else { return }
            if isAdvertisementDetected { isAdvertisementDetected = false }

            let playback = await Self.readPlaybackPosition()
            guard refreshGeneration == seekGeneration else { return }
            if uri != currentURI {
                currentURI = uri
                let pieces = description.components(separatedBy: " — ")
                let fallbackTitle = pieces.first ?? description
                let fallbackArtist = pieces.count > 1 ? pieces.dropFirst().joined(separator: " — ") : ""
                track = Track(
                    title: fallbackTitle, artist: fallbackArtist, album: "",
                    state: isPlaying ? "playing" : "paused", artworkURL: nil,
                    positionSeconds: playback.position, durationSeconds: playback.duration,
                    positionUpdatedAt: .now
                )
                await loadTrack(uri: uri, fallback: description, isPlaying: isPlaying,
                                position: playback.position, duration: playback.duration,
                                generation: refreshGeneration)
            } else if let old = track {
                track = Track(
                    title: old.title, artist: old.artist, album: old.album,
                    state: isPlaying ? "playing" : "paused",
                    artworkURL: old.artworkURL,
                    positionSeconds: playback.position,
                    durationSeconds: playback.duration > 0 ? playback.duration : old.durationSeconds,
                    positionUpdatedAt: .now
                )
            }
        }
    }

    private func loadTrack(uri: String, fallback: String, isPlaying: Bool,
                           position: Double, duration: Double, generation: Int) async {
        let state = isPlaying ? "playing" : "paused"
        guard let raw = await Self.runCLI(["lookup", uri, "--format", "json"]),
              currentURI == uri,
              let data = raw.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let entities = root["entities"] as? [[String: Any]],
              let entity = entities.first else {
            guard generation == seekGeneration else { return }
            let pieces = fallback.components(separatedBy: " — ")
            let title = pieces.first ?? fallback
            let artist = pieces.count > 1 ? pieces.dropFirst().joined(separator: " — ") : ""
            track = Track(title: title, artist: artist, album: "", state: state,
                          artworkURL: nil, positionSeconds: position,
                          durationSeconds: duration, positionUpdatedAt: .now)
            return
        }

        guard generation == seekGeneration else { return }
        let title = entity["name"] as? String ?? fallback
        let contributors = entity["contributors"] as? [[String: Any]] ?? []
        let artist = contributors.compactMap { $0["name"] as? String }.joined(separator: ", ")
        var image = entity["image_url"] as? String
        // Spotify lookup may return a tiny 64px thumbnail; request the full-size CDN variant.
        image = image?.replacingOccurrences(of: "00004851", with: "0000b273")
        let album = (entity["parent"] as? [String: Any])?["name"] as? String ?? ""
        track = Track(title: title, artist: artist, album: album, state: state,
                      artworkURL: image, positionSeconds: position,
                      durationSeconds: duration, positionUpdatedAt: .now)
    }

    private nonisolated static func readPlaybackPosition() async -> (position: Double, duration: Double) {
        guard let raw = await runAppleScript(
            "tell application \"Spotify\" to get (player position as text) & \"|\" & (duration of current track as text)"
        ) else { return (0, 0) }
        let values = raw.split(separator: "|", omittingEmptySubsequences: false)
        guard values.count == 2 else { return (0, 0) }
        // AppleScript may return "12,07" under regional decimal-comma settings.
        func number(_ value: Substring) -> Double? {
            let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: ",", with: ".")
            return Double(normalized)
        }
        guard let position = number(values[0]),
              let milliseconds = number(values[1]),
              position >= 0, milliseconds > 0 else {
            print("[Spotify] Не удалось разобрать player position/duration: \(raw)")
            return (0, 0)
        }
        return (position, milliseconds / 1000.0)
    }

    private nonisolated static func currentPlaybackURI() async -> String? {
        guard let raw = await runCLI(["now-playing", "--format", "json"]),
              let data = raw.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let playing = root["currently_playing"] as? [String: Any] else { return nil }
        return playing["uri"] as? String
    }

    private nonisolated static func runCLI(_ arguments: [String]) async -> String? {
        await Task.detached(priority: .utility) {
            let process = Process()
            let output = Pipe()
            process.executableURL = URL(fileURLWithPath: "/Applications/Spotify.app/Contents/MacOS/spotify_cli")
            process.arguments = arguments
            process.standardOutput = output
            process.standardError = FileHandle.nullDevice
            do {
                try process.run()
                let data = output.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                guard process.terminationStatus == 0 else { return nil }
                return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            } catch { return nil }
        }.value
    }

    private nonisolated static func runAppleScript(_ script: String) async -> String? {
        await Task.detached(priority: .utility) {
            let process = Process()
            let output = Pipe()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", script]
            process.standardOutput = output
            process.standardError = FileHandle.nullDevice
            do {
                try process.run()
                let data = output.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                guard process.terminationStatus == 0 else { return nil }
                return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            } catch { return nil }
        }.value
    }
}
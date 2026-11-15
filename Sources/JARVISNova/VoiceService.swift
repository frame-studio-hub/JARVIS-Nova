import Foundation
import AVFoundation
import Combine

@MainActor
final class VoiceService: ObservableObject {
    @Published private(set) var isSpeaking = false
    @Published private(set) var lastError: String?

    private var player: AVAudioPlayer?
    private var streamPlayer: FishStreamPlayer?
    private var speechTask: Task<Void, Never>?
    private var requestID = UUID()


    private var pcmPlayer: FishPCMPlayer?
    private var warmPCMPlayer: FishPCMPlayer?
    private var cachedFishAudioKey: String?
    private var preparedSocket: URLSessionWebSocketTask?
    private var isPreparingSocket = false

    func prepareForSpeech() async {
        if cachedFishAudioKey == nil {
            do {
                cachedFishAudioKey = try await Self.readFishAudioKey()
            } catch {
                print("[Fish SPEED] Не удалось заранее прочитать ключ: \(error.localizedDescription)")
                return
            }
        }
        guard let key = cachedFishAudioKey, !key.isEmpty else { return }
        if warmPCMPlayer == nil {
            do {
                warmPCMPlayer = try FishPCMPlayer()
                print("[Fish SPEED] Аудиодвижок заранее прогрет")
            } catch {
                print("[Fish SPEED] Не удалось прогреть аудиодвижок: \(error.localizedDescription)")
            }
        }
        // HTTP streaming is the primary transport. Do not open a WebSocket
        // in parallel: it adds work and can delay the first spoken audio.
    }

    func speak(_ text: String) {
        let phrase = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !phrase.isEmpty else { return }

        requestID = UUID()
        let currentID = requestID

        speechTask?.cancel()
        speechTask = nil

        streamPlayer?.stop()
        streamPlayer = nil

        pcmPlayer?.stop()
        pcmPlayer = nil

        player?.stop()
        player = nil

        isSpeaking = true
        lastError = nil

        speechTask = Task {
            let startedAt = Date()

            do {
                if cachedFishAudioKey == nil {
                    cachedFishAudioKey = try await Self.readFishAudioKey()
                }
                guard let key = cachedFishAudioKey, !key.isEmpty else {
                    throw VoiceError.missingKey
                }

                // Never wait for the fallback socket before starting HTTP TTS.
                // If HTTP fails, WebSocket fallback connects on demand.
                let socket = preparedSocket
                preparedSocket = nil

                let pcm = try (warmPCMPlayer ?? FishPCMPlayer())
                warmPCMPlayer = nil
                pcmPlayer = pcm
                var firstAudio = false
                let receiveAudio: @MainActor (Data) async -> Void = { data in
                    guard currentID == self.requestID else { return }
                    await pcm.append(data)
                    if pcm.started && !firstAudio {
                        firstAudio = true
                        print(
                            "[Fish PCM] Первый звук через",
                            String(format: "%.2f", Date().timeIntervalSince(startedAt)),
                            "сек"
                        )
                    }
                }

                do {
                    try await FishHTTPStream.stream(
                        text: phrase,
                        apiKey: key,
                        onAudio: receiveAudio
                    )
                } catch {
                    guard !firstAudio, currentID == requestID else { throw error }
                    print("[Fish SPEED] HTTP-поток не сработал, включаю резервный WebSocket:", error.localizedDescription)
                    try await FishWebSocket.stream(
                        text: phrase,
                        apiKey: key,
                        preparedSocket: socket,
                        onAudio: receiveAudio
                    )
                }

                guard currentID == requestID else { return }

                pcm.finish()

                while !pcm.playbackFinished {
                    try Task.checkCancellation()
                    guard currentID == requestID else { return }

                    try await Task.sleep(nanoseconds: 50_000_000)
                }

                guard currentID == requestID else { return }

                pcm.stop()
                pcmPlayer = nil
                isSpeaking = false

                print("[Fish PCM] Воспроизведение завершено")

            } catch {
                guard currentID == requestID else { return }

                pcmPlayer?.stop()
                pcmPlayer = nil
                print("[Fish PCM] Ошибка:", error.localizedDescription)
                // Never silently switch to the macOS system voice: JARVIS must use Fish Audio.
                lastError = "Fish Audio: \(error.localizedDescription)"
                isSpeaking = false
            }
        }
    }


    func stop() {
        requestID = UUID()
        speechTask?.cancel()
        speechTask = nil
        preparedSocket?.cancel(with: .goingAway, reason: nil)
        preparedSocket = nil
        warmPCMPlayer?.stop()
        warmPCMPlayer = nil
        streamPlayer?.stop()
        streamPlayer = nil
        pcmPlayer?.stop()
        pcmPlayer = nil
        player?.stop()
        player = nil
        isSpeaking = false
    }

    private nonisolated static func readFishAudioKey() async throws -> String? {
        try await Task.detached(priority: .utility) {
            let process = Process()
            let output = Pipe()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
            process.arguments = ["find-generic-password", "-a", NSUserName(), "-s", "AIHelper-FishAudio", "-w"]
            process.standardOutput = output
            process.standardError = FileHandle.nullDevice
            try process.run()
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        }.value
    }


    private enum VoiceError: LocalizedError {
        case missingKey, server, playback

        var errorDescription: String? {
            switch self {
            case .missingKey:
                return "Ключ Fish Audio не найден в связке ключей macOS."
            case .server:
                return "Fish Audio вернул ошибку. Проверь доступ к сервису."
            case .playback:
                return "Не удалось воспроизвести аудио."
            }
        }
    }
}
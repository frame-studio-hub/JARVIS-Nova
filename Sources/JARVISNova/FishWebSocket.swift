import Foundation
import SwiftMsgpack

struct FishWebSocket {
    struct Prosody: Encodable {
        let speed = 1.08
    }

    struct StartRequest: Encodable {
        let text = ""
        let format = "pcm"
        let chunk_length = 100
        let reference_id = "28e481b48ae84b4babe8da0988461ed6"
        let latency = "low"
        let prosody = Prosody()
    }

    struct StartEvent: Encodable {
        let event = "start"
        let request = StartRequest()
    }

    struct TextEvent: Encodable {
        let event = "text"
        let text: String
    }

    struct ControlEvent: Encodable {
        let event: String
    }

    struct ServerEvent: Decodable {
        let event: String
        let audio: Data?
        let message: String?
        let reason: String?
    }

    static func prepare(apiKey: String) async throws -> URLSessionWebSocketTask {
        var request = URLRequest(
            url: URL(string: "wss://api.fish.audio/v1/tts/live")!
        )
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("s2.1-pro-free", forHTTPHeaderField: "model")

        let socket = URLSession.shared.webSocketTask(with: request)
        socket.resume()
        let data = try MsgPackEncoder().encode(StartEvent())
        try await socket.send(.data(data))
        print("[Fish SPEED] Соединение и Start заранее подготовлены")
        return socket
    }

    static func stream(
        text: String,
        apiKey: String,
        preparedSocket: URLSessionWebSocketTask? = nil,
        onAudio: @escaping @MainActor (Data) async -> Void
    ) async throws {
        let socket: URLSessionWebSocketTask
        let timingStart = Date()
        if let preparedSocket {
            socket = preparedSocket
            print("[Fish SPEED] Использую заранее открытое соединение")
        } else {
            var request = URLRequest(
                url: URL(string: "wss://api.fish.audio/v1/tts/live")!
            )
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.setValue("s2.1-pro-free", forHTTPHeaderField: "model")
            socket = URLSession.shared.webSocketTask(with: request)
            socket.resume()
            let startData = try MsgPackEncoder().encode(StartEvent())
            try await socket.send(.data(startData))
        }

        defer {
            socket.cancel(with: .normalClosure, reason: nil)
        }

        func send<T: Encodable>(_ value: T) async throws {
            let data = try MsgPackEncoder().encode(value)
            try await socket.send(.data(data))
        }

        print("[Fish SPEED] Start отправлен через", String(format: "%.2f", Date().timeIntervalSince(timingStart)), "сек")
        try await send(TextEvent(text: text))
        try await send(ControlEvent(event: "flush"))
        try await send(ControlEvent(event: "stop"))
        print("[Fish SPEED] Все сообщения отправлены через", String(format: "%.2f", Date().timeIntervalSince(timingStart)), "сек")

        var chunks = 0
        var lastChunkAt: Date?

        while true {
            try Task.checkCancellation()

            let message = try await socket.receive()

            guard case .data(let data) = message else {
                continue
            }

            let response = try MsgPackDecoder().decode(
                ServerEvent.self,
                from: data
            )

            switch response.event {
            case "audio":
                if let audio = response.audio, !audio.isEmpty {
                    let now = Date()
                    if let previous = lastChunkAt {
                        let gap = now.timeIntervalSince(previous)
                        if gap > 0.5 {
                            print(
                                "[Fish SPEED] Пауза между PCM-фрагментами:",
                                String(format: "%.2f", gap),
                                "сек"
                            )
                        }
                    }
                    lastChunkAt = now
                    chunks += 1
                    if chunks == 1 {
                        print("[Fish SPEED] Первый PCM-фрагмент через", String(format: "%.2f", Date().timeIntervalSince(timingStart)), "сек")
                    }
                    await onAudio(audio)
                }

            case "finish":
                print("[Fish WS] PCM chunks:", chunks, "reason:", response.reason ?? "none")
                if response.reason == "error" {
                    throw NSError(
                        domain: "FishWebSocket",
                        code: 2,
                        userInfo: [
                            NSLocalizedDescriptionKey:
                                response.message ?? "Fish Audio завершил поток с ошибкой"
                        ]
                    )
                }
                guard chunks > 0 else {
                    throw NSError(
                        domain: "FishWebSocket",
                        code: 3,
                        userInfo: [NSLocalizedDescriptionKey: "Fish Audio вернул пустой аудиопоток"]
                    )
                }
                return

            case "error":
                throw NSError(
                    domain: "FishWebSocket",
                    code: 1,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            response.message ?? "Fish Audio WebSocket error"
                    ]
                )

            default:
                print("[Fish WS] Event:", response.event)
            }
        }
    }
}
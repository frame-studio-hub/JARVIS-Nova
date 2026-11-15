import Foundation
import SwiftMsgpack

struct StartRequest: Encodable {
    let text = ""
    let format = "pcm"
    let chunk_length = 100
    let reference_id = "28e481b48ae84b4babe8da0988461ed6"
    let latency = "low"
}

struct StartEvent: Encodable {
    let event = "start"
    let request = StartRequest()
}

struct TextEvent: Encodable {
    let event = "text"
    let text: String
}

struct FlushEvent: Encodable {
    let event = "flush"
}

struct StopEvent: Encodable {
    let event = "stop"
}

struct ServerEvent: Decodable {
    let event: String
    let audio: Data?
    let reason: String?
}

func fishKey() throws -> String {
    let process = Process()
    let pipe = Pipe()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
    process.arguments = [
        "find-generic-password", "-a", NSUserName(),
        "-s", "AIHelper-FishAudio", "-w"
    ]
    process.standardOutput = pipe
    process.standardError = FileHandle.nullDevice
    try process.run()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    guard process.terminationStatus == 0,
          let key = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
          !key.isEmpty else {
        throw NSError(domain: "FishTest", code: 1,
                      userInfo: [NSLocalizedDescriptionKey:
                        "Ключ Fish Audio не найден в Связке ключей"])
    }
    return key
}

@main
struct FishStreamTest {
    static func main() async {
        do {
            let key = try fishKey()
            let url = URL(string: "wss://api.fish.audio/v1/tts/live")!
            var request = URLRequest(url: url)
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
            request.setValue("s2.1-pro-free", forHTTPHeaderField: "model")
            let socket = URLSession.shared.webSocketTask(with: request)
            let encoder = MsgPackEncoder()
            let decoder = MsgPackDecoder()
            let started = Date()
            var firstAudio: TimeInterval?
            var chunks = 0
            var totalBytes = 0

            socket.resume()
            try await socket.send(.data(encoder.encode(StartEvent())))
            try await socket.send(.data(encoder.encode(
                TextEvent(text: "Здравствуйте, сэр. Джарвис на связи.")
            )))
            try await socket.send(.data(encoder.encode(FlushEvent())))
            try await socket.send(.data(encoder.encode(StopEvent())))

            print("WebSocket подключён. Жду аудио...")

            while true {
                let message = try await socket.receive()
                let data: Data
                switch message {
                case .data(let value): data = value
                case .string(let value): data = Data(value.utf8)
                @unknown default: continue
                }

                let event = try decoder.decode(ServerEvent.self, from: data)

                if event.event == "audio" {
                    if firstAudio == nil {
                        firstAudio = Date().timeIntervalSince(started)
                        print(String(format: "Первый аудиочанк через %.2f сек",
                                     firstAudio!))
                    }
                    chunks += 1
                    totalBytes += event.audio?.count ?? 0
                    print("Чанк \(chunks), байт: \(event.audio?.count ?? 0)")
                } else if event.event == "finish" {
                    print("Завершение: \(event.reason ?? "не указано")")
                    break
                } else {
                    print("Событие: \(event.event)")
                }
            }

            print("Всего чанков: \(chunks), байт: \(totalBytes)")
            socket.cancel(with: .normalClosure, reason: nil)
        } catch {
            print("Ошибка теста: \(error.localizedDescription)")
        }
    }
}
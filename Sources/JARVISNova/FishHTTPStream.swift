import Foundation
import SwiftMsgpack

struct FishHTTPStream {
    private struct Prosody: Encodable { let speed: Double }
    private struct Request: Encodable {
        let text: String
        let format = "pcm"
        let reference_id = "28e481b48ae84b4babe8da0988461ed6"
        let latency = "low"
        let chunk_length = 100
        let normalize = false
        let prosody: Prosody
    }

    static func stream(text: String, apiKey: String, onAudio: @escaping @MainActor (Data) async -> Void) async throws {
        var request = URLRequest(url: URL(string: "https://api.fish.audio/v1/tts")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("s2.1-pro-free", forHTTPHeaderField: "model")
        request.setValue("application/msgpack", forHTTPHeaderField: "Content-Type")
        request.setValue("audio/pcm, application/octet-stream", forHTTPHeaderField: "Accept")
        request.httpBody = try MsgPackEncoder().encode(Request(text: text, prosody: Prosody(speed: 1.10)))

        let startedAt = Date()
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw NSError(domain: "FishHTTP", code: code, userInfo: [NSLocalizedDescriptionKey: "Fish Audio HTTP \(code)"])
        }

        var buffer: [UInt8] = []
        buffer.reserveCapacity(1024)
        var totalBytes = 0
        var firstChunk = true
        for try await byte in bytes {
            try Task.checkCancellation()
            buffer.append(byte)
            if buffer.count >= 1024 {
                let count = buffer.count - buffer.count % 2
                let chunk = Data(buffer[..<count])
                buffer.removeFirst(count)
                totalBytes += chunk.count
                if firstChunk {
                    firstChunk = false
                    print("[Fish HTTP] Первый PCM-фрагмент через", String(format: "%.2f", Date().timeIntervalSince(startedAt)), "сек")
                }
                await onAudio(chunk)
            }
        }
        if buffer.count % 2 != 0 { buffer.removeLast() }
        if !buffer.isEmpty { totalBytes += buffer.count; await onAudio(Data(buffer)) }
        guard totalBytes > 0 else {
            throw NSError(domain: "FishHTTP", code: 2, userInfo: [NSLocalizedDescriptionKey: "Fish Audio вернул пустой аудиопоток"])
        }
        print("[Fish HTTP] Готово, PCM bytes:", totalBytes)
    }
}
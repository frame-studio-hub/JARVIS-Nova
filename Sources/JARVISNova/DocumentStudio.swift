import Foundation
import AppKit
import Dispatch

private final class ProcessDataCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = Data()

    func store(_ data: Data) {
        lock.lock()
        storage = data
        lock.unlock()
    }

    var data: Data {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}

@MainActor
enum DocumentStudio {
    enum StudioError: LocalizedError {
        case missingKey
        case emptyResponse
        case server(Int)
        case builder(String)

        var errorDescription: String? {
            switch self {
            case .missingKey: return "Не найден ключ Gemini."
            case .emptyResponse: return "Не удалось подготовить содержимое документа."
            case .server(let code): return "Gemini вернул ошибку HTTP \(code)."
            case .builder(let message): return message
            }
        }
    }

    static func create(topic: String, format: String, apiKey: String) async throws -> URL {
        guard !apiKey.isEmpty else { throw StudioError.missingKey }
        let normalizedFormat = format.lowercased().replacingOccurrences(of: ".", with: "")
        let isPresentation = normalizedFormat == "pptx"
        let isReport = topic.localizedCaseInsensitiveContains("реферат")
        let prompt = """
        Создай полноценный материал на русском языке по запросу пользователя: \(topic)
        Формат результата: \(isPresentation ? "презентация PowerPoint PPTX" : isReport ? "академический реферат" : "профессиональный документ").
        Верни ТОЛЬКО корректный JSON без Markdown и пояснений, строго со следующими ключами:
        {"title":"короткое название","subtitle":"подзаголовок","content":"вводный текст, если нужен","sections":[{"heading":"заголовок раздела","body":"содержательный текст раздела","bullets":["тезис"]}],"slides":[{"title":"заголовок слайда","subtitle":"короткое пояснение","bullets":["один чёткий тезис"]}]}
        Требования:
        - Содержательно, логично, без воды и повторов. Не выдумывай источники, статистику и цитаты.
        - Для презентации: 8–12 слайдов, один смысл на слайд, короткие тезисы, сильное начало, выводы в конце. Не пиши длинные абзацы. Добавляй конкретику и примеры.
        - Для реферата: структура с введением, 3–5 тематическими разделами, заключением и списком источников только если источники действительно известны; не выдумывай библиографию.
        - Для обычного документа: полноценная структура, заголовки и читаемые абзацы.
        - Экранируй кавычки и переносы строк по правилам JSON.
        """
        let endpoint = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent")!
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 90
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "contents": [["role": "user", "parts": [["text": prompt]]]],
            "generationConfig": ["temperature": 0.55, "responseMimeType": "application/json", "maxOutputTokens": 7000]
        ])
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw StudioError.emptyResponse }
        guard (200...299).contains(http.statusCode) else { throw StudioError.server(http.statusCode) }
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = root["candidates"] as? [[String: Any]],
              let parts = candidates.first?["content"] as? [String: Any],
              let textParts = parts["parts"] as? [[String: Any]] else { throw StudioError.emptyResponse }
        let raw = textParts.compactMap { $0["text"] as? String }.joined().trimmingCharacters(in: .whitespacesAndNewlines)
        guard let jsonData = raw.data(using: .utf8),
              let payload = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else { throw StudioError.emptyResponse }
        return try await build(payload: payload, format: normalizedFormat)
    }

    static func createBlank(title: String, format: String) async throws -> URL {
        let payload: [String: Any] = ["title": title, "subtitle": "", "content": "", "sections": [], "slides": []]
        return try await build(payload: payload, format: format)
    }

    private static func build(payload: [String: Any], format: String) async throws -> URL {
        guard let script = Bundle.module.url(forResource: "artifact_builder", withExtension: "py") else {
            throw StudioError.builder("Не найден модуль создания файлов в сборке JARVIS.")
        }
        var documentPayload = payload
        documentPayload["format"] = format
        let data = try JSONSerialization.data(withJSONObject: documentPayload, options: [.prettyPrinted, .sortedKeys])
        do {
            return try await Task.detached(priority: .userInitiated) {
                try runBuilder(scriptPath: script.path, payloadData: data)
            }.value
        } catch {
            throw StudioError.builder(error.localizedDescription)
        }
    }

    private nonisolated static func runBuilder(scriptPath: String, payloadData: Data) throws -> URL {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("jarvis-artifact-\(UUID().uuidString).json")
        try payloadData.write(to: temp, options: .atomic)
        defer { try? FileManager.default.removeItem(at: temp) }

        let candidates = [
            "/Library/Frameworks/Python.framework/Versions/3.13/bin/python3",
            "/opt/homebrew/bin/python3",
            "/usr/bin/python3"
        ]
        guard let python = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            throw NSError(domain: "DocumentStudio", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Python 3 не найден. Установи Python 3 или настрой путь к интерпретатору."
            ])
        }

        let process = Process()
        let output = Pipe()
        let errors = Pipe()
        process.executableURL = URL(fileURLWithPath: python)
        process.arguments = [scriptPath, temp.path]
        process.standardOutput = output
        process.standardError = errors

        do {
            try process.run()

            // Drain stdout and stderr concurrently so a full pipe cannot deadlock
            // the child process while the other stream is being read.
            let outputCollector = ProcessDataCollector()
            let errorCollector = ProcessDataCollector()
            let readers = DispatchGroup()
            readers.enter()
            DispatchQueue.global(qos: .utility).async {
                outputCollector.store(output.fileHandleForReading.readDataToEndOfFile())
                readers.leave()
            }
            readers.enter()
            DispatchQueue.global(qos: .utility).async {
                errorCollector.store(errors.fileHandleForReading.readDataToEndOfFile())
                readers.leave()
            }
            readers.wait()
            process.waitUntilExit()

            let outputData = outputCollector.data
            let errorData = errorCollector.data
            guard process.terminationStatus == 0,
                  let result = try JSONSerialization.jsonObject(with: outputData) as? [String: Any],
                  let path = result["path"] as? String,
                  FileManager.default.fileExists(atPath: path) else {
                let detail = String(data: errorData, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                throw NSError(domain: "DocumentStudio", code: Int(process.terminationStatus), userInfo: [
                    NSLocalizedDescriptionKey: detail.isEmpty ? "Не удалось создать файл." : detail
                ])
            }
            return URL(fileURLWithPath: path)
        } catch {
            if process.isRunning { process.terminate() }
            throw error
        }
    }
}
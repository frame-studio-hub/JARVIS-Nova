import Foundation

enum SmartWriter {
    enum WriterError: LocalizedError {
        case missingKey
        case emptyResponse
        case server(Int)

        var errorDescription: String? {
            switch self {
            case .missingKey:
                return "Не найден ключ Gemini."
            case .emptyResponse:
                return "Gemini не вернул текст."
            case .server(let code):
                return "Ошибка Gemini: HTTP \(code)."
            }
        }
    }

    static func generate(_ instruction: String, apiKey: String) async throws -> String {
        guard !apiKey.isEmpty else {
            throw WriterError.missingKey
        }

        let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent"

        guard let url = URL(string: endpoint) else {
            throw WriterError.emptyResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "systemInstruction": [
                "parts": [[
                    "text": """
                    Ты — модуль написания текстов голосового помощника JARVIS.

                    Пользователь диктует задачу, а ты создаёшь готовый текст
                    для вставки в выбранное поле ввода.

                    Правила:
                    - Пиши на русском, если не попросили другой язык.
                    - Исправляй грамматику, орфографию и пунктуацию.
                    - Сохраняй смысл и желаемый стиль пользователя.
                    - Если просят сообщение, напиши само сообщение.
                    - Если просят описание, напиши готовое описание.
                    - Не добавляй пояснений вроде «Вот ваш текст».
                    - Не добавляй Markdown без необходимости.
                    - Не выдумывай неизвестные имена, даты и факты.
                    - Возвращай только готовый текст.
                    """
                ]]
            ],
            "contents": [[
                "role": "user",
                "parts": [["text": instruction]]
            ]],
            "generationConfig": [
                "maxOutputTokens": 1200,
                "thinkingConfig": [
                    "thinkingLevel": "minimal"
                ]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw WriterError.emptyResponse
        }

        guard (200...299).contains(http.statusCode) else {
            throw WriterError.server(http.statusCode)
        }

        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let candidates = json["candidates"] as? [[String: Any]],
            let candidate = candidates.first,
            let content = candidate["content"] as? [String: Any],
            let parts = content["parts"] as? [[String: Any]]
        else {
            throw WriterError.emptyResponse
        }

        let result = parts.compactMap { $0["text"] as? String }
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !result.isEmpty else {
            throw WriterError.emptyResponse
        }

        return result
    }
}
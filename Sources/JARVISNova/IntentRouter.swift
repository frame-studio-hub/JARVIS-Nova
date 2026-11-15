import Foundation

struct IntentRouter {

    struct Decision: Decodable {
        let action: String
        let argument: String?
        let application: String?
        let response: String?
    }

    static func decide(
        _ message: String,
        apiKey: String
    ) async throws -> Decision {

        let url = URL(string:
            "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent"
        )!

        let instruction = """
        Ты — быстрый диспетчер и мозг JARVIS на macOS. Определи намерение по смыслу, учитывай синонимы, разговорную речь и ошибки распознавания.
        Допустимые action: chat, spotify, open_app, browser, search, vision, code, compose_text, type_text, task, system_volume, brightness.
        Музыка и любые команды управления треками выбирают spotify даже без слова Spotify. Не путай громкость Spotify и громкость Mac. Анализ кода — code. Вопрос о содержимом экрана — vision. Для type_text argument — только текст, application — целевое приложение. Для open_app application — название приложения. Для system_volume/brightness сохрани значение 0–100. Для остальных действий argument — короткая цель команды.
        Для chat сразу дай готовый краткий ответ по-русски в response (1–3 коротких предложения), без приветствий и обращения «сэр». Для действий response=null. Ничего не выполняй самостоятельно.
        Верни только JSON по схеме: {"action":"chat","argument":null,"application":null,"response":"Короткий ответ"}
        """

        let body: [String: Any] = [
            "systemInstruction": [
                "parts": [["text": instruction]]
            ],
            "contents": [[
                "role": "user",
                "parts": [["text": message]]
            ]],
            "generationConfig": [
                "responseMimeType": "application/json",
                "maxOutputTokens": 320,
                "thinkingConfig": [
                    "thinkingLevel": "minimal"
                ]
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 12
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(
            withJSONObject: body
        )

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw NSError(
                domain: "IntentRouter",
                code: code,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "Gemini router HTTP \(code)"
                ]
            )
        }

        let json = try JSONSerialization.jsonObject(
            with: data
        ) as? [String: Any]

        let candidates = json?["candidates"] as? [[String: Any]]
        let content = candidates?.first?["content"] as? [String: Any]
        let parts = content?["parts"] as? [[String: Any]]
        let answer = parts?.compactMap {
            $0["text"] as? String
        }.joined() ?? ""

        guard let answerData = answer.data(using: .utf8) else {
            throw NSError(
                domain: "IntentRouter",
                code: -1,
                userInfo: [
                    NSLocalizedDescriptionKey: "Пустой ответ маршрутизатора"
                ]
            )
        }

        return try JSONDecoder().decode(
            Decision.self,
            from: answerData
        )
    }
}
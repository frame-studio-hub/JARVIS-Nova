import Foundation

enum JarvisMemory {
    private static let conversationKey = "jarvis.memory.conversation.v1"
    private static let draftKey = "jarvis.memory.lastDraft.v1"
    private static let draftInstructionKey = "jarvis.memory.lastDraftInstruction.v1"

    struct Turn: Codable {
        let role: String
        let text: String
    }

    static var recentTurns: [Turn] {
        guard let data = UserDefaults.standard.data(forKey: conversationKey),
              let turns = try? JSONDecoder().decode([Turn].self, from: data) else { return [] }
        return Array(turns.suffix(16))
    }

    static func remember(user: String, assistant: String) {
        var turns = recentTurns
        turns.append(Turn(role: "user", text: user))
        turns.append(Turn(role: "model", text: assistant))
        if turns.count > 16 { turns = Array(turns.suffix(16)) }
        if let data = try? JSONEncoder().encode(turns) {
            UserDefaults.standard.set(data, forKey: conversationKey)
        }
    }

    static var lastDraft: String? {
        UserDefaults.standard.string(forKey: draftKey)
    }

    static var lastDraftInstruction: String? {
        UserDefaults.standard.string(forKey: draftInstructionKey)
    }

    static func rememberDraft(_ text: String, instruction: String) {
        UserDefaults.standard.set(text, forKey: draftKey)
        UserDefaults.standard.set(instruction, forKey: draftInstructionKey)
    }

    static func contextText() -> String {
        recentTurns.map { "\($0.role == "user" ? "Пользователь" : "JARVIS"): \($0.text)" }
            .joined(separator: "\n")
    }
}
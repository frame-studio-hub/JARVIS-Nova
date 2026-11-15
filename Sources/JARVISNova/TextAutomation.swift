import Foundation
import AppKit

enum TextAutomation {


    @MainActor
    static func typeInActiveField(
        _ text: String,
        applicationName: String? = nil
    ) async -> Bool {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        if let name = applicationName {
            guard let app = NSWorkspace.shared.runningApplications.first(where: {
                $0.localizedName?.localizedCaseInsensitiveContains(name) == true
            }) else {
                print("[TextAutomation] Приложение не запущено: \(name)")
                return false
            }
            guard app.activate(options: [.activateAllWindows]) else {
                print("[TextAutomation] Не удалось активировать \(name)")
                return false
            }
            try? await Task.sleep(for: .milliseconds(350))
        }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        guard pasteboard.setString(text, forType: .string) else { return false }
        return await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", "tell application \"System Events\" to keystroke \"v\" using command down"]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            do {
                try process.run()
                process.waitUntilExit()
                return process.terminationStatus == 0
            } catch {
                print("[TextAutomation] Ошибка: \(error.localizedDescription)")
                return false
            }
        }.value
    }

    static func typeInOpenChatGPT(_ text: String) async -> Bool {
        guard !text.isEmpty else { return false }

        // Передаём текст через stdin, а не вставляем в AppleScript.
        let script = """
        on run argv
            set messageText to item 1 of argv
            tell application "Google Chrome"
                if (count of windows) = 0 then error "Chrome не открыт"
                set foundTab to false
                repeat with w in windows
                    repeat with t in tabs of w
                        if (URL of t starts with "https://chatgpt.com/") or (URL of t is "https://chatgpt.com") then
                            set active tab index of w to (index of t)
                            set index of w to 1
                            activate
                            set foundTab to true
                            exit repeat
                        end if
                    end repeat
                    if foundTab then exit repeat
                end repeat
                if not foundTab then error "Открытая вкладка ChatGPT не найдена"
            end tell

            delay 0.4
            tell application "System Events"
                tell process "Google Chrome"
                    keystroke messageText
                end tell
            end tell
        end run
        """

        return await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", script, text]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            do { try process.run(); process.waitUntilExit(); return process.terminationStatus == 0 }
            catch { print("[TextAutomation] \(error.localizedDescription)"); return false }
        }.value
    }
}
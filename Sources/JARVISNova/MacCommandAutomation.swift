import AppKit
import Foundation

/// Deterministic macOS actions used by the voice command layer.
/// All destructive editor operations are limited to the active supported editor.
@MainActor
enum MacCommandAutomation {
    static func handle(_ raw: String) async -> String? {
        let text = raw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        if containsAny(text, ["заблокируй компьютер", "заблокируй мак", "заблокируй экран", "lock screen"]) {
            return await run("tell application \"System Events\" to keystroke \"q\" using {control down, command down}")
                ? "Экран заблокирован."
                : "Не удалось заблокировать экран. Проверьте разрешение JARVIS на управление компьютером."
        }

        if containsAny(text, ["диспетчер задач", "мониторинг системы", "монитор активности", "activity monitor"]) {
            let url = URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app")
            return NSWorkspace.shared.open(url) ? "Открыл Мониторинг системы. Здесь видны процессы, нагрузка CPU и память." : "Не удалось открыть Мониторинг системы."
        }

        if containsAny(text, ["окно влево", "прижми окно слева", "половина экрана слева"]) {
            return await tileFrontWindow(toLeft: true) ? "Активное окно размещено в левой половине экрана." : "Не удалось переместить окно. Убедитесь, что у JARVIS есть разрешение на управление компьютером."
        }
        if containsAny(text, ["окно вправо", "прижми окно справа", "половина экрана справа"]) {
            return await tileFrontWindow(toLeft: false) ? "Активное окно размещено в правой половине экрана." : "Не удалось переместить окно. Убедитесь, что у JARVIS есть разрешение на управление компьютером."
        }
        if containsAny(text, ["следующий слайд", "переключи слайд вперед"]) {
            return await run("tell application \"System Events\" to key code 124") ? "Переключил на следующий слайд." : "Не удалось переключить слайд."
        }
        if containsAny(text, ["предыдущий слайд", "верни слайд назад"]) {
            return await run("tell application \"System Events\" to key code 123") ? "Вернул предыдущий слайд." : "Не удалось переключить слайд."
        }

        if containsAny(text, ["покажи рабочий стол", "сверни все окна", "рабочий стол", "show desktop"]) {
            return await run("tell application \"System Events\" to key code 103")
                ? "Показываю рабочий стол."
                : "Не удалось показать рабочий стол."
        }

        if containsAny(text, ["сделай скриншот", "снимок экрана", "скриншот экрана"]) {
            return await run("tell application \"System Events\" to keystroke \"4\" using {command down, shift down}")
                ? "Инструмент снимка экрана открыт. Выберите область."
                : "Не удалось вызвать снимок экрана."
        }

        if containsAny(text, ["выключи звук", "отключи звук", "без звука", "замьюти звук"]) {
            return await run("set volume with output muted") ? "Звук Mac выключен." : "Не удалось выключить звук."
        }
        if containsAny(text, ["включи звук", "верни звук", "включи громкость", "сними мут"]) {
            return await run("set volume without output muted") ? "Звук Mac включён." : "Не удалось включить звук."
        }
        if containsAny(text, ["громкость на максимум", "громкость 100", "звук на максимум"]) {
            return await run("set volume output volume 100") ? "Громкость установлена на 100 процентов." : "Не удалось изменить громкость."
        }
        if containsAny(text, ["сделай потише", "уменьши громкость", "громкость ниже"]) {
            return await run("set volume output volume (output volume of (get volume settings) - 10)") ? "Уменьшил громкость на 10 процентов." : "Не удалось изменить громкость."
        }
        if containsAny(text, ["сделай погромче", "увеличь громкость", "громкость выше"]) {
            return await run("set volume output volume (output volume of (get volume settings) + 10)") ? "Увеличил громкость на 10 процентов." : "Не удалось изменить громкость."
        }

        if let editor = activeEditorName(), let shortcut = editorShortcut(for: text, editor: editor) {
            let ok = await sendShortcut(shortcut)
            return ok ? shortcut.confirmation : "Не удалось выполнить команду в \(editor). Проверьте разрешение JARVIS на управление компьютером."
        }

        if containsAny(text, ["разрежь клип", "разрезать клип", "разрежь видео", "раздели клип", "сделай разрез", "split clip"]) {
            return "Откройте Premiere Pro, CapCut или DaVinci Resolve и выберите таймлайн. Тогда команда «разрежь клип» выполнит разрез в активном редакторе."
        }
        if containsAny(text, ["удали со сдвигом", "удали и сдвинь", "ripple delete"]) {
            return "Откройте таймлайн в Premiere Pro, CapCut или DaVinci Resolve и выделите фрагмент. После этого повторите команду."
        }
        if containsAny(text, ["поставь метку входа", "метка входа", "поставь метку выхода", "метка выхода"]) {
            return "Метки входа и выхода доступны в режиме монтажа. Активируйте окно таймлайна и повторите команду."
        }

        return nil
    }

    private struct Shortcut {
        let key: String
        let modifiers: String
        let confirmation: String
    }

    private static func editorShortcut(for text: String, editor: String) -> Shortcut? {
        if containsAny(text, ["разрежь клип", "разрежь видео", "раздели клип", "сделай разрез", "split clip"]) {
            let key = editor == "Adobe Premiere Pro" ? "k" : "b"
            return Shortcut(key: key, modifiers: "command down", confirmation: "Выполнил разрез в \(editor).")
        }
        if containsAny(text, ["удали со сдвигом", "удали и сдвинь", "ripple delete"]) {
            let key = editor == "DaVinci Resolve" ? "delete" : "delete"
            let mods = editor == "DaVinci Resolve" ? "shift down" : "shift down"
            return Shortcut(key: key, modifiers: mods, confirmation: "Выполнил удаление со сдвигом в \(editor).")
        }
        if containsAny(text, ["поставь метку входа", "метка входа", "начало фрагмента"]) {
            return Shortcut(key: "i", modifiers: "", confirmation: "Поставил метку входа в \(editor).")
        }
        if containsAny(text, ["поставь метку выхода", "метка выхода", "конец фрагмента"]) {
            return Shortcut(key: "o", modifiers: "", confirmation: "Поставил метку выхода в \(editor).")
        }
        if containsAny(text, ["отмени действие", "отмени последнее", "undo"]) {
            return Shortcut(key: "z", modifiers: "command down", confirmation: "Отменил последнее действие в \(editor).")
        }
        if containsAny(text, ["играй", "пауза", "воспроизведение", "продолжи монтаж"]) {
            return Shortcut(key: "space", modifiers: "", confirmation: "Переключил воспроизведение в \(editor).")
        }
        if containsAny(text, ["экспортируй видео", "экспорт видео", "открой экспорт"]) {
            return Shortcut(key: "m", modifiers: "command down", confirmation: "Открыл экспорт в \(editor). Проверьте параметры перед сохранением.")
        }
        return nil
    }

    private static func activeEditorName() -> String? {
        guard let app = NSWorkspace.shared.frontmostApplication?.localizedName else { return nil }
        if app.localizedCaseInsensitiveContains("Premiere") { return "Adobe Premiere Pro" }
        if app.localizedCaseInsensitiveContains("DaVinci") { return "DaVinci Resolve" }
        if app.localizedCaseInsensitiveContains("CapCut") { return "CapCut" }
        return nil
    }

    private static func sendShortcut(_ shortcut: Shortcut) async -> Bool {
        let modifier = shortcut.modifiers.isEmpty ? "" : " using {\(shortcut.modifiers)}"
        if shortcut.key == "space" {
            return await run("tell application \"System Events\" to key code 49\(modifier)")
        }
        if shortcut.key == "delete" {
            return await run("tell application \"System Events\" to key code 51\(modifier)")
        }
        let escapedKey = shortcut.key.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        return await run("tell application \"System Events\" to keystroke \"\(escapedKey)\"\(modifier)")
    }

    private static func tileFrontWindow(toLeft: Bool) async -> Bool {
        guard let screen = NSScreen.main else { return false }
        let frame = screen.visibleFrame
        let halfWidth = Int(frame.width / 2)
        let height = Int(frame.height)
        let x = toLeft ? Int(frame.minX) : Int(frame.minX) + halfWidth
        let y = Int(screen.frame.height - frame.maxY)
        let script = """
        tell application "System Events"
            tell (first application process whose frontmost is true)
                if (count of windows) is 0 then error "No front window"
                set position of front window to {\(x), \(y)}
                set size of front window to {\(halfWidth), \(height)}
            end tell
        end tell
        """
        return await run(script)
    }

    private static func containsAny(_ text: String, _ phrases: [String]) -> Bool {
        phrases.contains { text.contains($0) }
    }

    @discardableResult
    private static func run(_ script: String) async -> Bool {
        await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", script]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            do { try process.run(); process.waitUntilExit(); return process.terminationStatus == 0 }
            catch { print("[MacCommandAutomation] \(error.localizedDescription)"); return false }
        }.value
    }
}
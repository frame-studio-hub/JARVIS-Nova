import SwiftUI
import AppKit
import ApplicationServices
import Vision
import CoreGraphics

struct ScreenItem: Identifiable {
    let id = UUID()
    let title: String
    let role: String
    let element: AXUIElement
}

@MainActor
final class OperatorCenterModel: ObservableObject {
    @Published var frontApp = "—"
    @Published var frontBundle = ""
    @Published var clipboard: [String] = []
    @Published var screenItems: [ScreenItem] = []
    @Published var screenText: [String] = []
    @Published var command = ""
    @Published var log: [String] = []
    @Published var isScanning = false
    private var pasteboardChange = NSPasteboard.general.changeCount
    private var timer: Timer?

    init() {
        refreshFrontApp()
    }

    func startMonitoring() {
        guard timer == nil else { return }
        refreshFrontApp()
        timer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkClipboard()
                self?.refreshFrontApp()
            }
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    private func setFrontApp(_ app: NSRunningApplication) {
        frontApp = app.localizedName ?? "Неизвестное приложение"
        frontBundle = app.bundleIdentifier ?? ""
    }
    func refreshFrontApp() { if let app = NSWorkspace.shared.frontmostApplication { setFrontApp(app) } }
    private func checkClipboard() {
        let board = NSPasteboard.general
        guard board.changeCount != pasteboardChange else { return }
        pasteboardChange = board.changeCount
        guard let value = board.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return }
        guard clipboard.first != value else { return }
        clipboard.insert(value, at: 0)
        if clipboard.count > 60 { clipboard.removeLast(clipboard.count - 60) }
    }
    func copyBack(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        logAction("Текст возвращён в буфер обмена")
    }
    func scanScreen() {
        // Accessibility tree scanning does not require Screen Recording permission.
        // Never block the whole scan just because screenshot/OCR permission is absent.
        let canCapture = CGPreflightScreenCaptureAccess()
        if !canCapture { logAction("Запись экрана недоступна: продолжаю анализ Accessibility-элементов без OCR") }
        guard let app = NSWorkspace.shared.frontmostApplication else { return }
        isScanning = true
        screenItems = []
        screenText = []
        Task.detached(priority: .userInitiated) { [weak self] in
            let appElement = AXUIElementCreateApplication(app.processIdentifier)
            AXUIElementSetMessagingTimeout(appElement, 0.35)
            var windows: CFTypeRef?
            AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windows)
            let windowList = windows as? [AXUIElement] ?? []
            var found: [ScreenItem] = []
            func walk(_ element: AXUIElement, depth: Int) {
                guard depth < 8, found.count < 160 else { return }
                var roleRef: CFTypeRef?, titleRef: CFTypeRef?, descRef: CFTypeRef?, childrenRef: CFTypeRef?
                AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef)
                AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleRef)
                AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &descRef)
                let role = roleRef as? String ?? ""
                let title = (titleRef as? String).flatMap { $0.isEmpty ? nil : $0 } ?? (descRef as? String ?? "")
                if !title.isEmpty && (["AXButton", "AXLink", "AXTextField", "AXTextArea", "AXCheckBox", "AXPopUpButton", "AXMenuItem", "AXRadioButton"].contains(role)) {
                    found.append(ScreenItem(title: title, role: role, element: element))
                }
                if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
                   let children = childrenRef as? [AXUIElement] {
                    for child in children.prefix(60) { walk(child, depth: depth + 1) }
                }
            }
            for window in windowList.prefix(4) { walk(window, depth: 0) }
            var recognized: [String] = []
            if canCapture, let screen = NSScreen.main,
               let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
               let image = CGDisplayCreateImage(CGDirectDisplayID(number.uint32Value)) {
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .fast
                request.recognitionLanguages = ["ru-RU", "en-US"]
                try? VNImageRequestHandler(cgImage: image).perform([request])
                recognized = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.prefix(100).map { $0 }
            }
            await MainActor.run {
                self?.screenItems = found
                self?.screenText = recognized
                self?.isScanning = false
                self?.logAction("Анализ завершён: приложение \(app.localizedName ?? "активное"), элементов \(found.count), строк OCR \(recognized.count)")
            }
        }
    }
    func press(_ item: ScreenItem) {
        let result = AXUIElementPerformAction(item.element, kAXPressAction as CFString)
        logAction(result == .success ? "Нажат элемент: \(item.title)" : "Не удалось нажать: \(item.title)")
    }
    func runCommand() {
        let raw = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return }
        command = ""
        let lower = raw.lowercased()
        if lower.hasPrefix("найди ") || lower.hasPrefix("поищи ") || lower.hasPrefix("загугли ") {
            let query = raw.replacingOccurrences(of: "^(найди|поищи|загугли)\\s+", with: "", options: [.regularExpression, .caseInsensitive])
            if let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed), let url = URL(string: "https://www.google.com/search?q=\(encoded)") { NSWorkspace.shared.open(url); logAction("Поиск в браузере: \(query)") }
        } else if lower.hasPrefix("открой ") {
            let target = String(raw.dropFirst("открой ".count)).trimmingCharacters(in: .whitespaces)
            if target.contains(".") && !target.contains(" "), let url = URL(string: target.contains("://") ? target : "https://\(target)"), ["http", "https"].contains(url.scheme?.lowercased() ?? "") {
                NSWorkspace.shared.open(url); logAction("Открыт сайт: \(target)")
            } else {
                let names = ["telegram": "Telegram", "телеграм": "Telegram", "chrome": "Google Chrome", "хром": "Google Chrome", "finder": "Finder", "файндер": "Finder", "safari": "Safari"]
                let appName = names[target.lowercased()] ?? target
                let process = Process(); process.executableURL = URL(fileURLWithPath: "/usr/bin/open"); process.arguments = ["-a", appName]
                do { try process.run(); logAction("Запускаю приложение: \(appName)") } catch { logAction("Не удалось открыть \(appName)") }
            }
        } else if lower.hasPrefix("нажми ") {
            let target = String(raw.dropFirst("нажми ".count)).lowercased()
            if let item = screenItems.first(where: { $0.title.localizedCaseInsensitiveContains(target) }) { press(item) }
            else { logAction("Элемент «\(target)» не найден. Сначала нажми «Сканировать экран».") }
        } else if lower.hasPrefix("скопируй ") {
            let value = String(raw.dropFirst("скопируй ".count)); copyBack(value)
        } else {
            logAction("Команда не распознана. Используй: открой…, найди…, нажми…")
        }
    }
    func logAction(_ value: String) {
        let time = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .short)
        log.insert("\(time)  \(value)", at: 0)
        if log.count > 30 { log.removeLast(log.count - 30) }
    }
}

struct OperatorCenterView: View {
    @StateObject private var model = OperatorCenterModel()
    private let accent = Color(red: 0.76, green: 1, blue: 0.02)
    @State private var selectedTab = "Оператор"
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .center, spacing: 14) {
                    RoundedRectangle(cornerRadius: 2).fill(accent).frame(width: 3, height: 48)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("JARVIS NOVA  /  DESKTOP") .font(.system(size: 9, weight: .bold, design: .monospaced)).tracking(1.7).foregroundStyle(accent)
                        Text("Центр управления").font(.system(size: 32, weight: .bold, design: .rounded)).tracking(-0.8)
                        Text("Экран, приложения, команды и буфер обмена — в одном месте").font(.system(size: 12)).foregroundStyle(.white.opacity(0.5))
                    }
                    Spacer()
                    HStack(spacing: 7) { Circle().fill(accent).frame(width: 7, height: 7); Text("АКТИВЕН").font(.system(size: 9, weight: .bold, design: .monospaced)).tracking(0.8) }
                        .foregroundStyle(accent).padding(.horizontal, 12).padding(.vertical, 9).background(accent.opacity(0.08), in: Capsule()).overlay(Capsule().stroke(accent.opacity(0.2), lineWidth: 1))
                }
                HStack(spacing: 8) {
                    tab("Оператор", "command")
                    tab("Экран", "viewfinder")
                    tab("Буфер", "doc.on.clipboard")
                    tab("Приложения", "macwindow")
                }
                Group {
                    if selectedTab == "Оператор" { operatorPanel }
                    else if selectedTab == "Экран" { screenPanel }
                    else if selectedTab == "Буфер" { clipboardPanel }
                    else { contextPanel }
                }
                .id(selectedTab)
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
                .animation(.spring(response: 0.42, dampingFraction: 0.86), value: selectedTab)
                panel("ЖУРНАЛ ОПЕРАЦИЙ", icon: "list.bullet.rectangle") {
                    if model.log.isEmpty { Text("Здесь появятся выполненные действия").font(.system(size: 11)).foregroundStyle(.white.opacity(0.4)) }
                    ForEach(model.log, id: \.self) { line in Text(line).font(.system(size: 10, design: .monospaced)).foregroundStyle(.white.opacity(0.7)).frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 3).transition(.move(edge: .top).combined(with: .opacity)) }
                }
            }.padding(24).frame(maxWidth: 1000, alignment: .leading).frame(maxWidth: .infinity, alignment: .leading)
        }.preferredColorScheme(.dark)
            .onAppear { model.startMonitoring() }
            .onDisappear { model.stopMonitoring() }
            .animation(.spring(response: 0.36, dampingFraction: 0.84), value: model.isScanning)
            .animation(.spring(response: 0.34, dampingFraction: 0.82), value: model.clipboard.count)
            .animation(.spring(response: 0.34, dampingFraction: 0.82), value: model.log.count)
    }
    private var operatorPanel: some View {
        panel("КОМАНДНЫЙ РЕЖИМ", icon: "terminal") {
            Text("Пиши короткие команды. JARVIS откроет сайты и приложения, выполнит поиск или нажмёт найденный элемент интерфейса.").font(.system(size: 11)).foregroundStyle(.white.opacity(0.55))
            HStack {
                TextField("Например: открой youtube.com / найди лучшие микрофоны / нажми Войти", text: $model.command).textFieldStyle(.roundedBorder).onSubmit { model.runCommand() }
                Button("ВЫПОЛНИТЬ") { model.runCommand() }.buttonStyle(.borderedProminent).tint(accent).foregroundStyle(.black)
            }
            Text("Пока поддерживаются безопасные базовые действия; отправка форм и публикация требуют отдельного подтверждения.").font(.system(size: 10)).foregroundStyle(.orange.opacity(0.8))
        }
    }
    private var screenPanel: some View {
        panel("РАСПОЗНАВАНИЕ ЭКРАНА", icon: "viewfinder") {
            HStack {
                Text("Элементы активного окна: \(model.screenItems.count) • OCR: \(model.screenText.count)").font(.system(size: 11)).foregroundStyle(.white.opacity(0.6))
                Spacer()
                Button { model.scanScreen() } label: { Label(model.isScanning ? "СКАНИРУЮ…" : "СКАНИРОВАТЬ", systemImage: "viewfinder") }.buttonStyle(.borderedProminent).tint(accent).foregroundStyle(.black).disabled(model.isScanning)
            }
            if model.isScanning {
                HStack(spacing: 10) { ProgressView().controlSize(.small).tint(accent); Text("Анализирую структуру окна и доступные элементы…").font(.system(size: 11)).foregroundStyle(.white.opacity(0.58)); Spacer() }.padding(12).background(accent.opacity(0.06), in: RoundedRectangle(cornerRadius: 10)).transition(.opacity.combined(with: .move(edge: .top)))
            }
            if !model.screenItems.isEmpty {
                ForEach(model.screenItems) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) { Text(item.title).font(.system(size: 12, weight: .medium)); Text(item.role).font(.system(size: 9, design: .monospaced)).foregroundStyle(.white.opacity(0.4)) }
                        Spacer()
                        Button("НАЖАТЬ") { model.press(item) }.buttonStyle(.bordered).tint(accent)
                    }.padding(.vertical, 4)
                }
            }
            if !model.screenText.isEmpty {
                Divider().overlay(.white.opacity(0.1))
                Text("ТЕКСТ НА ЭКРАНЕ (OCR)").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(accent)
                ForEach(Array(model.screenText.prefix(35).enumerated()), id: \.offset) { _, text in Text(text).font(.system(size: 10)).foregroundStyle(.white.opacity(0.7)) }
            }
            if model.screenItems.isEmpty && model.screenText.isEmpty { Text("Нажми «Сканировать», чтобы получить доступные кнопки, поля и текст активного экрана.").font(.system(size: 11)).foregroundStyle(.white.opacity(0.45)) }
        }
    }
    private var clipboardPanel: some View {
        panel("ИСТОРИЯ БУФЕРА ОБМЕНА", icon: "doc.on.clipboard") {
            Text("JARVIS отслеживает текстовый буфер обмена, пока приложение запущено. История хранится только в памяти текущего сеанса.").font(.system(size: 11)).foregroundStyle(.white.opacity(0.5))
            if model.clipboard.isEmpty { Text("Скопируй любой текст — он появится здесь.").font(.system(size: 12)).foregroundStyle(.white.opacity(0.4)) }
            ForEach(Array(model.clipboard.enumerated()), id: \.offset) { index, value in
                HStack(alignment: .top) {
                    Text(value).font(.system(size: 11)).lineLimit(3).frame(maxWidth: .infinity, alignment: .leading)
                    Button { model.copyBack(value) } label: { Image(systemName: "doc.on.doc") }.buttonStyle(.bordered).tint(accent).help("Вернуть в буфер")
                }.padding(10).background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 8)).transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .opacity))
            }
        }.animation(.spring(response: 0.38, dampingFraction: 0.84), value: model.clipboard)
    }
    private var contextPanel: some View {
        panel("АКТИВНОЕ ПРИЛОЖЕНИЕ", icon: "macwindow") {
            HStack(spacing: 12) {
                Image(systemName: "app.fill").font(.system(size: 27)).foregroundStyle(accent)
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.frontApp).font(.system(size: 19, weight: .semibold))
                    Text(model.frontBundle.isEmpty ? "Bundle ID недоступен" : model.frontBundle).font(.system(size: 10, design: .monospaced)).foregroundStyle(.white.opacity(0.45))
                }
                Spacer()
                Button("ОБНОВИТЬ") { model.refreshFrontApp() }.buttonStyle(.bordered).tint(accent)
            }
            Divider().overlay(.white.opacity(0.1))
            Text("Контекст автоматически обновляется при переключении между приложениями. Эти данные можно использовать как контекст для следующих голосовых команд.").font(.system(size: 11)).foregroundStyle(.white.opacity(0.55))
        }
    }
    private func tab(_ title: String, _ icon: String) -> some View {
        Button { selectedTab = title; if title == "Приложения" { model.refreshFrontApp() } } label: {
            Label(title, systemImage: icon).font(.system(size: 10, weight: .semibold)).frame(maxWidth: .infinity).padding(.vertical, 10)
                .background(selectedTab == title ? accent.opacity(0.16) : .white.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(selectedTab == title ? accent.opacity(0.45) : .white.opacity(0.08)))
        }.buttonStyle(.plain).foregroundStyle(selectedTab == title ? accent : .white.opacity(0.65)).animation(.spring(response:0.3,dampingFraction:0.78),value:selectedTab)
    }
    private func panel<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            Label(title, systemImage: icon).font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(1).foregroundStyle(accent)
            content()
        }.padding(21).frame(maxWidth: .infinity, alignment: .leading)
            .background(LinearGradient(colors:[Color.white.opacity(0.075),Color.white.opacity(0.022)],startPoint:.topLeading,endPoint:.bottomTrailing),in:RoundedRectangle(cornerRadius:20))
            .overlay(RoundedRectangle(cornerRadius:20).stroke(LinearGradient(colors:[.white.opacity(0.14),accent.opacity(0.13),.white.opacity(0.03)],startPoint:.topLeading,endPoint:.bottomTrailing),lineWidth:1))
            .shadow(color:.black.opacity(0.2),radius:18,y:9)
    }
}
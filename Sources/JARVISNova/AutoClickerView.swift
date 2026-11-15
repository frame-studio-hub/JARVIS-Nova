import SwiftUI
import AppKit
import ApplicationServices

@MainActor
final class NovaAutoClickerModel: ObservableObject {
    enum ButtonKind: String, CaseIterable, Identifiable {
        case left = "Левая"
        case right = "Правая"
        var id: String { rawValue }
        var cg: CGMouseButton { self == .left ? .left : .right }
        var down: CGEventType { self == .left ? .leftMouseDown : .rightMouseDown }
        var up: CGEventType { self == .left ? .leftMouseUp : .rightMouseUp }
    }

    @Published var button: ButtonKind = .left
    @Published var clicksPerSecond = 10.0
    @Published var clickLimit = 0 // 0 = until stopped
    @Published private(set) var isRunning = false
    @Published private(set) var clicksDone = 0
    @Published private(set) var status = "ГОТОВ К РАБОТЕ"
    @Published private(set) var startedAt: Date?
    private var worker: Task<Void, Never>?
    private var runID = UUID()

    var intervalLabel: String { String(format: "%.3f сек", 1.0 / max(1, clicksPerSecond)) }
    var limitLabel: String { clickLimit == 0 ? "Без ограничений" : "\(clickLimit) кликов" }

    func start() {
        guard !isRunning else { return }
        guard AXIsProcessTrusted() else {
            status = "НУЖНО РАЗРЕШЕНИЕ ДОСТУПНОСТИ"
            let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
            return
        }
        runID = UUID()
        let id = runID
        clicksDone = 0
        startedAt = Date()
        isRunning = true
        status = "АВТОКЛИКЕР АКТИВЕН"
        let selectedButton = button
        let cps = min(50, max(1, clicksPerSecond))
        let limit = max(0, clickLimit)
        worker = Task.detached(priority: .userInitiated) { [weak self] in
            let interval = UInt64(1_000_000_000 / cps)
            while !Task.isCancelled {
                guard await self?.isCurrent(id) == true else { break }
                let point = CGEvent(source: nil)?.location ?? .zero
                if let down = CGEvent(mouseEventSource: nil, mouseType: selectedButton.down, mouseCursorPosition: point, mouseButton: selectedButton.cg),
                   let up = CGEvent(mouseEventSource: nil, mouseType: selectedButton.up, mouseCursorPosition: point, mouseButton: selectedButton.cg) {
                    down.post(tap: .cghidEventTap)
                    up.post(tap: .cghidEventTap)
                    let count = await self?.recordClick(id) ?? 0
                    if limit > 0 && count >= limit { break }
                } else { break }
                try? await Task.sleep(nanoseconds: interval)
            }
            await self?.finish(id)
        }
    }

    func stop() {
        guard isRunning else { return }
        worker?.cancel()
        worker = nil
        isRunning = false
        status = "ОСТАНОВЛЕН"
    }

    private func isCurrent(_ id: UUID) -> Bool { isRunning && runID == id }
    private func recordClick(_ id: UUID) -> Int {
        guard isRunning, runID == id else { return clicksDone }
        clicksDone += 1
        return clicksDone
    }
    private func finish(_ id: UUID) {
        guard runID == id else { return }
        worker = nil
        isRunning = false
        status = clickLimit > 0 && clicksDone >= clickLimit ? "ЛИМИТ ВЫПОЛНЕН" : "ОСТАНОВЛЕН"
    }

    deinit { worker?.cancel() }
}

struct AutoClickerView: View {
    @StateObject private var model = NovaAutoClickerModel()
    @State private var pulse = false
    @State private var appeared = false
    private let green = Color(red: 0.36, green: 1.0, blue: 0.015)

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 7) {
                        Label("JARVIS / INPUT AUTOMATION", systemImage: "cursorarrow.click")
                            .font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(1.5).foregroundStyle(green)
                        Text("Автокликер")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                        Text("Управление кликами мыши с точным интервалом")
                            .font(.system(size: 13)).foregroundStyle(.white.opacity(0.52))
                    }
                    Spacer()
                    ZStack {
                        Circle().stroke(green.opacity(model.isRunning ? (pulse ? 0.65 : 0.12) : 0.22), lineWidth: 1.5).frame(width: pulse && model.isRunning ? 108 : 92, height: pulse && model.isRunning ? 108 : 92)
                        Circle().fill(model.isRunning ? green.opacity(pulse ? 0.22 : 0.08) : .white.opacity(0.04)).frame(width: 70, height: 70)
                        Image(systemName: "cursorarrow.click").font(.system(size: 28, weight: .light)).foregroundStyle(model.isRunning ? green : .white.opacity(0.7)).scaleEffect(model.isRunning && pulse ? 1.12 : 1)
                    }
                    .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulse)
                    .onAppear { pulse = true }
                }
                panel {
                    HStack {
                        Label("СОСТОЯНИЕ СИСТЕМЫ", systemImage: "dot.radiowaves.left.and.right")
                            .font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(.white.opacity(0.55))
                        Spacer()
                        Circle().fill(model.isRunning ? green : .white.opacity(0.3)).frame(width: 7, height: 7)
                        Text(model.status).font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(model.isRunning ? green : .white.opacity(0.65))
                    }
                    Divider().overlay(.white.opacity(0.08))
                    HStack(spacing: 0) {
                        stat("ВЫПОЛНЕНО КЛИКОВ", "\(model.clicksDone)")
                        Spacer()
                        stat("ИНТЕРВАЛ", model.intervalLabel)
                        Spacer()
                        stat("РЕЖИМ", model.clickLimit == 0 ? "∞" : "ЛИМИТ")
                    }
                    if model.clickLimit > 0 {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack { Text("ПРОГРЕСС ЛИМИТА").font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundStyle(.white.opacity(0.42)); Spacer(); Text("\(min(model.clicksDone, model.clickLimit)) / \(model.clickLimit)").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(green).contentTransition(.numericText()) }
                            GeometryReader { geo in ZStack(alignment: .leading) { Capsule().fill(.white.opacity(0.07)); Capsule().fill(LinearGradient(colors: [green.opacity(0.65), green], startPoint: .leading, endPoint: .trailing)).frame(width: geo.size.width * min(1, Double(model.clicksDone) / Double(max(1, model.clickLimit)))) }.clipShape(Capsule()) }.frame(height: 7)
                        }.transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    HStack(spacing: 8) {
                        Image(systemName: AXIsProcessTrusted() ? "checkmark.shield.fill" : "lock.fill").foregroundStyle(AXIsProcessTrusted() ? green : .orange)
                        Text(AXIsProcessTrusted() ? "Универсальный доступ разрешён" : "Нужно разрешение Универсального доступа").font(.system(size: 10)).foregroundStyle(.white.opacity(0.58))
                        Spacer()
                        if !AXIsProcessTrusted() { Button("ОТКРЫТЬ") { let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!; NSWorkspace.shared.open(url) }.buttonStyle(.bordered).tint(.orange) }
                    }
                }
                panel {
                    sectionTitle("01", "ПАРАМЕТРЫ КЛИКА")
                    HStack {
                        Text("Кнопка мыши").font(.system(size: 12, weight: .medium))
                        Spacer()
                        Picker("Кнопка", selection: $model.button) {
                            ForEach(NovaAutoClickerModel.ButtonKind.allCases) { item in Text(item.rawValue).tag(item) }
                        }.pickerStyle(.segmented).frame(width: 190).disabled(model.isRunning)
                    }
                    Divider().overlay(.white.opacity(0.07))
                    VStack(alignment: .leading, spacing: 9) {
                        HStack { Text("Скорость кликов").font(.system(size: 12, weight: .medium)); Spacer(); Text("\(Int(model.clicksPerSecond)) CPS").font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundStyle(green) }
                        Slider(value: $model.clicksPerSecond, in: 1...50, step: 1).tint(green).disabled(model.isRunning)
                        HStack { Text("1 клик/сек"); Spacer(); Text("50 кликов/сек") }.font(.system(size: 9, design: .monospaced)).foregroundStyle(.white.opacity(0.35))
                    }
                    Divider().overlay(.white.opacity(0.07))
                    VStack(alignment: .leading, spacing: 9) {
                        HStack { Text("Количество кликов").font(.system(size: 12, weight: .medium)); Spacer(); Text(model.clickLimit == 0 ? "∞" : "\(model.clickLimit)").font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundStyle(green) }
                        Slider(value: Binding(get: { Double(model.clickLimit) }, set: { model.clickLimit = Int($0) }), in: 0...5000, step: 50).tint(green).disabled(model.isRunning)
                        HStack { Text("0 — бесконечно"); Spacer(); Text("5000 максимум") }.font(.system(size: 9, design: .monospaced)).foregroundStyle(.white.opacity(0.35))
                    }
                }
                HStack(spacing: 12) {
                    Button { model.start() } label: {
                        Label("ЗАПУСТИТЬ", systemImage: "play.fill").font(.system(size: 12, weight: .black, design: .monospaced)).frame(maxWidth: .infinity).frame(height: 52)
                    }.buttonStyle(.borderedProminent).tint(green).foregroundStyle(.black).disabled(model.isRunning)
                    Button { model.stop() } label: {
                        Label("ОСТАНОВИТЬ", systemImage: "stop.fill").font(.system(size: 12, weight: .black, design: .monospaced)).frame(maxWidth: .infinity).frame(height: 52)
                    }.buttonStyle(.bordered).tint(.red).disabled(!model.isRunning)
                }
                panel {
                    Label("КАК ЭТО РАБОТАЕТ", systemImage: "info.circle").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(green)
                    Text("1. Наведи курсор на нужную точку.  2. Выбери левую или правую кнопку.  3. Настрой частоту и лимит.  4. Нажми «Запустить». Клики будут выполняться в текущем положении курсора — не двигай мышь во время работы.")
                        .font(.system(size: 11)).foregroundStyle(.white.opacity(0.62)).fixedSize(horizontal: false, vertical: true)
                    Text("Для отправки кликов macOS требуется разрешение Универсального доступа для JARVIS.")
                        .font(.system(size: 10)).foregroundStyle(.white.opacity(0.38)).fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(26).frame(maxWidth: 900, alignment: .leading).frame(maxWidth: .infinity, alignment: .leading)
        }
        .onDisappear { model.stop() }
        .onAppear { withAnimation(.spring(response: 0.55, dampingFraction: 0.82).delay(0.08)) { appeared = true }; pulse = true }
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: model.isRunning)
        .animation(.spring(response: 0.34, dampingFraction: 0.8), value: model.clicksDone)
        .animation(.spring(response: 0.36, dampingFraction: 0.82), value: model.clickLimit)
        .opacity(appeared ? 1 : 0.88).offset(y: appeared ? 0 : 9)
        .preferredColorScheme(.dark)
    }

    private func panel<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 15, content: content)
            .padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 20)
                    .fill(LinearGradient(colors: [Color.white.opacity(0.085), Color.white.opacity(0.025)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(alignment: .topTrailing) { Circle().fill(green.opacity(0.07)).frame(width: 130, height: 130).blur(radius: 38).offset(x: 25, y: -45) }
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(LinearGradient(colors: [.white.opacity(0.15), green.opacity(0.17), .white.opacity(0.035)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
            .shadow(color: .black.opacity(0.22), radius: 18, y: 9)
    }
    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundStyle(.white.opacity(0.42))
            Text(value).font(.system(size: 19, weight: .semibold, design: .rounded)).monospacedDigit().foregroundStyle(green)
        }
    }
    private func sectionTitle(_ number: String, _ title: String) -> some View {
        HStack(spacing: 9) { Text(number).foregroundStyle(green); Text(title).foregroundStyle(.white.opacity(0.85)) }
            .font(.system(size: 9, weight: .black, design: .monospaced)).tracking(1.2)
    }
}
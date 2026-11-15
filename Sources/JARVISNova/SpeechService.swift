import Foundation
@preconcurrency import Speech
import AVFoundation
import AppKit

private final class SpeechAudioRequestBox: @unchecked Sendable {
    let request: SFSpeechAudioBufferRecognitionRequest

    init(_ request: SFSpeechAudioBufferRecognitionRequest) {
        self.request = request
    }

    func append(_ buffer: AVAudioPCMBuffer) {
        request.append(buffer)
    }
}

@MainActor
final class SpeechService: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var message = "Голосовой ввод готов"

    var onTranscript: ((String) -> Void)?

    private let engine = AVAudioEngine()
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "ru-RU"))
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var recordingID = UUID()
    private var buttonHeld = false
    private var latestTranscript = ""

    func startRecording() {
        print("JARVIS DEBUG: startRecording, buttonHeld =", buttonHeld)
        guard !buttonHeld else { print("JARVIS DEBUG: запуск заблокирован"); return }

        let id = UUID()
        recordingID = id
        buttonHeld = true
        latestTranscript = ""

        task?.cancel()
        task = nil
        request = nil

        if engine.isRunning {
            engine.stop()
        }
        engine.inputNode.removeTap(onBus: 0)
        isRecording = false
        message = "Подготовка микрофона…"

        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        guard speechStatus == .authorized || speechStatus == .notDetermined else {
            buttonHeld = false
            message = "Нет разрешения на распознавание речи. Открой Настройки → Конфиденциальность и безопасность → Распознавание речи → JARVIS."
            openPrivacySettings("Privacy_SpeechRecognition")
            return
        }

        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        NSLog("JARVIS MIC: start request; microphone authorization=%ld speech authorization=%ld", micStatus.rawValue, speechStatus.rawValue)
        switch micStatus {
        case .denied, .restricted:
            buttonHeld = false
            message = "Доступ к микрофону запрещён macOS. Открой Настройки → Конфиденциальность и безопасность → Микрофон → включи JARVIS."
            openPrivacySettings("Privacy_Microphone")
            return
        case .authorized:
            requestSpeechAuthorizationAndStart(id: id)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                Task { @MainActor in
                    guard let self, self.recordingID == id, self.buttonHeld else { return }
                    guard granted else {
                        self.buttonHeld = false
                        self.message = "macOS не разрешила микрофон. Включи JARVIS в Настройки → Конфиденциальность и безопасность → Микрофон."
                        self.openPrivacySettings("Privacy_Microphone")
                        return
                    }
                    self.requestSpeechAuthorizationAndStart(id: id)
                }
            }
        @unknown default:
            buttonHeld = false
            message = "Не удалось определить разрешение микрофона."
        }
    }

    private func requestSpeechAuthorizationAndStart(id: UUID) {
        let status = SFSpeechRecognizer.authorizationStatus()
        if status == .authorized {
            beginRecording(id: id)
            return
        }
        guard status == .notDetermined else {
            buttonHeld = false
            message = "Нет разрешения на распознавание речи. Включи JARVIS в настройках macOS."
            openPrivacySettings("Privacy_SpeechRecognition")
            return
        }
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor in
                guard let self, self.recordingID == id, self.buttonHeld else { return }
                guard status == .authorized else {
                    self.buttonHeld = false
                    self.message = "Микрофон разрешён, но распознавание речи запрещено. Включи JARVIS в настройках macOS."
                    self.openPrivacySettings("Privacy_SpeechRecognition")
                    return
                }
                self.beginRecording(id: id)
            }
        }
    }

    private func openPrivacySettings(_ pane: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity?\(pane)") {
            NSWorkspace.shared.open(url)
        }
    }

    private func beginRecording(id: UUID) {
        guard buttonHeld, recordingID == id else { return }

        guard let recognizer, recognizer.isAvailable else {
            buttonHeld = false
            message = "Распознавание речи сейчас недоступно"
            return
        }

        do {
            let audioRequest = SFSpeechAudioBufferRecognitionRequest()
            audioRequest.shouldReportPartialResults = true
            request = audioRequest
            let audioRequestBox = SpeechAudioRequestBox(audioRequest)

            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)

            input.removeTap(onBus: 0)
            input.installTap(onBus: 0, bufferSize: 1024, format: format) {
                @Sendable buffer, _ in
                audioRequestBox.append(buffer)
            }

            engine.prepare()
            try engine.start()

            isRecording = true
            message = "Слушаю… отпусти кнопку, когда закончишь"
            NSLog("JARVIS MIC: audio engine started successfully")

            task = recognizer.recognitionTask(with: audioRequest) {
                @Sendable [weak self] result, error in

                let text = result?.bestTranscription.formattedString
                let isFinal = result?.isFinal ?? false
                let failed = error != nil

                Task { @MainActor in
                    guard let self, self.recordingID == id else { return }

                    if let text {
                        self.latestTranscript = text
                    }

                    if isFinal || failed {
                        self.finishTranscript(self.latestTranscript, id: id)
                    }
                }
            }
        } catch {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
            isRecording = false
            buttonHeld = false
            request = nil
            task?.cancel()
            task = nil
            message = "Не удалось запустить микрофон: \(error.localizedDescription)"
            NSLog("JARVIS MIC ERROR: \(error.localizedDescription)")
        }
    }

    func stopRecording() {
        print("JARVIS DEBUG: stopRecording, buttonHeld =", buttonHeld, "isRecording =", isRecording)
        guard buttonHeld else { print("JARVIS DEBUG: остановка пропущена"); return }
        buttonHeld = false

        guard isRecording else {
            recordingID = UUID()
            task?.cancel()
            task = nil
            request = nil
            message = "Запись отменена"
            return
        }

        isRecording = false
        message = "Распознаю речь…"

        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()

        // Give Speech.framework time to deliver its final hypothesis after endAudio.
        // The final callback wins immediately; this timeout is only a fallback.
        let stoppedID = recordingID
        Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(2200))
            } catch {
                return
            }
            guard let self, self.recordingID == stoppedID, !self.buttonHeld else { return }
            let latest = self.latestTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
            self.finishTranscript(latest, id: stoppedID)
        }
    }

    private func finishTranscript(_ text: String, id: UUID) {
        guard recordingID == id else { return }

        recordingID = UUID()
        buttonHeld = false

        if engine.isRunning {
            engine.stop()
        }
        engine.inputNode.removeTap(onBus: 0)

        isRecording = false
        task?.cancel()
        task = nil
        request = nil

        let phrase = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !phrase.isEmpty else {
            message = "Речь не распознана. Попробуй ещё раз."
            return
        }

        message = "Распознано: \(phrase)"
        onTranscript?(phrase)
    }
}
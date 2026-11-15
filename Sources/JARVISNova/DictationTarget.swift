import Foundation
import AppKit
import ApplicationServices
import CoreGraphics

@MainActor
final class DictationTarget {
    static let shared = DictationTarget()

    private var application: NSRunningApplication?
    private var capturedAppName = ""
    private var capturedPID: pid_t = 0
    private var lastExternalApplication: NSRunningApplication?
    private var activationObserver: NSObjectProtocol?

    private init() {
        if let current = NSWorkspace.shared.frontmostApplication,
           current.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            lastExternalApplication = current
        }
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.processIdentifier != ProcessInfo.processInfo.processIdentifier,
                  app.activationPolicy == .regular,
                  !app.isTerminated else { return }
            Task { @MainActor in
                self?.lastExternalApplication = app
                self?.log("LAST_EXTERNAL app=\(app.localizedName ?? "unknown") pid=\(app.processIdentifier)")
            }
        }
    }

    private func log(_ message: String) {
        let line = "\(ISO8601DateFormatter().string(from: Date())) \(message)\n"
        let url = URL(fileURLWithPath: "/tmp/jarvis-dictation.log")
        if let data = line.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: url.path), let h = try? FileHandle(forWritingTo: url) {
                defer { try? h.close() }; _ = try? h.seekToEnd(); try? h.write(contentsOf: data)
            } else { try? data.write(to: url, options: .atomic) }
        }
    }

    var isExternalTarget: Bool {
        guard capturedPID != 0 else { return false }
        return capturedPID != ProcessInfo.processInfo.processIdentifier
    }

    /// Clears a previously captured external dictation target so the in-app microphone
    /// routes the recognized phrase to JARVIS instead of pasting it into another app.
    func clear() {
        application = nil
        capturedAppName = ""
        capturedPID = 0
        log("CLEAR target; voice input will be routed to JARVIS")
    }

    @discardableResult
    func capture() -> Bool {
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let frontmost = NSWorkspace.shared.frontmostApplication
        let target: NSRunningApplication?
        if let frontmost,
           frontmost.processIdentifier != ownPID,
           frontmost.activationPolicy == .regular,
           !frontmost.isTerminated {
            target = frontmost
            lastExternalApplication = frontmost
        } else {
            // Ignore macOS agents such as Notification Center, Dock and Control Center.
            target = lastExternalApplication
        }
        guard let app = target, !app.isTerminated else {
            log("CAPTURE FAILED: no external frontmost app; frontmost=\(frontmost?.localizedName ?? "none")")
            return false
        }
        application = app
        capturedPID = app.processIdentifier
        capturedAppName = app.localizedName ?? "Неизвестное приложение"
        log("CAPTURE app=\(capturedAppName) pid=\(capturedPID) self=\(ownPID) frontmost=\(frontmost?.localizedName ?? "none") accessibility=\(AXIsProcessTrusted())")
        print("[Dictation] Цель диктовки сохранена: \(capturedAppName), pid=\(capturedPID)")
        return true
    }

    @discardableResult
    func insert(_ text: String) -> Bool {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return false }
        log("INSERT requested chars=\(value.count) target=\(capturedAppName) pid=\(capturedPID) frontmost=\(NSWorkspace.shared.frontmostApplication?.processIdentifier ?? -1) accessibility=\(AXIsProcessTrusted())")
        guard let app = application, !app.isTerminated, app.processIdentifier == capturedPID else {
            print("[Dictation] Сохранённое приложение недоступно")
            return false
        }

        // Keyboard event posting has its own macOS permission check. Do not
        // confuse it with AXIsProcessTrusted(): AX access may be unavailable
        // while CGEvent posting is still authorized.
        guard CGPreflightPostEventAccess() else {
            log("BLOCKED: Post Event access missing; requesting permission")
            _ = CGRequestPostEventAccess()
            return false
        }

        // Use paste instead of AXValue: setting AXValue replaces the entire contents
        // of many text fields and often fails for Chromium/web editors and Telegram.
        let pasteboard = NSPasteboard.general
        let previousString = pasteboard.string(forType: .string)
        pasteboard.clearContents()
        guard pasteboard.setString(value, forType: .string) else {
            print("[Dictation] Не удалось поместить текст в буфер обмена")
            return false
        }

        // Restore the app that was active when the user pressed the mouse button.
        if NSWorkspace.shared.frontmostApplication?.processIdentifier != capturedPID {
            app.activate(options: [.activateAllWindows])
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            guard !app.isTerminated else { return }
            guard NSWorkspace.shared.frontmostApplication?.processIdentifier == self.capturedPID else {
                self.log("BLOCKED: target did not become frontmost; target=\(self.capturedAppName) current=\(NSWorkspace.shared.frontmostApplication?.localizedName ?? "unknown")")
                return
            }
            let source = CGEventSource(stateID: .combinedSessionState)
            guard let down = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
                  let up = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) else {
                print("[Dictation] Не удалось создать событие Cmd+V")
                return
            }
            down.flags = .maskCommand
            up.flags = .maskCommand
            down.post(tap: .cghidEventTap)
            up.post(tap: .cghidEventTap)
            self.log("POSTED Cmd+V target=\(self.capturedAppName) frontmostNow=\(NSWorkspace.shared.frontmostApplication?.localizedName ?? "unknown")")

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                if pasteboard.string(forType: .string) == value {
                    pasteboard.clearContents()
                    if let previousString { pasteboard.setString(previousString, forType: .string) }
                }
            }
            print("[Dictation] Cmd+V отправлен в \(self.capturedAppName)")
        }
        return true
    }
}
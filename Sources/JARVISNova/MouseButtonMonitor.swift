import Foundation
import AppKit
import ApplicationServices
import CoreGraphics

final class MouseButtonMonitor: @unchecked Sendable {
    static let shared = MouseButtonMonitor()

    var onButtonDown: (@Sendable (Int64) -> Void)?
    var onButtonUp: (@Sendable (Int64) -> Void)?

    private let lock = NSLock()
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var started = false
    private let diagnosticURL = URL(fileURLWithPath: "/tmp/jarvis-input-diagnostic.log")
    // File I/O must never run inside the CoreGraphics event-tap callback.
    private let diagnosticQueue = DispatchQueue(label: "com.jarvis.input-diagnostics", qos: .utility)

    private func diagnostic(_ message: String) {
        let line = "\(ISO8601DateFormatter().string(from: Date())) \(message)\n"
        guard let data = line.data(using: .utf8) else { return }
        if FileManager.default.fileExists(atPath: diagnosticURL.path),
           let handle = try? FileHandle(forWritingTo: diagnosticURL) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: diagnosticURL, options: .atomic)
        }
    }

    func start() {
        lock.lock()
        guard !started else { lock.unlock(); return }
        started = true
        lock.unlock()

        let hasInputMonitoring = CGPreflightListenEventAccess()
        diagnostic("START monitor; Input Monitoring=\(hasInputMonitoring)")
        NSLog("JARVIS INPUT: запуск монитора; Input Monitoring=%@", hasInputMonitoring ? "granted" : "not granted")
        if !hasInputMonitoring {
            _ = CGRequestListenEventAccess()
        }
        // Request permission to synthesize keyboard events at launch, rather
        // than silently failing only after a dictation has already completed.
        let hasPostEventAccess = CGPreflightPostEventAccess()
        diagnostic("START monitor; Post Event=\(hasPostEventAccess)")
        if !hasPostEventAccess {
            _ = CGRequestPostEventAccess()
        }
        // Session-level tap is the supported user-process tap for global mouse events.
        // HID-level taps can silently fail for ordinary, non-root GUI applications.
        installEventTap()
    }

    private func installEventTap() {
        let mask = (CGEventMask(1) << CGEventType.otherMouseDown.rawValue) |
                   (CGEventMask(1) << CGEventType.otherMouseUp.rawValue) |
                   (CGEventMask(1) << CGEventType.leftMouseDown.rawValue) |
                   (CGEventMask(1) << CGEventType.leftMouseUp.rawValue) |
                   (CGEventMask(1) << CGEventType.rightMouseDown.rawValue) |
                   (CGEventMask(1) << CGEventType.rightMouseUp.rawValue)
        let info = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { proxy, type, event, userInfo in
                guard let userInfo else { return Unmanaged.passUnretained(event) }
                let monitor = Unmanaged<MouseButtonMonitor>.fromOpaque(userInfo).takeUnretainedValue()
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    monitor.diagnosticQueue.async {
                        monitor.diagnostic("TAP DISABLED type=\(type.rawValue); trying re-enable")
                    }
                    monitor.reenableEventTap()
                    return Unmanaged.passUnretained(event)
                }
                // Log ordinary clicks asynchronously: preserve the requested
                // click history without blocking the system event-tap callback.
                if type == .leftMouseDown || type == .leftMouseUp ||
                   type == .rightMouseDown || type == .rightMouseUp {
                    let name = (type == .leftMouseDown || type == .leftMouseUp) ? "LEFT" : "RIGHT"
                    let phase = (type == .leftMouseDown || type == .rightMouseDown) ? "DOWN" : "UP"
                    monitor.diagnosticQueue.async {
                        monitor.diagnostic("MOUSE CLICK \(name) \(phase)")
                    }
                } else if type == .otherMouseDown || type == .otherMouseUp {
                    let button = event.getIntegerValueField(.mouseEventButtonNumber)
                    monitor.handleButton(button, isDown: type == .otherMouseDown)
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: info
        ) else {
            diagnostic("ERROR CGEventTap create failed; Input Monitoring=\(CGPreflightListenEventAccess())")
            NSLog("JARVIS INPUT ERROR: CGEventTap не создан; Input Monitoring=%@", CGPreflightListenEventAccess() ? "granted" : "denied")
            lock.lock(); started = false; lock.unlock()
            return
        }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            NSLog("JARVIS INPUT ERROR: не удалось создать RunLoopSource")
            CFMachPortInvalidate(tap)
            lock.lock(); started = false; lock.unlock()
            return
        }
        lock.lock()
        eventTap = tap
        runLoopSource = source
        lock.unlock()
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        diagnostic("SUCCESS CGEventTap installed Session-level")
        NSLog("JARVIS INPUT: CGEventTap установлен на уровне Session; ожидание дополнительных кнопок")
    }

    fileprivate func handleButton(_ button: Int64, isDown: Bool) {
        guard (2...31).contains(button) else { return }
        diagnosticQueue.async {
            self.diagnostic("SIDE BUTTON \(isDown ? "DOWN" : "UP") button=\(button)")
        }
        NSLog("JARVIS INPUT: %@ дополнительная кнопка мыши %lld", isDown ? "нажата" : "отпущена", button)
        if isDown { onButtonDown?(button) } else { onButtonUp?(button) }
    }

    private func reenableEventTap() {
        lock.lock()
        let tap = eventTap
        lock.unlock()
        if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
    }

    func stop() {
        lock.lock()
        let tap = eventTap
        let source = runLoopSource
        eventTap = nil
        runLoopSource = nil
        started = false
        lock.unlock()
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        if let tap { CFMachPortInvalidate(tap) }
    }
}
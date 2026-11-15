import Foundation
import AppKit
import CoreGraphics

@MainActor
final class VisionService {

    enum VisionError: LocalizedError {
        case permissionDenied
        case screenshotFailed

        var errorDescription: String? {
            switch self {
            case .permissionDenied:
                return "Разрешите запись экрана для JARVIS в настройках macOS."
            case .screenshotFailed:
                return "Не удалось получить изображение экрана."
            }
        }
    }

    func captureScreen() throws -> Data {
        guard CGPreflightScreenCaptureAccess() else {
            _ = CGRequestScreenCaptureAccess()
            if let url = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity?Privacy_ScreenCapture") {
                NSWorkspace.shared.open(url)
            }
            throw VisionError.permissionDenied
        }

        guard let screen = NSScreen.main,
              let screenNumber = screen.deviceDescription[
                NSDeviceDescriptionKey("NSScreenNumber")
              ] as? NSNumber,
              let image = CGDisplayCreateImage(
                CGDirectDisplayID(screenNumber.uint32Value)
              ) else {
            print("[JARVIS VISION] Screen capture failed. ScreenCapture permission=\(CGPreflightScreenCaptureAccess()), mainScreen=\(NSScreen.main != nil)")
            throw VisionError.screenshotFailed
        }
        print("[JARVIS VISION] Screenshot captured: \(image.width)x\(image.height), permission=\(CGPreflightScreenCaptureAccess())")

        let original = NSBitmapImageRep(cgImage: image)
        let maxWidth = 1280
        let width = min(original.pixelsWide, maxWidth)
        let height = max(1, Int(
            Double(original.pixelsHigh) *
            Double(width) / Double(original.pixelsWide)
        ))

        let resized = NSImage(size: NSSize(width: width, height: height))
        resized.lockFocus()
        NSImage(cgImage: image, size: NSSize(
            width: original.pixelsWide,
            height: original.pixelsHigh
        )).draw(
            in: NSRect(x: 0, y: 0, width: width, height: height),
            from: .zero,
            operation: .copy,
            fraction: 1
        )
        resized.unlockFocus()

        guard let tiff = resized.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let data = bitmap.representation(
                using: .jpeg,
                properties: [.compressionFactor: 0.60]
              ) else {
            throw VisionError.screenshotFailed
        }

        return data
    }

    func captureBase64() throws -> String {
        try captureScreen().base64EncodedString()
    }
}
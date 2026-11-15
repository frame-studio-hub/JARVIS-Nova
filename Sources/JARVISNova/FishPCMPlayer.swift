import Foundation
import AVFoundation

@MainActor
final class FishPCMPlayer {
    private let engine = AVAudioEngine()
    private let node = AVAudioPlayerNode()
    private let format = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: 44100,
        channels: 1,
        interleaved: false
    )!

    private var pendingBuffers = 0
    private var receivedFrames = 0
    private var finishedReceiving = false
    private let maxPendingBuffers = 48

    private(set) var started = false

    var playbackFinished: Bool {
        finishedReceiving && pendingBuffers == 0
    }

    init() throws {
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        try engine.start()
    }

    func append(_ data: Data) async {
        guard !data.isEmpty, data.count % 2 == 0 else { return }

        // Bound queued PCM memory when the network delivers audio faster than playback.
        while pendingBuffers >= maxPendingBuffers && !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(10))
        }
        guard !Task.isCancelled else { return }

        let frames = data.count / 2

        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(frames)
        ) else { return }

        buffer.frameLength = AVAudioFrameCount(frames)

        guard let output = buffer.floatChannelData?[0] else { return }

        data.withUnsafeBytes { raw in
            let bytes = raw.bindMemory(to: UInt8.self)
            for i in 0..<frames {
                let lo = UInt16(bytes[i * 2])
                let hi = UInt16(bytes[i * 2 + 1]) << 8
                let sample = Int16(bitPattern: lo | hi)
                output[i] = Float(sample) / 32768.0
            }
        }

        pendingBuffers += 1
        receivedFrames += frames

        node.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) {
            [weak self] _ in
            Task { @MainActor in
                self?.pendingBuffers -= 1
            }
        }

        if !started && receivedFrames > 0 {
            node.play()
            started = true
            print("[Fish PCM] Воспроизведение запущено")
        }
    }

    func finish() {
        finishedReceiving = true

        if !started && pendingBuffers > 0 {
            node.play()
            started = true
        }
    }

    func stop() {
        node.stop()
        engine.stop()
        started = false
    }
}
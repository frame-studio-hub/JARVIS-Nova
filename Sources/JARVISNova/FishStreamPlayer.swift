import Foundation
import AudioToolbox

final class FishStreamPlayer {
    var stream: AudioFileStreamID?
    var queue: AudioQueueRef?
    var buffers: [AudioQueueBufferRef] = []
    var totalPackets = 0
    var started = false
    var stopped = false
    var failureStatus: OSStatus = noErr
    var sampleRate: Double = 44100
    var framesPerPacket: UInt32 = 1152
    private let bufferLock = NSLock()
    private var completedBuffers = 0
    private var enqueuedBuffers = 0
    private var downloadFinished = false

    var playbackFinished: Bool {
        bufferLock.lock()
        defer { bufferLock.unlock() }

        return downloadFinished &&
            enqueuedBuffers > 0 &&
            completedBuffers >= enqueuedBuffers
    }

    func printPlaybackDiagnostics() {
        bufferLock.lock()
        let queued = enqueuedBuffers
        let completed = completedBuffers
        let finished = downloadFinished
        bufferLock.unlock()

        print("[Fish DEBUG] Буферов в очереди:", queued)
        print("[Fish DEBUG] Обработано:", completed)
        print("[Fish DEBUG] Загрузка завершена:", finished)
        print("[Fish DEBUG] Пакетов MP3:", totalPackets)
        print("[Fish DEBUG] Длительность аудио:", estimatedDuration, "сек")
    }

    func finishDownload() {
        bufferLock.lock()
        downloadFinished = true
        bufferLock.unlock()
    }

    private func bufferCompleted() {
        bufferLock.lock()
        completedBuffers += 1
        bufferLock.unlock()
    }

    private func bufferEnqueued() {
        bufferLock.lock()
        enqueuedBuffers += 1
        bufferLock.unlock()
    }

    init() {
        let propertyCallback: AudioFileStream_PropertyListenerProc = {
            clientData, stream, propertyID, _ in

            let player = Unmanaged<FishStreamPlayer>
                .fromOpaque(clientData)
                .takeUnretainedValue()

            guard propertyID ==
                kAudioFileStreamProperty_ReadyToProducePackets else {
                return
            }

            var format = AudioStreamBasicDescription()
            var size = UInt32(
                MemoryLayout<AudioStreamBasicDescription>.size
            )

            let status = AudioFileStreamGetProperty(
                stream,
                kAudioFileStreamProperty_DataFormat,
                &size,
                &format
            )

            guard status == noErr else {
                print("Ошибка формата:", status)
                return
            }

            let callback: AudioQueueOutputCallback = {
                userData, _, _ in

                guard let userData else { return }

                let player = Unmanaged<FishStreamPlayer>
                    .fromOpaque(userData)
                    .takeUnretainedValue()

                player.bufferCompleted()
            }

            var queueRef: AudioQueueRef?
            let queueStatus = AudioQueueNewOutput(
                &format,
                callback,
                Unmanaged.passUnretained(player).toOpaque(),
                nil,
                nil,
                0,
                &queueRef
            )

            guard queueStatus == noErr else {
                print("Ошибка AudioQueue:", queueStatus)
                return
            }

            player.queue = queueRef
            player.sampleRate = format.mSampleRate
            player.framesPerPacket = format.mFramesPerPacket
            
        }

        let packetCallback: AudioFileStream_PacketsProc = {
            clientData, bytes, count, inputData, descriptions in

            let player = Unmanaged<FishStreamPlayer>
                .fromOpaque(clientData)
                .takeUnretainedValue()

            guard let queue = player.queue else { return }

            var bufferRef: AudioQueueBufferRef?
            let capacity = max(bytes, 4096)

            guard AudioQueueAllocateBuffer(
                queue,
                capacity,
                &bufferRef
            ) == noErr, let buffer = bufferRef else {
                return
            }

            memcpy(
                buffer.pointee.mAudioData,
                inputData,
                Int(bytes)
            )

            buffer.pointee.mAudioDataByteSize = bytes

            let status = AudioQueueEnqueueBuffer(
                queue,
                buffer,
                count,
                descriptions
            )

            guard status == noErr else {
                print("Ошибка добавления:", status)
                AudioQueueFreeBuffer(queue, buffer)
                return
            }

            player.buffers.append(buffer)
            player.bufferEnqueued()
            player.totalPackets += Int(count)

            if !player.started &&
               player.estimatedDuration >= 1.0 {
                let startStatus = AudioQueueStart(queue, nil)
                if startStatus == noErr {
                    player.started = true
                    
                }
            }
        }

        let status = AudioFileStreamOpen(
            Unmanaged.passUnretained(self).toOpaque(),
            propertyCallback,
            packetCallback,
            kAudioFileMP3Type,
            &stream
        )

        guard status == noErr else {
            fatalError("Ошибка парсера: \(status)")
        }
    }

    func append(_ data: Data) {
        guard !stopped, let stream else { return }

        let status = data.withUnsafeBytes { bytes in
            AudioFileStreamParseBytes(
                stream,
                UInt32(bytes.count),
                bytes.baseAddress!,
                []
            )
        }

        if status != noErr {
            failureStatus = status
            print("Ошибка MP3:", status)
        }
    }

    var estimatedDuration: TimeInterval {
        guard sampleRate > 0 else { return 0 }
        return Double(totalPackets) *
            Double(framesPerPacket) / sampleRate
    }

    func stop() {
        guard !stopped else { return }
        stopped = true

        if let queue {
            AudioQueueStop(queue, false)
        }

        started = false
    }

    deinit {
        if let queue {
            AudioQueueStop(queue, true)
            AudioQueueDispose(queue, true)
        }

        if let stream {
            AudioFileStreamClose(stream)
        }
    }
}
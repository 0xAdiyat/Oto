import AVFoundation
import Combine
import Foundation

/// Taps the system default input device and publishes its RMS level.
/// Tear down by calling `stop()`; the engine releases the mic so the
/// macOS "mic in use" indicator goes away.
@MainActor
final class InputLevelMonitor: ObservableObject {

    /// 0–1 RMS level. Smoothed for display.
    @Published private(set) var level: Float = 0
    @Published private(set) var isRunning: Bool = false

    private let engine = AVAudioEngine()
    private var attached = false

    func start() {
        guard !isRunning else { return }
        do {
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            // Some virtual devices report 0 sample rate / 0 channels — bail.
            guard format.sampleRate > 0, format.channelCount > 0 else { return }

            input.removeTap(onBus: 0)
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
                let rms = Self.rms(buffer)
                Task { @MainActor in
                    guard let self else { return }
                    // Light smoothing.
                    self.level = self.level * 0.6 + rms * 0.4
                }
            }
            attached = true
            try engine.start()
            isRunning = true
        } catch {
            NSLog("Oto: InputLevelMonitor.start failed: \(error)")
            stop()
        }
    }

    func stop() {
        if attached {
            engine.inputNode.removeTap(onBus: 0)
            attached = false
        }
        if engine.isRunning { engine.stop() }
        level = 0
        isRunning = false
    }

    private static func rms(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else { return 0 }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return 0 }
        let channels = Int(buffer.format.channelCount)
        var total: Float = 0
        for ch in 0..<channels {
            let ptr = channelData[ch]
            var sumSquares: Float = 0
            for i in 0..<frameLength {
                let s = ptr[i]
                sumSquares += s * s
            }
            total += sumSquares / Float(frameLength)
        }
        let avg = total / Float(channels)
        return min(1, sqrt(avg) * 4) // small gain so quiet voice shows up
    }
}

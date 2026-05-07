import AVFoundation
import Combine
import Foundation

/// Records ~3 s from the current default input, then plays it back.
/// Used by the "Test microphone" button in Devices view.
@MainActor
final class MicTester: NSObject, ObservableObject {

    enum State: Equatable {
        case idle, recording, playing
    }

    @Published private(set) var state: State = .idle

    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer?
    private var fileURL: URL?

    func toggleTest(durationSeconds: TimeInterval = 3.0) {
        switch state {
        case .idle: startRecording(durationSeconds: durationSeconds)
        case .recording: stopRecordingAndPlay()
        case .playing: stopPlaying()
        }
    }

    private func startRecording(durationSeconds: TimeInterval) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("oto-mic-test-\(UUID().uuidString).m4a")
        fileURL = url

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]

        do {
            let r = try AVAudioRecorder(url: url, settings: settings)
            r.delegate = self
            r.record(forDuration: durationSeconds)
            recorder = r
            state = .recording
        } catch {
            NSLog("Oto: MicTester record failed: \(error)")
            state = .idle
        }
    }

    private func stopRecordingAndPlay() {
        recorder?.stop()
        // playback starts in audioRecorderDidFinishRecording
    }

    private func stopPlaying() {
        player?.stop()
        cleanup()
    }

    private func cleanup() {
        if let url = fileURL { try? FileManager.default.removeItem(at: url) }
        fileURL = nil
        recorder = nil
        player = nil
        state = .idle
    }
}

extension MicTester: AVAudioRecorderDelegate, AVAudioPlayerDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            guard flag, let url = self.fileURL else { self.cleanup(); return }
            do {
                let p = try AVAudioPlayer(contentsOf: url)
                p.delegate = self
                self.player = p
                p.play()
                self.state = .playing
            } catch {
                NSLog("Oto: MicTester playback failed: \(error)")
                self.cleanup()
            }
        }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in self.cleanup() }
    }
}

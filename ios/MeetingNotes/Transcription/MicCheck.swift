import Foundation
import AVFoundation
import Observation

/// Runs a short live-transcription check at the start of a recording so an obstructed mic or
/// wrong input source surfaces immediately instead of after the whole meeting. Built on the
/// streaming path, consuming buffers fanned out from `AudioRecorder`'s own tap rather than
/// opening a second `AVAudioEngine` on the same input.
@Observable
final class MicCheck: @unchecked Sendable {
    enum State: Equatable {
        case idle
        case listening
        case heardSpeech
        case timedOut
        case failed(String)
    }

    private(set) var state: State = .idle

    private let transcriber: any Transcriber
    private let duration: TimeInterval
    private var runTask: Task<Void, Never>?

    init(transcriber: any Transcriber = SpeechAnalyzerTranscriber(), duration: TimeInterval = 30) {
        self.transcriber = transcriber
        self.duration = duration
    }

    func start(bufferStream: AsyncStream<AVAudioPCMBuffer>, inputFormat: AVAudioFormat, locale: Locale) {
        guard runTask == nil else { return }
        state = .listening

        runTask = Task {
            do {
                try await withThrowingTaskGroup(of: Void.self) { group in
                    group.addTask {
                        let events = self.transcriber.transcribeLive(
                            from: bufferStream,
                            inputFormat: inputFormat,
                            locale: locale
                        )
                        for try await event in events {
                            if case .segment(let segment) = event, !segment.text.isEmpty {
                                self.state = .heardSpeech
                                return
                            }
                        }
                    }
                    group.addTask {
                        try await Task.sleep(nanoseconds: UInt64(self.duration * 1_000_000_000))
                    }
                    try await group.next()
                    group.cancelAll()
                }
                if state == .listening {
                    state = .timedOut
                }
            } catch is CancellationError {
                // stop() was called deliberately.
            } catch {
                state = .failed(error.localizedDescription)
            }
            runTask = nil
        }
    }

    func stop() {
        runTask?.cancel()
        runTask = nil
    }
}

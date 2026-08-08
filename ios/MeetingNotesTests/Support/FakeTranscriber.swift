import Foundation
import AVFoundation
@testable import MeetingNotes

enum FakeTranscriberError: Error {
    case simulatedFailure
}

/// A `Transcriber` that fails a configurable number of times before succeeding — exercises
/// `TranscriptionQueue`'s retry logic without touching real Speech APIs.
final class FakeTranscriber: Transcriber, @unchecked Sendable {
    private(set) var attemptCount = 0
    private let failuresBeforeSuccess: Int
    private let resultSegments: [TranscribedSegment]

    init(
        failuresBeforeSuccess: Int = 0,
        resultSegments: [TranscribedSegment] = [TranscribedSegment(text: "Hello", startTime: 0, endTime: 1)]
    ) {
        self.failuresBeforeSuccess = failuresBeforeSuccess
        self.resultSegments = resultSegments
    }

    func transcribe(fileAt url: URL, locale: Locale) -> AsyncThrowingStream<TranscriptionEvent, Error> {
        attemptCount += 1
        let shouldFail = attemptCount <= failuresBeforeSuccess

        return AsyncThrowingStream { continuation in
            if shouldFail {
                continuation.finish(throwing: FakeTranscriberError.simulatedFailure)
                return
            }
            for segment in resultSegments {
                continuation.yield(.segment(segment))
            }
            continuation.yield(.progress(1))
            continuation.finish()
        }
    }

    func transcribeLive(
        from audioStream: AsyncStream<AVAudioPCMBuffer>,
        inputFormat: AVAudioFormat,
        locale: Locale
    ) -> AsyncThrowingStream<TranscriptionEvent, Error> {
        AsyncThrowingStream { $0.finish() }
    }
}

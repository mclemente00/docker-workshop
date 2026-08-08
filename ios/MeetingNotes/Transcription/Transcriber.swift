import Foundation
import AVFoundation

// AVAudioPCMBuffer isn't audited for Sendable, but each tap callback hands off a buffer that
// nothing else touches afterward — safe to cross into the analyzer's AsyncStream.
extension AVAudioPCMBuffer: @unchecked @retroactive Sendable {}

struct TranscribedSegment: Sendable, Equatable {
    var text: String
    var startTime: TimeInterval
    var endTime: TimeInterval
}

enum TranscriptionEvent: Sendable {
    case segment(TranscribedSegment)
    case progress(Double)
}

enum TranscriberError: Error {
    case unsupportedAudioFormat
}

/// Abstraction over the transcription engine — keeps a future WhisperKit swap cheap.
protocol Transcriber: Sendable {
    /// Deferred, file-based transcription of a finished recording.
    func transcribe(fileAt url: URL, locale: Locale) -> AsyncThrowingStream<TranscriptionEvent, Error>

    /// Live transcription of microphone input, used by the opt-in streaming toggle and the mic check.
    func transcribeLive(
        from audioStream: AsyncStream<AVAudioPCMBuffer>,
        inputFormat: AVAudioFormat,
        locale: Locale
    ) -> AsyncThrowingStream<TranscriptionEvent, Error>
}

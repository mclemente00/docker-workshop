import Foundation
import AVFoundation
import Speech

/// `Transcriber` backed by the on-device `SpeechAnalyzer` / `SpeechTranscriber` APIs.
final class SpeechAnalyzerTranscriber: Transcriber {
    func transcribe(fileAt url: URL, locale: Locale) -> AsyncThrowingStream<TranscriptionEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    // No .volatileResults here — this is the deferred, file-based path, so we
                    // only want finalized results. Reporting volatile ones too would mean the
                    // in-progress guess AND the corrected final result both get appended as
                    // segments, reading as repeated/duplicated text.
                    let transcriber = SpeechTranscriber(
                        locale: locale,
                        transcriptionOptions: [],
                        reportingOptions: [],
                        attributeOptions: [.audioTimeRange]
                    )
                    let analyzer = SpeechAnalyzer(modules: [transcriber])
                    let audioFile = try AVAudioFile(forReading: url)
                    let totalDuration = audioFile.fileFormat.sampleRate > 0
                        ? Double(audioFile.length) / audioFile.fileFormat.sampleRate
                        : 0

                    let resultsTask = Task {
                        for try await result in transcriber.results {
                            let segment = TranscribedSegment(
                                text: String(result.text.characters),
                                startTime: result.range.start.seconds,
                                endTime: result.range.end.seconds
                            )
                            continuation.yield(.segment(segment))
                            if totalDuration > 0 {
                                continuation.yield(.progress(min(1, segment.endTime / totalDuration)))
                            }
                        }
                    }

                    let lastSample = try await analyzer.analyzeSequence(from: audioFile)
                    if let lastSample {
                        try await analyzer.finalizeAndFinish(through: lastSample)
                    } else {
                        try await analyzer.finalizeAndFinishThroughEndOfInput()
                    }
                    _ = try await resultsTask.value

                    continuation.yield(.progress(1))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func transcribeLive(
        from audioStream: AsyncStream<AVAudioPCMBuffer>,
        inputFormat: AVAudioFormat,
        locale: Locale
    ) -> AsyncThrowingStream<TranscriptionEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let transcriber = SpeechTranscriber(
                        locale: locale,
                        transcriptionOptions: [],
                        reportingOptions: [.volatileResults],
                        attributeOptions: [.audioTimeRange]
                    )
                    let analyzer = SpeechAnalyzer(modules: [transcriber])

                    guard let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(
                        compatibleWith: [transcriber],
                        considering: inputFormat
                    ) else {
                        throw TranscriberError.unsupportedAudioFormat
                    }
                    guard let converter = AVAudioConverter(from: inputFormat, to: analyzerFormat) else {
                        throw TranscriberError.unsupportedAudioFormat
                    }

                    let (analyzerInputs, analyzerContinuation) = AsyncStream.makeStream(of: AnalyzerInput.self)

                    let resultsTask = Task {
                        for try await result in transcriber.results {
                            let segment = TranscribedSegment(
                                text: String(result.text.characters),
                                startTime: result.range.start.seconds,
                                endTime: result.range.end.seconds
                            )
                            continuation.yield(.segment(segment))
                        }
                    }

                    let feedTask = Task {
                        for await buffer in audioStream {
                            if let converted = Self.convert(buffer: buffer, using: converter, to: analyzerFormat) {
                                analyzerContinuation.yield(AnalyzerInput(buffer: converted))
                            }
                        }
                        analyzerContinuation.finish()
                    }

                    try await analyzer.start(inputSequence: analyzerInputs)
                    _ = await feedTask.value
                    try await analyzer.finalizeAndFinishThroughEndOfInput()
                    _ = try await resultsTask.value

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private static func convert(
        buffer: AVAudioPCMBuffer,
        using converter: AVAudioConverter,
        to format: AVAudioFormat
    ) -> AVAudioPCMBuffer? {
        let ratio = format.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1024
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else {
            return nil
        }

        // AVAudioConverter invokes this block synchronously and serially — never actually
        // concurrent — but its type is @Sendable, so the compiler can't see that itself.
        nonisolated(unsafe) var consumed = false
        var conversionError: NSError?
        converter.convert(to: outputBuffer, error: &conversionError) { _, inputStatus in
            if consumed {
                inputStatus.pointee = .noDataNow
                return nil
            }
            consumed = true
            inputStatus.pointee = .haveData
            return buffer
        }
        return conversionError == nil ? outputBuffer : nil
    }
}

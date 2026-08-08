import Foundation
import SwiftData
import Observation

/// Bridges the `TranscriptionQueue` actor to SwiftData: kicks off a job for a `Recording` and
/// applies progress/completion back onto the model on the main actor.
@Observable
@MainActor
final class TranscriptionCoordinator {
    private let queue: TranscriptionQueue
    private let modelContainer: ModelContainer
    private let liveActivity: LiveActivityCoordinator

    init(
        modelContainer: ModelContainer,
        liveActivity: LiveActivityCoordinator,
        transcriber: any Transcriber = SpeechAnalyzerTranscriber()
    ) {
        self.modelContainer = modelContainer
        self.liveActivity = liveActivity
        self.queue = TranscriptionQueue(transcriber: transcriber)
    }

    func transcribe(recording: Recording) {
        let id = recording.persistentModelID
        let url = AudioFileStore.url(for: recording.audioFileName)
        let locale = Locale(identifier: recording.locale)
        let container = modelContainer
        let liveActivity = self.liveActivity

        recording.transcriptionState = .running(0)
        liveActivity.beginTranscribing()

        Task {
            await queue.enqueue(audioURL: url, locale: locale) { outcome in
                Task { @MainActor in
                    Self.apply(outcome, to: id, in: container, liveActivity: liveActivity)
                }
            }
        }
    }

    @MainActor
    private static func apply(
        _ outcome: TranscriptionJobOutcome,
        to id: PersistentIdentifier,
        in container: ModelContainer,
        liveActivity: LiveActivityCoordinator
    ) {
        let context = container.mainContext
        guard let recording = context.model(for: id) as? Recording else { return }

        switch outcome {
        case .progress(let fraction):
            recording.transcriptionState = .running(fraction)
            liveActivity.updateTranscribingProgress(fraction)
        case .completed(let segments):
            recording.transcriptionState = .completed
            recording.transcriptText = segments.map(\.text).joined(separator: " ")
            for segment in segments {
                let model = TranscriptSegment(
                    text: segment.text,
                    startTime: segment.startTime,
                    endTime: segment.endTime,
                    recording: recording
                )
                context.insert(model)
            }
            liveActivity.finishTranscribing()
        case .failed(let message):
            recording.transcriptionState = .failed(message)
            liveActivity.finishTranscribing()
        }

        try? context.save()
    }
}

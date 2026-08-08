import Foundation
import BackgroundTasks

enum TranscriptionJobOutcome: Sendable {
    case progress(Double)
    case completed([TranscribedSegment])
    case failed(String)
}

/// Runs transcription jobs one at a time, retrying on failure, and registers a
/// `BGProcessingTaskRequest` so a long transcription can finish if the user leaves the app.
actor TranscriptionQueue {
    static let backgroundTaskIdentifier = "dev.mclemente.MeetingNotes.transcription"

    private struct Job: Sendable {
        let id: UUID
        let audioURL: URL
        let locale: Locale
    }

    private let transcriber: any Transcriber
    private let maxAttempts: Int
    private var pendingJobs: [Job] = []
    private var isProcessing = false
    private var outcomeHandlers: [UUID: @Sendable (TranscriptionJobOutcome) -> Void] = [:]

    init(transcriber: any Transcriber = SpeechAnalyzerTranscriber(), maxAttempts: Int = 3) {
        self.transcriber = transcriber
        self.maxAttempts = maxAttempts
    }

    /// Call once at app launch, before the app finishes launching.
    static func registerBackgroundTask() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: backgroundTaskIdentifier, using: nil) { task in
            guard let processingTask = task as? BGProcessingTask else {
                task.setTaskCompleted(success: false)
                return
            }
            // Step 5+ wires actual queue draining into this handler.
            processingTask.setTaskCompleted(success: true)
        }
    }

    private static func scheduleBackgroundTask() {
        let request = BGProcessingTaskRequest(identifier: backgroundTaskIdentifier)
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        try? BGTaskScheduler.shared.submit(request)
    }

    @discardableResult
    func enqueue(
        audioURL: URL,
        locale: Locale,
        onOutcome: @escaping @Sendable (TranscriptionJobOutcome) -> Void
    ) -> UUID {
        let job = Job(id: UUID(), audioURL: audioURL, locale: locale)
        outcomeHandlers[job.id] = onOutcome
        pendingJobs.append(job)
        Self.scheduleBackgroundTask()
        Task { await processNextIfNeeded() }
        return job.id
    }

    private func processNextIfNeeded() async {
        guard !isProcessing, !pendingJobs.isEmpty else { return }
        isProcessing = true
        let job = pendingJobs.removeFirst()
        await run(job, attempt: 1)
        isProcessing = false
        await processNextIfNeeded()
    }

    private func run(_ job: Job, attempt: Int) async {
        var segments: [TranscribedSegment] = []
        do {
            for try await event in transcriber.transcribe(fileAt: job.audioURL, locale: job.locale) {
                switch event {
                case .progress(let fraction):
                    outcomeHandlers[job.id]?(.progress(fraction))
                case .segment(let segment):
                    segments.append(segment)
                }
            }
            outcomeHandlers[job.id]?(.completed(segments))
            outcomeHandlers[job.id] = nil
        } catch {
            if attempt < maxAttempts {
                await run(job, attempt: attempt + 1)
            } else {
                outcomeHandlers[job.id]?(.failed(error.localizedDescription))
                outcomeHandlers[job.id] = nil
            }
        }
    }
}

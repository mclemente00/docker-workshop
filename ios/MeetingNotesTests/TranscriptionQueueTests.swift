import Testing
import Foundation
@testable import MeetingNotes

@Suite("TranscriptionQueue")
struct TranscriptionQueueTests {
    @Test func succeedsOnFirstAttempt() async {
        let transcriber = FakeTranscriber(failuresBeforeSuccess: 0)
        let queue = TranscriptionQueue(transcriber: transcriber, maxAttempts: 3)

        let outcome = await runJob(on: queue)

        guard case .completed(let segments) = outcome else {
            Issue.record("Expected .completed, got \(outcome)")
            return
        }
        #expect(segments.count == 1)
        #expect(transcriber.attemptCount == 1)
    }

    @Test func recoversAfterTransientFailures() async {
        let transcriber = FakeTranscriber(failuresBeforeSuccess: 2)
        let queue = TranscriptionQueue(transcriber: transcriber, maxAttempts: 3)

        let outcome = await runJob(on: queue)

        guard case .completed = outcome else {
            Issue.record("Expected .completed, got \(outcome)")
            return
        }
        #expect(transcriber.attemptCount == 3)
    }

    @Test func failsPermanentlyAfterExhaustingRetries() async {
        let transcriber = FakeTranscriber(failuresBeforeSuccess: 10)
        let queue = TranscriptionQueue(transcriber: transcriber, maxAttempts: 3)

        let outcome = await runJob(on: queue)

        guard case .failed = outcome else {
            Issue.record("Expected .failed, got \(outcome)")
            return
        }
        #expect(transcriber.attemptCount == 3)
    }

    private func runJob(on queue: TranscriptionQueue) async -> TranscriptionJobOutcome {
        await withCheckedContinuation { continuation in
            Task {
                await queue.enqueue(
                    audioURL: URL(fileURLWithPath: "/tmp/fake.m4a"),
                    locale: Locale(identifier: "en_US")
                ) { outcome in
                    switch outcome {
                    case .completed, .failed:
                        continuation.resume(returning: outcome)
                    case .progress:
                        break
                    }
                }
            }
        }
    }
}

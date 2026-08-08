import Foundation
import ActivityKit
import Observation

// Not audited for Sendable in this SDK, but update()/end() are async and meant to be called
// from background contexts — safe to cross actor boundaries here.
extension Activity: @unchecked @retroactive Sendable {}

/// Owns the recording's Live Activity: elapsed time and a stop control on the Lock Screen while
/// recording, then transcription progress after the recording ends. Lives at the app level
/// (not RecordView) so it survives RecordView being dismissed right after the user taps stop.
@Observable
@MainActor
final class LiveActivityCoordinator: @unchecked Sendable {
    var onStopRequested: (() -> Void)?

    private var activity: Activity<MeetingActivityAttributes>?
    private var startDate: Date?
    private var stopObserver: DarwinNotificationObserver?

    init() {
        stopObserver = DarwinNotificationObserver(name: DarwinNotification.stopRecording) { [weak self] in
            Task { @MainActor in
                self?.onStopRequested?()
            }
        }
    }

    var isAvailable: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    func start(title: String) {
        guard isAvailable, activity == nil else { return }
        let startDate = Date.now
        self.startDate = startDate

        let attributes = MeetingActivityAttributes(title: title)
        let state = MeetingActivityAttributes.ContentState(phase: .recording(isPaused: false), startDate: startDate)
        activity = try? Activity.request(
            attributes: attributes,
            content: ActivityContent(state: state, staleDate: nil)
        )
    }

    func setPaused(_ isPaused: Bool) {
        guard let activity, let startDate else { return }
        let state = MeetingActivityAttributes.ContentState(phase: .recording(isPaused: isPaused), startDate: startDate)
        Task { await activity.update(ActivityContent(state: state, staleDate: nil)) }
    }

    func beginTranscribing() {
        guard let activity, let startDate else { return }
        let state = MeetingActivityAttributes.ContentState(phase: .transcribing(progress: 0), startDate: startDate)
        Task { await activity.update(ActivityContent(state: state, staleDate: nil)) }
    }

    func updateTranscribingProgress(_ progress: Double) {
        guard let activity, let startDate else { return }
        let state = MeetingActivityAttributes.ContentState(phase: .transcribing(progress: progress), startDate: startDate)
        Task { await activity.update(ActivityContent(state: state, staleDate: nil)) }
    }

    func finishTranscribing() {
        guard let activity, let startDate else { return }
        let state = MeetingActivityAttributes.ContentState(phase: .finished, startDate: startDate)
        let content = ActivityContent(state: state, staleDate: nil)
        Task { await activity.end(content, dismissalPolicy: .after(.now.addingTimeInterval(5))) }
        self.activity = nil
        self.startDate = nil
    }

    /// Ends the activity immediately with no "finished" phase — used when a recording is
    /// cancelled rather than stopped, so there's nothing worth showing.
    func cancel() {
        guard let activity else { return }
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
        self.activity = nil
        self.startDate = nil
    }
}

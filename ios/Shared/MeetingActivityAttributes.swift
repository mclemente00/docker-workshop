import Foundation
import ActivityKit

/// Shared between the app and the Live Activity widget extension.
struct MeetingActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        enum Phase: Codable, Hashable {
            case recording(isPaused: Bool)
            case transcribing(progress: Double)
            case finished
        }

        var phase: Phase
        /// Original recording start time — the Lock Screen renders a native ticking timer from
        /// this instead of us pushing an update every second.
        var startDate: Date
    }

    var title: String
}

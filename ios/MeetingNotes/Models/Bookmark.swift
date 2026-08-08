import Foundation
import SwiftData

extension MeetingNotesSchemaV1 {
    @Model
    final class Bookmark {
        var timestamp: TimeInterval
        var label: String?
        var recording: Recording?

        init(timestamp: TimeInterval, label: String? = nil, recording: Recording? = nil) {
            self.timestamp = timestamp
            self.label = label
            self.recording = recording
        }
    }
}

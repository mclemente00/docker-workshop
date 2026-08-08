import Foundation
import SwiftData

extension MeetingNotesSchemaV1 {
    @Model
    final class TranscriptSegment {
        var text: String
        var startTime: TimeInterval
        var endTime: TimeInterval
        var recording: Recording?

        init(text: String, startTime: TimeInterval, endTime: TimeInterval, recording: Recording? = nil) {
            self.text = text
            self.startTime = startTime
            self.endTime = endTime
            self.recording = recording
        }
    }
}

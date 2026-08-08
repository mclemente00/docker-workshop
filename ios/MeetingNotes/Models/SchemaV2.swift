import Foundation
import SwiftData

// V2 adds `Recording.audioDiscarded` for the "keep transcript, discard audio" storage option.
// TranscriptSegment and Bookmark are unchanged from V1, but SwiftData's versioned-schema
// relationships are typed to a specific version's types, so the whole connected graph gets
// redeclared here rather than reusing V1's types directly.

extension MeetingNotesSchemaV2 {
    @Model
    final class Recording {
        @Attribute(.unique) var id: UUID
        var title: String
        var createdAt: Date
        var duration: TimeInterval
        /// Filename only, resolved against the app's container at read time — the container
        /// path itself changes between launches and on restore.
        var audioFileName: String
        /// True once the audio file has been deleted to reclaim space while keeping the
        /// transcript — `audioFileName` is retained for history even though the file is gone.
        var audioDiscarded: Bool
        var transcriptText: String
        var locale: String
        var transcriptionState: TranscriptionState
        var summary: MeetingSummary?
        var calendarEventID: String?

        @Relationship(deleteRule: .cascade, inverse: \TranscriptSegment.recording)
        var segments: [TranscriptSegment] = []

        @Relationship(deleteRule: .cascade, inverse: \Bookmark.recording)
        var bookmarks: [Bookmark] = []

        init(
            id: UUID = UUID(),
            title: String,
            createdAt: Date = .now,
            duration: TimeInterval = 0,
            audioFileName: String,
            audioDiscarded: Bool = false,
            transcriptText: String = "",
            locale: String,
            transcriptionState: TranscriptionState = .pending,
            summary: MeetingSummary? = nil,
            calendarEventID: String? = nil
        ) {
            self.id = id
            self.title = title
            self.createdAt = createdAt
            self.duration = duration
            self.audioFileName = audioFileName
            self.audioDiscarded = audioDiscarded
            self.transcriptText = transcriptText
            self.locale = locale
            self.transcriptionState = transcriptionState
            self.summary = summary
            self.calendarEventID = calendarEventID
        }
    }

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

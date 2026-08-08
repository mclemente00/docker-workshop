import Foundation
import SwiftData

extension MeetingNotesSchemaV1 {
    @Model
    final class Recording {
        @Attribute(.unique) var id: UUID
        var title: String
        var createdAt: Date
        var duration: TimeInterval
        /// Filename only, resolved against the app's container at read time — the container
        /// path itself changes between launches and on restore.
        var audioFileName: String
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
            self.transcriptText = transcriptText
            self.locale = locale
            self.transcriptionState = transcriptionState
            self.summary = summary
            self.calendarEventID = calendarEventID
        }
    }
}

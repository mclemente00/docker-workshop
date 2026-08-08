import Testing
import Foundation
import SwiftData
@testable import MeetingNotes

@Suite("Model round-trip")
struct ModelRoundTripTests {
    private func makeInMemoryContext() throws -> ModelContext {
        let schema = Schema(versionedSchema: MeetingNotesSchemaV2.self)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: MeetingNotesMigrationPlan.self,
            configurations: [configuration]
        )
        return ModelContext(container)
    }

    @Test func recordingPersistsWithRelationshipsAndEnums() throws {
        let context = try makeInMemoryContext()

        let recording = Recording(
            title: "Standup",
            duration: 125,
            audioFileName: "abc.m4a",
            locale: "en_US",
            transcriptionState: .completed,
            summary: MeetingSummary(
                title: "Standup",
                summary: "Quick sync.",
                actionItems: ["Ship it"],
                decisions: ["Go with plan A"]
            )
        )
        context.insert(recording)
        context.insert(TranscriptSegment(text: "Hello team", startTime: 0, endTime: 2, recording: recording))
        context.insert(Bookmark(timestamp: 1, label: "Key moment", recording: recording))
        try context.save()

        let id = recording.persistentModelID
        let fetched = try #require(context.model(for: id) as? Recording)

        #expect(fetched.title == "Standup")
        #expect(fetched.duration == 125)
        #expect(fetched.transcriptionState == .completed)
        #expect(fetched.summary?.title == "Standup")
        #expect(fetched.summary?.actionItems == ["Ship it"])
        #expect(fetched.segments.count == 1)
        #expect(fetched.segments.first?.text == "Hello team")
        #expect(fetched.bookmarks.count == 1)
        #expect(fetched.bookmarks.first?.label == "Key moment")
        #expect(fetched.audioDiscarded == false)
    }

    @Test func deletingRecordingCascadesToSegmentsAndBookmarks() throws {
        let context = try makeInMemoryContext()

        let recording = Recording(title: "Temp", audioFileName: "temp.m4a", locale: "en_US")
        context.insert(recording)
        context.insert(TranscriptSegment(text: "Text", startTime: 0, endTime: 1, recording: recording))
        context.insert(Bookmark(timestamp: 0, recording: recording))
        try context.save()

        let segmentDescriptor = FetchDescriptor<TranscriptSegment>()
        let bookmarkDescriptor = FetchDescriptor<Bookmark>()
        #expect(try context.fetch(segmentDescriptor).count == 1)
        #expect(try context.fetch(bookmarkDescriptor).count == 1)

        context.delete(recording)
        try context.save()

        #expect(try context.fetch(segmentDescriptor).count == 0)
        #expect(try context.fetch(bookmarkDescriptor).count == 0)
    }

    @Test func discardingAudioPersists() throws {
        let context = try makeInMemoryContext()

        let recording = Recording(title: "Call", audioFileName: "call.m4a", locale: "en_US")
        context.insert(recording)
        try context.save()

        recording.audioDiscarded = true
        try context.save()

        let id = recording.persistentModelID
        let fetched = try #require(context.model(for: id) as? Recording)
        #expect(fetched.audioDiscarded == true)
    }
}

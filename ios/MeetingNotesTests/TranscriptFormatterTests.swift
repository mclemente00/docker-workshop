import Testing
import Foundation
@testable import MeetingNotes

@Suite("TranscriptFormatter")
struct TranscriptFormatterTests {
    private func makeRecording() -> Recording {
        let recording = Recording(
            title: "Weekly Sync",
            duration: 90,
            audioFileName: "sync.m4a",
            locale: "en_US",
            transcriptionState: .completed,
            summary: MeetingSummary(
                title: "Weekly Sync",
                summary: "Discussed roadmap.",
                actionItems: ["Send follow-up doc"],
                decisions: ["Ship next Tuesday"]
            )
        )
        recording.segments = [
            TranscriptSegment(text: "Let's get started.", startTime: 0, endTime: 2, recording: recording),
            TranscriptSegment(text: "First up, the roadmap.", startTime: 2, endTime: 5, recording: recording)
        ]
        recording.bookmarks = [
            Bookmark(timestamp: 3, label: "Roadmap discussion", recording: recording)
        ]
        return recording
    }

    @Test func plainTextIncludesAllSections() {
        let text = TranscriptFormatter.plainText(for: makeRecording())

        #expect(text.contains("Weekly Sync"))
        #expect(text.contains("Discussed roadmap."))
        #expect(text.contains("Send follow-up doc"))
        #expect(text.contains("Ship next Tuesday"))
        #expect(text.contains("Roadmap discussion"))
        #expect(text.contains("Let's get started."))
        #expect(text.contains("First up, the roadmap."))
    }

    @Test func markdownUsesHeadersAndChecklists() {
        let markdown = TranscriptFormatter.markdown(for: makeRecording())

        #expect(markdown.contains("# Weekly Sync"))
        #expect(markdown.contains("## Summary"))
        #expect(markdown.contains("## Transcript"))
        #expect(markdown.contains("- [ ] Send follow-up doc"))
    }

    @Test func fallsBackToFlatTranscriptWhenNoSegments() {
        let recording = Recording(
            title: "Quick Note",
            audioFileName: "note.m4a",
            transcriptText: "Just a quick note.",
            locale: "en_US",
            transcriptionState: .completed
        )
        let text = TranscriptFormatter.plainText(for: recording)
        #expect(text.contains("Just a quick note."))
    }
}

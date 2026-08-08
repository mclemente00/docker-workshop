import Foundation

/// Formats a `Recording`'s transcript for export via `ShareLink` — reaches Notes, Mail, Files,
/// Obsidian, anything, instead of being locked to one destination.
enum TranscriptFormatter {
    static func plainText(for recording: Recording) -> String {
        var lines = [recording.title, dateString(recording.createdAt), ""]

        if let summary = recording.summary {
            lines.append("Summary")
            lines.append(summary.summary)
            if !summary.decisions.isEmpty {
                lines.append("")
                lines.append("Decisions:")
                lines.append(contentsOf: summary.decisions.map { "- \($0)" })
            }
            if !summary.actionItems.isEmpty {
                lines.append("")
                lines.append("Action Items:")
                lines.append(contentsOf: summary.actionItems.map { "- \($0)" })
            }
            lines.append("")
        }

        if !recording.bookmarks.isEmpty {
            lines.append("Bookmarks:")
            lines.append(contentsOf: sortedBookmarks(recording).map(bookmarkLine))
            lines.append("")
        }

        lines.append("Transcript")
        lines.append(contentsOf: transcriptLines(for: recording, timestampPrefix: { "[\(timeString($0))] " }))

        return lines.joined(separator: "\n")
    }

    static func markdown(for recording: Recording) -> String {
        var lines = ["# \(recording.title)", "", "_\(dateString(recording.createdAt))_", ""]

        if let summary = recording.summary {
            lines.append("## Summary")
            lines.append(summary.summary)
            lines.append("")
            if !summary.decisions.isEmpty {
                lines.append("### Decisions")
                lines.append(contentsOf: summary.decisions.map { "- \($0)" })
                lines.append("")
            }
            if !summary.actionItems.isEmpty {
                lines.append("### Action Items")
                lines.append(contentsOf: summary.actionItems.map { "- [ ] \($0)" })
                lines.append("")
            }
        }

        if !recording.bookmarks.isEmpty {
            lines.append("### Bookmarks")
            lines.append(contentsOf: sortedBookmarks(recording).map(bookmarkLine))
            lines.append("")
        }

        lines.append("## Transcript")
        lines.append(contentsOf: transcriptLines(for: recording, timestampPrefix: { "**[\(timeString($0))]** " }))

        return lines.joined(separator: "\n")
    }

    private static func transcriptLines(for recording: Recording, timestampPrefix: (TimeInterval) -> String) -> [String] {
        let segments = recording.segments.sorted { $0.startTime < $1.startTime }
        guard !segments.isEmpty else { return [recording.transcriptText] }
        return segments.map { timestampPrefix($0.startTime) + $0.text }
    }

    private static func sortedBookmarks(_ recording: Recording) -> [Bookmark] {
        recording.bookmarks.sorted { $0.timestamp < $1.timestamp }
    }

    private static func bookmarkLine(_ bookmark: Bookmark) -> String {
        var line = "- \(timeString(bookmark.timestamp))"
        if let label = bookmark.label, !label.isEmpty {
            line += " — \(label)"
        }
        return line
    }

    private static func timeString(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private static func dateString(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }
}

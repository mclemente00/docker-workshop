import Foundation
import FoundationModels

enum SummaryError: LocalizedError {
    case unavailable
    case emptyTranscript

    var errorDescription: String? {
        switch self {
        case .unavailable:
            "On-device summaries aren't available on this device."
        case .emptyTranscript:
            "There's no transcript to summarize yet."
        }
    }
}

@Generable
private struct ChunkSummary {
    @Guide(description: "A concise summary of only what this portion of the transcript actually says")
    var summary: String

    @Guide(description: """
    Action items explicitly assigned or agreed to in this portion of the transcript. Leave this \
    empty if none were explicitly stated — never infer one from general discussion.
    """)
    var actionItems: [String]

    @Guide(description: """
    Decisions explicitly made in this portion of the transcript. Leave this empty if none were \
    explicitly stated — never infer one from general discussion.
    """)
    var decisions: [String]
}

/// Summarizes a transcript with Foundation Models. A full meeting easily exceeds the on-device
/// model's context window, so this chunks the transcript first: each chunk gets its own summary
/// (map), then those get combined into one `MeetingSummary` (reduce) rather than discovering the
/// context-window problem on the first long meeting.
enum SummaryService {
    /// Conservative character budget per chunk — comfortably under the on-device model's context
    /// window even after accounting for instructions and the structured-output schema.
    private static let chunkCharacterBudget = 4000

    static var isAvailable: Bool {
        SystemLanguageModel.default.isAvailable
    }

    /// A short explanation when summaries aren't available — surfaced in the UI as quiet
    /// secondary text (not an error) so the option's absence isn't a mystery.
    static var unavailableReason: String? {
        switch SystemLanguageModel.default.availability {
        case .available:
            return nil
        case .unavailable(.deviceNotEligible):
            return "Summaries need Apple Intelligence, which this device doesn't support."
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Summaries need Apple Intelligence — turn it on in Settings to use this."
        case .unavailable(.modelNotReady):
            return "The on-device model is still downloading — try again shortly."
        case .unavailable:
            return "Summaries aren't available on this device right now."
        }
    }

    static func summarize(transcript: String) async throws -> MeetingSummary {
        guard SystemLanguageModel.default.isAvailable else {
            throw SummaryError.unavailable
        }

        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SummaryError.emptyTranscript }

        let chunks = chunk(trimmed, characterBudget: chunkCharacterBudget)

        var chunkSummaries: [ChunkSummary] = []
        for piece in chunks {
            chunkSummaries.append(try await summarizeChunk(piece))
        }

        return try await combine(chunkSummaries)
    }

    private static func summarizeChunk(_ text: String) async throws -> ChunkSummary {
        let session = LanguageModelSession(
            instructions: """
            You summarize one portion of a meeting transcript. Only include what was explicitly \
            said — never infer, assume, or invent action items or decisions that weren't actually \
            stated. Transcripts are often informal chat with no action items or decisions at all; \
            when that's the case, leave those lists empty rather than manufacturing something \
            plausible-sounding to fill them.
            """
        )
        let response = try await session.respond(
            to: "Summarize this portion of a meeting transcript:\n\n\(text)",
            generating: ChunkSummary.self
        )
        return response.content
    }

    private static func combine(_ chunkSummaries: [ChunkSummary]) async throws -> MeetingSummary {
        let sections = chunkSummaries.enumerated().map { index, chunk -> String in
            var lines = ["Section \(index + 1) summary: \(chunk.summary)"]
            if !chunk.actionItems.isEmpty {
                lines.append("Section \(index + 1) action items: " + chunk.actionItems.joined(separator: "; "))
            }
            if !chunk.decisions.isEmpty {
                lines.append("Section \(index + 1) decisions: " + chunk.decisions.joined(separator: "; "))
            }
            return lines.joined(separator: "\n")
        }.joined(separator: "\n\n")

        let session = LanguageModelSession(
            instructions: """
            You write an overall summary for a meeting from summaries of its consecutive sections. \
            The action items and decisions listed below are the complete, final set — merge them \
            across sections and remove duplicates, but do not add any that aren't listed, and do \
            not infer new ones from the summary text. If no action items or decisions are listed \
            below, leave those lists empty in your output. Write a short, specific title for the \
            whole meeting.
            """
        )
        let response = try await session.respond(to: sections, generating: MeetingSummary.self)
        return response.content
    }

    /// Internal (not private) so the chunker's boundary behavior is directly unit-testable.
    static func chunk(_ text: String, characterBudget: Int) -> [String] {
        guard text.count > characterBudget else { return [text] }

        var chunks: [String] = []
        var remaining = Substring(text)
        while !remaining.isEmpty {
            if remaining.count <= characterBudget {
                chunks.append(String(remaining))
                break
            }
            let cutoff = remaining.index(remaining.startIndex, offsetBy: characterBudget)
            let breakIndex = remaining[remaining.startIndex..<cutoff].lastIndex(of: " ") ?? cutoff
            chunks.append(String(remaining[remaining.startIndex..<breakIndex]))
            remaining = remaining[remaining.index(after: breakIndex)...]
        }
        return chunks
    }
}

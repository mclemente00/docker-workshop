import Foundation
import FoundationModels

@Generable
struct MeetingSummary: Codable, Equatable, Hashable {
    @Guide(description: "A short, specific title for the meeting, under 8 words")
    var title: String

    @Guide(description: "A concise paragraph summarizing what the meeting covered")
    var summary: String

    @Guide(description: """
    Concrete action items explicitly assigned during the meeting, each a short imperative \
    sentence. Empty if none were explicitly assigned — never invent one.
    """)
    var actionItems: [String]

    @Guide(description: """
    Decisions explicitly made during the meeting. Empty if none were explicitly made — never \
    invent one.
    """)
    var decisions: [String]
}

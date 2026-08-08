import Testing
@testable import MeetingNotes

@Suite("SummaryService chunking")
struct SummaryChunkerTests {
    @Test func textUnderBudgetStaysWhole() {
        let text = "Short transcript."
        let chunks = SummaryService.chunk(text, characterBudget: 4000)
        #expect(chunks == [text])
    }

    @Test func longTextSplitsWithinBudget() {
        let text = Array(repeating: "word", count: 2000).joined(separator: " ")
        let chunks = SummaryService.chunk(text, characterBudget: 4000)

        #expect(chunks.count > 1)
        for chunk in chunks {
            #expect(chunk.count <= 4000)
        }
    }

    @Test func splitsReconstructOriginalTextWithoutLosingOrDuplicatingWords() {
        let text = Array(repeating: "alpha beta gamma delta", count: 200).joined(separator: " ")
        let chunks = SummaryService.chunk(text, characterBudget: 100)

        #expect(chunks.joined(separator: " ") == text)
    }

    @Test func emptyTextProducesOneEmptyChunk() {
        let chunks = SummaryService.chunk("", characterBudget: 100)
        #expect(chunks == [""])
    }
}

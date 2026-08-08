import Testing
import Foundation
@testable import MeetingNotes

@Suite("TranscriptionState")
struct TranscriptionStateTests {
    @Test func codableRoundTripPreservesAssociatedValues() throws {
        let states: [TranscriptionState] = [.pending, .running(0.42), .completed, .failed("network blip")]
        for state in states {
            let data = try JSONEncoder().encode(state)
            let decoded = try JSONDecoder().decode(TranscriptionState.self, from: data)
            #expect(decoded == state)
        }
    }

    @Test func distinctCasesAreNotEqual() {
        #expect(TranscriptionState.running(0.5) != TranscriptionState.running(0.6))
        #expect(TranscriptionState.pending != TranscriptionState.completed)
        #expect(TranscriptionState.failed("a") != TranscriptionState.failed("b"))
    }
}

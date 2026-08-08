import Foundation

enum TranscriptionState: Codable, Equatable, Hashable {
    case pending
    case running(Double)
    case completed
    case failed(String)
}

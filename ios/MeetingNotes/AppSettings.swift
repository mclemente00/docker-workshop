import Foundation

enum AppSettingsKey {
    static let hasAcknowledgedConsent = "hasAcknowledgedConsent"
    static let liveTranscriptionEnabled = "liveTranscriptionEnabled"
    static let transcriptionLocaleIdentifier = "transcriptionLocaleIdentifier"
    static let audioRetentionDays = "audioRetentionDays"
}

enum AudioRetentionPeriod: Int, CaseIterable, Identifiable {
    case thirtyDays = 30
    case ninetyDays = 90
    case forever = 0

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .thirtyDays: "30 Days"
        case .ninetyDays: "90 Days"
        case .forever: "Keep Forever"
        }
    }
}

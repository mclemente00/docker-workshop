import AppIntents

/// Runs in the widget extension's process when the Lock Screen / Dynamic Island stop button is
/// tapped. It can't call back into the app directly, so it posts a Darwin notification instead.
struct StopRecordingIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Stop Recording"

    func perform() async throws -> some IntentResult {
        DarwinNotification.post(DarwinNotification.stopRecording)
        return .result()
    }
}

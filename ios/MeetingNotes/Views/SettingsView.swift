import SwiftUI
import Speech

struct SettingsView: View {
    @AppStorage(AppSettingsKey.liveTranscriptionEnabled) private var liveTranscriptionEnabled = false
    @AppStorage(AppSettingsKey.transcriptionLocaleIdentifier) private var transcriptionLocaleIdentifier = Locale.current.identifier
    @AppStorage(AppSettingsKey.audioRetentionDays) private var audioRetentionDays = AudioRetentionPeriod.forever.rawValue

    @State private var supportedLocales: [Locale] = []

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Live Transcription While Recording", isOn: $liveTranscriptionEnabled)
                } footer: {
                    Text("""
                    Shows a running transcript preview for the whole recording, after the \
                    30-second mic check, instead of only transcribing once you stop. Uses more \
                    battery.
                    """)
                }

                Section("Transcription Language") {
                    Picker("Language", selection: $transcriptionLocaleIdentifier) {
                        ForEach(supportedLocales, id: \.identifier) { locale in
                            Text(locale.localizedString(forIdentifier: locale.identifier) ?? locale.identifier)
                                .tag(locale.identifier)
                        }
                    }
                }

                Section {
                    Picker("Keep Audio For", selection: $audioRetentionDays) {
                        ForEach(AudioRetentionPeriod.allCases) { period in
                            Text(period.label).tag(period.rawValue)
                        }
                    }
                } footer: {
                    Text("""
                    Recordings older than this automatically have their audio discarded to save \
                    space — the transcript, bookmarks, and summary are kept.
                    """)
                }
            }
            .navigationTitle("Settings")
            .task {
                await loadSupportedLocales()
            }
        }
    }

    private func loadSupportedLocales() async {
        let locales = await SpeechTranscriber.supportedLocales
        supportedLocales = locales.sorted {
            let lhs = $0.localizedString(forIdentifier: $0.identifier) ?? $0.identifier
            let rhs = $1.localizedString(forIdentifier: $1.identifier) ?? $1.identifier
            return lhs < rhs
        }
    }
}

#Preview {
    SettingsView()
}

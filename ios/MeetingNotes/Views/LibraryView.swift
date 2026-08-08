import SwiftUI
import SwiftData

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Recording.createdAt, order: .reverse) private var recordings: [Recording]

    @AppStorage(AppSettingsKey.hasAcknowledgedConsent) private var hasAcknowledgedConsent = false
    @AppStorage(AppSettingsKey.audioRetentionDays) private var audioRetentionDays = AudioRetentionPeriod.forever.rawValue

    @State private var searchText = ""
    @State private var isPresentingRecordView = false
    @State private var isPresentingConsentNotice = false
    @State private var isPresentingSettings = false

    private var filteredRecordings: [Recording] {
        guard !searchText.isEmpty else { return recordings }
        return recordings.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
                || $0.transcriptText.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if recordings.isEmpty {
                    ContentUnavailableView(
                        "No Recordings",
                        systemImage: "waveform",
                        description: Text("Tap Record to capture your first meeting.")
                    )
                } else {
                    List {
                        ForEach(filteredRecordings) { recording in
                            NavigationLink(value: recording) {
                                RecordingRow(recording: recording)
                            }
                        }
                        .onDelete(perform: delete)
                    }
                }
            }
            .navigationTitle("Meeting Notes")
            .navigationDestination(for: Recording.self) { recording in
                RecordingDetailView(recording: recording)
            }
            .searchable(text: $searchText, prompt: "Search recordings")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        isPresentingSettings = true
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(action: recordButtonTapped) {
                        Label("Record", systemImage: "record.circle")
                    }
                }
            }
            .fullScreenCover(isPresented: $isPresentingRecordView) {
                RecordView()
            }
            .fullScreenCover(isPresented: $isPresentingConsentNotice) {
                ConsentNoticeView {
                    hasAcknowledgedConsent = true
                    isPresentingConsentNotice = false
                    isPresentingRecordView = true
                }
            }
            .sheet(isPresented: $isPresentingSettings) {
                SettingsView()
            }
            .task {
                performRetentionCleanup()
            }
        }
    }

    private func recordButtonTapped() {
        if hasAcknowledgedConsent {
            isPresentingRecordView = true
        } else {
            isPresentingConsentNotice = true
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            let recording = filteredRecordings[index]
            AudioFileStore.delete(fileName: recording.audioFileName)
            modelContext.delete(recording)
        }
        try? modelContext.save()
    }

    private func performRetentionCleanup() {
        guard audioRetentionDays != AudioRetentionPeriod.forever.rawValue else { return }
        let cutoff = Calendar.current.date(byAdding: .day, value: -audioRetentionDays, to: .now) ?? .now

        var didDiscardAny = false
        for recording in recordings
        where !recording.audioDiscarded
            && recording.transcriptionState == .completed
            && recording.createdAt < cutoff {
            AudioFileStore.delete(fileName: recording.audioFileName)
            recording.audioDiscarded = true
            didDiscardAny = true
        }
        if didDiscardAny {
            try? modelContext.save()
        }
    }
}

private struct RecordingRow: View {
    var recording: Recording

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(recording.title)
                .font(.headline)
            HStack(spacing: 8) {
                Text(recording.createdAt, style: .date)
                Text(durationString)
                statusLabel
                if recording.audioDiscarded {
                    Image(systemName: "trash.slash")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private var durationString: String {
        let minutes = Int(recording.duration) / 60
        let seconds = Int(recording.duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    @ViewBuilder
    private var statusLabel: some View {
        switch recording.transcriptionState {
        case .pending:
            Text("Pending")
        case .running(let fraction):
            Text("Transcribing \(Int(fraction * 100))%")
        case .completed:
            EmptyView()
        case .failed:
            Text("Transcription failed")
                .foregroundStyle(.red)
        }
    }
}

#Preview {
    LibraryView()
        .modelContainer(for: [Recording.self, TranscriptSegment.self, Bookmark.self], inMemory: true)
}

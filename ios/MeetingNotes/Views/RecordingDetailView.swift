import SwiftUI
import SwiftData

struct RecordingDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let recording: Recording

    @State private var player = AudioPlayer()
    @State private var isEditingTitle = false
    @State private var editedTitle = ""
    @State private var isShowingDeleteConfirmation = false
    @State private var isGeneratingSummary = false
    @State private var summaryError: String?

    private var sortedSegments: [TranscriptSegment] {
        recording.segments.sorted { $0.startTime < $1.startTime }
    }

    private var audioFileURL: URL {
        AudioFileStore.url(for: recording.audioFileName)
    }

    private var isEligibleForSummary: Bool {
        recording.transcriptionState == .completed && recording.summary == nil
    }

    private var canGenerateSummary: Bool {
        SummaryService.isAvailable && isEligibleForSummary
    }

    var body: some View {
        VStack(spacing: 0) {
            summarySection

            HStack(spacing: 0) {
                transcriptSection
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if !recording.bookmarks.isEmpty {
                    Divider()
                    BookmarkRail(bookmarks: recording.bookmarks, currentTime: player.currentTime) { bookmark in
                        player.seek(to: bookmark.timestamp)
                    }
                }
            }

            Divider()

            if recording.audioDiscarded {
                Label("Audio discarded — transcript kept", systemImage: "trash.slash")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                playbackControls
                    .padding()
            }
        }
        .navigationTitle(recording.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        editedTitle = recording.title
                        isEditingTitle = true
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }
                    if canGenerateSummary {
                        Button(action: generateSummary) {
                            Label("Generate Summary", systemImage: "sparkles")
                        }
                        .disabled(isGeneratingSummary)
                    }
                    if recording.transcriptionState == .completed {
                        Menu {
                            ShareLink(item: TranscriptFormatter.plainText(for: recording)) {
                                Label("Plain Text", systemImage: "doc.plaintext")
                            }
                            ShareLink(item: TranscriptFormatter.markdown(for: recording)) {
                                Label("Markdown", systemImage: "doc.richtext")
                            }
                        } label: {
                            Label("Share Transcript", systemImage: "doc.text")
                        }
                    }
                    if !recording.audioDiscarded {
                        ShareLink(item: audioFileURL) {
                            Label("Share Audio", systemImage: "square.and.arrow.up")
                        }
                        if recording.transcriptionState == .completed {
                            Button(action: discardAudio) {
                                Label("Discard Audio, Keep Transcript", systemImage: "trash.slash")
                            }
                        }
                    }
                    Button(role: .destructive) {
                        isShowingDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert("Rename Recording", isPresented: $isEditingTitle) {
            TextField("Title", text: $editedTitle)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                recording.title = editedTitle
                try? modelContext.save()
            }
        }
        .confirmationDialog("Delete this recording?", isPresented: $isShowingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive, action: deleteRecording)
            Button("Cancel", role: .cancel) {}
        }
        .task {
            loadAudio()
        }
    }

    @ViewBuilder
    private var summarySection: some View {
        if let summary = recording.summary {
            SummaryCard(summary: summary)
        } else if isGeneratingSummary {
            HStack(spacing: 8) {
                ProgressView()
                Text("Generating summary…")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding()
        } else if let summaryError {
            Text(summaryError)
                .font(.footnote)
                .foregroundStyle(.red)
                .padding(.horizontal)
                .padding(.top, 8)
        } else if isEligibleForSummary, let reason = SummaryService.unavailableReason {
            Text(reason)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.top, 8)
        }
    }

    @ViewBuilder
    private var transcriptSection: some View {
        switch recording.transcriptionState {
        case .pending:
            ContentUnavailableView("Waiting to Transcribe", systemImage: "clock")
        case .running(let fraction):
            ContentUnavailableView(
                "Transcribing… \(Int(fraction * 100))%",
                systemImage: "waveform"
            )
        case .failed(let message):
            ContentUnavailableView(message, systemImage: "exclamationmark.triangle")
        case .completed:
            if sortedSegments.isEmpty {
                ContentUnavailableView("No Speech Detected", systemImage: "text.bubble")
            } else {
                TranscriptList(segments: sortedSegments, currentTime: player.currentTime) { segment in
                    player.seek(to: segment.startTime)
                }
            }
        }
    }

    private var playbackControls: some View {
        VStack(spacing: 12) {
            Slider(
                value: Binding(
                    get: { player.currentTime },
                    set: { player.seek(to: $0) }
                ),
                in: 0...max(player.duration, 1)
            )
            HStack {
                Text(timeString(player.currentTime))
                Spacer()
                Text(timeString(player.duration))
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Button {
                if player.isPlaying {
                    player.pause()
                } else {
                    player.play()
                }
            } label: {
                Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 48))
            }
        }
    }

    private func timeString(_ time: TimeInterval) -> String {
        guard time.isFinite, time >= 0 else { return "0:00" }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func loadAudio() {
        guard !recording.audioDiscarded else { return }
        try? player.load(url: audioFileURL)
    }

    private func discardAudio() {
        player.stop()
        AudioFileStore.delete(fileName: recording.audioFileName)
        recording.audioDiscarded = true
        try? modelContext.save()
    }

    private func generateSummary() {
        guard !isGeneratingSummary else { return }
        isGeneratingSummary = true
        summaryError = nil

        Task {
            do {
                let result = try await SummaryService.summarize(transcript: recording.transcriptText)
                recording.summary = result
                try? modelContext.save()
            } catch {
                summaryError = error.localizedDescription
            }
            isGeneratingSummary = false
        }
    }

    private func deleteRecording() {
        player.stop()
        AudioFileStore.delete(fileName: recording.audioFileName)
        modelContext.delete(recording)
        try? modelContext.save()
        dismiss()
    }
}

private struct SummaryCard: View {
    let summary: MeetingSummary

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(summary.summary)
                    .font(.body)

                if !summary.decisions.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Decisions").font(.headline)
                        ForEach(summary.decisions, id: \.self) { decision in
                            Label(decision, systemImage: "checkmark.circle")
                        }
                    }
                }

                if !summary.actionItems.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Action Items").font(.headline)
                        ForEach(summary.actionItems, id: \.self) { item in
                            Label(item, systemImage: "arrow.right.circle")
                        }
                    }
                }
            }
            .font(.subheadline)
            .padding()
        }
        .frame(maxHeight: 220)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .padding(.top, 8)
    }
}

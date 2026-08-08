import SwiftUI
import SwiftData

struct RecordView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(TranscriptionCoordinator.self) private var transcriptionCoordinator
    @Environment(LiveActivityCoordinator.self) private var liveActivity

    @State private var recorder = AudioRecorder()
    @State private var sessionManager = AudioSessionManager()
    @State private var micCheck = MicCheck()
    @State private var currentFileName: String?
    @State private var currentTitle: String?
    @State private var errorMessage: String?
    @State private var bookmarkTimestamps: [TimeInterval] = []
    @State private var liveTranscriptText = ""
    @State private var liveTranscriptionTask: Task<Void, Never>?

    @AppStorage(AppSettingsKey.liveTranscriptionEnabled) private var liveTranscriptionEnabled = false
    @AppStorage(AppSettingsKey.transcriptionLocaleIdentifier) private var transcriptionLocaleIdentifier = Locale.current.identifier

    private var locale: Locale { Locale(identifier: transcriptionLocaleIdentifier) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                micCheckStatus
                    .frame(minHeight: 20)

                LevelMeter(level: recorder.currentLevel)
                    .frame(height: 12)
                    .padding(.horizontal, 40)

                Text(elapsedTimeString)
                    .font(.system(size: 48, weight: .medium, design: .rounded))
                    .monospacedDigit()

                if liveTranscriptionEnabled, !liveTranscriptText.isEmpty {
                    ScrollViewReader { proxy in
                        ScrollView {
                            Text(liveTranscriptText)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .id("liveTranscriptText")
                        }
                        .frame(maxHeight: 100)
                        .padding(.horizontal)
                        .onChange(of: liveTranscriptText) { _, _ in
                            withAnimation {
                                proxy.scrollTo("liveTranscriptText", anchor: .bottom)
                            }
                        }
                    }
                }

                bookmarkButton
                    .sensoryFeedback(.success, trigger: bookmarkTimestamps.count)

                RecordButton(
                    isRecording: recorder.isRecording,
                    isPaused: recorder.isPaused,
                    onToggleRecording: toggleRecording,
                    onTogglePause: togglePause
                )

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                        .multilineTextAlignment(.center)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("New Recording")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: cancel)
                }
            }
        }
        .onChange(of: micCheck.state) { _, newState in
            guard liveTranscriptionEnabled, recorder.isRecording, !recorder.isPaused else { return }
            switch newState {
            case .heardSpeech, .timedOut:
                startLiveTranscriptionPreview()
            default:
                break
            }
        }
    }

    private var elapsedTimeString: String {
        let minutes = Int(recorder.elapsedTime) / 60
        let seconds = Int(recorder.elapsedTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    @ViewBuilder
    private var micCheckStatus: some View {
        switch micCheck.state {
        case .idle:
            Text(" ")
        case .listening:
            Label("Checking mic — say something", systemImage: "waveform")
                .foregroundStyle(.secondary)
        case .heardSpeech:
            Label("Mic sounds good", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .timedOut:
            Label("No speech heard — check your mic", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        case .failed(let message):
            Label(message, systemImage: "xmark.circle.fill")
                .foregroundStyle(.red)
        }
    }

    private var bookmarkButton: some View {
        let isEnabled = recorder.isRecording && !recorder.isPaused
        return Button(action: addBookmark) {
            Label(
                bookmarkTimestamps.isEmpty ? "Add Bookmark" : "Add Bookmark (\(bookmarkTimestamps.count))",
                systemImage: "bookmark.fill"
            )
            .font(.subheadline)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.thinMaterial, in: Capsule())
        }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.4)
    }

    private func addBookmark() {
        bookmarkTimestamps.append(recorder.elapsedTime)
    }

    private func startLiveTranscriptionPreview() {
        guard liveTranscriptionTask == nil else { return }
        let bufferStream = recorder.liveBufferStream()
        let inputFormat = recorder.inputFormat
        let transcriber: any Transcriber = SpeechAnalyzerTranscriber()
        let sessionLocale = locale

        liveTranscriptionTask = Task {
            do {
                let events = transcriber.transcribeLive(from: bufferStream, inputFormat: inputFormat, locale: sessionLocale)
                for try await event in events {
                    if case .segment(let segment) = event, !segment.text.isEmpty {
                        liveTranscriptText += (liveTranscriptText.isEmpty ? "" : " ") + segment.text
                    }
                }
            } catch {
                // Best-effort preview only — the deferred pass after stop remains authoritative.
            }
            liveTranscriptionTask = nil
        }
    }

    private func stopLiveTranscriptionPreview() {
        liveTranscriptionTask?.cancel()
        liveTranscriptionTask = nil
    }

    private func toggleRecording() {
        if recorder.isRecording {
            finishRecording()
        } else {
            startRecording()
        }
    }

    private func togglePause() {
        if recorder.isPaused {
            try? recorder.resume()
            liveActivity.setPaused(false)
            switch micCheck.state {
            case .heardSpeech, .timedOut:
                if liveTranscriptionEnabled {
                    startLiveTranscriptionPreview()
                }
            default:
                break
            }
        } else {
            recorder.pause()
            liveActivity.setPaused(true)
            stopLiveTranscriptionPreview()
        }
    }

    private func startRecording() {
        do {
            try sessionManager.activate()
            let (fileName, url) = AudioFileStore.newRecordingURL()
            currentFileName = fileName
            try recorder.startRecording(to: url)
            let bufferStream = recorder.liveBufferStream()
            micCheck.start(bufferStream: bufferStream, inputFormat: recorder.inputFormat, locale: locale)

            let title = defaultTitle()
            currentTitle = title
            liveActivity.onStopRequested = { finishRecording() }
            liveActivity.start(title: title)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func finishRecording() {
        micCheck.stop()
        stopLiveTranscriptionPreview()
        let stoppedURL = recorder.stopRecording()
        sessionManager.deactivate()
        liveActivity.onStopRequested = nil

        guard stoppedURL != nil, let fileName = currentFileName else {
            liveActivity.cancel()
            dismiss()
            return
        }

        let recording = Recording(
            title: currentTitle ?? defaultTitle(),
            duration: recorder.elapsedTime,
            audioFileName: fileName,
            locale: locale.identifier
        )
        modelContext.insert(recording)
        for timestamp in bookmarkTimestamps {
            modelContext.insert(Bookmark(timestamp: timestamp, recording: recording))
        }
        try? modelContext.save()
        transcriptionCoordinator.transcribe(recording: recording)

        dismiss()
    }

    private func cancel() {
        micCheck.stop()
        stopLiveTranscriptionPreview()
        liveActivity.onStopRequested = nil
        liveActivity.cancel()
        if recorder.isRecording {
            if let url = recorder.stopRecording() {
                try? FileManager.default.removeItem(at: url)
            }
        }
        sessionManager.deactivate()
        dismiss()
    }

    private func defaultTitle() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "Recording — \(formatter.string(from: .now))"
    }
}

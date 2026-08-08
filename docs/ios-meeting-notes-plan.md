# Meeting Notes — iOS meeting recorder with on-device transcription

## Context

An iOS app that records meetings, transcribes them on-device, and keeps both the audio and the
transcript as the system of record. Apple Notes is demoted from destination to one export target
among many.

`mclemente00/docker-workshop` is currently empty (README + Python `.gitignore`); the app goes in a
new `ios/` subdirectory. A Docker-workshop repo is an odd home for an iOS app — noted, proceeding as
directed.

### How the design got here

The original framing was "record → file into an Apple Notes folder." That collapsed under two facts:
Apple exposes no public write API for Notes, and `Create Note` in Shortcuts has no folder parameter
(folder targeting needs `Move Notes to Folder` chained after it, with the folder chosen at build
time). Delivering it required a user-built Shortcut, an App Intent existing solely to dodge URL
length limits, and x-callback error handling — a large share of the build, all scaffolding around an
unsupported path.

Keeping audio in-app inverts that. The transcriber already emits `.audioTimeRange` attributes that a
flat Notes body would discard; owning the audio turns them into tap-to-seek playback, re-transcription,
and cross-meeting search. Export becomes `ShareLink` — about twenty lines, and it reaches Notes,
Mail, Files, and everything else instead of only Notes.

### Scope

Core loop plus five features: **live bookmarks, Lock Screen Live Activity, calendar-aware titling,
transcript search, on-device summaries**. Deployment target **iOS 26.0** — `SpeechAnalyzer` and the
Foundation Models framework both require it.

### Build constraint

This session is Linux with no Xcode. I can deliver a complete, review-ready project but cannot
compile, run, or test it. First build happens on a Mac; the README will cover signing and setup.

---

## Transcription runs after recording, not during

**Default: deferred.** Recording writes audio to disk and nothing else. Transcription kicks off when
recording stops.

Three reasons, in order of weight:

1. **Robustness.** The recording path does one thing — buffers to disk. Nothing to corrupt, nothing
   lost if the app is jetsammed at minute 90. Transcription becomes a retryable operation against a
   file that already exists. Live transcription couples the fragile part to the irreplaceable part.
2. **Timing of energy spend.** Meetings happen off-charger. Deferring moves the cost to when the
   phone is likely at a desk.
3. **Total energy.** Live inference runs the Neural Engine for the full meeting duration. Batched, the
   same audio processes at several times realtime — roughly 10–15 minutes of ANE time for a two-hour
   meeting instead of 120. Sustained high utilization is also more efficient per unit of work than
   pushing 100ms buffers through continuously, which holds the SoC out of deep idle throughout.

**The cost, and the mitigation.** Deferred mode removes live text as proof the capture is working. An
obstructed mic or wrong input source would surface only after the meeting, unrecoverably. So every
recording opens with a **30-second live mic check**: the transcriber runs briefly, the UI confirms
words are landing, then it shuts down and the session goes audio-only. Catches the failure that
matters for near-zero cost.

Live streaming stays available as an opt-in toggle in settings.

---

## Architecture

```
ios/
  README.md                          build, signing, first-run notes
  project.yml                        XcodeGen spec (regeneration escape hatch)
  MeetingNotes.xcodeproj/            hand-written, Xcode 16 synchronized root group
  MeetingNotes/
    MeetingNotesApp.swift            entry, SwiftData container, scene phase
    Info.plist  MeetingNotes.entitlements
    Models/
      Recording.swift                id, title, createdAt, duration, audioFileName,
                                     transcriptText, segments, bookmarks, locale,
                                     transcriptionState, summary, calendarEventID
      TranscriptSegment.swift        text + start/end time
      Bookmark.swift                 timestamp + optional label
      TranscriptionState.swift       .pending / .running(Double) / .completed / .failed(String)
      MeetingSummary.swift           @Generable: title, summary, actionItems, decisions
    Audio/
      AudioSessionManager.swift      .playAndRecord/.spokenAudio, interruptions, route changes
      AudioRecorder.swift            AVAudioEngine → .m4a, level metering, pause/resume
      AudioPlayer.swift              playback + seek(to:), drives transcript highlighting
    Transcription/
      Transcriber.swift              protocol — keeps a WhisperKit swap cheap later
      SpeechAnalyzerTranscriber.swift  file-based + streaming paths
      TranscriptionQueue.swift       serial queue, progress, retry, BGProcessingTask
      TranscriptionAssets.swift      AssetInventory reserve / download / progress
      MicCheck.swift                 30-second startup verification
    Intelligence/
      SummaryService.swift           FoundationModels, chunked map-reduce, availability gating
    Calendar/
      CalendarService.swift          EventKit — event overlapping now, title + attendees
    Export/
      TranscriptFormatter.swift      plain text and Markdown
    Views/
      RecordView.swift               level meter, elapsed, bookmark button, pause
      LibraryView.swift              list, search, sort, delete
      RecordingDetailView.swift      transcript ↔ playback sync, bookmarks, summary, share
      SettingsView.swift             live-transcription toggle, locale, audio retention
      Components/                    RecordButton, LevelMeter, TranscriptList, BookmarkRail
  MeetingNotesActivity/              Live Activity widget extension
  MeetingNotesTests/                 formatter, chunker, model round-trip, state machine
```

### Recording

`AVAudioEngine` input tap → `AVAudioFile` (AAC `.m4a`). Pause/resume by detaching and reattaching the
tap while holding the file handle — meetings have breaks, and it's nearly free to support.

`UIBackgroundModes: [audio]` plus interruption handling (call arrives → pause, resume on
`.shouldResume`) so a locked screen or an incoming call doesn't truncate the recording.

**Store `audioFileName`, never an absolute URL.** The container path changes between launches and on
restore; persisting full paths yields recordings that silently fail to play weeks later.

### Transcription

`SpeechTranscriber` configured with `attributeOptions: [.audioTimeRange]` so every segment carries
its position in the audio — this is what makes tap-to-seek work.

- **Deferred path (default):** `analyzer.analyzeSequence(from: AVAudioFile)` over the finished file.
- **Streaming path (opt-in, and the mic check):** buffers converted via `AVAudioConverter` to
  `bestAvailableAudioFormat`, fed through an `AsyncStream<AnalyzerInput>`, with
  `reportingOptions: [.volatileResults]` so in-flight text renders greyed before finalizing.

`TranscriptionQueue` runs one job at a time, surfaces progress, and retries on failure. Long jobs
register a `BGProcessingTaskRequest` so a two-hour meeting can finish if the user leaves the app.

**Language assets are not bundled.** `AssetInventory.assetInstallationRequest(supporting:)` must run
before the first transcription, with visible progress and a `reserve(locale:)` call. "Asset
unavailable for this locale" is a real user-facing state, not an edge case.

### The five features

**Bookmarks.** A button during recording appends a timestamp. Highest value per line of code here —
you know in the moment which thirty seconds mattered and never afterward. Rendered as a rail beside
the transcript for jump-to navigation.

**Live Activity.** ActivityKit extension showing elapsed time and a stop control on the Lock Screen,
then transcription progress after the recording ends. The phone is face-down for the entire use
case, so the app is invisible exactly when you need confirmation it's still running.

**Calendar titling.** EventKit lookup for an event overlapping the recording's start; offer its title
and attendee list. Turns "Recording 14" into "Q3 Planning — 6 attendees" with no typing. Requires
`requestFullAccessToEvents` and `NSCalendarsUsageDescription`. Always a suggestion, never automatic
— and fully functional if the user declines calendar access.

**Search.** SwiftData predicate across titles and transcript text, with matched-snippet results.
Non-negotiable past about ten recordings.

**Summaries.** Foundation Models (`SystemLanguageModel` + `LanguageModelSession`) with `@Generable`
guided generation into `MeetingSummary` — title, summary, action items, decisions. On-device, no API
key, no network, no cost.

Two things that will bite if unplanned:

- **Context window.** A two-hour transcript vastly exceeds the on-device model's window. Summarization
  must chunk the transcript, summarize each chunk, then summarize the summaries. Build it map-reduce
  from the start rather than discovering this on the first long meeting.
- **Availability.** `SystemLanguageModel.default.availability` is `.unavailable` on devices without
  Apple Intelligence support. Summaries degrade gracefully — the app is fully usable without them,
  and the UI must not present them as broken.

### Export

`ShareLink` with plain-text or Markdown transcript, optionally including timestamps, bookmarks, and
the summary. Reaches Notes, Mail, Files, Obsidian, anything. Audio shares as `.m4a` separately.

No Shortcuts integration in v1 — it can return later as automation, and it will be far easier to add
to a working app than to carry through the initial build.

### Storage

AAC runs roughly 30–60 MB/hour, so a year of meetings is real. Ship delete and a "keep transcript,
discard audio" option from the start rather than bolting them on once a library is 8 GB.

### Info.plist

`NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription` (defensive — cheap, and its
absence is a hard crash if the system does prompt), `NSCalendarsUsageDescription`,
`UIBackgroundModes: [audio, processing]`, and a `BGTaskSchedulerPermittedIdentifiers` entry for the
transcription task.

### Consent

Recording meetings carries real legal exposure — several US states require all-party consent, and
much of Europe is stricter. A one-time onboarding notice plus a persistent recording indicator. An
afternoon of work, and the responsible default for a tool built to capture other people talking.

---

## Build order

1. Xcode project skeleton, Info.plist, entitlements, README.
2. SwiftData models, storage helper, migration-safe schema.
3. `AudioSessionManager` + `AudioRecorder` + `AudioPlayer`; record/pause/playback with level meter.
4. `TranscriptionAssets` download UI, then `SpeechAnalyzerTranscriber` file path and
   `TranscriptionQueue`. `MicCheck` on top of the streaming path.
5. `LibraryView` + `RecordingDetailView`: search, rename, edit, delete, transcript↔playback sync.
6. Bookmarks (capture during recording, navigation in detail).
7. Live Activity extension.
8. `CalendarService` titling suggestions.
9. `SummaryService` with chunked map-reduce and availability gating.
10. Export, consent notice, settings, storage management.
11. Unit tests; README pass.
12. Commit and push to `claude/ios-meeting-notes-transcription-97pffn`. No PR unless you ask.

## Verification

I can only do static checks here — structure, plist and pbxproj well-formedness, Swift read-through.
Real verification is on your Mac:

1. `open ios/MeetingNotes.xcodeproj`, set signing team. If the hand-written pbxproj misbehaves,
   `xcodegen generate` from `ios/` rebuilds it from `project.yml`.
2. **Run on a physical device.** Mic input, speech-asset download, Live Activities, and Foundation
   Models are all unreliable or absent in the Simulator.
3. First launch: grant mic access, watch the language asset download complete.
4. Record ~2 minutes. Confirm the mic check shows words in the first 30 seconds, then goes quiet.
   Drop two bookmarks. Lock the screen mid-recording and confirm the Live Activity shows elapsed time
   and that the recording is not truncated.
5. Stop. Confirm transcription starts automatically, reports progress, and completes.
6. In detail: tap a transcript line, confirm audio seeks there. Tap a bookmark, same. Generate a
   summary and confirm action items are extracted.
7. Record with a calendar event active; confirm the title suggestion appears.
8. Share to Notes; confirm formatting survives.
9. Force-quit and relaunch; confirm old recordings still play — this is the relative-path check.
10. Test on a non-Apple-Intelligence device (or with the model unavailable) and confirm the app works
    with summaries cleanly absent.
11. `⌘U` for unit tests.

## Known limits, stated plainly

- iOS 26+ only. Summaries additionally require Apple Intelligence hardware.
- No speaker diarization. `SpeechAnalyzer` doesn't provide it; adding it means a separate model and a
  clustering pipeline — a project unto itself, deliberately excluded.
- No audio import in v1. Natural v1.1 alongside custom vocabulary.
- No iCloud sync. SwiftData + CloudKit complicates the audio-file story; worth revisiting later.

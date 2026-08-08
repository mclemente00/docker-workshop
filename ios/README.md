# Meeting Notes

An iOS app that records meetings, transcribes them on-device, and keeps both the audio and the
transcript as the system of record. See [`docs/ios-meeting-notes-plan.md`](../docs/ios-meeting-notes-plan.md)
in the repo root for the full design rationale.

## Requirements

- **Xcode 26** or later
- **iOS 26.0** deployment target — the app uses `SpeechAnalyzer` (Speech framework) and
  Foundation Models, both of which require it
- **[XcodeGen](https://github.com/yonaskolb/XcodeGen)** — the `.xcodeproj` is generated from
  [`project.yml`](project.yml), not hand-maintained. Install with `brew install xcodegen` if you
  don't have it.
- **A physical device**, for anything beyond confirming the build compiles. Mic input, on-device
  speech-asset downloads, Live Activities, and Foundation Models are all unreliable or entirely
  absent in the Simulator.

## Building

```sh
cd ios
xcodegen generate
open MeetingNotes.xcodeproj
```

### Signing

There are **two targets that each need a signing team**: `MeetingNotes` (the app) and
`MeetingNotesActivity` (the Live Activity widget extension). In Xcode, select each target in
turn → Signing & Capabilities → pick your team. Both need one, or the build fails with "requires
a development team" — easy to miss since the error only ever names the target that's still
unset.

**Regenerating the project wipes both teams.** Because the `.xcodeproj` is fully rebuilt from
`project.yml` every time `xcodegen generate` runs, any team you picked in Xcode's GUI doesn't
survive the next regeneration (it's stored in the generated file, not in `project.yml`, which is
the actual source of truth). You'll need to re-pick both teams after regenerating. If this gets
annoying, a gitignored local `.xcconfig` with `DEVELOPMENT_TEAM` set can be wired in so it
survives regeneration — ask if you want that set up.

### Command-line builds

`xcodebuild -scheme MeetingNotes -destination 'generic/platform=iOS' build` needs a team
configured the same as above. To verify the project compiles without dealing with signing at all
(e.g. in CI, or before you've set a team), override it on the command line instead of touching
`project.yml`:

```sh
xcodebuild -scheme MeetingNotes -destination 'generic/platform=iOS' build \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
```

## Running the unit tests

```sh
xcodebuild test -scheme MeetingNotes -destination 'platform=iOS Simulator,name=<a simulator you have>'
```

Or `⌘U` in Xcode. The suite (`MeetingNotesTests/`) covers transcript formatting, the summary
chunker's boundary behavior, SwiftData model round-trips (including cascade deletes and the
`audioDiscarded` flag), the transcription retry state machine, and `TranscriptionState`'s Codable
round-trip. It's pure logic plus a fake `Transcriber` — no real Speech/mic access needed, so it
runs fine in the Simulator or CI.

## First run

1. Launch on a physical device, grant microphone access when prompted.
2. Tap **Record** for the first time — a one-time consent notice appears (recording other people
   carries real legal responsibility in many jurisdictions); acknowledge it to proceed.
3. Start a recording. A 30-second live mic check runs first, confirming words are landing, then
   goes quiet — the actual transcription happens after you stop, not live (see the plan doc for
   why). The first time you transcribe in a given language, the on-device speech model for that
   language downloads with visible progress. If there's a calendar event happening right now,
   you'll also see a "Use '<event title>'" suggestion chip — tap it to adopt that title, or
   ignore it; it's never applied automatically. First use prompts for calendar access, and
   everything works fine if you decline.
4. **Summaries** (in a recording's detail view, "…" menu) additionally require Apple
   Intelligence to be turned on for the device (Settings → Apple Intelligence & Siri — this is a
   separate opt-in from just owning eligible hardware). If it's off, or the device doesn't
   support it, the summary option quietly doesn't appear rather than failing.
5. **Settings** (gear icon on the library screen): live-transcription toggle (an opt-in
   continuous preview during recording, off by default since it costs more battery than the
   default deferred-transcription approach), transcription language, and audio retention.

## What's built

Following the build order in the plan doc:

1. ✅ Project scaffold (XcodeGen, Info.plist, entitlements)
2. ✅ SwiftData models — versioned schema (`V1` → `V2`), migration-safe
3. ✅ Audio layer — `AudioSessionManager`, `AudioRecorder`, `AudioPlayer`
4. ✅ Transcription layer — `SpeechAnalyzerTranscriber` (deferred + streaming paths),
   `TranscriptionAssets`, `TranscriptionQueue`, `MicCheck`
5. ✅ `LibraryView` + `RecordView` + `RecordingDetailView`
6. ✅ Bookmarks (capture during recording, `BookmarkRail` navigation in detail)
7. ✅ Live Activity extension (`MeetingNotesActivity`) — Lock Screen + Dynamic Island, with a
   working Stop control that signals the app cross-process via Darwin notifications
8. ✅ `CalendarService` — EventKit lookup for an event overlapping the recording's start; shown
   as a dismissible suggestion chip in `RecordView`, never applied automatically
9. ✅ `SummaryService` — chunked map-reduce summarization via Foundation Models, availability-gated
10. ✅ Export (`TranscriptFormatter`, plain text/Markdown via `ShareLink`), consent notice,
    Settings, storage management (discard-audio-keep-transcript + automatic retention)
11. ✅ Unit tests, this README
12. ⬜ Commit and push — not done automatically; ask explicitly when you want it committed

Also added: a custom app icon (`Assets.xcassets/AppIcon.appiconset`).

## Known limits

- No speaker diarization — `SpeechAnalyzer` doesn't provide it, and adding it would mean a
  separate model and clustering pipeline.
- No audio import.
- No iCloud sync — SwiftData + CloudKit would complicate the audio-file story.
- Summaries require Apple Intelligence-capable hardware with it enabled; the app is fully usable
  without it.

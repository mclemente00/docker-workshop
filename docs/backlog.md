# Backlog and design memory

The app is feature-complete for v1 and verified working on device. It's now in a deliberate
**soak-testing period** — months of real use to find out what actually matters before building
anything else.

This document exists so that period doesn't cost us the context. It records the decisions that are
expensive to re-derive and the candidates that were considered and shelved.

---

## Status

| | |
|---|---|
| v1 build | Complete — all 11 build-order steps, merged in PR #1 |
| Device verification | Core loop verified end to end on hardware |
| Current phase | Soak testing, no active development |
| Next decision point | After a few months of use, pick from the backlog below |

---

## Design decisions worth remembering

These are the ones where the reasoning is non-obvious and someone revisiting the code would
reasonably wonder "why is it like this?"

### Apple Notes is an export target, not the destination

The original ask was "save transcripts into an Apple Notes folder called Audio Transcriptions."
That turned out to be structurally unavailable:

- There is **no public write API** for Apple Notes. No framework, no documented URL scheme.
- The Shortcuts path works but has no folder parameter on `Create Note` — folder targeting requires
  chaining `Move Notes to Folder` after it, and that action needs the folder to exist and be chosen
  when the Shortcut is built.
- Delivering it therefore required a user-built Shortcut, an App Intent existing *solely* to pass
  transcript text back out (because stuffing it into a `shortcuts://` URL breaks on long meetings),
  and x-callback success/error plumbing.

That was a large share of the build serving an unsupported path. Keeping audio in-app inverted the
tradeoff: the transcriber already emits `.audioTimeRange` attributes that a flat Notes body would
discard, and owning them is what makes tap-to-seek playback, re-transcription, and cross-meeting
search possible. Export became `ShareLink` — a fraction of the code, and it reaches Notes, Mail,
Files, and everything else instead of only Notes.

**If anyone proposes "just write to Notes directly" again:** it isn't possible with public API, and
private schemes get apps rejected.

### Transcription runs after recording, not during

Default is deferred. The recording path writes audio buffers to disk and does nothing else.
Three reasons, in order of weight:

1. **Robustness.** Nothing to corrupt, nothing lost if the app is jetsammed at minute 90.
   Transcription becomes a retryable operation against a file that already exists. Live
   transcription couples the fragile part to the irreplaceable part.
2. **When the energy is spent.** Meetings happen off-charger. Deferring moves the cost to when the
   phone is likely at a desk.
3. **Total energy.** Live inference runs the Neural Engine for the whole meeting. Batched, the same
   audio processes at several times realtime. Sustained high utilization is also more efficient per
   unit of work than pushing small buffers through continuously, which holds the SoC out of deep
   idle throughout.

The cost is losing live text as proof the capture is working — an obstructed mic would otherwise
surface only after the meeting. Hence the **30-second mic check** at the start of every recording:
transcribe briefly, confirm words are landing, then shut down and go audio-only. Live streaming
remains available as an opt-in toggle in Settings.

### Other decisions

- **Relative `audioFileName`, never absolute paths.** Container paths change between launches and on
  restore. Persisting full URLs produces recordings that silently fail to play weeks later.
- **iOS 26 floor** for `SpeechAnalyzer` and Foundation Models. No `@available` gymnastics; supporting
  older systems would need a second engine (WhisperKit), which was out of scope.
- **Summaries are map-reduce by design.** A long transcript vastly exceeds the on-device model's
  context window, so summarization chunks, summarizes each chunk, then summarizes the summaries.
  This is not over-engineering — the naive version fails on the first two-hour meeting.
- **Summaries degrade to absent, not broken.** `SystemLanguageModel.default.availability` is
  `.unavailable` without Apple Intelligence hardware *and* the user enabling it in Settings. The UI
  hides the option rather than presenting a failure.
- **Calendar titles are suggestions, never automatic.** Declining calendar access must leave the app
  fully functional.

---

## Backlog

Shelved pending real-use signal. Ordered by my assessment of value, which the soak period may well
overturn — that's the point of soaking.

### 1. Custom vocabulary

Meeting transcripts fail overwhelmingly on proper nouns: people's names, product names, acronyms,
company names. Everything else transcribes well, and the proper nouns are precisely what needs to be
right.

`AnalysisContext.contextualStrings` biases recognition toward supplied terms, so this is contained to
the transcription layer plus a term-list UI. No new targets. Improves every subsequent transcript.

**Why it's first:** it fixes the failure mode that degrades output quality, rather than adding
surface area.

### 2. Audio import

A share extension to bring in Voice Memos, WhatsApp voice notes, and video files. New target plus
`AVAsset` format handling.

**Why it's second:** more work for narrower benefit. It only pays off against a backlog of existing
audio. If the app is only ever used to record live meetings, it delivers nothing.

### 3. Speaker diarization

"Who said that" is the most-requested capability in this category and the most expensive.
`SpeechAnalyzer` does not provide it, so it means a separate model plus a clustering pipeline — a
project unto itself, deliberately excluded from v1.

**Only worth it** if the soak period shows this is the thing you keep reaching for and can't get.

### 4. Smaller candidates

Considered during planning, not chosen for v1:

- **One-tap start** — Control Center control or Action Button. Meetings begin abruptly and "open app,
  tap record" loses the opening.
- **iCloud sync** — SwiftData + CloudKit. Complicates the audio-file story considerably.
- **Export formats** — SRT/VTT (timestamps), PDF. Plain text and Markdown cover the real cases.
- **Face ID lock**, tags/folders.

---

## iOS 27 readiness

Checked October 2026. **Caveat: the findings below come from third-party developer blogs, not
Apple's release notes.** Confirm against the iOS 27 SDK release notes and Xcode's own documentation
before treating any of it as settled.

### Audited and clean

The codebase was checked against every iOS 27 breaking change these sources reported, and currently
trips none of them:

| Reported change | This app |
|---|---|
| Scene lifecycle now mandatory | Clean — SwiftUI `App` + `WindowGroup` |
| Launch screen declaration required | Clean — `UILaunchScreen` present in `Info.plist` |
| `@State` is now a macro; values set in both declaration and `init` get discarded | Clean — no `@State` initialized in `init` |
| `PreviewProvider` deprecated (use `#Preview`) | Clean — not used |
| `canOpenURL` deprecated | Clean — not used |
| On Demand Resources deprecated | Clean — not used |

### One known exposure

`AVAudioNode.installTap(onBus:bufferSize:format:block:)` is reportedly deprecated in iOS 27.
Used at **`ios/MeetingNotes/Audio/AudioRecorder.swift:125`**.

This is a deprecation, so it produces a **build warning, not an error** — nothing breaks. Worth
tracking rather than fixing reactively; when Apple's replacement is confirmed, migrating is a
contained change to one method in `AudioRecorder`.

### Toolchain notes

Reportedly: Xcode 27 requires macOS Tahoe 26.6+, ships Swift 6.4, and has removed the old `ld64`
linker. App Store uploads require the iOS 27 SDK from April 2027 — so migration has a real deadline
even though nothing is urgent today.

Unverified claims seen but not corroborated: that the Foundation Models API was "rewritten" in
iOS 27. If true, `SummaryService` is the thing to check first. No details were available.

---

## During the soak period

The most useful thing to produce is **a rough log of friction as it happens**: mis-transcribed names,
moments you wanted a feature, anything that felt wrong. Specific annoyances from real use are far
better input than a feature list, and they're nearly impossible to reconstruct months later.

That log should drive which backlog item gets built — not the ordering above.

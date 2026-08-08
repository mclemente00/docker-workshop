# Step 10 manual test script

Covers: export, consent notice, settings (live transcription, locale, audio retention), and
storage management (discard audio / keep transcript), plus the schema migration that underpins
the storage feature.

Run these in order — several later sections assume state from earlier ones (e.g. an existing
recording with a completed transcript). Check each box as you go; note anything that doesn't
match "Expected."

## 0. Pre-flight: migration didn't lose data

Only relevant if you have recordings from before this build.

- [ ] Rebuild and run over your **existing** install (don't delete the app first)
- [ ] Library still shows your prior recordings, titles/transcripts intact
- [ ] Open one — transcript, bookmarks, and summary (if it had one) still there
- [ ] Playback still works

**Expected:** nothing lost. This is the `MeetingNotesSchemaV1` → `V2` lightweight migration
(adds `Recording.audioDiscarded`) running automatically on launch.

## 1. Consent notice (one-time)

- [ ] Fresh install (or reset by clearing `hasAcknowledgedConsent` — easiest is a clean
      reinstall since there's no in-app reset yet)
- [ ] Tap **Record** on the library screen
- [ ] A non-dismissible "Before You Record" screen appears (can't swipe it away)
- [ ] Tap **I Understand**
- [ ] It proceeds directly into the Record screen
- [ ] Cancel out, tap **Record** again
- [ ] Consent screen does **not** appear a second time — goes straight to Record

**Expected:** shown exactly once, ever, then never again.

## 2. Settings screen

- [ ] Tap the gear icon (top-left on the library screen)
- [ ] Settings sheet opens with three sections: Live Transcription toggle, Transcription
      Language picker, Keep Audio For picker
- [ ] Transcription Language list populates with real language names (not empty, not raw
      identifiers like `en_US`) — may take a second, it's fetched live from the Speech framework
- [ ] Change the language selection, dismiss, reopen Settings — selection persisted
- [ ] Change "Keep Audio For", dismiss, reopen — persisted

## 3. Locale picker actually takes effect

- [ ] In Settings, set Transcription Language to something other than your device's default
      (if available)
- [ ] Record a short clip, speaking in that language if you can, or just note the setting
- [ ] After transcription completes, check the transcript came back reasonably (not garbled/empty)

**Expected:** confirms `RecordView`'s mic check and the deferred transcription are both using the
picked locale instead of the old hardcoded `Locale.current`.

## 4. Live transcription toggle — OFF (default)

- [ ] Confirm the toggle is off in Settings
- [ ] Record a clip past the 30-second mic check
- [ ] No growing text preview appears in the Record screen after the mic check resolves —
      just the mic-check status line, level meter, and timer, same as before this step

## 5. Live transcription toggle — ON

- [ ] Turn the toggle on in Settings
- [ ] Start a new recording, talk continuously through and past the 30-second mic check
- [ ] After the mic check resolves ("Mic sounds good" or "No speech heard"), a scrolling text
      preview should appear below the timer and start filling in with what you're saying
- [ ] Tap Pause — preview stops growing
- [ ] Tap Resume — preview starts growing again
- [ ] Stop the recording
- [ ] Open the recording afterward — the **final** transcript should still look complete and
      correct (the live preview is best-effort only; the deferred pass after stop remains the
      source of truth for the saved transcript)

## 6. Export — plain text and Markdown

- [ ] Open a recording with a completed transcript
- [ ] Tap "…" → **Share Transcript** → **Plain Text**
- [ ] Share sheet appears with readable text: title, date, transcript lines (and summary/
      bookmarks sections if that recording has them)
- [ ] Send it somewhere you can inspect (Notes, Messages to yourself, Files)
- [ ] Repeat with **Markdown** — confirm `#`/`##` headers and `- [ ]` action-item checkboxes
      render correctly wherever you paste it (e.g. Notes renders Markdown-ish, or just eyeball
      the raw text)
- [ ] Confirm **Share Audio** (separate menu item) still shares the `.m4a` file directly

## 7. Discard audio, keep transcript

- [ ] Open a recording with a **completed** transcript
- [ ] Tap "…" — confirm you see **Discard Audio, Keep Transcript**
- [ ] Open a recording that's still **pending/transcribing** — confirm that option is **absent**
      (deleting the audio before transcription finishes would break the in-flight job)
- [ ] Back on the completed recording, tap **Discard Audio, Keep Transcript**
- [ ] Playback controls are replaced with an "Audio discarded — transcript kept" notice
- [ ] Transcript is still fully browsable, tap-to-seek on transcript lines does nothing (no
      crash, just a no-op since there's no audio to seek)
- [ ] "…" menu: **Share Audio** is now gone; **Share Transcript** still works
- [ ] Back in the library list, that recording shows a small trash-slash icon next to its status
- [ ] Force-quit and relaunch the app — discarded state persisted (didn't revert)

## 8. Automatic audio retention

Hard to test on a real clock without waiting days, so this is a code-path sanity check rather
than a full simulation:

- [ ] In Settings, set "Keep Audio For" to **30 Days**
- [ ] Relaunch the app (retention cleanup runs once each time the library screen appears)
- [ ] Any *recent* recordings should be unaffected (their audio still plays)
- [ ] Set it back to **Keep Forever** when done, unless you want it on

If you want to force a real end-to-end check: temporarily record something, then in Xcode's
debugger set that recording's `createdAt` far enough in the past (or ask me and I'll add a
temporary debug hook) — not required for normal testing, just flagging it's the one path here
that can't be exercised in real time.

## 9. Regression pass (quick)

Make sure nothing earlier broke:

- [ ] Bookmarks still capture and jump correctly (step 6)
- [ ] Live Activity still shows on Lock Screen / Dynamic Island with working Stop (step 7)
- [ ] Generate Summary still works, still refuses to invent action items (step 9)

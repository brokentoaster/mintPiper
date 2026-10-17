# TBC-speak-watch: Debounced voice updates from streaming stdout

## Goal
A user piping any command's stdout (or tailing a log) hears a spoken summary
whenever the output goes quiet, instead of a voice announcement for every
write. With the defaults they get the *last line* spoken (e.g. the newest
progress percentage) after 1 second of silence; optionally the *delta* (all
lines since the previous announcement) instead. "GNU watch, but for voice."

## Context
- The local piper TTS stack already exists: `piper` binary and voices in
  `$HOME/.local/share/piper`, plus a working one-shot speaker script
  (`~/.agents/skills/speak-text/scripts/speak.sh [voice] [file]`).
- Raw streaming output is hostile to TTS: progress bars rewrite one line many
  times per second, and speaking every write is unintelligible and laggy.
  The missing piece is a debounce/throttle layer between a stream and the
  speaker.

## Scope

### In scope
- A standalone filter script (stdin → stdout-to-speaker), pipeable:
  `some-command | speak-watch [voice] [quiet_seconds]`
  and `tail -f file.log | speak-watch`.
- Debounce: nothing is spoken until stdin has been quiet for
  `quiet_seconds` (default 1). New input during a spoken announcement is
  buffered and covered by the next quiet period; announcements never overlap.
- Two update modes:
  - **last** (default): speak only the most recent line of the quiet burst.
  - **delta**: speak all lines received since the previous announcement,
    joined into one utterance.
- Voice selection passed through to the TTS layer (numeric index or short
  name like `alan`, `alba`), same semantics as speak.sh.
- Speech-friendly cleanup of the text to be spoken (strip markdown noise,
  pronounce `%` as "percent", skip empty lines).
- End-of-stream handling: when stdin closes, any pending unspoken burst is
  spoken once, then the tool exits.
- Long-line protection: text longer than a configured limit (default ~300
  chars) is truncated for speech (progress bars can be enormous).

### Out of scope
- Any GUI, daemon, or background service; no interception of other programs'
  stdout without an explicit pipe.
- Windows/macOS or non-ALSA audio; Wayland/headless environments.
- Speaking stderr, exit codes, or process completion status.
- Reading files directly (speak.sh already covers that path).
- Config files; all options are CLI arguments/env only.

## Constraints & Assumptions
- Depends on the existing piper install at `$HOME/.local/share/piper` and
  `aplay`; no new binaries or downloads.
- Target is glibc Linux with GNU awk (gawk) available; POSIX-shell friendly
  where practical but bash is acceptable (matches speak.sh).
- Audio is exclusive-ish: overlapping announcements from other apps may mix;
  this tool must never self-overlap.
- Latency budget: an announcement should start within ~0.5 s of the quiet
  period elapsing.

## Decisions
- Debounce model chosen over interval (cron-like) model: the user asked for
  "when the output has stopped", and quiet-detection avoids speaking
  mid-burst.
- Default mode is **last line only**; **delta** mode remains available as a
  flag (user confirmed).
- Default quiet period: 1 second (user confirmed).
- Standalone script, not added to the speak-text skill (user confirmed); it
  may call speak.sh internally or shell out to piper directly as long as
  voice-selection semantics match.
- Implemented as a small line-oriented filter (awk or equivalent) rather
  than a compiled tool; no new dependencies beyond what exists.

## Acceptance Criteria
1. Given a stream that writes 10 lines in rapid succession then goes silent,
   When the quiet period (default 1 s) elapses, Then exactly one utterance
   is spoken, containing the last line (default) or all 10 lines (delta
   mode) — not 10 utterances.
2. Given a progress-style stream that rewrites "42%" every 200 ms for 30 s,
   Then updates are spoken only after gaps of at least the quiet period,
   each announcing the most recent percentage, and no utterance contains a
   stale intermediate percentage spoken after a newer one was seen.
3. Given two bursts separated by more than the quiet period, Then two
   separate utterances are spoken, in order, with no overlap.
4. Given lines arriving while an utterance is being spoken, Then those lines
   are not lost; they are included in the next announcement.
5. Given stdin closing immediately after final output, Then the final burst
   is spoken exactly once and the tool exits 0.
6. Given an invalid voice argument, Then a nonzero exit occurs with the
   available voices listed (matching speak.sh behavior).
7. Given a quiet-seconds argument of `0` or non-numeric, Then the default
   (1) is used rather than erroring or busy-looping.
8. Given a last line longer than the truncation limit, Then the spoken text
   is truncated (silently to the ear) and the tool continues.
9. Given a stream emitting empty/whitespace-only lines only, Then nothing is
   spoken.

## Verification Plan
- Burst test: `{ for i in 1..10; do echo "step $i"; done; sleep 3; } | speak-watch`
  with speech stubbed (TTS swapped for `echo`) — assert one announcement,
  containing "step 10".
- Progress test: emit `N%` lines every 200 ms with jitter, stubbed speaker
  writing to a log with timestamps — assert announcement cadence ≥ quiet
  period and last-line-only content.
- Overlap test: two bursts 2 s apart; assert two logged utterances, ordered.
- Delta mode test: same fixture with delta flag; assert all lines present.
- EOF test: pipe a finite stream; assert final burst spoken and exit 0.
- Bad-input tests: invalid voice, `0`/non-numeric quiet, empty lines.
- One live audio smoke test with the real piper voice (alan) reading a
  short burst.

## Rollback Plan
- Single standalone script; delete the file to undo. No system state, config,
  or other scripts are modified.

## Open Questions
- Should repeated identical last lines (e.g. stuck at "42%" through several
  quiet periods) be re-spoken, or suppressed until the value changes?
- Preferred flag names for delta mode and quiet seconds (e.g. `-d`,
  `--delta`, positional vs long options) — left to implementation.

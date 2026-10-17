# AGENTS.md

Guidance for AI agents working in this repository.

## What this project is

mintPiper is a small Linux Mint desktop utility that reads selected screen text aloud using the local [piper](https://github.com/rhasspy/piper) neural TTS engine. It is a deployment/setup project, not a conventional buildable application: the repo contains scripts and an installer that download prebuilt piper binaries and voice models into a user-chosen directory. There is no compiler, package manager, or test suite.

## Repository layout

- `setup.sh` — the installer. Run as `./setup.sh <target-folder> <arch>` where arch is one of `amd64|arm64|armv7`. Downloads the piper v1.1.0 release tarball and the `en_US-amy-low` voice (ONNX + JSON config) from Hugging Face, then copies the scripts, icon, and `silence/silence.wav` into `<target>/piper/`.
- `scripts/playSelectedTTS.sh` — the core runtime: reads the X11 clipboard selection via `xclip -out selection`, writes it to a temp file, runs `piper --model en_US-amy-low.onnx --output_file <wav>`, then plays it with `aplay`. Also appends a timestamped log line to `/tmp/piper.log`.
- `scripts/mintPiper.py` — a GTK3 + XApp (Linux Mint) system-tray/status icon. "Run Piper TTS" menu item shells out to `xterm -T mintPiper -e playSelectedTTS.sh`. Includes an About dialog; loads `orange_piper.png` from its own directory.
- `silence/silence.wav` — a short silence file prepended to playback by `aplay` (see playSelectedTTS.sh).

## How the pieces fit together

1. `setup.sh` installs everything into `<target>/piper/` and prints two commands the user wires up manually:
   - Keyboard shortcut: `xterm -e "<target>/piper/playSelectedTTS.sh"`
   - Startup application (panel icon): `<target>/piper/mintPiper.py`
2. Triggering either path launches `playSelectedTTS.sh`, which is where all TTS work happens. `mintPiper.py` is purely a launcher/UI wrapper around it.
3. Both scripts resolve their dependencies relative to their own directory (`dirname $0` / `pathlib.Path(__file__).parent`), so they must sit alongside the piper binary, model, and icon as arranged by setup.sh.

## Running / testing manually

There is no automated test suite. To exercise the pipeline by hand on a Linux desktop with X11:

1. Run `./setup.sh /tmp/piper-test amd64` (requires `wget aplay tar xclip date xterm` on PATH — setup.sh checks these and exits with code 2 if any are missing).
2. Copy text into the X selection (`xclip`), then run `/tmp/piper-test/piper/playSelectedTTS.sh`.
3. Check `/tmp/piper.log` for invocation entries.

Note: `xclip` reads the X11 selection, so this will not work from a headless/Wayland-only session.

## Conventions and gotchas

- Scripts use `set -eo pipefail`; a failing command aborts the script.
- `mintPiper.py` requires `gi.require_versions({'Gtk': '3.0','XApp': '1.0'})` — the XApp bindings (`python3-xapp` / gir packages) are Mint-specific and not a standard GTK install. The script cannot run without them.
- The tray icon path, piper binary, and voice model are all expected in the *installed* directory, not the repo checkout. Running `scripts/mintPiper.py` or `playSelectedTTS.sh` directly from the repo will fail until `setup.sh` has populated a target folder (and even then, scripts are copied out, not run in place).
- `playSelectedTTS.sh` uses `$RANDOM` temp filenames in `/tmp`; it cleans up with `rm ... || :` so missing temp files don't error.
- Playback prepends `silence.wav` before the generated wav in a single `aplay` invocation — keep this pattern if adding audio output.
- Python style: single class, no external pip dependencies (stdlib + gi only), f-strings, `-u` shebang for unbuffered output. Version string lives in `VERSION` in mintPiper.py.
- Target platforms are Cinnamon/XFCE-style Mint desktops; X11 tooling (`xclip`, `xterm`) is assumed present.

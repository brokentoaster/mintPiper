---
name: speak-text
description: >
  Read a document, file, or response aloud using the local piper TTS engine.
  Use when the user asks to "read this aloud", "speak this", "say this",
  "read back", or wants audio playback of text or a file's contents.
---

# Speak Text Aloud

Speak text using local piper TTS (voices in `$HOME/.local/share/piper`).

## How to speak

Run the helper script (pipe text on stdin, or pass a file as the 2nd argument):

```bash
echo "Text to speak" | /home/nick/.agents/skills/speak-text/scripts/speak.sh
/home/nick/.agents/skills/speak-text/scripts/speak.sh "" /path/to/document.md
/home/nick/.agents/skills/speak-text/scripts/speak.sh alba "Some text to read"
/home/nick/.agents/skills/speak-text/scripts/speak.sh 2 /path/to/file.txt
```

- Argument 1 (optional): voice, 1-based index or short name/substring (e.g. `alan`, `alba`, `amy`). Omit or empty string to use the default voice.
- Argument 2 (optional): path to a text file to read. If omitted, text is read from stdin.
- The script blocks until playback finishes; audio plays on the default ALSA device.

## Preparing text for speech

Before piping text in, clean it up so the speech sounds natural:

- Strip markdown syntax: remove code fences, tables, links (`[text](url)` → text), emphasis markers, and headings' `#` symbols.
- Convert bullets/numbers into plain sentences.
- Add pauses for blank lines or after headings or in lists
- Keep responses to a reasonable spoken length; for long documents, summarise or ask the user whether to read everything.

## Available voices

List voices with `ls $HOME/.local/share/piper/*.onnx`. Currently installed include
`en_GB-alan-medium`, `en_GB-alba-medium`, `en_GB-northern_english_male-medium`,
`en_GB-southern_english_female-low`, `en_US-amy-low`.

## Requirements

- Requires an audio-capable desktop session (`aplay`/ALSA). Will fail headless.
- `piper` binary lives in `$HOME/.local/share/piper/piper` (installed by mintPiper's setup.sh).

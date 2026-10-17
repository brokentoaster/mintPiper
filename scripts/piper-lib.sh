#!/bin/bash
# piper-lib.sh — shared helpers for the mintPiper speak scripts.
# Source this file; do not execute it directly.

PIPER_DIR="${PIPER_DIR:-$HOME/.local/share/piper}"

require_piper() {
	[ -x "$PIPER_DIR/piper" ] || { echo "piper not found in $PIPER_DIR" >&2; exit 1; }
}

print_voice_list() {
	(cd "$PIPER_DIR" && ls *.onnx 2>/dev/null || true) | nl -w2 -s"    " -v1
}

# find_voice [pick] — echo the resolved *.onnx filename (or exit 1).
# pick: empty (first voice), 1-based index, exact short name, or unique substring.
find_voice() {
	voices=($(cd "$PIPER_DIR" && ls *.onnx 2>/dev/null || true))
	if [ ${#voices[@]} -eq 0 ]; then
		echo "No .onnx voices found in $PIPER_DIR" >&2
		exit 1
	fi
	local pick="$1"
	if [ -z "$pick" ]; then
		echo "${voices[0]}"
		return
	fi
	if [[ "$pick" =~ ^[0-9]+$ ]]; then
		if [ "$pick" -ge 1 ] && [ "$pick" -le ${#voices[@]} ]; then
			echo "${voices[$((pick-1))]}"
			return
		fi
		echo "Invalid voice index: $pick (1..${#voices[@]})" >&2
		exit 1
	fi
	local v matches=()
	for v in "${voices[@]}"; do
		if [ "$v" = "$pick.onnx" ]; then
			echo "$v"
			return
		fi
		case "$v" in *"$pick"*) matches+=("$v") ;; esac
	done
	if [ ${#matches[@]} -eq 1 ]; then
		echo "${matches[0]}"
		return
	fi
	if [ ${#matches[@]} -eq 0 ]; then
		echo "No voice matching '$pick' in $PIPER_DIR" >&2
	else
		echo "Ambiguous voice '$pick', matches: ${matches[*]}" >&2
	fi
	echo "Available voices:" >&2
	print_voice_list >&2
	exit 1
}

# find_speaker <voice_file> [pick] — echo a valid speaker id (default 0).
find_speaker() {
	local voice_file="$1"
	local num_speakers
	num_speakers=$(python3 -c 'import json,sys; print(int(json.load(open(sys.argv[1])).get("num_speakers", 1)))' "$PIPER_DIR/$voice_file.json" 2>/dev/null || echo 1)
	if [ -z "${2:-}" ]; then
		echo 0
	elif [[ "$2" =~ ^[0-9]+$ ]] && [ "$2" -lt "$num_speakers" ] 2>/dev/null; then
		echo "$2"
	else
		echo "Invalid speaker: ${2:-} (num_speakers=$num_speakers for $voice_file)" >&2
		echo "Defaulting to speaker 0" >&2
		echo 0
	fi
}

# find_sample_rate <voice_file> — echo the voice's sample rate (default 22050).
find_sample_rate() {
	python3 -c 'import json,sys; print(int(json.load(open(sys.argv[1]))["audio"]["sample_rate"]))' "$PIPER_DIR/$1.json" 2>/dev/null || echo 22050
}

# find_speak_cli — echo the path of an executable speak script.
find_speak_cli() {
	local here
	here="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
	local candidate
	for candidate in "$here/speak" "$here/speak.sh" "$HOME/.local/bin/speak"; do
		if [ -x "$candidate" ]; then
			echo "$candidate"
			return 0
		fi
	done
	echo "speak script not found (looked in $here and $HOME/.local/bin)" >&2
	return 1
}

# speak_text <voice> <speaker> <stream:0|1> <text> — speak one utterance via the speak script.
speak_text() {
	local voice="$1" speaker="$2" stream="$3" text="$4"
	local speak_cli args=()
	speak_cli="$(find_speak_cli)" || return 1
	[ -n "$voice" ] && args+=("$voice")
	if [ -n "$speaker" ]; then
		args+=("" "$speaker")
	fi
	[ "$stream" = 1 ] && args+=(--stream)
	printf '%s' "$text" | "$speak_cli" "${args[@]}"
}

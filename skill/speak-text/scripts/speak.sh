#!/bin/bash
# speak.sh [voice] [file]
# Speaks text aloud with piper. voice: index or short name (e.g. alan, alba).
# file: path to a text file; if omitted, text is read from stdin.
set -eo pipefail

dir="$HOME/.local/share/piper"
voice_arg="${1:-}"
file_arg="${2:-}"

[ -x "$dir/piper" ] || { echo "piper not found in $dir" >&2; exit 1; }

# resolve voice: index (1-based) or short-name/substring match on *.onnx
voices=($(cd "$dir" && ls *.onnx 2>/dev/null || true))
[ ${#voices[@]} -gt 0 ] || { echo "No .onnx voices in $dir" >&2; exit 1; }

pick="$voice_arg"
if [ -z "$pick" ]; then
    voice_file="${voices[0]}"
elif [[ "$pick" =~ ^[0-9]+$ ]] && [ "$pick" -ge 1 ] && [ "$pick" -le ${#voices[@]} ]; then
    voice_file="${voices[$((pick-1))]}"
elif [ -f "$dir/$pick.onnx" ]; then
    voice_file="$pick.onnx"
else
    matches=()
    for v in "${voices[@]}"; do
        case "$v" in *"$pick"*) matches+=("$v") ;; esac
    done
    if [ ${#matches[@]} -eq 1 ]; then
        voice_file="${matches[0]}"
    else
        echo "Voice '$pick' not found or ambiguous. Available:" >&2
        printf '  %s\n' "${voices[@]}" >&2
        exit 1
    fi
fi

tmp=$(mktemp /tmp/speak.XXXXXX.wav)
trap 'rm -f "$tmp"' EXIT

if [ -n "$file_arg" ]; then
    cat "$file_arg"
else
    cat
fi | "$dir/piper" --model "$dir/$voice_file" --output_file "$tmp"

aplay "$dir/silence.wav" "$tmp" 2>/dev/null || aplay "$tmp"

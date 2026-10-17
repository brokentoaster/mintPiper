#!/bin/bash

set -eo pipefail

dir="$HOME/.local/share/piper"
input="/tmp/toplay.$RANDOM-$RANDOM"
wav="/tmp/toplay.$RANDOM-$RANDOM.wav"

usage() {
	echo "usage: $0 [voice] [speaker]"
	echo "  voice: numeric index (1-based, see list below) or short name, e.g. alan, alba"
	echo "  speaker: numeric speaker id (0-based); must be < num_speakers of the chosen voice, defaults to 0"
	echo "  available voices:"
	(cd "$dir" && ls *.onnx 2>/dev/null || true)|nl -w2 -s"    " -v1   
}

find_voice() {
	voices=($(cd "$dir" && ls *.onnx 2>/dev/null || true))
	if [ ${#voices[@]} -eq 0 ]; then
		echo "No .onnx voices found in $dir" >&2
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
		usage >&2
		exit 1
	fi
	for v in "${voices[@]}"; do
		if [ "$v" = "$pick.onnx" ]; then
			echo "$v"
			return
		fi
	done
	local matches=()
	for v in "${voices[@]}"; do
		case "$v" in
			*"$pick"*) matches+=("$v") ;;
		esac
	done
	if [ ${#matches[@]} -eq 1 ]; then
		echo "${matches[0]}"
		return
	fi
	if [ ${#matches[@]} -eq 0 ]; then
		echo "No voice matching '$pick' in $dir" >&2
	else
		echo "Ambiguous voice '$pick', matches: ${matches[*]}" >&2
	fi
	usage >&2
	exit 1
}

find_speaker() {
	local voice_file="$1"
	num_speakers=$(python3 -c 'import json,sys; print(int(json.load(open(sys.argv[1])).get("num_speakers", 1)))' "$dir/$voice_file.json" 2>/dev/null || echo 1)
	if [ -z "${2:-}" ]; then
		speaker=0
	elif [[ "$2" =~ ^[0-9]+$ ]] && [ "$2" -lt "$num_speakers" ] 2>/dev/null; then
		speaker="$2"
	else
		echo "Invalid speaker: ${2:-} (num_speakers=$num_speakers for $voice_file)" >&2
		echo "Defaulting to speaker 0" >&2
		speaker=0
	fi
	echo "$speaker"
}

voices=""
voice_file="$(find_voice "$1")"
speaker="$(find_speaker "$voice_file" "$2")"

data=$(xclip -out selection | sed 's/^$/./')
if [ ${#data} -gt 2 ]; then
    echo $data > $input
    echo "$(date) voice: $voice_file speaker: $speaker data: $input" >> /tmp/piper.log &
    "$dir"/piper --model "$dir/$voice_file" --speaker "$speaker" --output_file $wav \
        --sentence-silence 1 < $input &
    wait
    aplay $dir/silence.wav $wav
    rm $input $wav || :
fi

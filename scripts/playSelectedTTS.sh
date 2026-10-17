#!/bin/bash
# playSelectedTTS — read the X11 clipboard selection aloud.
# Usage: playSelectedTTS.sh [voice] [speaker] [--stream]
#   voice    numeric index (1-based) or short name, e.g. alan, alba
#   speaker  numeric speaker id (0-based); must be < num_speakers of the voice
#   --stream pipe piper's raw audio straight to aplay (no wav file)
set -eo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
. "$here/piper-lib.sh"

stream=0
positional=()
for a in "$@"; do
	case "$a" in
		--stream) stream=1 ;;
		-h|--help)
			grep "^#" "$0" | grep -v "^#!/bin/bash" | sed 's/^# \{0,1\}//'
			exit 0
			;;
		*) positional+=("$a") ;;
	esac
done
voice_arg="${positional[0]:-}"
speaker_arg="${positional[1]:-}"

data=$(xclip -out selection) || exit 0
[ ${#data} -gt 2 ] || exit 0

speak_cli="$(find_speak_cli)"

input="/tmp/toplay.$RANDOM-$RANDOM"
echo "$data" > "$input"
echo "$(date) data: $input" >> /tmp/piper.log &

args=("$voice_arg")
[ -n "$speaker_arg" ] && args+=("")
[ -n "$speaker_arg" ] && args+=("$speaker_arg")
[ "$stream" = 1 ] && args+=(--stream)

"$speak_cli" "${args[@]}" < "$input"
rm -f "$input" || :

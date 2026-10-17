#!/bin/bash
# speak-watch.sh [voice] [quiet_secs]
# Reads stdin continuously; when output has been quiet for quiet_secs
# (default 1), speaks the lines that arrived since the last spoken update.
# If you only want the LAST line rather than the whole delta, set
# ONLY_LAST=1 in the environment.
#
# Usage examples:
#   tail -f build.log | speak-watch.sh alan 2
#   ./someprogress-command | speak-watch.sh          # quiet 1s, default voice
set -uo pipefail

SPEAK="/home/nick/.agents/skills/speak-text/scripts/speak.sh"
voice_arg="${1:-}"
quiet="${2:-1}"

awk -v quiet="$quiet" -v only_last="${ONLY_LAST:-0}" '
{
    now = systime()
    if (now - last > quiet && NR > 1) {          # previous burst went quiet: flush it
        flush()
    }
    buf[++n] = $0
    last = now
}
END { flush() }

function flush() {
    if (n == 0) return
    out = (only_last == "1") ? buf[n] : buf[1]
    if (only_last != "1") {
        for (i = 2; i <= n; i++) out = out " " buf[i]
    }
    printf "%s\n", out
    n = 0
    last = systime()
}' | while IFS= read -r chunk; do
    [ -n "$chunk" ] && speak_chunk "$chunk"
done

speak_chunk() {
    # speech-friendly cleanups
    local text
    text=$(printf '%s' "$1" \
        | sed -E 's/[|`#*_~]+//g; s/https?:\/\/[^ ]+/link/g; s/[0-9]+%/percent /g')
    printf '%s' "$text" | "$SPEAK" "$voice_arg"
}

#!/usr/bin/env bash
# Emit a Geant4 batch macro whose /run/beamOn count is forced to <events>.
#
# Usage:   replace_beam_on.sh <events> [input-macro]
# Example: replace_beam_on.sh 100 run1.mac > callgrind_run.mac
#
# With an input macro, its existing /run/beamOn lines are stripped and a single
# "/run/beamOn <events>" is appended; every other line of the macro is kept as-is. Without an
# input macro, only the "/run/beamOn <events>" line is emitted. The result is written to stdout.
set -euo pipefail

events="${1:?usage: replace_beam_on.sh <events> [input-macro]}"
input="${2:-}"

if [ -n "$input" ]; then
	[ -f "$input" ] || { echo "ERROR: input macro '$input' not found" >&2; exit 1; }
	grep -vE '^[[:space:]]*/run/beamOn' "$input"
fi
printf '/run/beamOn %s\n' "$events"

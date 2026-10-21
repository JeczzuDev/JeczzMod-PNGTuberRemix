#!/bin/sh
# Copies the mod into the MODS test install, with the sandbox guard enabled.
# --selftest also registers mods/_tests/axis_selftest.gd, which rewrites the
# first sprite's follow settings 4s after start: never use it for manual testing.
set -e
B="$(cd "$(dirname "$0")" && pwd)"
M="$B/../PNGTubeRemix Windows MODS"
rm -rf "$M/mods"
mkdir -p "$M/mods"
cp -r "$B/mod/mods/." "$M/mods/"
touch "$M/mods/SANDBOX"
cp "$B/mod/override.cfg" "$M/override.cfg"
if [ "$1" = "--selftest" ]; then
	mkdir -p "$M/mods/_tests"
	cp "$B/mod/tests/"*.gd "$M/mods/_tests/"
	echo 'JeczzSelfTest="*res://mods/_tests/axis_selftest.gd"' >> "$M/override.cfg"
fi
echo "deployed to $M $1"

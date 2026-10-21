#!/bin/sh
# Builds dist/JeczzMod-MouseAxis-<version>/ and its .zip from mod/ (no test files, no SANDBOX).
set -e
B="$(cd "$(dirname "$0")" && pwd)"
V="$(sed -n 's/^const MOD_VERSION := "\(.*\)"$/\1/p' "$B/mod/mods/jeczz_mod_loader.gd")"
N="JeczzMod-FollowMovement-$V"
D="$B/dist/$N"
rm -rf "$D" "$B/dist/$N.zip"
mkdir -p "$D"
cp -r "$B/mod/mods" "$B/mod/override.cfg" "$D/"
rm -f "$D/mods/SANDBOX"
for f in "LEEME.txt" "Desinstalar JeczzMod.bat"; do
	sed 's/\r$//; s/$/\r/' "$B/mod/$f" > "$D/$f"
done
powershell -NoProfile -ExecutionPolicy Bypass -File "$(cygpath -w "$B/make_zip.ps1")" -Source "$(cygpath -w "$D")" -Zip "$(cygpath -w "$B/dist/$N.zip")"
echo "built $N"

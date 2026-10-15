#!/usr/bin/env bash
# Write dist/appcast.xml for Sparkle, signing dist/AI-Usage.dmg with the EdDSA key.
# Usage: SPARKLE_PRIVATE_KEY=... scripts/make-appcast.sh <download-url-prefix>
# Without SPARKLE_PRIVATE_KEY the key is read from the login Keychain.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

prefix="${1:?Pass the release download URL prefix, ending in /}"
derived="${DERIVED_DATA_PATH:-$root/.build}"
tools="$derived/SourcePackages/artifacts/sparkle/Sparkle/bin"
dmg="$root/dist/AI-Usage.dmg"
feed="$root/dist/feed"

if [[ ! -x "$tools/generate_appcast" ]]; then
  echo "Sparkle tools not found in $tools. Build the app first." >&2
  exit 1
fi
if [[ ! -f "$dmg" ]]; then
  echo "Missing $dmg. Run scripts/package-dmg.sh first." >&2
  exit 1
fi

rm -rf "$feed"
mkdir -p "$feed"
cp "$dmg" "$feed/"

args=(--download-url-prefix "$prefix" --maximum-deltas 0)
if [[ -n "${SPARKLE_PRIVATE_KEY:-}" ]]; then
  printf '%s' "$SPARKLE_PRIVATE_KEY" | "$tools/generate_appcast" --ed-key-file - "${args[@]}" "$feed"
else
  "$tools/generate_appcast" "${args[@]}" "$feed"
fi

cp "$feed/appcast.xml" "$root/dist/appcast.xml"
echo "Wrote $root/dist/appcast.xml"

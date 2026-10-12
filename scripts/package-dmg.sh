#!/usr/bin/env bash
# Build a Release "AI Usage.app" and wrap it in a drag-to-Applications disk image.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

app_name="AI Usage"
volume="AI Usage"
configuration="${CONFIGURATION:-Release}"
derived="${DERIVED_DATA_PATH:-$root/.build}"
app_path="${APP_PATH:-$derived/Build/Products/$configuration/$app_name.app}"
dmg_path="${DMG_PATH:-$root/dist/AI-Usage.dmg}"
background="$root/packaging/dmg-background.png"

if [[ "${SKIP_BUILD:-}" != "1" ]]; then
  args=(
    -scheme AIUsageWidget
    -configuration "$configuration"
    -destination "platform=macOS"
    -derivedDataPath "$derived"
    build
    CODE_SIGN_IDENTITY="-"
    CODE_SIGN_STYLE=Manual
  )
  if [[ -n "${MARKETING_VERSION:-}" ]]; then
    args+=(MARKETING_VERSION="$MARKETING_VERSION")
  fi
  if [[ -n "${CURRENT_PROJECT_VERSION:-}" ]]; then
    args+=(CURRENT_PROJECT_VERSION="$CURRENT_PROJECT_VERSION")
  fi
  xcodebuild "${args[@]}"
fi

if [[ ! -d "$app_path" ]]; then
  echo "Built app not found at $app_path" >&2
  exit 1
fi
if [[ ! -f "$background" ]]; then
  echo "Missing $background. Run: swift scripts/render-branding.swift" >&2
  exit 1
fi

venv="$root/dist/.venv"
if [[ ! -x "$venv/bin/dmgbuild" ]]; then
  python3 -m venv "$venv"
  "$venv/bin/pip" install --disable-pip-version-check 'dmgbuild==1.6.5'
fi

mkdir -p "$(dirname "$dmg_path")"
rm -f "$dmg_path"
"$venv/bin/dmgbuild" \
  -s "$root/packaging/dmg_settings.py" \
  -D app="$app_path" \
  -D background="$background" \
  "$volume" \
  "$dmg_path"

echo "Wrote $dmg_path"

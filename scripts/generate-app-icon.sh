#!/usr/bin/env bash
# Generate AppIcon.appiconset from assets/branding/logo-source.png.
# Uses sips (built-in) — no external deps.
#
# Xcode 14+ accepts a single 1024×1024 PNG in the "Single Size" app icon slot,
# but exporting the 10 individual sizes makes the icon visible on older toolchains
# and removes any ambiguity about which slot is canonical.

set -euo pipefail

cd "$(dirname "$0")/.."

SRC="assets/branding/logo-source.png"
OUT="GhosttyConfigurator/Resources/Assets.xcassets/AppIcon.appiconset"

if [[ ! -f "$SRC" ]]; then
    echo "ERROR: $SRC not found." >&2
    exit 1
fi

mkdir -p "$OUT"

# Downscale source to 1024×1024 master first (it ships as 1254×1254).
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
sips -Z 1024 "$SRC" --out "$TMP/master_1024.png" >/dev/null

# size_in_pt scale filename
SPECS=(
    "16   1x icon_16x16.png"
    "16   2x icon_16x16@2x.png"
    "32   1x icon_32x32.png"
    "32   2x icon_32x32@2x.png"
    "128  1x icon_128x128.png"
    "128  2x icon_128x128@2x.png"
    "256  1x icon_256x256.png"
    "256  2x icon_256x256@2x.png"
    "512  1x icon_512x512.png"
    "512  2x icon_512x512@2x.png"
)

CONTENTS='{
  "images" : ['
FIRST=1

for spec in "${SPECS[@]}"; do
    set -- $spec
    PT=$1 SCALE=$2 FILE=$3
    case "$SCALE" in
        1x) PX=$PT ;;
        2x) PX=$((PT * 2)) ;;
    esac

    sips -Z "$PX" "$TMP/master_1024.png" --out "$OUT/$FILE" >/dev/null
    echo "  wrote $FILE (${PX}x${PX})"

    if [[ $FIRST -eq 1 ]]; then FIRST=0; else CONTENTS+=","; fi
    CONTENTS+=$'\n    {
      "size" : "'"${PT}x${PT}"'",
      "idiom" : "mac",
      "filename" : "'"$FILE"'",
      "scale" : "'"$SCALE"'"
    }'
done

CONTENTS+='
  ],
  "info" : {
    "version" : 1,
    "author" : "xcode"
  }
}'

printf '%s\n' "$CONTENTS" > "$OUT/Contents.json"
echo "✓ AppIcon.appiconset generated at $OUT"

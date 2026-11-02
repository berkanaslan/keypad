#!/usr/bin/env bash
# Renders the full-bleed app icon into the macOS AppIcon set and the README image; macOS applies its own mask.
# Usage: Tools/AppIcon/render.sh docs/assets/icon.png Keypad/Resources/Assets.xcassets/AppIcon.appiconset docs/assets/icon-256.png
set -euo pipefail

source_image=$1
iconset=$2
readme_png=$3

render() {
  sips -s format png -z "$1" "$1" "$source_image" --out "$2" >/dev/null
}

for points in 16 32 128 256 512; do
  render "$points" "$iconset/icon_${points}x${points}.png"
  render $((points * 2)) "$iconset/icon_${points}x${points}@2x.png"
done
render 256 "$readme_png"

#!/usr/bin/env bash
# Recolors an image into the Violet palette (gradient map over the grey levels).
#   recolor.sh <image> [dusk|glow] [gamma]
#   dusk : dark, violet only on the highlights (default)
#   glow : black -> violet -> lavender, brighter
#   gamma: < 1 darkens bright images (e.g. 0.6), default 1
set -euo pipefail
in=$1; mode=${2:-dusk}; gamma=${3:-1}
case $mode in
  dusk) stops=('#0d0c10' '#141218' '#1f1630' '#40256f' '#8a5ad8' '#c9a8ff') ;;
  glow) stops=('#0d0c10' '#18141f' '#3d2566' '#7d4fd0' '#a77bf3' '#ece2ff') ;;
  *) echo "unknown mode: $mode" >&2; exit 1 ;;
esac
out="$(dirname "$0")/$(basename "${in%.*}")-$mode.png"
clut=()
for c in "${stops[@]}"; do clut+=("xc:$c"); done
magick "$in" -resize 1920x1080^ -gravity center -extent 1920x1080 -colorspace gray -auto-level -level "0%,100%,$gamma" \
  \( -size 1x1 "${clut[@]}" +append -filter Cubic -resize 256x1! \) -clut "$out"
echo "$out"

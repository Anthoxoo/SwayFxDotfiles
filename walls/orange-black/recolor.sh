#!/usr/bin/env bash
# Recolore une image dans la palette Orange Black (carte de dégradé sur les niveaux de gris).
#   recolor.sh <image> [dusk|ember|tan] [gamma]
#   dusk  : sombre, orange seulement sur les hautes lumières (défaut)
#   ember : noir -> orange -> crème, plus lumineux
#   tan   : noir -> tan -> greige, sans orange vif
#   gamma : < 1 assombrit les images claires (ex. 0.6), défaut 1
set -euo pipefail
in=$1; mode=${2:-dusk}; gamma=${3:-1}
case $mode in
  dusk)  stops=('#0e0e10' '#141416' '#2a1d12' '#6b3a0c' '#d97408' '#ffb04a') ;;
  ember) stops=('#0e0e10' '#1b1612' '#5a3410' '#c46a10' '#ff9a2a' '#f2dcb8') ;;
  tan)   stops=('#0e0e10' '#1e1a17' '#5e4a36' '#a8977f' '#c6a67f' '#e8dcc4') ;;
  *) echo "mode inconnu : $mode" >&2; exit 1 ;;
esac
out="$(dirname "$0")/$(basename "${in%.*}")-$mode.png"
clut=()
for c in "${stops[@]}"; do clut+=("xc:$c"); done
magick "$in" -resize 1920x1080^ -gravity center -extent 1920x1080 -colorspace gray -auto-level -level "0%,100%,$gamma" \
  \( -size 1x1 "${clut[@]}" +append -filter Cubic -resize 256x1! \) -clut "$out"
echo "$out"

#!/bin/bash
#
# Regenerate the launcher-icon overlay from the edited master images.
#
#   icon/master/*.png   (hand-edited sources, committed)
#        |  this script (ImageMagick)
#        v
#   icon/res/**         (all densities, WebP/PNG, committed) -> copied over
#                       upstream's res/ by the CI before building.
#
# Run this after changing anything in icon/master/. Requires ImageMagick.
#
# Usage: scripts/regen_icons.sh
set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
MASTER="$here/icon/master"
RES="$here/icon/res"

command -v magick >/dev/null || { echo "FATAL: ImageMagick 'magick' not found"; exit 1; }
for m in foreground background legacy_square legacy_round monochrome notif_icon; do
  test -f "$MASTER/$m.png" || { echo "FATAL: missing master $MASTER/$m.png"; exit 1; }
done

rm -rf "$RES"

# density bucket : foreground/background px : legacy launcher/round px
buckets="mdpi:108:48 hdpi:162:72 xhdpi:216:96 xxhdpi:324:144 xxxhdpi:432:192"

emit_webp() { # <src> <size> <dest.webp>
  magick "$1" -resize "${2}x${2}" -filter Lanczos -define webp:lossless=true "$3"
}

for b in $buckets; do
  dens="${b%%:*}"; rest="${b#*:}"; adaptive="${rest%%:*}"; legacy="${rest##*:}"
  d="$RES/mipmap-$dens"; mkdir -p "$d"
  emit_webp "$MASTER/foreground.png"    "$adaptive" "$d/ic_launcher_foreground.webp"
  emit_webp "$MASTER/background.png"     "$adaptive" "$d/ic_launcher_background.webp"
  emit_webp "$MASTER/legacy_square.png"  "$legacy"   "$d/ic_launcher.webp"
  emit_webp "$MASTER/legacy_round.png"   "$legacy"   "$d/ic_launcher_round.webp"
done

# Density-independent drawables.
mkdir -p "$RES/drawable"
magick "$MASTER/monochrome.png" -define webp:lossless=true "$RES/drawable/ic_launcher_monochrome.webp"
cp "$MASTER/notif_icon.png" "$RES/drawable/notif_icon.png"

echo "Regenerated overlay under $RES:"
find "$RES" -type f | sort | sed "s#$here/##"

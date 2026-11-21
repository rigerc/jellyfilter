#!/bin/bash
# Regenerate the website screenshots from the real app widgets.
#
# Downloads the public-domain posters credited in website/README.md, renders
# each scene in tool/website_screenshots/, and writes WebP files to
# website/src/assets/screenshots/. Needs curl and ImageMagick.

set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
work="$root/build/website_screenshots"
posters="$work/posters"
frames="$work/frames"
fonts="$(dirname "$(dirname "$(readlink -f "$(command -v flutter)")")")/bin/cache/artifacts/material_fonts"
out="$root/website/src/assets/screenshots"

mkdir -p "$posters" "$frames" "$out"

while read -r id file; do
  target="$posters/$id.img"
  [[ -s "$target" ]] && continue
  curl -fsSL -A "poster-fetch/1.0 (screenshot tooling)" -o "$target" \
    "https://commons.wikimedia.org/wiki/Special:FilePath/$file?width=600"
done <<'POSTERS'
general The_General_(1926)_-_Movie_Poster_2.png
goldrush Gold_rush_poster.jpg
phantom The_Phantom_of_the_Opera_(1925_film).jpg
lostworld The_Lost_World_(1925)_-_film_poster.jpg
safetylast Safety_last_poster.jpg
sherlockjr Sherlock_jr_poster.jpg
POSTERS

cd "$root"
flutter test \
  --dart-define=POSTER_DIR="$posters" \
  --dart-define=OUT_DIR="$frames" \
  --dart-define=FONT_DIR="$fonts" \
  tool/website_screenshots/website_screenshots_test.dart

for frame in "$frames"/*.png; do
  magick "$frame" -strip -quality 82 "$out/$(basename "${frame%.png}").webp"
done
echo "Wrote $(ls "$frames" | wc -l) screenshots to $out"

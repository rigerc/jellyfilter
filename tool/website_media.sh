#!/bin/bash
# Regenerate the website screenshots and tour video from the real app widgets.
#
#   tool/website_media.sh [screenshots|video|all]   (default: all)
#
# Downloads the public-domain posters credited in website/README.md, renders
# the scenes in tool/website_screenshots/, and writes WebP screenshots to
# website/src/assets/screenshots/ and the tour video to website/public/media/.
# Needs curl, ImageMagick, and ffmpeg (for the video).

set -euo pipefail

what="${1:-all}"
root="$(cd "$(dirname "$0")/.." && pwd)"
work="$root/build/website_media"
posters="$work/posters"
frames="$work/frames"
fonts="$(dirname "$(dirname "$(readlink -f "$(command -v flutter)")")")/bin/cache/artifacts/material_fonts"
screens="$root/website/src/assets/screenshots"
media="$root/website/public/media"

mkdir -p "$posters" "$frames" "$screens" "$media"

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

render() {
  flutter test \
    --dart-define=POSTER_DIR="$posters" \
    --dart-define=OUT_DIR="$frames" \
    --dart-define=FONT_DIR="$fonts" \
    "$root/tool/website_screenshots/$1"
}

cd "$root"

if [[ "$what" == screenshots || "$what" == all ]]; then
  render website_screenshots_test.dart
  for frame in "$frames"/*.png; do
    magick "$frame" -strip -quality 82 "$screens/$(basename "${frame%.png}").webp"
  done
  echo "Wrote screenshots to $screens"
fi

if [[ "$what" == video || "$what" == all ]]; then
  rm -rf "$frames/tour"
  render website_video_test.dart
  input=(-framerate 60 -i "$frames/tour/%05d.png")
  scale=(-vf "scale=720:-2:flags=lanczos")
  ffmpeg -loglevel error -y "${input[@]}" "${scale[@]}" \
    -c:v libx264 -preset slow -crf 23 -pix_fmt yuv420p \
    -movflags +faststart -an "$media/tour.mp4"
  ffmpeg -loglevel error -y "${input[@]}" "${scale[@]}" \
    -c:v libvpx-vp9 -crf 36 -b:v 0 -row-mt 1 -deadline good \
    -pix_fmt yuv420p -an "$media/tour.webm"
  magick "$frames/tour/00000.png" -resize 720x -strip -quality 80 \
    "$media/tour-poster.webp"
  rm -rf "$frames/tour"
  echo "Wrote tour video to $media"
fi

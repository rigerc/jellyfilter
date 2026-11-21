# Jellyfilter website

The Jellyfilter landing page uses [Landpack](https://github.com/lauroguedes/landpack) and Astro. It is hosted at [rigerc.github.io/jellyfilter](https://rigerc.github.io/jellyfilter/).

## Local development

From this directory, use Node.js 24 LTS and run:

```sh
npm ci
npm run dev
```

Open the URL printed by Astro. Edit the landing page copy in `src/content/`. The screenshots are in `src/assets/screenshots/`. If you change the name, palette, or hero copy, regenerate the social card with `npm run og:generate`.

## Build and deploy

```sh
npm run check
npm run build
npm run seo:check
```

The static site is built into `dist/`. GitHub Actions publishes it to GitHub Pages when website files change on `main`. Astro uses the GitHub Pages URL by default. Set `PUBLIC_SITE_URL` before building to target a different origin or base path.

## Poster credits

The screenshots and the tour video in `public/media/` are rendered from the app's own widgets with a sample library; the video advances one 60 fps frame of app time at a time, with a touch mark drawn where each tap or swipe lands. To refresh them after a UI change, run `tool/website_media.sh` from the repository root (use `screenshots` or `video` to render only one; it needs Flutter, curl, ImageMagick, and ffmpeg), then regenerate the social card. The theatrical posters and the TV publicity photos come from Wikimedia Commons, where they are marked public domain.

- [The General (1926)](https://commons.wikimedia.org/wiki/File:The_General_(1926)_-_Movie_Poster_2.png)
- [The Gold Rush (1925)](https://commons.wikimedia.org/wiki/File:Gold_rush_poster.jpg)
- [The Phantom of the Opera (1925)](https://commons.wikimedia.org/wiki/File:The_Phantom_of_the_Opera_(1925_film).jpg)
- [The Lost World (1925)](https://commons.wikimedia.org/wiki/File:The_Lost_World_(1925)_-_film_poster.jpg)
- [Safety Last! (1923)](https://commons.wikimedia.org/wiki/File:Safety_last_poster.jpg)
- [Sherlock Jr. (1924)](https://commons.wikimedia.org/wiki/File:Sherlock_jr_poster.jpg)
- [Star Trek (1968)](https://commons.wikimedia.org/wiki/File:Leonard_Nimoy_William_Shatner_Star_Trek_1968.JPG)
- [The Twilight Zone: Rod Serling (1959)](https://commons.wikimedia.org/wiki/File:Rod_Serling_photo_portrait_1959.JPG)
- [The Addams Family (1964)](https://commons.wikimedia.org/wiki/File:Addams_Family_main_cast_1964.JPG)
- [I Love Lucy (TV Guide, 1954)](https://commons.wikimedia.org/wiki/File:I_Love_Lucy_(TV_Guide,_December_25,_1954).jpg)
- [The Munsters (1964)](https://commons.wikimedia.org/wiki/File:The_Munsters_1964.JPG)
- [The Andy Griffith Show (1960)](https://commons.wikimedia.org/wiki/File:Andy_Griffith_Andy_Griffith_Show_1960.jpg)
- [Dragnet promo card](https://commons.wikimedia.org/wiki/File:Dragnet_promo_card.jpg)

See the [Landpack and Lumos license](public/landpack-license.txt) and the [Inter font license](public/OFL-Inter.txt).

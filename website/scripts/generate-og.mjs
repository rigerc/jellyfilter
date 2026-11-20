import { readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import sharp from "sharp";
import { parse } from "yaml";

const root = new URL("../", import.meta.url);
const content = new URL("src/content/project/main.yaml", root);
const project = parse(await readFile(content, "utf8"));
const css = await readFile(new URL("src/styles/global.css", root), "utf8");
const color = (name) =>
  css.match(new RegExp(`--${name}: (#[a-f0-9]+);`, "i"))?.[1];
const escape = (value) =>
  value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;");
const wrap = (value, length) => {
  const lines = [""];
  for (const word of value.split(/\s+/)) {
    const line = lines.at(-1);
    if (line && line.length + word.length + 1 > length) lines.push(word);
    else lines[lines.length - 1] = line ? `${line} ${word}` : word;
  }
  return lines;
};

const headline = wrap(project.headline, 14);
const intro = wrap(project.intro, 48);
if (headline.length > 3 || intro.length > 3) {
  throw new Error("Shorten the headline or intro so the social image fits.");
}

const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="630" viewBox="0 0 1200 630">
<rect width="1200" height="630" fill="${color("paper")}"/>
<text x="76" y="117" fill="${color("ink")}" font-family="sans-serif" font-size="36" font-weight="700">${escape(project.name)}</text>
${headline.map((line, index) => `<text x="72" y="${230 + index * 81}" fill="${color("ink")}" font-family="sans-serif" font-size="76" font-weight="700" letter-spacing="-2">${escape(line)}</text>`).join("\n")}
${intro.map((line, index) => `<text x="76" y="${210 + headline.length * 81 + index * 38}" fill="${color("muted")}" font-family="sans-serif" font-size="28">${escape(line)}</text>`).join("\n")}
</svg>`;
const screen = fileURLToPath(new URL(project.screenshots[0].image, content));
const screenshot = await sharp(screen).resize({ width: 260 }).png().toBuffer();
const output = fileURLToPath(new URL("public/og-image.jpg", root));
await sharp(Buffer.from(svg))
  .composite([{ input: screenshot, left: 852, top: 65 }])
  .jpeg({ quality: 92, mozjpeg: true })
  .toFile(output);
console.log("Generated public/og-image.jpg (1200 × 630).");

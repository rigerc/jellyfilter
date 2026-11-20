// @ts-check
import { defineConfig, fontProviders } from "astro/config";
import sitemap from "@astrojs/sitemap";
import { loadEnv } from "vite";
const env = loadEnv(
  process.env.NODE_ENV || "production",
  process.cwd(),
  "PUBLIC_",
);
const publicUrl = new URL(
  process.env.PUBLIC_SITE_URL ||
    env.PUBLIC_SITE_URL ||
    "https://rigerc.github.io/jellyfilter/",
);

export default defineConfig({
  site: publicUrl.origin,
  base: publicUrl.pathname,
  trailingSlash: "always",
  devToolbar: { enabled: false },
  integrations: [sitemap()],
  fonts: [
    {
      name: "Inter",
      cssVariable: "--font-inter",
      provider: fontProviders.local(),
      options: {
        variants: [
          {
            weight: 400,
            style: "normal",
            src: ["./src/assets/fonts/inter-regular.woff2"],
          },
        ],
      },
    },
  ],
  vite: { build: { cssTarget: "safari15.4" } },
});

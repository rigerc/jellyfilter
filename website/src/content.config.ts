import { defineCollection } from "astro:content";
import { glob } from "astro/loaders";
import { z } from "astro/zod";

const text = z.string().min(1);
const link = z
  .url()
  .refine((value) => /^https?:\/\//i.test(value), "Use an HTTP or HTTPS URL.");
const heading = z.object({
  title: text,
  description: text,
  order: z.number().int().positive(),
});

const project = defineCollection({
  loader: glob({ pattern: "*.yaml", base: "./src/content/project" }),
  schema: ({ image }) =>
    z.object({
      name: text,
      shortName: text,
      description: text,
      repository: link,
      docs: link,
      download: link,
      eyebrow: text,
      headline: text,
      headlineAccent: text,
      intro: text,
      background: z.enum(["grid", "glow", "rays"]).default("glow"),
      stats: z.array(
        z.object({ value: text, label: text, href: link.optional() }),
      ),
      screenshots: z
        .array(z.object({ image: image(), label: text, alt: text }))
        .min(1),
      featuresHeading: text,
      featuresIntro: text,
      setupHeading: text,
      setupIntro: text,
      faqHeading: text,
      ctaHeading: text,
      ctaIntro: text,
      seo: z
        .object({
          image: z.union([link, z.string().regex(/^\/(?!\/)[^\s]+$/)]),
          imageAlt: text,
          imageWidth: z.number().int().positive().optional(),
          imageHeight: z.number().int().positive().optional(),
        })
        .optional(),
    }),
});

const features = defineCollection({
  loader: glob({ pattern: "*.json", base: "./src/content/features" }),
  schema: heading.extend({
    icon: z.enum([
      "key",
      "globe",
      "apps",
      "shield",
      "users",
      "code",
      "activity",
      "palette",
      "book",
    ]),
  }),
});

const steps = defineCollection({
  loader: glob({ pattern: "*.json", base: "./src/content/steps" }),
  schema: heading.extend({
    link: z.object({ label: text, href: link }).optional(),
  }),
});

const faq = defineCollection({
  loader: glob({ pattern: "*.md", base: "./src/content/faq" }),
  schema: z.object({ question: text, order: z.number().int().positive() }),
});

export const collections = { project, features, steps, faq };

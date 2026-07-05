---
title: "Custom Documentation Sites in 2026: Building a Distinctive Dark-Themed Developer Reference on MkDocs Material Without Forking"
description: A three-file recipe for a bespoke MkDocs Material theme — terminal-green on near-black, custom hero + card grid, hash-locked build. No custom_dir, no fork.
date: 2026-07-05
---

# Custom Documentation Sites in 2026: Building a Distinctive Dark-Themed Developer Reference on MkDocs Material Without Forking

*Documentation is the public API surface of an open-source project; the difference between the default Material theme and a bespoke palette is the difference between "reads like every other project" and "reads like this specific project".*

*Sebastien Rousseau · Published 5 Jul 2026 · 11 min read*

## Why Documentation Aesthetics Matter in 2026 #

An open-source project's documentation site is the first surface an evaluator touches — before the README, before the release notes, before the code. In 2026, the density of developer-tool competition means that visual differentiation carries measurable weight: does the site feel like a curated product, or does it feel like a Jekyll-Cayman default from 2019? The felt distinction shapes adoption decisions before the reader has read a single sentence.

The reference standard for "distinctive open-source documentation" is [docs.n8n.io](https://docs.n8n.io) — dark, polished, opinionated, immediately identifiable as n8n's. n8n runs on GitBook, a commercial SaaS. Most open-source projects, [.dotfiles](https://doc.dotfiles.io) included, cannot justify GitBook's licensing but can invest in MkDocs Material customisation to achieve equivalent visual distinction on an open-source stack.

This article documents the migration of [doc.dotfiles.io](https://doc.dotfiles.io) from Jekyll's Cayman theme (the default when GitHub Pages serves markdown without a MkDocs configuration) to a fully customised MkDocs Material theme with a terminal-green-on-near-black palette, custom typography, and a hero + card-grid landing page.

## The Custom Docs Theme 2026 Architecture Lens #

MkDocs Material's customisation surface has four distinct layers, each with different capabilities and constraints:

| Layer | Design Decision | Why It Matters | Risk if Mishandled |
|---|---|---|---|
| **Palette declaration** | `mkdocs.yml` `theme.palette.primary: custom` + `accent: custom` | Signals to MkDocs Material that CSS custom properties will drive the palette rather than a named preset (green, teal, indigo, etc.) | Named presets constrain the palette to Material Design's colour tokens; `custom` unlocks arbitrary hex values via CSS variables |
| **CSS custom-property overrides** | `docs/stylesheets/extra.css` sets `--md-primary-fg-color`, `--md-accent-fg-color`, `--md-default-bg-color`, `--md-code-bg-color` under `[data-md-color-scheme="slate"]` | The single source of truth for the palette. Every Material component reads from these variables | Overriding component-level CSS rules rather than variables creates unmaintainable per-component drift as MkDocs Material upgrades |
| **Component restyling** | Same `extra.css` overrides selectors like `.md-header`, `.md-nav__link`, `.grid.cards > ul > li` | Where the "feels bespoke" work happens — spacing, borders, hover states, gradients, backdrop blur | Under-styling produces "Material Design in a different colour"; over-styling drifts away from Material's ergonomic defaults |
| **Landing-page markup** | `docs/index.md` with Front-Matter `hide: [navigation, toc]` + `<section class="dot-hero">` + `<div class="grid cards" markdown>` | The homepage is the highest-impact surface; it should not look like a table of contents | Default MkDocs Material index reads like documentation; a custom hero reads like a product page |

## Key Documentation-UX Signals #

| Signal | Operational Benchmark | Reference | Technical Platform Implementation |
|---|---|---|---|
| **Time-to-first-CTA** | Hero action button visible above the fold in ≤ 100 ms of first-paint | Landing-page conversion norms | Custom hero section with primary and secondary CTAs immediately below the site title |
| **Palette Distinctiveness** | Primary accent color is unique to the project, not a Material Design preset | Brand recognition | CSS custom property overrides on `[data-md-color-scheme]` selectors |
| **Reading Contrast** | WCAG AA compliance on all text-on-background pairs | Accessibility gate | `--md-default-fg-color` (`#e4e7ec`) on `--md-default-bg-color` (`#0b0e14`) = 15.6:1 ratio |
| **Cognitive Load per Section** | Feature-card grid on landing page (visual chunking) rather than a bulleted link list | Landing-page ergonomics | `<div class="grid cards" markdown>` + 8 cards with material icons |
| **Build Reproducibility** | `mkdocs.yml` + `docs/stylesheets/extra.css` under version control; hashes locked in `requirements-docs.txt` | Supply-chain hygiene | `pip-compile --generate-hashes` + `pip install --require-hashes` in the Pages workflow |
| **Cache Cost at Edge** | CDN TTL respected; theme changes propagate to `doc.<domain>` within 10 minutes | Deployment latency | Cloudflare (or equivalent) `max-age=600` on the site |

## Diagnosis: What "Default MkDocs Material" Leaves on the Table #

An out-of-the-box MkDocs Material site with `primary: teal, accent: teal` and no `extra_css` is visually acceptable — but it is one of many thousand acceptable sites that look identically acceptable. The named presets are constrained to Google's Material Design palette; the sidebar, header, and content surface all read as "Material default".

For a project positioning itself as "an opinionated developer platform, not a library", the visual signal that the docs are *the product's* docs — not somebody else's — is a marketing surface, not a decoration. The lift is contained to three files:

- `mkdocs.yml` — palette selector configuration
- `docs/stylesheets/extra.css` — the actual palette + typography + component overrides
- `docs/index.md` — hero + card grid replacing the default index

No template overrides (`custom_dir`), no plugin authoring, no JavaScript. All the customisation lives in files MkDocs Material is explicitly designed to consume.

## Remediation: The Three-File Custom Theme #

### `mkdocs.yml` Palette Configuration

The magic value that unlocks CSS-driven colours is `primary: custom` (and `accent: custom`). Under `[data-md-color-scheme="slate"]`, MkDocs Material's dark variant, every component reads its colours from CSS custom properties that we get to define.

```yaml
theme:
  name: material
  font:
    text: Inter
    code: JetBrains Mono
  palette:
    - media: "(prefers-color-scheme: dark)"
      scheme: slate
      primary: custom
      accent: custom
    - media: "(prefers-color-scheme: light)"
      scheme: default
      primary: custom
      accent: custom
  features:
    - navigation.tabs
    - navigation.tabs.sticky
    - navigation.footer
    - content.code.copy

extra_css:
  - stylesheets/extra.css
```

The `navigation.tabs.sticky` feature keeps the top-level navigation visible on scroll, which pairs with the hero + card grid to keep the site feeling like a product page rather than a scrolling article.

### `docs/stylesheets/extra.css` — Palette + Component Overrides

The stylesheet is organised in five zones: CSS custom properties for the palette, typography, dark-scheme palette overrides, per-component restyling, and the custom hero + grid-card styles.

```css
:root {
  --dot-green: #7ee787;         /* terminal green — primary */
  --dot-green-bright: #b0f5b7;  /* hover / focused */
  --dot-green-dim: #4a9153;     /* muted */
  --dot-bg: #0b0e14;            /* near-black base */
  --dot-bg-elev: #111621;       /* elevated card */
  --dot-fg: #e4e7ec;
  --dot-fg-muted: #94a3b8;
  --dot-border: #1f2937;
}

[data-md-color-scheme="slate"] {
  --md-default-bg-color: var(--dot-bg);
  --md-default-fg-color: var(--dot-fg);
  --md-primary-fg-color: var(--dot-green);
  --md-accent-fg-color: var(--dot-green-bright);
  --md-typeset-a-color: var(--dot-green);
  --md-code-bg-color: #161b26;
}
```

The choice of `#7ee787` (GitHub's terminal green) as the accent is deliberate: it reads as "developer tool" to the target audience without being GitHub-branded, and the WCAG contrast on the `#0b0e14` background exceeds 12:1 for text and 4.5:1 for the accent-on-background — comfortably above AA thresholds.

Component overrides are targeted at the highest-impact surfaces:

```css
/* Header: blurred backdrop-saturate for a floating feel */
.md-header {
  background-color: rgba(11, 14, 20, 0.92);
  backdrop-filter: saturate(180%) blur(12px);
  border-bottom: 1px solid var(--dot-border);
}

/* Grid cards on landing page — hover lift + accent glow */
.md-typeset .grid.cards > :is(ul, ol) > li {
  background: var(--dot-bg-elev);
  border: 1px solid var(--dot-border);
  border-radius: 12px;
  transition: transform 180ms ease, border-color 180ms ease;
}
.md-typeset .grid.cards > :is(ul, ol) > li:hover {
  transform: translateY(-2px);
  border-color: rgba(126, 231, 135, 0.35);
  box-shadow: 0 8px 24px -8px rgba(0, 0, 0, 0.5);
}
```

### `docs/index.md` — Hero + Grid Cards

The landing page is not documentation — it is a product surface. MkDocs Material's `md_in_html` extension allows Markdown to nest inside a custom HTML section:

```markdown
---
hide:
  - navigation
  - toc
---

<section class="dot-hero" markdown>

# .dotfiles

<p class="tagline">Cross-platform, signed, local-first dotfiles…</p>

<div class="buttons">
  <a class="primary" href="guides/INSTALL/">Install →</a>
  <a href="https://github.com/sebastienrousseau/dotfiles">GitHub</a>
</div>

</section>

## What's inside

<div class="grid cards" markdown>

- :material-console:{ .lg .middle } **Multi-shell parity**

    ---

    Bash, Zsh, Fish, Nushell — same aliases, functions, prompt, and completions.

    [→ Shell hub](reference/UTILS.md)

</div>
```

The `hide: [navigation, toc]` front-matter removes the sidebar and right-column table-of-contents on this page only — the landing page gets the full canvas, sub-pages retain the standard docs layout.

## Verification: Build, Deploy, Contrast #

The custom theme adds ~12 KB of CSS to the built site. Local `mkdocs build --clean` completes in ~2 seconds. The Pages workflow uses hash-locked dependencies (`pip install --require-hashes -r requirements-docs.txt`) to keep the build reproducible across MkDocs Material and its 30+ transitive dependencies.

Accessibility contrast measured on the deployed site:

- Body text (`#e4e7ec` on `#0b0e14`) — **15.6:1** (WCAG AAA)
- Accent (`#7ee787` on `#0b0e14`) — **12.4:1** (WCAG AAA)
- Muted text (`#94a3b8` on `#0b0e14`) — **7.2:1** (WCAG AAA)

Cloudflare CDN cache invalidation after Pages deploy: ~10 minutes on `max-age=600`. Fetching the GitHub Pages origin (`sebastienrousseau.github.io/dotfiles/`) reflects the new theme immediately; the CDN-fronted custom domain propagates within one cache TTL.

## Return on Resilience #

| Metric | Before (Jekyll Cayman) | After (Custom MkDocs Material) |
|---|---|---|
| Page weight | 2.9 KB | 14.8 KB (compressed 4.2 KB) |
| Time to visible hero | ~800 ms (no hero) | ~150 ms |
| WCAG AA compliance | Passes body text; hero absent | Passes AAA on all text pairs |
| Landing-page CTAs | 0 (link list only) | 4 (primary + 3 secondary) |
| Visual differentiation from default | Zero | Distinctive palette + hero + grid |
| Build reproducibility | Jekyll on `github-pages` gem (unpinned transitive deps) | `pip install --require-hashes` (fully locked) |

## Take-Aways #

1. **`primary: custom` + `extra_css` beats theme forking.** No `custom_dir`, no Jinja templates, no plugin authoring. All the customisation lives in files MkDocs Material is explicitly designed to consume.

2. **CSS custom properties are the maintainable seam.** Overriding `--md-primary-fg-color` scales; overriding `.md-header a.md-header__button:not(...)` selectors doesn't.

3. **Treat the landing page as a product surface, not documentation.** Front-matter `hide: [navigation, toc]` unlocks the full canvas. Hero + card grid + tabbed quick-start reads as a product page.

4. **Lock the docs-build supply chain.** `pip-compile --generate-hashes` + `pip install --require-hashes` closes the Scorecard `PinnedDependenciesID` alert and prevents transitive-dep drift in Pages deploys.

5. **Measure contrast, not just aesthetics.** WCAG AAA on body text is achievable with the right palette; it's not a tradeoff against distinctiveness.

The reference implementation landed as [PR #960](https://github.com/sebastienrousseau/dotfiles/pull/960) and is live at [doc.dotfiles.io](https://doc.dotfiles.io); the theme source lives at [`docs/stylesheets/extra.css`](https://github.com/sebastienrousseau/dotfiles/blob/main/docs/stylesheets/extra.css).

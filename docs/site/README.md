# doc.dotfiles.io (ssg + Lucid)

The whole of `https://doc.dotfiles.io/` is built by
[ssg](https://github.com/sebastienrousseau/static-site-generator) with the
[Lucid](https://themes.static-site-generator.com/lucid/) documentation theme:

- the documentation pages listed in `docs/_toc.yml`, in that order and
  grouped into its sections;
- the landing page, from the front matter of `docs/index.md`;
- the manual, from `docs/manual/_toc.yml`, published under `/manual/`.

```bash
make docs          # build into _build/site (needs ssg >= 0.0.63 and python3)
make docs-serve    # build, then serve at http://127.0.0.1:8000/
make manual-site   # the manual alone, into _build/site/manual
```

`.github/workflows/pages.yml` runs the same `tools/docs/build-site.sh` with a
pinned, SHA-256-verified ssg release and publishes `_build/site` as-is.

## How it is put together

- `themes/lucid/` is vendored from
  [ssg-themes.github.io](https://github.com/sebastienrousseau/ssg-themes.github.io)
  at commit `b5cba1f` (Apache-2.0 OR MIT, see `themes/lucid/LICENSE-APACHE`
  and `LICENSE-MIT`). `styles.css`, `skeletonic.min.css`, `main.js`,
  `theme-init.js`, `404.html` and `theme.toml` are upstream unchanged.
  Local changes:
  - `header.html`: the .dotfiles terminal mark, Install / Reference / Manual /
    GitHub links, no language switcher (the site is English only);
  - `doc.html`: side navigation, contents, breadcrumbs and pager come from
    front matter instead of fixed links;
  - `index.html`: the landing layout without the stock hero photo, with the
    cards linking to their pages;
  - `base.html`: no theme screenshot or `.ico`;
  - `footer.html`: the "Made with SSG" credit ssg's quality gate looks for.
- `tools/docs/build-manual-site.py` does what the template engine cannot
  (it has no loops): it reads the table of contents, writes one ssg content
  page per entry with the side navigation, contents list and pager in front
  matter, and rewrites links between pages to their published URLs (links
  into `docs/manual/` go to `/manual/`, anything else in the repository to
  GitHub). After the build it adds heading ids, drops ssg's injected
  `highlight.css` (its colours follow the OS scheme rather than Lucid's
  toggle, so a light page on a dark OS got dark text on a dark block), and
  fails on any internal link or fragment that does not resolve, across the
  whole site.
- `tests/unit/docs/test_manual_site.sh` holds the palette to WCAG AAA in both
  schemes and requires ssg's quality gate to pass for the manual;
  `tests/unit/docs/test_site_build.sh` builds the whole site and checks the
  published pages, layouts, stylesheets, SRI hashes and CNAME.

To pick up a newer Lucid, copy `themes/lucid/_layouts` from the theme
repository, re-apply the changes above, update the commit here, and run both
tests.

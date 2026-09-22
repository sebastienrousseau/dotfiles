# Manual site (ssg + Lucid)

`https://doc.dotfiles.io/manual/` is built from `docs/manual/*.md` by
[ssg](https://github.com/sebastienrousseau/static-site-generator) with the
[Lucid](https://themes.static-site-generator.com/lucid/) documentation theme.
The rest of `doc.dotfiles.io` is still MkDocs; `mkdocs.yml` excludes
`manual/`, and `.github/workflows/pages.yml` merges the ssg output into
`site/manual/` before publishing.

```bash
make manual-site          # build into _build/site/manual (needs ssg >= 0.0.63)
make manual-site-serve    # build, then serve at http://127.0.0.1:8000/manual/
```

## How it is put together

- `themes/lucid/` is vendored from
  [ssg-themes.github.io](https://github.com/sebastienrousseau/ssg-themes.github.io)
  at commit `b5cba1f1ead2f11023de62d80be0cb470cd894ab` (Apache-2.0 OR MIT,
  see `themes/lucid/LICENSE-APACHE` and `LICENSE-MIT`). Local changes:
  - `header.html`: the .dotfiles terminal mark, Docs / Manual / GitHub links,
    no language switcher (the manual is English only);
  - `doc.html`: side navigation, contents, breadcrumbs and pager come from
    front matter instead of fixed links;
  - `base.html`, `footer.html`: no theme screenshot or `.ico`, dark
    `theme-color`, credit line;
  - `styles.css`: the .dotfiles palette (terminal green on `#0b0e14`, with a
    light counterpart) in place of Lucid's blue, the P3 accent block removed,
    and a scrolling side navigation for the ~30 chapters.
- `tools/docs/build-manual-site.py` reads `docs/manual/_toc.yml`, writes one
  ssg content page per chapter (chapter links rewritten to their published
  URLs), and after the build adds heading ids and fails on any internal link
  or fragment that does not resolve.
- `tests/unit/docs/test_manual_site.sh` holds the palette to WCAG AAA (7:1
  text, 4.5:1 non-text) in both schemes and, when ssg is installed, runs the
  full build and requires ssg's quality gate to pass.

To pick up a newer Lucid, copy `themes/lucid/_layouts` from the theme
repository, re-apply the changes above, update the commit here, and run the
test.

#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
"""Prepare and finalise the web manual built by ssg with the Lucid theme.

ssg's template engine substitutes `{{field}}` values from front matter and
has no loops, so everything that depends on the manual's structure — the
grouped side navigation, the "On this page" list, breadcrumbs and prev/next —
is computed here from docs/manual/_toc.yml and written into each page's
front matter.

  prepare  <manual-src> <content-out> <base-path>
      Write one ssg content file per manual page, with links between
      chapters rewritten to their published URLs.

  prepare-site <docs-src> <content-out>
      The same for the whole documentation site (doc.dotfiles.io/): the
      pages listed in docs/_toc.yml with the doc layout, and docs/index.md
      with the landing layout. Links into docs/manual/ point at /manual/.

  finalize <site-out> <base-path>
      ssg renders Markdown without heading ids. Add them with the same slug
      rule `prepare` used for the contents list, then fail if any internal
      link or in-page fragment does not resolve.

Standard library only.
"""

from __future__ import annotations

import html
import json
import re
import subprocess
import sys
import unicodedata
from dataclasses import dataclass, field
from datetime import date
from pathlib import Path, PurePosixPath

REPO_URL = "https://github.com/sebastienrousseau/dotfiles"
DOCS_URL = "https://doc.dotfiles.io/"

# ── slugs ────────────────────────────────────────────────────────────────

TAG = re.compile(r"<[^>]+>")


def slug(text: str) -> str:
    """Heading id. Used for both Markdown source and rendered HTML text."""
    text = TAG.sub("", text)
    text = html.unescape(text)
    text = text.replace("&", " and ")
    for apostrophe in ("'", "’"):
        text = text.replace(apostrophe, "")
    text = unicodedata.normalize("NFKD", text)
    text = "".join(c for c in text if not unicodedata.combining(c))
    text = re.sub(r"[^a-z0-9]+", "-", text.lower())
    return re.sub(r"-{2,}", "-", text).strip("-")


def unique(base: str, seen: set[str]) -> str:
    candidate, n = base, 2
    while candidate in seen:
        candidate, n = f"{base}-{n}", n + 1
    seen.add(candidate)
    return candidate


# ── table of contents ────────────────────────────────────────────────────


@dataclass
class Page:
    src: Path  # absolute source path
    rel: PurePosixPath  # path relative to docs/manual
    group: str  # "" for ungrouped pages
    url: str = ""  # path under base, "" for the landing page
    headline: str = ""
    lead: str = ""
    body: str = ""
    toc: list[tuple[str, str]] = field(default_factory=list)


def parse_toc(path: Path) -> list[tuple[str, str]]:
    """Return [(group, relative file)] in reading order from _toc.yml.

    The file is a fixed, simple shape (sections of `file:` or
    `group:`/`prefix:`/`files:`), so a line parser avoids a YAML dependency.
    """
    entries: list[tuple[str, str]] = []
    group = prefix = ""
    in_files = False
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.split("#", 1)[0].rstrip()
        if not line.strip():
            continue
        stripped = line.strip()
        value = lambda s: s.split(":", 1)[1].strip().strip('"')
        if stripped.startswith("- file:"):
            group, prefix, in_files = "", "", False
            entries.append(("", value(stripped[2:])))
        elif stripped.startswith("- group:"):
            group, prefix, in_files = value(stripped[2:]), "", False
        elif stripped.startswith("prefix:") and group:
            prefix = value(stripped)
        elif stripped == "files:" and group:
            in_files = True
        elif in_files and stripped.startswith("- "):
            name = stripped[2:].strip()
            entries.append((group, f"{prefix}/{name}" if prefix else name))
    return entries


# ── Markdown shaping ─────────────────────────────────────────────────────

FRONT_MATTER = re.compile(r"\A---\n.*?\n---\n", re.DOTALL)
FENCE = re.compile(r"^(```|~~~)")
LIQUID_RAW = re.compile(r"^[ \t]*\{%-?\s*(?:end)?raw\s*-?%\}[ \t]*\n?", re.MULTILINE)
HIGHLIGHT_LINK = re.compile(r'\s*<link rel="stylesheet" href="/highlight\.css">')
LEADING_COMMENTS = re.compile(r"\A(?:\s*<!--.*?-->)+\s*", re.DOTALL)
MD_LINK = re.compile(r"(?<!!)\[([^\]]*)\]\(([^)\s]+)(\s+\"[^\"]*\")?\)")


def strip_inline(text: str) -> str:
    text = MD_LINK.sub(lambda m: m.group(1), text)
    return re.sub(r"[`*]", "", text).strip()


def split_page(text: str) -> tuple[str, str, str]:
    """Return (headline, lead, body) with the H1 and a plain first paragraph
    moved out of the body: the doc layout renders both itself."""
    text = FRONT_MATTER.sub("", text, count=1)
    # Jekyll-era `{% raw %}` guards around Go-template examples mean nothing
    # to ssg; they would render as literal text.
    text = LIQUID_RAW.sub("", text).lstrip("\n")
    # Leading HTML comments (SPDX and copyright headers) precede the title
    # in most docs pages; they are not content.
    text = LEADING_COMMENTS.sub("", text)
    lines = text.splitlines()
    headline = ""
    if lines and lines[0].startswith("# "):
        headline = strip_inline(lines[0][2:])
        lines = lines[1:]
    while lines and not lines[0].strip():
        lines.pop(0)
    lead_lines: list[str] = []
    if lines and not re.match(r"^\s*([#>|\-*+`~<]|\d+\.|!\[)", lines[0]):
        while lines and lines[0].strip():
            lead_lines.append(lines.pop(0))
    lead = " ".join(line.strip() for line in lead_lines)
    return headline, lead, "\n".join(lines).strip() + "\n"


def headings(body: str) -> list[tuple[str, str]]:
    """H2 headings outside code fences, as (text, id)."""
    out: list[tuple[str, str]] = []
    seen: set[str] = set()
    fenced = False
    for line in body.splitlines():
        if FENCE.match(line.strip()):
            fenced = not fenced
            continue
        if not fenced and line.startswith("## "):
            text = strip_inline(line[3:])
            base = slug(text)
            if base:
                out.append((text, unique(base, seen)))
    return out


def rewrite_links(
    page: Page,
    pages: dict[PurePosixPath, Page],
    base: str,
    manual_root: Path,
    repo_root: Path,
    elsewhere=None,
) -> str:
    """Point chapter links at published URLs and repo links at GitHub."""

    def repl(m: re.Match[str]) -> str:
        label, target, title = m.group(1), m.group(2), m.group(3) or ""
        if re.match(r"^[a-z][a-z0-9+.-]*:|^#|^/", target):
            return m.group(0)
        path_part, _, frag = target.partition("#")
        resolved = (page.src.parent / path_part).resolve()
        try:
            rel = PurePosixPath(resolved.relative_to(manual_root).as_posix())
        except ValueError:
            rel = None
        if rel is not None and rel in pages:
            url = base + pages[rel].url
        elif rel is not None and elsewhere and (hit := elsewhere(rel)):
            url = hit
        else:
            try:
                repo_rel = resolved.relative_to(repo_root).as_posix()
            except ValueError:
                return m.group(0)
            kind = "tree" if resolved.is_dir() else "blob"
            url = f"{REPO_URL}/{kind}/main/{repo_rel}"
        if frag:
            url += "#" + frag
        return f"[{label}]({url}{title})"

    out, fenced = [], False
    for line in page.body.splitlines():
        if FENCE.match(line.strip()):
            fenced = not fenced
        out.append(line if fenced else MD_LINK.sub(repl, line))
    return "\n".join(out) + "\n"


# ── HTML fragments carried in front matter ───────────────────────────────


def a(href: str, text: str, current: bool = False, cls: str = "") -> str:
    attrs = f' class="{cls}"' if cls else ""
    if current:
        attrs += ' aria-current="page"'
    return f'<a href="{html.escape(href)}"{attrs}>{html.escape(text)}</a>'


def side_nav(order: list[Page], current: Page, base: str) -> str:
    blocks: list[tuple[str, list[Page]]] = []
    for p in order:
        if p.group:
            name = p.group
        elif not p.url or p.rel.name.startswith("00-") or p.rel.parent == PurePosixPath("."):
            name = "Start"
        else:
            name = "Indexes"
        if not blocks or blocks[-1][0] != name:
            blocks.append((name, []))
        blocks[-1][1].append(p)
    parts = []
    for name, members in blocks:
        items = "".join(
            f"<li>{a(base + p.url, p.headline if p.url else 'Overview', p is current)}</li>"
            for p in members
        )
        parts.append(
            f'<p class="side-h">{html.escape(name)}</p><ul class="side-list">{items}</ul>'
        )
    return "".join(parts)


def pager(prev: Page | None, nxt: Page | None, base: str) -> str:
    out = []
    for p, cls, label in (
        (prev, "pager-prev", "Previous"),
        (nxt, "pager-next", "Next"),
    ):
        if p is None:
            continue
        out.append(
            f'<a class="pager-link {cls}" href="{html.escape(base + p.url)}">'
            f'<span class="pager-dir">{label}</span>'
            f'<span class="pager-name">{html.escape(p.headline)}</span></a>'
        )
    return "".join(out)


def last_changed(path: Path) -> str:
    try:
        out = subprocess.run(
            ["git", "log", "-1", "--format=%cs", "--", str(path)],
            capture_output=True,
            text=True,
            check=True,
            cwd=path.parent,
        ).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        out = ""
    return out or date.today().isoformat()


MANUAL = {
    "kind": "manual",
    "name": ".dotfiles Manual",
    "title_suffix": " — .dotfiles Manual",
    "home_title": ".dotfiles Manual",
    "nav_home": "Manual",
    "label_docs_nav": "Manual chapters",
    "eyebrow": "Manual",
    "describe": "the .dotfiles manual",
    "current": "manual",
}
SITE = {
    "kind": "site",
    "name": ".dotfiles",
    "title_suffix": " — .dotfiles",
    "home_title": ".dotfiles — cross-platform, signed dotfiles",
    "nav_home": "Docs",
    "label_docs_nav": "Documentation",
    "eyebrow": "Docs",
    "describe": ".dotfiles documentation",
    "current": "",
}


def dotfiles_version(repo_root: Path) -> str:
    data = repo_root / "defaults" / ".chezmoidata.toml"
    if data.is_file():
        m = re.search(
            r'^dotfiles_version\s*=\s*"([^"]+)"',
            data.read_text(encoding="utf-8"),
            re.MULTILINE,
        )
        return m.group(1) if m else ""
    return ""


def shared_fields(profile: dict, base: str, root: str, year: str) -> dict:
    """Front matter every page carries: labels, header links, footer."""
    cur = {k: "" for k in ("cur_install", "cur_reference", "cur_manual")}
    if profile["current"]:
        cur[f"cur_{profile['current']}"] = ' aria-current="true"'
    return {
        "author": "Sebastien Rousseau",
        "language": "en-GB",
        "name": profile["name"],
        "base_path": base,
        "root": root,
        "form_origin": "",
        "docs_url": DOCS_URL,
        "repo_url": REPO_URL,
        "nav_docs": "Docs",
        "nav_install": "Install",
        "nav_reference": "Reference",
        "nav_manual": "Manual",
        "nav_repo": "GitHub",
        "nav_home": profile["nav_home"],
        "label_skip": "Skip to main content",
        "label_menu": "Menu",
        "label_nav": "Main",
        "label_docs_nav": profile["label_docs_nav"],
        "label_crumbs": "Breadcrumb",
        "label_pager": "Page",
        "label_toc": "On this page",
        "label_theme": "Theme",
        "label_theme_system": "System",
        "label_theme_light": "Light",
        "label_theme_dark": "Dark",
        "footer_note": "Chezmoi-managed dotfiles for macOS, Linux, WSL and PowerShell — signed, attested and multi-shell.",
        "copyright": f"© 2015–{year} Sebastien Rousseau. Licensed under Apache-2.0 OR MIT.",
        **cur,
    }


def write_content(dest: Path, fm: dict, body: str) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    # JSON strings are valid YAML double-quoted scalars.
    front = "".join(f"{k}: {json.dumps(v, ensure_ascii=False)}\n" for k, v in fm.items())
    dest.write_text(f"---\n{front}---\n\n{body}", encoding="utf-8")


def build_pages(
    src_root: Path,
    order: list[Page],
    content_out: Path,
    base: str,
    root: str,
    profile: dict,
    repo_root: Path,
    elsewhere=None,
) -> int:
    missing = [str(p.rel) for p in order if not p.src.is_file()]
    if missing:
        print(
            f"{profile['kind']}: _toc.yml names missing files: {', '.join(missing)}",
            file=sys.stderr,
        )
        return 1
    version = dotfiles_version(repo_root)
    pages = {p.rel: p for p in order}
    for p in order:
        if p.rel.parent == PurePosixPath(".") and p.rel.name == "index.md":
            p.url = ""
        elif p.rel.parent == PurePosixPath(".") and p.rel.name == "README.md":
            p.url = "overview/"
        elif p.rel.name in ("README.md", "index.md"):
            p.url = str(p.rel.parent) + "/"
        else:
            p.url = str(p.rel.with_suffix("")) + "/"
        p.headline, p.lead, p.body = split_page(p.src.read_text(encoding="utf-8"))
        if not p.headline:
            print(f"{profile['kind']}: {p.rel} has no '# ' title", file=sys.stderr)
            return 1
        p.toc = headings(p.body)

    content_out.mkdir(parents=True, exist_ok=True)
    year = str(date.today().year)
    common = shared_fields(profile, base, root, year)
    for i, p in enumerate(order):
        body = rewrite_links(p, pages, base, src_root, repo_root, elsewhere)
        prev = order[i - 1] if i > 0 else None
        nxt = order[i + 1] if i + 1 < len(order) else None
        description = strip_inline(p.lead) or f"{p.headline} — {profile['describe']}."
        if len(description) > 160:
            description = description[:157].rsplit(" ", 1)[0] + "…"
        fm = {
            "layout": "doc",
            "title": f"{p.headline}{profile['title_suffix']}" if p.url else profile["home_title"],
            "description": description,
            "headline": p.headline,
            "headline_id": slug(p.headline),
            "lead": strip_inline(p.lead),
            "eyebrow": p.group or (profile["eyebrow"] + (f" · v{version}" if version else "")),
            "date": last_changed(p.src),
            "changefreq": "weekly",
            **common,
            "side_nav": side_nav(order, p, base),
            "crumb_group": f"<li><span>{html.escape(p.group)}</span></li>" if p.group else "",
            "pager": pager(prev, nxt, base),
            "toc_items": "".join(
                f'<li><a href="#{i}">{html.escape(t)}</a></li>' for t, i in p.toc
            ),
        }
        # A section index sits beside the section's own pages, so it is the
        # directory's index.md; a file and a directory of the same name
        # collide in ssg's output.
        if not p.url:
            dest = content_out / "index.md"
        elif p.rel.name in ("README.md", "index.md") and p.url != "overview/":
            dest = content_out / p.url / "index.md"
        else:
            dest = content_out / (p.url.rstrip("/") + ".md")
        write_content(dest, fm, body)
    print(f"{profile['kind']}: prepared {len(order)} pages in {content_out}")
    return 0


def prepare(manual_root: Path, content_out: Path, base: str) -> int:
    repo_root = manual_root.parent.parent
    order = [Page(manual_root / "index.md", PurePosixPath("index.md"), "")]
    for group, rel in parse_toc(manual_root / "_toc.yml"):
        order.append(Page(manual_root / rel, PurePosixPath(rel), group))
    return build_pages(manual_root, order, content_out, base, "/", MANUAL, repo_root)


def manual_url(rel: PurePosixPath) -> str | None:
    """Published URL of a docs/manual/ page, for links from the site."""
    if not rel.parts or rel.parts[0] != "manual" or rel.suffix != ".md":
        return None
    inner = PurePosixPath(*rel.parts[1:])
    if inner == PurePosixPath("index.md"):
        return "/manual/"
    return "/manual/" + str(inner.with_suffix("")) + "/"


def prepare_site(docs_root: Path, content_out: Path) -> int:
    """Doc pages from docs/_toc.yml plus the landing page from docs/index.md."""
    repo_root = docs_root.parent
    order = [Page(docs_root / rel, PurePosixPath(rel), group) for group, rel in parse_toc(docs_root / "_toc.yml")]
    rc = build_pages(docs_root, order, content_out, "/", "/", SITE, repo_root, manual_url)
    if rc:
        return rc
    landing = docs_root / "index.md"
    m = FRONT_MATTER.match(landing.read_text(encoding="utf-8"))
    if not m:
        print("site: docs/index.md needs landing front matter", file=sys.stderr)
        return 1
    year = str(date.today().year)
    fm = {
        "layout": "index",
        "title": SITE["home_title"],
        "date": last_changed(landing),
        "changefreq": "weekly",
        **shared_fields(SITE, "/", "/", year),
    }
    # The landing page's own fields (hero, cards, facts) are simple
    # `key: "value"` lines; carry them over verbatim, overriding defaults.
    for line in m.group(0).splitlines()[1:-1]:
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        key, _, value = line.partition(":")
        value = value.strip()
        fm[key.strip()] = json.loads(value) if value.startswith('"') else value
    write_content(content_out / "index.md", fm, "")
    print(f"site: landing page prepared from {landing}")
    return 0


# ── finalize ─────────────────────────────────────────────────────────────

HEADING = re.compile(r"<(h[2-4])([^>]*)>(.*?)</\1>", re.DOTALL)
ID_ATTR = re.compile(r'\bid\s*=\s*"([^"]*)"')
PROSE = re.compile(
    r'(<div class="prose">)(.*?)(</div>\s*<nav class="pager")', re.DOTALL
)
HREF = re.compile(r'\bhref="([^"]*)"')


def anchor(page_html: str) -> str:
    m = PROSE.search(page_html)
    if not m:
        return page_html
    prose = m.group(2)
    seen = set(ID_ATTR.findall(page_html))

    def assign(level: str, text: str) -> str:
        def repl(h: re.Match[str]) -> str:
            if h.group(1) != level or "id=" in h.group(2):
                return h.group(0)
            base = slug(h.group(3))
            if not base:
                return h.group(0)
            return f'<{h.group(1)}{h.group(2)} id="{unique(base, seen)}">{h.group(3)}</{h.group(1)}>'

        return HEADING.sub(repl, text)

    # h2 first, in order, so their ids match the contents list `prepare`
    # built from the Markdown H2s; deeper levels then avoid those ids.
    for level in ("h2", "h3", "h4"):
        prose = assign(level, prose)
    return page_html[: m.start(2)] + prose + page_html[m.end(2) :]


def finalize(site: Path, base: str) -> int:
    for junk in ("CNAME",):
        (site / junk).unlink(missing_ok=True)
    pages = sorted(site.rglob("index.html"))
    # ssg 0.0.63 injects a code-highlighting stylesheet as "/highlight.css"
    # (the file it writes is fingerprinted, and the link ignores a sub-path
    # base such as /manual/). Its colours follow prefers-color-scheme, not
    # Lucid's theme toggle, so with the OS dark and the page light it paints
    # a dark block under Lucid's dark text: unreadable. Lucid styles code
    # blocks itself, with AAA-checked tokens that follow the toggle, so the
    # injected sheet is dropped rather than re-linked.
    for css in site.glob("highlight*.css"):
        css.unlink()
    for page in pages:
        text = anchor(page.read_text(encoding="utf-8"))
        text = HIGHLIGHT_LINK.sub("", text)
        page.write_text(text, encoding="utf-8")

    problems: list[str] = []
    for page in pages:
        text = page.read_text(encoding="utf-8")
        ids = set(ID_ATTR.findall(text))
        rel = page.relative_to(site).as_posix()
        for href in HREF.findall(text):
            href = html.unescape(href)
            if href.startswith("#"):
                if href[1:] and href[1:] not in ids:
                    problems.append(f"{rel}: dangling fragment {href}")
                continue
            if not href.startswith(base):
                continue
            path, _, frag = href[len(base) :].partition("#")
            path = path.split("?", 1)[0]
            target = site / path
            if path == "" or path.endswith("/"):
                target = target / "index.html"
            if not target.is_file():
                problems.append(f"{rel}: broken link {href}")
                continue
            if frag and target.suffix == ".html":
                if frag not in set(ID_ATTR.findall(target.read_text(encoding="utf-8"))):
                    problems.append(f"{rel}: {href} has no #{frag}")
    for p in problems:
        print(f"manual: {p}", file=sys.stderr)
    if problems:
        return 1
    print(f"manual: {len(pages)} pages anchored; all internal links resolve")
    return 0


def main(argv: list[str]) -> int:
    if len(argv) == 4 and argv[0] == "prepare":
        return prepare(Path(argv[1]).resolve(), Path(argv[2]), argv[3])
    if len(argv) == 3 and argv[0] == "prepare-site":
        return prepare_site(Path(argv[1]).resolve(), Path(argv[2]))
    if len(argv) == 3 and argv[0] == "finalize":
        return finalize(Path(argv[1]), argv[2])
    print(__doc__, file=sys.stderr)
    return 64


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
"""Finish the doc.dotfiles.io build for browsers and search engines.

    python3 tools/docs/finalize-site.py SITE_DIR SITE_URL

Runs build-manual-site.py's ``finalize`` over the whole site (heading ids
and the link check), then:

* copies the Lucid theme's favicon.ico to the root: browsers and crawlers
  request /favicon.ico whatever the pages link;
* removes the sitemap.xml, news-sitemap.xml and robots.txt that ssg writes
  beside every page, and the root news-sitemap.xml (robots.txt names only
  /sitemap.xml, and this is not a news site);
* writes /sitemap.xml from the pages' own canonical URLs, leaving out a
  page marked noindex or whose canonical names another URL (ssg's own
  sitemap comes out empty);
* fails if a sitemap URL or an hreflang alternate is not a page in the
  build.
"""

from __future__ import annotations

import html
import importlib.util
import re
import shutil
import sys
from pathlib import Path
from urllib.parse import urljoin

HERE = Path(__file__).resolve().parent
FAVICON = HERE.parent.parent / "docs/site/themes/lucid/_layouts/favicon.ico"
CANONICAL = re.compile(r'<link rel="canonical" href="([^"]+)"')
NOINDEX = re.compile(r'<meta name="robots" content="[^"]*\bnoindex', re.IGNORECASE)
HREFLANG = re.compile(r'<link\b[^>]*\bhreflang="[^"]*"[^>]*>')
HREF = re.compile(r'\bhref="([^"]+)"')
PER_PAGE = ("sitemap.xml", "news-sitemap.xml", "robots.txt")


def page_for(site: Path, base: str, url: str) -> Path | None:
    """The built file a same-site URL serves, or None."""
    if not url.startswith(base):
        return None
    path = url[len(base) :].split("#", 1)[0].split("?", 1)[0]
    target = site / path
    if path == "" or path.endswith("/"):
        target = target / "index.html"
    return target if target.is_file() else None


def prune(site: Path) -> None:
    for name in PER_PAGE:
        for found in site.rglob(name):
            if found.parent != site or name == "news-sitemap.xml":
                found.unlink()


def canonical_urls(site: Path, base: str) -> list[str]:
    urls = set()
    for page in site.rglob("*.html"):
        text = page.read_text(encoding="utf-8")
        m = CANONICAL.search(text)
        if m and not NOINDEX.search(text) and page_for(site, base, m.group(1)) == page:
            urls.add(m.group(1))
    return sorted(urls)


def write_sitemap(site: Path, urls: list[str]) -> None:
    items = "".join(f"  <url><loc>{html.escape(u)}</loc></url>\n" for u in urls)
    (site / "sitemap.xml").write_text(
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n'
        f"{items}</urlset>\n",
        encoding="utf-8",
    )


def check(site: Path, base: str, urls: list[str]) -> list[str]:
    problems = [f"sitemap.xml: {u} is not a page in the build" for u in urls if not page_for(site, base, u)]
    for page in site.rglob("*.html"):
        rel = page.relative_to(site).as_posix()
        own = base + rel.removesuffix("index.html")
        for tag in HREFLANG.findall(page.read_text(encoding="utf-8")):
            m = HREF.search(tag)
            target = urljoin(own, html.unescape(m.group(1))) if m else ""
            if not page_for(site, base, target):
                problems.append(f"{rel}: hreflang alternate {target or tag} is not a page in the build")
    return problems


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print(__doc__, file=sys.stderr)
        return 64
    site, base = Path(argv[0]), argv[1].rstrip("/") + "/"
    spec = importlib.util.spec_from_file_location("build_manual_site", HERE / "build-manual-site.py")
    builder = importlib.util.module_from_spec(spec)
    # Its dataclasses look their module up in sys.modules while it loads.
    sys.modules[spec.name] = builder
    spec.loader.exec_module(builder)
    rc = builder.finalize(site, "/")
    if rc:
        return rc
    shutil.copy2(FAVICON, site / "favicon.ico")
    prune(site)
    urls = canonical_urls(site, base)
    write_sitemap(site, urls)
    problems = check(site, base, urls)
    for p in problems:
        print(f"site: {p}", file=sys.stderr)
    if problems:
        return 1
    print(f"site: sitemap.xml lists {len(urls)} canonical pages; favicon.ico at the root")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

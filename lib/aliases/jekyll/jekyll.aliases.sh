#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.463) - https://dotfiles.io
# Made with ♥ in London, UK by @sebastienrousseau
# Copyright (c) 2015-2023. All rights reserved
# License: MIT

# 🅹🅴🅺🆈🅻🅻 🅰🅻🅸🅰🆂🅴🆂 - Jekyll aliases.
if command -v 'jekyll' >/dev/null; then
  alias jkb='JEKYLL_ENV=development bundle exec jekyll build'                 # jkb: Performs a one off build your site to ./_site.
  alias jkc='JEKYLL_ENV=development bundle exec jekyll clean'                 # jkc: Removes all generated files: destination folder, metadata file, Sass and Jekyll caches.
  alias jkd='JEKYLL_ENV=development bundle exec jekyll serve --watch --trace' # jkd: Does a development build of the site to '_site' and runs a local development server.
  alias jkl='JEKYLL_ENV=development bundle exec jekyll serve --livereload'    # jkl: Does a development build of the site to '_site' and runs a local development server.
  alias jko="open http://localhost:4000/"                                     # jko: Open local development server.
  alias jkp='JEKYLL_ENV=production bundle exec jekyll serve --watch --trace'  # jkp: Does a production build of the site to '_site' and runs a local development server.
fi

#!/bin/zsh
#
#  ____        _   _____ _ _
# |  _ \  ___ | |_|  ___(_) | ___  ___
# | | | |/ _ \| __| |_  | | |/ _ \/ __|
# | |_| | (_) | |_|  _| | | |  __/\__ \
# |____/ \___/ \__|_|   |_|_|\___||___/
#
# DotFiles v0.2.449
# https://dotfiles.io
#
# Description:  Mac OS X Dotfiles - Simply designed to fit your shell life.
#
# Sections:
#
#   1. Jekyll Core aliases.
#      1.1 Jekyll development aliases.
#      1.2 Jekyll release aliases.
#
# Copyright (c) Sebastien Rousseau 2022. All rights reserved
# Licensed under the MIT license
#


##  ----------------------------------------------------------------------------
##  1. Jekyll Core aliases.
##  ----------------------------------------------------------------------------

##  ----------------------------------------------------------------------------
##  1.1 Jekyll development aliases.
##  ----------------------------------------------------------------------------


# jkb: Performs a one off build your site to ./_site.
alias jkb='JEKYLL_ENV=development bundle exec jekyll build'

# jkc: Removes all generated files: destination folder, metadata file, Sass and
# Jekyll caches.
alias jkc='JEKYLL_ENV=development bundle exec jekyll clean'

# jkd: Does a development build of the site to '_site' and runs a local
# development server.
alias jkd='JEKYLL_ENV=development bundle exec jekyll serve --watch --trace'

# jkl: Does a development build of the site to '_site' and runs a
# local development server.
alias jkl='JEKYLL_ENV=development bundle exec jekyll serve --livereload'

# jko: Open local development server.
alias jko="open http://localhost:4000/"


##  ----------------------------------------------------------------------------
##  1.2 Jekyll release aliases.
##  ----------------------------------------------------------------------------

# jkp: Does a production build of the site to '_site' and runs a local
# development server.
alias jkp='JEKYLL_ENV=production bundle exec jekyll serve --watch --trace'

#!/bin/sh
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
# Description: Deploy documentation to gh-pages
#
# Environment variables that may be of use:
#
# - SITE_URL indicates the URL to the site, to ensure search works;
# - GH_USER_NAME indicates the GitHub author name to use;
# - GH_USER_EMAIL indicates the email address for that author;
# - GH_REF indicates the URI, without scheme or user-info, to the repository;
# - GH_TOKEN is the personal security token to use for commits.
#
# All of the above are exported via the project .travis.yml file (with
# GH_TOKEN being encrypted and present in the `secure` key). The user details
# need to match the token used for this to work.
#
# The script should be run from the project root.
#
# @license   http://opensource.org/licenses/BSD-3-Clause BSD-3-Clause
# @copyright Copyright (c) 2016 Zend Technologies USA Inc. (http://www.zend.com)
#
# Copyright (c) Sebastien Rousseau 2021. All rights reserved
# Licensed under the MIT license
#

set -o errexit -o nounset

echo "Preparing to build and deploy documentation"

if [ -z "${"GH_USER_NAME"}" ] || [ -z "${"GH_USER_EMAIL"}" ] || [ -z "${"GH_TOKEN"}" ] || [ -z "${"GH_REF"}" ]; then
    echo "Missing environment variables. Aborting"
    exit 1
fi;

SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd -P)"

# Get curent commit revision
rev=$(git rev-parse --short HEAD)

# Initialize gh-pages checkout
mkdir -p docs/html
(
    cd docs/html
    git init
    git config user.name "${GH_USER_NAME}"
    git config user.email "${GH_USER_EMAIL}"
    git remote add upstream "https://${GH_TOKEN}@${GH_REF}"
    git fetch upstream
    git reset --hard upstream/gh-pages
)

# Build the documentation
"${SCRIPT_PATH}"/build.sh

# Commit and push the documentation to gh-pages
(
    cd docs/html
    touch .
    git add -A .
    git commit -m "Rebuild pages at ${rev}"
    git push -q upstream HEAD:gh-pages
)

echo "Completed deploying documentation"

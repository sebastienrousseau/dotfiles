#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Drop the repository-local git variables before any test runs.
#
# Git exports GIT_DIR (and friends) to hooks run in a linked worktree.
# The pre-push hook runs the suite, so every fixture `git init`, `commit`,
# `tag` and `config` in a throwaway directory wrote into the real .git
# instead: moved branches, fixture tags, core.bare=true, gpgsign=false.
# Without these variables git finds each repository from the working
# directory, which is what the fixtures and the runner both expect.
# Sourced by test_runner.sh and assertions.sh.

# shellcheck disable=SC2046 # one variable name per word, by design
unset $(git rev-parse --local-env-vars 2>/dev/null ||
  echo GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY \
    GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_CONFIG GIT_CONFIG_PARAMETERS GIT_CONFIG_COUNT \
    GIT_IMPLICIT_WORK_TREE GIT_GRAFT_FILE GIT_NO_REPLACE_OBJECTS GIT_REPLACE_REF_BASE \
    GIT_PREFIX GIT_SHALLOW_FILE)

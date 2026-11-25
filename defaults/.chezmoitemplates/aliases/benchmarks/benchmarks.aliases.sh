# shellcheck shell=bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Benchmarking aliases

if command -v hyperfine &>/dev/null; then
  alias bench='hyperfine'
  alias benchw='hyperfine --warmup 3'
fi

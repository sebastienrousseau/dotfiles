# shellcheck shell=bash
# Copyright (c) 2015-2026 Sebastien Rousseau. All rights reserved.
# Benchmarking aliases

if command -v hyperfine &>/dev/null; then
  alias bench='hyperfine'
  alias benchw='hyperfine --warmup 3'
fi

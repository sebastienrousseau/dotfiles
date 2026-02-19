# shellcheck shell=bash
# Benchmarking aliases

if command -v hyperfine &>/dev/null; then
  alias bench='hyperfine'
  alias benchw='hyperfine --warmup 3'
fi

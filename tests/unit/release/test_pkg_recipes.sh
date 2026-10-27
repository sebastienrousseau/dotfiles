#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
#
# The Homebrew, AUR and Scoop recipes in pkg/ install the release archive
# that tools/release/stage-dot.sh builds. Each one runs here against a
# staged archive, and the installed CLI must run a bundled plugin's entry:
# an install that drops plugins/ or defaults/ answers only `dot version`.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

version="$(grep -m1 '^pkgver=' "$REPO_ROOT/pkg/aur/PKGBUILD" | cut -d= -f2)"
tmp="$(mktemp -d -t dot-pkg.XXXXXX)"
trap 'rm -rf "$tmp"' EXIT
bundle="$tmp/src/dot-$version"
mkdir -p "$tmp/src" "$tmp/home"
bash "$REPO_ROOT/tools/release/stage-dot.sh" "$bundle" >/dev/null 2>&1

# entry_runs DOT: the installed CLI runs a plugin entry that reads defaults.
entry_runs() {
  HOME="$tmp/home" DOTFILES_NONINTERACTIVE=1 NO_COLOR=1 DOTFILES_SHOW_LOGO=0 \
    "$1" fleet policy show </dev/null >"$tmp/out" 2>&1
}

test_start "archive_carries_the_licences"
assert_file_exists "$bundle/LICENSE-APACHE" "the archive ships LICENSE-APACHE"
assert_file_exists "$bundle/LICENSE-MIT" "the archive ships LICENSE-MIT"

# ── AUR: package() from the PKGBUILD, as makepkg runs it ─────────────────
test_start "aur_package_installs_a_working_cli"
pkgdir="$tmp/aur"
rc=0
(
  set -e
  source "$REPO_ROOT/pkg/aur/PKGBUILD"
  srcdir="$tmp/src"
  package
) >/dev/null 2>&1 || rc=$?
assert_equals "0" "$rc" "package() succeeds on the staged archive"
assert_file_exists "$pkgdir/usr/share/licenses/dot-cli-git/LICENSE-MIT" "the package installs its licence"
rc=0
entry_runs "$pkgdir/usr/bin/dot" || rc=$?
assert_equals "0" "$rc" "dot fleet policy show runs from the AUR package"

# ── Homebrew: the formula's install and test blocks, under a minimal ─────
# stand-in for the Formula DSL (paths and helpers the formula uses).
test_start "brew_formula_installs_a_working_cli"
if command -v ruby >/dev/null 2>&1; then
  cellar="$tmp/brew"
  rc=0
  (cd "$bundle" && HOME="$tmp/home" ruby - "$REPO_ROOT/pkg/brew/dot.rb" "$cellar" "$version") \
    >"$tmp/brew.out" 2>&1 <<'RUBY' || rc=$?
require "fileutils"
require "pathname"
formula_path, cellar, version = ARGV
class Pathname
  # Homebrew's Pathname#install: place files or trees into this directory.
  def install(*srcs)
    mkpath
    srcs.flatten.each { |src| FileUtils.cp_r(src.to_s, to_s) }
  end
end
class Formula
  def self.method_missing(*) end
  attr_reader :prefix
  def initialize(prefix, version)
    @prefix = Pathname(prefix)
    @version = version
  end
  def version
    @version
  end
  def bin
    prefix/"bin"
  end
  def lib
    prefix/"lib"
  end
  def libexec
    prefix/"libexec"
  end
  def man1
    man/"man1"
  end
  def man
    prefix/"share/man"
  end
  def doc
    prefix/"share/doc/dot"
  end
  def bash_completion
    prefix/"etc/bash_completion.d"
  end
  def zsh_completion
    prefix/"share/zsh/site-functions"
  end
  def fish_completion
    prefix/"share/fish/vendor_completions.d"
  end
  def testpath
    Pathname(ENV.fetch("HOME"))
  end
  def system(*cmd)
    Kernel.system(*cmd) || raise("failed: #{cmd.join(" ")}")
  end
  def shell_output(cmd)
    out = `#{cmd}`
    raise "exit #{$?.exitstatus}: #{cmd}\n#{out}" unless $?.success?
    out
  end
  def assert_match(want, got)
    raise "#{want.inspect} not in output" unless got.include?(want.to_s)
  end
  def self.test(&block)
    define_method(:run_test, &block)
  end
end
load formula_path
f = Dot.new(cellar, version)
f.install
f.run_test
RUBY
  assert_equals "0" "$rc" "the formula's install and test blocks pass ($(tail -1 "$tmp/brew.out"))"
  rc=0
  entry_runs "$cellar/bin/dot" || rc=$?
  assert_equals "0" "$rc" "dot fleet policy show runs from the Homebrew layout"
else
  printf '  - SKIP %s: %s\n' "$CURRENT_TEST" "ruby not installed"
fi

# ── Scoop: every shim target exists in the zip's tree ────────────────────
test_start "scoop_bin_entries_exist"
while IFS= read -r shim; do
  assert_file_exists "$bundle/$shim" "Scoop shims $shim"
done < <(jq -r '.bin[]' "$REPO_ROOT/pkg/scoop/dot.json")
if command -v pwsh >/dev/null 2>&1; then
  test_start "scoop_ps1_runs"
  rc=0
  HOME="$tmp/home" NO_COLOR=1 pwsh -NoProfile -File "$bundle/bin/dot.ps1" version >"$tmp/out" 2>&1 || rc=$?
  assert_equals "0" "$rc" "bin/dot.ps1 version runs from the archive"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"

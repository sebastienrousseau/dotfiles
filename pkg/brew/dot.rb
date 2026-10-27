# typed: false
# frozen_string_literal: true

# Homebrew formula for the `dot` CLI from
# https://github.com/sebastienrousseau/dotfiles
#
# This file is the template the release pipeline rewrites per tag:
# `release-distribute-homebrew.yml` swaps the `url` and `sha256`
# lines and opens a PR against sebastienrousseau/homebrew-tap.
#
# Verify locally with:
#   brew install --build-from-source dot.rb && dot version

class Dot < Formula
  desc "Declarative dotfiles CLI for macOS, Linux, WSL, and PowerShell"
  homepage "https://github.com/sebastienrousseau/dotfiles"
  url "https://github.com/sebastienrousseau/dotfiles/releases/download/v0.2.511/dot-0.2.511.tar.gz"
  sha256 "6b9f435ebeaca6ff5ec9e6c7458972cb1b8d43b80959a75ff990b629ff5af2cf"
  license "MIT"

  depends_on "bash" => :build
  depends_on "chezmoi"

  # Optional but commonly used by the framework:
  depends_on "gum"      => :recommended
  depends_on "jq"       => :recommended
  depends_on "starship" => :recommended

  # The archive's own `make install` places the whole tree the CLI reads
  # at run time (scripts, plugins, defaults) under libexec, and links
  # bin/dot to it; installing bin and lib alone left every command but
  # `dot version` unknown.
  def install
    system "make", "install",
           "PREFIX=#{prefix}",
           "LIBEXECDIR=#{libexec}",
           "DOT_LINK=../libexec/bin/dot",
           "MANDIR=#{man}",
           "DOCDIR=#{doc}",
           "BASHCOMPDIR=#{bash_completion}",
           "ZSHCOMPDIR=#{zsh_completion}",
           "FISHCOMPDIR=#{fish_completion}"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/dot version")
    # A bundled plugin's entry reads its defaults, so this fails on an
    # install that left out plugins/ or defaults/.
    ENV["HOME"] = testpath.to_s
    ENV["DOTFILES_NONINTERACTIVE"] = "1"
    ENV["NO_COLOR"] = "1"
    shell_output("#{bin}/dot fleet policy show")
  end
end

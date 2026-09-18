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
  desc 'Declarative dotfiles CLI for macOS, Linux, WSL, and PowerShell'
  homepage 'https://github.com/sebastienrousseau/dotfiles'
  url 'https://github.com/sebastienrousseau/dotfiles/releases/download/v0.2.503/dot-0.2.503.tar.gz'
  sha256 'PLACEHOLDER_FILL_ON_v0.2.503_PUBLICATION'
  license 'MIT'

  depends_on 'bash' => :build
  depends_on 'chezmoi'

  # Optional but commonly used by the framework:
  depends_on 'gum'      => :recommended
  depends_on 'jq'       => :recommended
  depends_on 'starship' => :recommended

  def install
    bin.install 'bin/dot'
    bin.install Dir['bin/dot-*']
    lib.install Dir['lib/*']
    man1.install 'share/man/man1/dot.1'
    zsh_completion.install 'share/zsh/site-functions/_dot'
    bash_completion.install 'share/bash-completion/completions/dot'
    fish_completion.install 'share/fish/vendor_completions.d/dot.fish'
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/dot version")
  end
end

# typed: false
# frozen_string_literal: true

# Homebrew formula scaffold for the `dot` CLI from
# https://github.com/sebastienrousseau/dotfiles
#
# STATUS: scaffold only. The framework does not yet ship a single-
# tarball release artefact (the chezmoi-managed `dot_*` prefixed
# files at the repo root require chezmoi to render). The v0.2.503
# repo reorganisation (`docs/operations/ROADMAP_V0_2_503.md`)
# unblocks publication by separating the CLI binary into a
# `bin/dot` path that can be distributed standalone.
#
# Until then, this file lives here as the target structure so the
# v0.2.503 PR's reviewer can see exactly what shape the formula
# needs and can validate it against the Brew-tap publication
# checklist.
#
# Once v0.2.503 ships the standalone-CLI tarball:
#   1. Publish to sebastienrousseau/homebrew-tap (separate repo)
#   2. Refresh `sha256` below from the release artefact
#   3. Verify via:  brew install --build-from-source dot.rb && dot version

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

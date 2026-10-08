# Dotfiles Dev Container
# Provides a full development environment with chezmoi-managed dotfiles
#
# Base image pinned by sha256 digest per Scorecard's Pinned-Dependencies
# check. Refresh with:
#   docker pull mcr.microsoft.com/devcontainers/base:ubuntu
#   docker inspect --format '{{index .RepoDigests 0}}' \
#     mcr.microsoft.com/devcontainers/base:ubuntu
FROM mcr.microsoft.com/devcontainers/base:ubuntu@sha256:edfb983aab9c579a385dc23c57d7d3703f5ec920124d99c16204a2cac465aab4

ARG DEBIAN_FRONTEND=noninteractive

# Install system dependencies for dotfiles
RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    age \
    bat \
    curl \
    fd-find \
    fzf \
    git \
    jq \
    neovim \
    ripgrep \
    shellcheck \
    tmux \
    unzip \
    zsh \
    && rm -rf /var/lib/apt/lists/*

# Install chezmoi — SHA256-verified via the same script the production
# bootstrap uses (closes R4 §8.3 P3 / mirrors R1 H6 fix in install.sh).
ARG CHEZMOI_VERSION=2.72.2
COPY tools/ci/install-chezmoi-verified.sh /tmp/install-chezmoi-verified.sh
RUN bash /tmp/install-chezmoi-verified.sh "${CHEZMOI_VERSION}" /usr/local/bin \
    && rm -f /tmp/install-chezmoi-verified.sh

# Install starship prompt — pinned release tarball with SHA256
# verification, the same release and hash as STARSHIP_TAG /
# STARSHIP_SHA256_X86_64 in defaults/dot_config/dotfiles/versions.env.
# Source: https://github.com/starship/starship/releases/download/v1.24.2/starship-x86_64-unknown-linux-musl.tar.gz.sha256
ARG STARSHIP_VERSION=1.24.2
ARG STARSHIP_SHA256=00ff3c1f8ffb59b5c15d4b44c076bcca04d92cf0055c86b916248c14f3ae714a
RUN set -eu \
    && url="https://github.com/starship/starship/releases/download/v${STARSHIP_VERSION}/starship-x86_64-unknown-linux-musl.tar.gz" \
    && curl -fsSL "$url" -o /tmp/starship.tar.gz \
    && echo "${STARSHIP_SHA256}  /tmp/starship.tar.gz" | sha256sum -c - \
    && tar -xzf /tmp/starship.tar.gz -C /tmp starship \
    && install -m 0755 /tmp/starship /usr/local/bin/starship \
    && rm -f /tmp/starship /tmp/starship.tar.gz

# Install eza (modern ls). apt's signed-by trusts every primary key in the
# keyring, so it must hold exactly the pinned one. Fingerprint read from
# https://raw.githubusercontent.com/eza-community/eza/main/deb.asc on
# 2026-10-08 (Sandro-Alessio Gierens, aptly key).
ARG EZA_GPG_FPR=1548BC8A4B4D2688F9B0DAF7EC29E2090CE3FD43
RUN set -eu \
    && mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://raw.githubusercontent.com/eza-community/eza/main/deb.asc -o /tmp/eza.asc \
    && gpg --batch --dearmor -o /etc/apt/keyrings/gierens.gpg /tmp/eza.asc \
    && keys="$(gpg --no-default-keyring --keyring /etc/apt/keyrings/gierens.gpg --list-keys --with-colons)" \
    && test "$(printf '%s\n' "$keys" | grep -c '^pub:')" = 1 \
    && test "$(printf '%s\n' "$keys" | awk -F: '/^pub:/ { p = 1; next } p && /^fpr:/ { print $10; exit }')" = "$EZA_GPG_FPR" \
    && echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] https://deb.gierens.de stable main" \
        | tee /etc/apt/sources.list.d/gierens.list >/dev/null \
    && apt-get update -qq && apt-get install -y --no-install-recommends eza \
    && rm -rf /var/lib/apt/lists/* /tmp/eza.asc

# Install zoxide — pinned release tarball with SHA256 verification.
# The previous `curl … | sh` pattern fetched a moving `main`-branch
# install.sh and ran it without any integrity check, which Scorecard
# flags as `downloadThenRun not pinned by hash`. Refresh recipe:
#   curl -fsSL https://api.github.com/repos/ajeetdsouza/zoxide/releases/latest \
#     | jq -r .tag_name
#   curl -fsSL https://github.com/.../zoxide-X.Y.Z-x86_64-unknown-linux-musl.tar.gz \
#     | sha256sum
ARG ZOXIDE_VERSION=0.9.9
ARG ZOXIDE_SHA256=4ff057d3c4d957946937274c2b8be7af2a9bbae7f90a1b5e9baaa7cb65a20caa
RUN set -eu \
    && url="https://github.com/ajeetdsouza/zoxide/releases/download/v${ZOXIDE_VERSION}/zoxide-${ZOXIDE_VERSION}-x86_64-unknown-linux-musl.tar.gz" \
    && curl -fsSL "$url" -o /tmp/zoxide.tar.gz \
    && echo "${ZOXIDE_SHA256}  /tmp/zoxide.tar.gz" | sha256sum -c - \
    && tar -xzf /tmp/zoxide.tar.gz -C /tmp \
    && install -m 0755 /tmp/zoxide /usr/local/bin/zoxide \
    && rm -rf /tmp/zoxide /tmp/zoxide.tar.gz /tmp/man /tmp/completions

# Install mise (universal version manager) — pinned release binary
# with SHA256 verification. Refresh recipe:
#   curl -fsSL https://api.github.com/repos/jdx/mise/releases/latest \
#     | jq -r .tag_name
#   curl -fsSL https://github.com/jdx/mise/releases/download/<TAG>/SHASUMS256.txt \
#     | grep mise-<TAG>-linux-x64$
ARG MISE_VERSION=2026.5.7
ARG MISE_SHA256=f70272c144e6a3da52cea68d544bb43ef5410905efe6f3bfc2c9d448949e1ce5
RUN set -eu \
    && url="https://github.com/jdx/mise/releases/download/v${MISE_VERSION}/mise-v${MISE_VERSION}-linux-x64" \
    && curl -fsSL "$url" -o /tmp/mise \
    && echo "${MISE_SHA256}  /tmp/mise" | sha256sum -c - \
    && install -m 0755 /tmp/mise /usr/local/bin/mise \
    && rm /tmp/mise

# fd-find and bat are named differently on Debian/Ubuntu
RUN ln -sf /usr/bin/fdfind /usr/local/bin/fd 2>/dev/null || true
RUN ln -sf /usr/bin/batcat /usr/local/bin/bat 2>/dev/null || true

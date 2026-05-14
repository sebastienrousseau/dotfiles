# Dotfiles Dev Container
# Provides a full development environment with chezmoi-managed dotfiles
#
# Base image pinned by sha256 digest per Scorecard's Pinned-Dependencies
# check. Refresh with:
#   docker pull mcr.microsoft.com/devcontainers/base:ubuntu
#   docker inspect --format '{{index .RepoDigests 0}}' \
#     mcr.microsoft.com/devcontainers/base:ubuntu
FROM mcr.microsoft.com/devcontainers/base:ubuntu@sha256:7ee7da33a68d997971660d91ecc8372e55a38a777c3c6bd6808daf91928052db

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

# Install chezmoi
RUN sh -c "$(curl -fsSL https://get.chezmoi.io)" -- -b /usr/local/bin

# Install starship prompt
RUN sh -c "$(curl -fsSL https://starship.rs/install.sh)" -- -y

# Install eza (modern ls)
RUN mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://raw.githubusercontent.com/eza-community/eza/main/deb.asc \
        | gpg --dearmor -o /etc/apt/keyrings/gierens.gpg \
    && gpg --no-default-keyring --keyring /etc/apt/keyrings/gierens.gpg \
        --list-keys --with-colons 2>/dev/null | grep -q "pub:" \
    && echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" \
        | tee /etc/apt/sources.list.d/gierens.list >/dev/null \
    && apt-get update -qq && apt-get install -y --no-install-recommends eza \
    && rm -rf /var/lib/apt/lists/*

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

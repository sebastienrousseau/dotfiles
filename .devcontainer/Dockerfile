# Dotfiles Dev Container
# Provides a full development environment with chezmoi-managed dotfiles
FROM mcr.microsoft.com/devcontainers/base:ubuntu

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
    wget \
    zsh \
    && rm -rf /var/lib/apt/lists/*

# Install chezmoi
RUN sh -c "$(curl -fsSL https://get.chezmoi.io)" -- -b /usr/local/bin

# Install starship prompt
RUN sh -c "$(curl -fsSL https://starship.rs/install.sh)" -- -y

# Install eza (modern ls)
RUN mkdir -p /etc/apt/keyrings \
    && wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc \
       | gpg --dearmor -o /etc/apt/keyrings/gierens.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" \
       | tee /etc/apt/sources.list.d/gierens.list >/dev/null \
    && apt-get update -qq && apt-get install -y eza \
    && rm -rf /var/lib/apt/lists/*

# Install zoxide
RUN curl -fsSL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh

# Install mise (universal version manager)
RUN curl -fsSL https://mise.jdx.dev/install.sh | sh \
    && ln -sf /root/.local/bin/mise /usr/local/bin/mise

# fd-find and bat are named differently on Debian/Ubuntu
RUN ln -sf /usr/bin/fdfind /usr/local/bin/fd 2>/dev/null || true \
    && ln -sf /usr/bin/batcat /usr/local/bin/bat 2>/dev/null || true

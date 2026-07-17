#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Universal Dotfiles Installer (Zero-Dependency)
# Usage: bash -c "$(curl -fsSL https://raw.githubusercontent.com/sebastienrousseau/dotfiles/main/install.sh)"
# (or ./install.sh locally)

# This installer uses bash features (set -o pipefail, arrays, [[ ]]). If it is
# run under a POSIX/other shell — e.g. `sh install.sh` or piped to `sh` where
# /bin/sh is dash — fail fast with a clear message instead of the cryptic
# "set: Illegal option -o pipefail" from the next line. Kept strictly POSIX so
# it parses in any shell before bash takes over.
if [ -z "${BASH_VERSION:-}" ]; then
  echo "install.sh requires bash. Run:  bash install.sh" >&2
  echo "  or:  bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/sebastienrousseau/dotfiles/main/install.sh)\"" >&2
  exit 1
fi

set -euo pipefail

# Restrict the permissions of any file/dir we create during bootstrap.
# The installer writes secret-adjacent artifacts (chezmoi config, age
# keys, ssh tooling, downloaded archives) under $HOME — 077 prevents
# other local accounts from reading them. Individual call sites can
# still relax with `chmod` when a file is meant to be world-readable.
umask 077

# ANSI Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Paths
SOURCE_DIR="${SOURCE_DIR:-$HOME/.dotfiles}"
LEGACY_SOURCE_DIR="$HOME/.local/share/chezmoi"
CHEZMOI_CONFIG_DIR="$HOME/.config/chezmoi"
CHEZMOI_CONFIG_FILE="$CHEZMOI_CONFIG_DIR/chezmoi.toml"

# Utility Functions
step() {
  if [[ "${DOTFILES_SILENT:-0}" != "1" ]]; then
    printf '%b\n' "${BOLD}${BLUE}==>${NC} ${BOLD}$1${NC}"
  fi
}

error() {
  printf '%b\n' "${RED}Error:${NC} $1" >&2
  exit 1
}

success() {
  if [[ "${DOTFILES_SILENT:-0}" != "1" ]]; then
    printf '%b\n' "${GREEN}Success!${NC} $1"
  fi
}

# Cross-platform sed in-place (BSD vs GNU)
sed_in_place() {
  if sed --version >/dev/null 2>&1; then
    sed -i "$@" # GNU
  else
    sed -i '' "$@" # BSD (macOS)
  fi
}

show_help() {
  cat <<EOF
Usage: install.sh [version] [options]

Arguments:
  version       The version (tag or branch) to install (default: v0.2.512)

Options:
  --help        Show this help message
  --force       Non-interactive mode (sets DOTFILES_NONINTERACTIVE=1)
  --silent      Quiet mode (sets DOTFILES_SILENT=1)
  --minimal     Minimal profile (disable nvim, tmux, zellij)
  --provision   After applying configs, install the toolchain (packages,
                fonts, language tools) via the install/provision scripts.
                Also enabled by DOTFILES_PROVISION=1. Opt-in because it
                installs packages and may change OS defaults.

EOF
}

main() {
  local version="v0.2.512"
  local version_set=0
  local minimal=0
  local provision="${DOTFILES_PROVISION:-0}"
  local _cleanup_files=()
  trap 'set +u; rm -f "${_cleanup_files[@]}" 2>/dev/null; set -u' EXIT

  for arg in "$@"; do
    case "$arg" in
      -h | --help)
        show_help
        exit 0
        ;;
      --silent) export DOTFILES_SILENT=1 ;;
      --force) export DOTFILES_NONINTERACTIVE=1 ;;
      --minimal) minimal=1 ;;
      --provision) provision=1 ;;
      -*)
        # Catch single-dash and double-dash unknowns the same way.
        error "Unknown option: $arg"
        ;;
      *)
        if [[ $version_set -eq 1 ]]; then
          error "Multiple versions specified: $version and $arg"
        fi
        # Validate the positional looks like a semver (with or without
        # leading v). Reject garbage early so an unknown positional
        # like `foobar` doesn't trigger a 30s+ network download attempt.
        # Caught by the install.sh fuzz harness (#881).
        if [[ ! "$arg" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+([-+][a-zA-Z0-9.-]+)?$ ]]; then
          error "Unrecognized positional argument '$arg' — expected a semver version (e.g. v0.2.512)."
        fi
        version="$arg"
        version_set=1
        ;;
    esac
  done

  # 2. Check Prerequisites & Bootstrap Package Managers
  step "Checking Prerequisites..."

  # Detect Operating System
  OS="$(uname -s)"
  case "$OS" in
    Darwin) target_os="macos" ;;
    Linux)
      if grep -qi microsoft /proc/version 2>/dev/null; then
        target_os="wsl2"
      elif [ -f /etc/debian_version ]; then
        target_os="debian"
      elif [ -f /etc/fedora-release ]; then
        target_os="fedora"
      elif [ -f /etc/arch-release ]; then
        target_os="arch"
      else
        target_os="linux"
      fi
      ;;
    *) target_os="unknown" ;;
  esac

  # Bootstrap gum for a better UI if available or install it
  bootstrap_gum() {
    if command -v gum >/dev/null 2>&1; then return 0; fi
    if [[ "${DOTFILES_SILENT:-0}" == "1" ]]; then return 0; fi

    echo "   Bootstrapping UI components (gum)..."
    if [[ "$OS" == "Darwin" ]] && command -v brew >/dev/null; then
      brew install gum >/dev/null 2>&1
    elif [[ "$target_os" == "debian" || "$target_os" == "wsl2" ]]; then
      sudo mkdir -p /etc/apt/keyrings
      curl -fsSL https://repo.charm.sh/apt/gpg.key |
        sudo gpg --batch --yes --dearmor -o /etc/apt/keyrings/charm.gpg
      # Pin the Charm GPG key fingerprint — a DNS attacker swapping
      # repo.charm.sh/apt/gpg.key for a forged key with the same uid
      # would otherwise pass the prior "any fid: present" check.
      # Pinned value taken from https://repo.charm.sh/apt/gpg.key on
      # 2026-05-16. If Charm rotates, update this and call it out in
      # CHANGELOG.md.
      CHARM_GPG_EXPECTED_FPR="C026D31B92F9BBE91D5DB75AB07AE17C9E0A6585"
      charm_actual_fpr="$(gpg --no-default-keyring \
        --keyring /etc/apt/keyrings/charm.gpg \
        --with-colons --fingerprint 2>/dev/null |
        awk -F: '/^fpr:/{print $10; exit}')"
      if [[ -z "$charm_actual_fpr" ]]; then
        echo "Error: Could not extract Charm GPG fingerprint — aborting" >&2
        sudo rm -f /etc/apt/keyrings/charm.gpg
        return 1
      fi
      if [[ "$charm_actual_fpr" != "$CHARM_GPG_EXPECTED_FPR" ]]; then
        echo "Error: Charm GPG fingerprint mismatch" >&2
        echo "  expected: $CHARM_GPG_EXPECTED_FPR" >&2
        echo "  got:      $charm_actual_fpr" >&2
        echo "  aborting (possible DNS / keyserver hijack)" >&2
        sudo rm -f /etc/apt/keyrings/charm.gpg
        return 1
      fi
      echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | sudo tee /etc/apt/sources.list.d/charm.list
      sudo apt-get update && sudo apt-get install gum -y >/dev/null 2>&1
    fi
  }

  # 3. Install Chezmoi (in parallel with other checks where possible)
  install_chezmoi() {
    if command -v chezmoi >/dev/null; then
      echo "   chezmoi already installed: $(chezmoi --version)"
      return 0
    fi

    if command -v brew >/dev/null; then
      echo "   Installing chezmoi via Homebrew..."
      brew install chezmoi >/dev/null 2>&1
    else
      bin_dir="$HOME/.local/bin"
      mkdir -p "$bin_dir"
      echo "   Installing chezmoi via binary download..."

      # Prefer verified installer with SHA256 checksum when available.
      # When verification fails or the verified installer isn't present
      # we refuse to bootstrap rather than silently downloading and
      # executing an unverified script (the previous fall-back to
      # `get.chezmoi.io` was an unsigned bootstrap and a security hole).
      local verified_installer
      verified_installer="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/tools/ci/install-chezmoi-verified.sh"
      if [[ -x "$verified_installer" ]] || [[ -f "$verified_installer" ]]; then
        echo "   Using checksum-verified installer..."
        if ! bash "$verified_installer" "${CHEZMOI_VERSION:-2.47.1}" "$bin_dir"; then
          echo "" >&2
          echo "   The verified chezmoi installer failed." >&2
          echo "   Refusing to fall back to an unverified bootstrap path." >&2
          echo "   Install chezmoi manually from a trusted source, then re-run install.sh:" >&2
          echo "     macOS:  brew install chezmoi" >&2
          echo "     Linux:  see https://www.chezmoi.io/install/" >&2
          return 1
        fi
        return 0
      fi
      echo "" >&2
      echo "   tools/ci/install-chezmoi-verified.sh is missing; cannot verify chezmoi bootstrap." >&2
      echo "   Install chezmoi manually (brew install chezmoi / official binary)" >&2
      echo "   and re-run install.sh." >&2
      return 1
    fi
  }

  # Parallel execution of bootstrapping components
  local pid_gum pid_cm
  (bootstrap_gum) &
  pid_gum=$!
  (install_chezmoi) &
  pid_cm=$!

  # Wait and check exit codes
  wait "$pid_gum" || true # gum is optional
  wait "$pid_cm" || error "chezmoi installation failed"

  # Critical: Add to PATH for the rest of the script to see it
  bin_dir="$HOME/.local/bin"
  export PATH="$bin_dir:$PATH"

  # 4. Prepare source directory
  step "Preparing source directory..."

  # VERSION pinning for supply-chain security
  VERSION="$version"

  ensure_chezmoi_source() {
    local dir="$1"
    mkdir -p "$CHEZMOI_CONFIG_DIR"
    # Escape sed metacharacters in replacement string
    local escaped_dir
    escaped_dir=$(printf '%s\n' "$dir" | sed -e 's/[\/&]/\\&/g')
    if [[ -f "$CHEZMOI_CONFIG_FILE" ]] && grep -q '^sourceDir' "$CHEZMOI_CONFIG_FILE"; then
      sed_in_place "s,^sourceDir.*$,sourceDir = \"$escaped_dir\"," "$CHEZMOI_CONFIG_FILE"
    else
      printf 'sourceDir = "%s"\n' "$dir" >"$CHEZMOI_CONFIG_FILE"
    fi
  }

  apply_minimal_profile_overrides() {
    local data_file="$1"
    [[ -f "$data_file" ]] || return 0
    sed_in_place 's/^profile = ".*"/profile = "minimal"/' "$data_file"
    sed_in_place 's/^nvim = true/nvim = false/' "$data_file"
    sed_in_place 's/^tmux = true/tmux = false/' "$data_file"
    sed_in_place 's/^zellij = true/zellij = false/' "$data_file"
  }

  # Carry the user's existing global git identity into chezmoi's data.
  #
  # This installer sets up chezmoi via sourceDir rather than `chezmoi init`,
  # so the config template's prompts for git_name / git_email never run. The
  # gitconfig template coalesces git_name->name->"" (likewise email,
  # signingkey) and only emits a [user] block when non-empty — so without
  # this, a fresh install produces a ~/.gitconfig with no identity at all,
  # and commits fail with "Author identity unknown". Seed name/email/
  # signingkey from `git config --global` when present. Idempotent: skips if
  # the config already carries a [data] block.
  toml_escape() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }
  seed_git_identity() {
    local cfg="$CHEZMOI_CONFIG_FILE"
    [[ -f "$cfg" ]] || return 0
    grep -q '^\[data\]' "$cfg" 2>/dev/null && return 0
    local gname gemail gkey
    gname="$(git config --global user.name 2>/dev/null || true)"
    gemail="$(git config --global user.email 2>/dev/null || true)"
    gkey="$(git config --global user.signingkey 2>/dev/null || true)"
    [[ -z "$gname" && -z "$gemail" ]] && return 0
    {
      printf '\n[data]\n'
      [[ -n "$gname" ]] && printf 'name = "%s"\n' "$(toml_escape "$gname")"
      [[ -n "$gemail" ]] && printf 'email = "%s"\n' "$(toml_escape "$gemail")"
      [[ -n "$gkey" ]] && printf 'signingkey = "%s"\n' "$(toml_escape "$gkey")"
    } >>"$cfg"
    echo "   Seeded git identity ($gname <$gemail>) into chezmoi data."
  }

  # 5. Backup existing dotfiles that chezmoi will overwrite
  step "Backing up existing dotfiles..."
  BACKUP_DIR="$HOME/.dotfiles.bak.$(date +"%Y%m%d_%H%M%S")"
  backup_count=0

  # Determine the source directory for chezmoi to diff against
  if [[ -d "$SOURCE_DIR/.git" ]]; then
    ensure_chezmoi_source "$SOURCE_DIR"
  elif [[ -d "$LEGACY_SOURCE_DIR/.git" ]]; then
    ensure_chezmoi_source "$LEGACY_SOURCE_DIR"
  fi

  # Back up any existing files that chezmoi would overwrite
  if command -v chezmoi >/dev/null && [[ -f "$CHEZMOI_CONFIG_FILE" ]]; then
    while IFS= read -r file; do
      [[ -z "$file" ]] && continue
      # Skip managed *directories*: chezmoi apply never clobbers a
      # directory's existing contents, so they don't need backing up, and
      # `cp -a` on one recurses into things it can't copy — e.g. the live
      # ssh-agent sockets under ~/.ssh/agent, which spew
      # "is a socket (not copied)" warnings. The managed files chezmoi
      # would actually overwrite are listed (and backed up) individually.
      # `-d` without `-L` excludes only real dirs; symlinks are copied as
      # links by `cp -a`, so they never recurse.
      if [[ -d "$file" && ! -L "$file" ]]; then
        continue
      fi
      if [[ -e "$file" ]]; then
        rel="${file#"$HOME"/}"
        mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
        cp -a "$file" "$BACKUP_DIR/$rel"
        backup_count=$((backup_count + 1))
      fi
    done < <(chezmoi managed --path-style=absolute 2>/dev/null || true)
  fi

  if [[ "$backup_count" -gt 0 ]]; then
    echo "   Backed up $backup_count files to $BACKUP_DIR"
  else
    echo "   No existing dotfiles to back up."
    rm -rf "$BACKUP_DIR" 2>/dev/null || true
  fi

  # Detect devcontainer/Codespaces environment
  if [[ -f /.dockerenv ]] || [[ -n "${CODESPACES:-}" ]] || [[ -n "${REMOTE_CONTAINERS:-}" ]]; then
    DOTFILES_MINIMAL=1
    step "Detected container environment — using minimal profile"
  fi

  # Apply --minimal overrides if requested
  if [[ $minimal -eq 1 ]] || [[ "${DOTFILES_MINIMAL:-0}" = "1" ]]; then
    step "Applying minimal profile overrides..."
    apply_minimal_profile_overrides "$SOURCE_DIR/.chezmoidata.toml"
  fi

  # 6. Initialize & Apply
  step "Applying Configuration..."

  # ── Auto-migration for v0.2.512 reorg ─────────────────────────────────
  # If the user is upgrading from a pre-0.2.503 install, run the
  # migration script BEFORE `chezmoi apply` so the reorg's source-
  # path moves don't cause chezmoi to delete deployed files.
  # The script is idempotent + silent-by-default; safe to run on
  # every install (fresh installs detect "no prior state" and exit 0).
  for migrate_src in "$SOURCE_DIR" "$LEGACY_SOURCE_DIR"; do
    migrate_script="$migrate_src/install/migrate/migrate-v0_2-to-v0_2_503.sh"
    if [[ -x "$migrate_script" ]]; then
      echo "   Running v0.2.512 migration (idempotent; safe on fresh installs)..."
      "$migrate_script" || echo "   migration exited non-zero — continuing apply"
      break
    fi
  done

  # If we are running from a local source, just apply
  if [[ -d "$SOURCE_DIR/.git" ]]; then
    echo "   Applying from local source: $SOURCE_DIR"
    ensure_chezmoi_source "$SOURCE_DIR"
    seed_git_identity
    APPLY_FLAGS=()
    if [[ "${DOTFILES_NONINTERACTIVE:-0}" = "1" ]]; then
      APPLY_FLAGS=(--force --no-tty)
    fi
    chezmoi apply "${APPLY_FLAGS[@]}"
  elif [[ -d "$LEGACY_SOURCE_DIR/.git" ]]; then
    echo "   Migrating from legacy source: $LEGACY_SOURCE_DIR"
    mv "$LEGACY_SOURCE_DIR" "$SOURCE_DIR"
    ensure_chezmoi_source "$SOURCE_DIR"
    seed_git_identity
    APPLY_FLAGS=()
    if [[ "${DOTFILES_NONINTERACTIVE:-0}" = "1" ]]; then
      APPLY_FLAGS=(--force --no-tty)
    fi
    chezmoi apply "${APPLY_FLAGS[@]}"
  else
    echo "   Initializing from GitHub (Branch/Tag: $VERSION)..."
    printf '%b\n' "${CYAN}   SECURITY NOTE: Cloning pinned version $VERSION for supply-chain safety${NC}"

    # STRICT MODE: We pin to the specific tag to avoid 'main' branch drift
    git clone --depth 1 --branch "$VERSION" https://github.com/sebastienrousseau/dotfiles.git "$SOURCE_DIR" 2>/dev/null ||
      { git clone https://github.com/sebastienrousseau/dotfiles.git "$SOURCE_DIR" && (cd "$SOURCE_DIR" && git checkout "$VERSION"); }

    # Verify the checkout succeeded and we're on the expected version
    ACTUAL_REF=$(
      cd "$SOURCE_DIR" || exit 1
      if ! git describe --tags --exact-match 2>/dev/null; then
        git rev-parse --short HEAD
      fi
    )
    if [[ "$ACTUAL_REF" != "$VERSION" ]] && [[ "${ACTUAL_REF#v}" != "${VERSION#v}" ]]; then
      printf '%b\n' "${RED}   WARNING: Checked out ref $ACTUAL_REF (requested: $VERSION) — version mismatch${NC}" >&2
    fi

    if [[ $minimal -eq 1 ]]; then
      step "Applying minimal profile overrides..."
      apply_minimal_profile_overrides "$SOURCE_DIR/.chezmoidata.toml"
    fi

    ensure_chezmoi_source "$SOURCE_DIR"
    seed_git_identity
    APPLY_FLAGS=()
    if [[ "${DOTFILES_NONINTERACTIVE:-0}" = "1" ]]; then
      APPLY_FLAGS=(--force --no-tty)
    fi
    chezmoi apply "${APPLY_FLAGS[@]}"
  fi

  # Toolchain provisioning (opt-in). The install/provision/ scripts (package
  # managers, fonts, language + AI tools) are chezmoi run_ scripts, but they
  # live OUTSIDE the .chezmoiroot source dir (defaults/), so `chezmoi apply`
  # never runs them — a fresh install otherwise ships configs but zero tools.
  # Run them here only when explicitly requested: they install packages and
  # can change OS defaults, so we never do it implicitly (CI / Docker /
  # unattended automation must opt in via --provision or DOTFILES_PROVISION=1).
  if [[ "$provision" = "1" && $minimal -eq 0 ]]; then
    step "Provisioning toolchain (packages, fonts, tools)..."
    local prov_dir="$SOURCE_DIR/install/provision"
    if [[ -d "$prov_dir" ]]; then
      local script
      # run_once_install_* (shells) first, then numbered run_onchange_* in order.
      while IFS= read -r script; do
        [[ -f "$script" ]] || continue
        echo "   → $(basename "$script")"
        if [[ "$script" == *.tmpl ]]; then
          chezmoi execute-template <"$script" | bash ||
            echo "     (step exited non-zero — continuing)"
        else
          bash "$script" || echo "     (step exited non-zero — continuing)"
        fi
      done < <(ls "$prov_dir"/run_once_install_* "$prov_dir"/run_onchange_* 2>/dev/null | sort)
    fi
  elif [[ $minimal -eq 0 ]]; then
    step "Configs deployed. To also install the toolchain (packages, fonts, tools):"
    echo "   bash \"$SOURCE_DIR/install.sh\" --provision    # or DOTFILES_PROVISION=1"
    echo "   (or: brew bundle --file ~/.config/shell/Brewfile.cli)"
  fi

  success "Configuration loaded. Please restart your shell."

  # If no git identity ended up configured, commits will fail with
  # "Author identity unknown". Point the user at the one-line fix rather
  # than letting them discover it on their first commit.
  if [[ -z "$(git config --global user.email 2>/dev/null || true)" ]] &&
    ! grep -q '^email' "$CHEZMOI_CONFIG_FILE" 2>/dev/null; then
    step "No git identity detected. Set yours so commits are attributed:"
    echo "   git config --global user.name  \"Your Name\""
    echo "   git config --global user.email \"you@example.com\""
    echo "   then re-run: chezmoi apply"
  fi

  step "Run 'dot learn' for an interactive tour of your new dotfiles."
}

# Run main if executed directly (or via bash -c where BASH_SOURCE is unset)
if [[ "${BASH_SOURCE[0]:-}" == "${0:-}" ]] || [[ -z "${BASH_SOURCE[0]:-}" ]]; then
  main "$@"
fi

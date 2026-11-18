#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Universal Dotfiles Installer (Zero-Dependency)
# Usage: gh repo clone sebastienrousseau/dotfiles && cd dotfiles && ./install.sh
# (or ./install.sh locally)

# Needs bash (pipefail, arrays, [[ ]]). Under sh/dash, fail with a clear message
# instead of "set: Illegal option -o pipefail"; this guard is strictly POSIX.
if [ -z "${BASH_VERSION:-}" ]; then
  echo "install.sh requires bash. Run:  bash install.sh" >&2
  echo "  clone: gh repo clone sebastienrousseau/dotfiles && cd dotfiles && ./install.sh" >&2
  exit 1
fi

set -euo pipefail

# Bootstrap writes secret-adjacent files (chezmoi config, age keys, ssh tooling,
# archives) under $HOME: 077 keeps other accounts out; call sites chmod to relax.
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

toml_escape() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }

# Rewrite $CHEZMOI_CONFIG_FILE through an awk program, atomically.
# Values reach awk via the environment, so no sed/awk escaping applies.
_chezmoi_config_rewrite() {
  local prog="$1" tmp
  tmp=$(mktemp "$CHEZMOI_CONFIG_FILE.XXXXXX") || return 1
  if awk "$prog" "$CHEZMOI_CONFIG_FILE" >"$tmp"; then
    mv "$tmp" "$CHEZMOI_CONFIG_FILE"
  else
    rm -f "$tmp"
    return 1
  fi
}

# Point chezmoi at the source dir. Existing config (data, git settings)
# is preserved: only the top-level sourceDir key is set or inserted.
ensure_chezmoi_source() {
  local dir="$1"
  mkdir -p "$CHEZMOI_CONFIG_DIR"
  local line
  line="sourceDir = \"$(toml_escape "$dir")\""
  if [[ ! -f "$CHEZMOI_CONFIG_FILE" ]]; then
    printf '%s\n' "$line" >"$CHEZMOI_CONFIG_FILE"
    return
  fi
  # shellcheck disable=SC2016
  DOT_LINE="$line" _chezmoi_config_rewrite '
    !done && /^[[:space:]]*\[/ { print ENVIRON["DOT_LINE"]; done = 1 }
    !done && /^[[:space:]]*sourceDir[[:space:]]*=/ { print ENVIRON["DOT_LINE"]; done = 1; next }
    { print }
    END { if (!done) print ENVIRON["DOT_LINE"] }'
}

# Select the minimal profile in the per-host chezmoi config ([data]
# overrides .chezmoidata.toml), never in the tracked source tree.
apply_minimal_profile_overrides() {
  [[ -f "$CHEZMOI_CONFIG_FILE" ]] || printf '' >"$CHEZMOI_CONFIG_FILE"
  # shellcheck disable=SC2016
  _chezmoi_config_rewrite '
    /^[[:space:]]*\[/ {
      if (in_data && !done) { print "profile = \"minimal\""; done = 1 }
      in_data = ($0 ~ /^[[:space:]]*\[data\][[:space:]]*$/)
      print
      next
    }
    in_data && !done && /^[[:space:]]*profile[[:space:]]*=/ { print "profile = \"minimal\""; done = 1; next }
    { print }
    END {
      if (in_data && !done) { print "profile = \"minimal\""; done = 1 }
      if (!done) printf "\n[data]\nprofile = \"minimal\"\n"
    }'
}

# Charm apt key, pinned against a swapped gpg.key: primary fingerprint read from
# https://repo.charm.sh/apt/gpg.key on 2026-10-08 (the old C026D31B... pin
# matched no served key). If Charm rotates, update it and note it in CHANGELOG.md.
CHARM_GPG_EXPECTED_FPR="ED927B38BE981E53CA09153D03BBF595D4DFD35C" # pragma: allowlist secret

# charm_keyring_verify <keyring>: apt trusts every primary key in a signed-by
# file, so it must hold exactly the pinned one; else remove it and return 1.
charm_keyring_verify() {
  local keyring="$1" keys pub_count primary_fpr
  keys="$(gpg --no-default-keyring --keyring "$keyring" \
    --with-colons --list-keys 2>/dev/null || true)"
  pub_count="$(grep -c '^pub:' <<<"$keys" || true)"
  primary_fpr="$(awk -F: '/^pub:/ { pub = 1; next } pub && /^fpr:/ { print $10; exit }' <<<"$keys")"
  if [[ "$pub_count" == 1 && "$primary_fpr" == "$CHARM_GPG_EXPECTED_FPR" ]]; then
    return 0
  fi
  echo "Error: Charm keyring must hold only $CHARM_GPG_EXPECTED_FPR (found ${pub_count:-0} key(s), first ${primary_fpr:-none})" >&2
  sudo rm -f "$keyring"
  return 1
}

# chezmoi_release_sha256 <asset>: reviewed SHA-256 (else $CHEZMOI_SHA256), in step
# with tools/ci/install-chezmoi-verified.sh; from the v0.2.547 checksums.txt.
chezmoi_release_sha256() {
  local sha
  case "$1" in
    chezmoi_2.74.1_linux_amd64.tar.gz) sha=ae01c66b1a6dbf563667c63fbbd9986b3cfa3c98dd266ddee732f63e8af2e9d1 ;;
    chezmoi_2.74.1_linux_arm64.tar.gz) sha=8c62619c4303770342e7c7e75d168b6cc6efee4ad5e4b994980de7cf794d68e2 ;;
    chezmoi_2.74.1_darwin_amd64.tar.gz) sha=b2229c6ff9eb7d1f10d098aac94241da652dd7df989c7ef35df6777dbe00d397 ;;
    chezmoi_2.74.1_darwin_arm64.tar.gz) sha=fbc7b86c7b36eb0448e2a99a616b6d32f022d1f3895076ad44f4c5d65a77fe60 ;;
    *) sha="${CHEZMOI_SHA256:-}" ;;
  esac
  if [[ "$sha" =~ ^[0-9a-f]{64}$ ]]; then
    echo "$sha"
    return 0
  fi
  echo "No pinned SHA-256 for $1; export CHEZMOI_SHA256 after reviewing the release" >&2
  return 1
}

# chezmoi_checksums_agree <file> <asset> <pin>: the release's checksums are only a
# cross-check (a replaced release matches its own), but a mismatch stops us.
chezmoi_checksums_agree() {
  local published
  published="$(awk -v f="$2" '$2 == f { print $1; exit }' "$1")"
  [[ -z "$published" || "$published" == "$3" ]] && return 0
  echo "Release checksums file disagrees with the pinned SHA-256 for $2" >&2
  return 1
}

# Print macos, wsl2, debian, fedora, arch, linux or unknown. $1: fixture root.
detect_target_os() {
  local root="${1:-}" os="linux"
  case "$(uname -s)" in
    Darwin) os="macos" ;;
    Linux) # Later checks win: wsl2 > debian > fedora > arch > linux.
      [ -f "$root/etc/arch-release" ] && os="arch"
      [ -f "$root/etc/fedora-release" ] && os="fedora"
      [ -f "$root/etc/debian_version" ] && os="debian"
      grep -qi microsoft "$root/proc/version" 2>/dev/null && os="wsl2"
      ;;
    *) os="unknown" ;;
  esac
  echo "$os"
}

# Succeed in a devcontainer, Codespace or Docker container. $1: a fixture root.
detect_container_env() {
  [[ -f "${1:-}/.dockerenv" || -n "${CODESPACES:-}" || -n "${REMOTE_CONTAINERS:-}" ]]
}

# apply_source <want_minimal>: apply the configured source, after seeding
# the git identity and, when asked (1), the minimal profile overrides.
apply_source() {
  local -a flags=()
  seed_git_identity
  if [[ "$1" -eq 1 ]]; then
    step "Applying minimal profile overrides..."
    apply_minimal_profile_overrides
  fi
  [[ "${DOTFILES_NONINTERACTIVE:-0}" != "1" ]] || flags=(--force --no-tty)
  chezmoi apply ${flags[@]+"${flags[@]}"}
}

# _backup_one <path>: copy an existing file or symlink to BACKUP_DIR under
# its path relative to $HOME; false when there is nothing to copy. Real
# directories are skipped: apply never clobbers their contents, their files
# are backed up one by one, and `cp -a` would hit uncopyable things such as
# ssh-agent sockets ("is a socket (not copied)").
_backup_one() {
  local rel="${1#"$HOME"/}"
  [[ -n "$1" && -e "$1" ]] || return 1
  [[ ! -d "$1" || -L "$1" ]] || return 1
  mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
  cp -a "$1" "$BACKUP_DIR/$rel"
}

# backup_managed_files: copy every existing file chezmoi manages (and so
# would overwrite) to BACKUP_DIR, keeping its path under $HOME. Until
# chezmoi has a config there is nothing to compare against; a second run
# copies the same files over their first copies.
backup_managed_files() {
  local file count=0
  command -v chezmoi >/dev/null && [[ -f "$CHEZMOI_CONFIG_FILE" ]] || {
    echo "   No chezmoi source yet: the backup runs once the source is in place."
    return 0
  }
  while IFS= read -r file; do
    if _backup_one "$file"; then count=$((count + 1)); fi
  done < <(chezmoi managed --path-style=absolute 2>/dev/null || true)
  if [[ "$count" -gt 0 ]]; then
    echo "   Backed up $count files to $BACKUP_DIR"
  else
    echo "   No existing dotfiles to back up."
    rm -rf "$BACKUP_DIR" 2>/dev/null || true
  fi
}

# run_migration SCRIPT WARNING [NOTICE]: run the first checkout's install/migrate/SCRIPT.
run_migration() {
  local src script
  for src in "$SOURCE_DIR" "$LEGACY_SOURCE_DIR"; do
    script="$src/install/migrate/$1"
    [[ -f "$script" ]] || continue
    [[ -z "${3:-}" ]] || echo "   $3"
    bash "$script" || echo "   $2"
    return 0
  done
}

show_help() {
  cat <<EOF
Usage: install.sh [version] [options]

Arguments:
  version       The version (tag or branch) to install (default: v0.2.547)

Options:
  --help        Show this help message
  --force       Non-interactive mode (sets DOTFILES_NONINTERACTIVE=1)
  --silent      Quiet mode (sets DOTFILES_SILENT=1)
  --minimal     Select the minimal profile (written to this host's chezmoi config)
  --provision   After applying configs, install the toolchain (packages,
                fonts, language tools) via the install/provision scripts.
                Also enabled by DOTFILES_PROVISION=1. Opt-in because it
                installs packages and may change OS defaults. Runs only the
                scripts changed since their last successful run.
  --all         With --provision, run every provisioning script.

EOF
}

# Bootstrap gum for a better UI if available or install it
bootstrap_gum() {
  if command -v gum >/dev/null 2>&1; then return 0; fi
  if [[ "${DOTFILES_SILENT:-0}" == "1" ]]; then return 0; fi

  echo "   Bootstrapping UI components (gum)..."
  if [[ "$OS" == "Darwin" ]] && command -v brew >/dev/null; then
    brew install gum >/dev/null 2>&1
  elif [[ "$target_os" == "debian" || "$target_os" == "wsl2" ]]; then
    sudo mkdir -p /etc/apt/keyrings
    charm_key_tmp="$(mktemp -t charm-key.XXXXXX)"
    if ! curl --proto '=https' --tlsv1.2 -fsSL \
      -o "$charm_key_tmp" https://repo.charm.sh/apt/gpg.key; then
      rm -f "$charm_key_tmp"
      return 1
    fi
    sudo gpg --batch --yes --dearmor \
      -o /etc/apt/keyrings/charm.gpg "$charm_key_tmp"
    rm -f "$charm_key_tmp"
    charm_keyring_verify /etc/apt/keyrings/charm.gpg || return 1
    echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | sudo tee /etc/apt/sources.list.d/charm.list
    sudo apt-get update && sudo apt-get install gum -y >/dev/null 2>&1
  fi
}

# chezmoi_platform: print the release's <os>_<arch> for this machine, or
# fail with the reason.
chezmoi_platform() {
  local os arch
  os="$(uname -s | tr '[:upper:]' '[:lower:]')"
  arch="$(uname -m)"
  case "$os" in
    linux | darwin) ;;
    *)
      echo "Unsupported OS for chezmoi bootstrap: $os" >&2
      return 1
      ;;
  esac
  case "$arch" in
    x86_64 | amd64) arch="amd64" ;;
    arm64 | aarch64) arch="arm64" ;;
    *)
      echo "Unsupported architecture for chezmoi bootstrap: $arch" >&2
      return 1
      ;;
  esac
  printf '%s_%s\n' "$os" "$arch"
}

# _chezmoi_fetch_install <dir> <base_url> <asset> <checksums_asset> <pinned>
# <destination>: download <asset> into <dir>, check it against the pinned
# SHA-256 (and the release checksums, when served), install chezmoi.
# `set -e` does not apply here: this runs as an `if !` condition, where bash
# ignores errexit, so every step exits on failure itself; before this, a
# checksum mismatch fell through to the install. A subshell body, so `cd`
# and `exit` stay local.
_chezmoi_fetch_install() (
  temp_dir="$1" base_url="$2" asset="$3" checksums_asset="$4" pinned="$5" destination="$6"
  curl --proto '=https' --tlsv1.2 -fsSL \
    -o "$temp_dir/$asset" "$base_url/$asset" || exit 1
  if curl --proto '=https' --tlsv1.2 -fsSL \
    -o "$temp_dir/checksums.txt" "$base_url/$checksums_asset"; then
    chezmoi_checksums_agree "$temp_dir/checksums.txt" "$asset" "$pinned" || exit 1
  fi
  # cd/mkdir: a failure there fails the checksum check or install below.
  cd "$temp_dir"
  sha_check=(shasum -a 256 -c -)
  command -v sha256sum >/dev/null 2>&1 && sha_check=(sha256sum -c -)
  printf '%s  %s\n' "$pinned" "$asset" | "${sha_check[@]}" || exit 1
  tar -xzf "$asset" chezmoi || exit 1
  mkdir -p "$destination"
  install -m 755 chezmoi "$destination/chezmoi" || exit 1
)

# Standalone checksum-verified chezmoi bootstrap, kept here so a release-pinned
# install.sh stays self-contained (repo and npm installs use the helper script).
install_chezmoi_verified_embedded() {
  local chezmoi_version="$1" destination="$2"
  local platform asset checksums_asset base_url temp_dir pinned

  platform="$(chezmoi_platform)" || return 1
  asset="chezmoi_${chezmoi_version}_${platform}.tar.gz"
  checksums_asset="chezmoi_${chezmoi_version}_checksums.txt"
  base_url="https://github.com/twpayne/chezmoi/releases/download/v${chezmoi_version}"
  pinned="$(chezmoi_release_sha256 "$asset")" || return 1
  temp_dir="$(umask 077 && mktemp -d)"

  if ! _chezmoi_fetch_install "$temp_dir" "$base_url" "$asset" "$checksums_asset" "$pinned" "$destination"; then
    rm -rf "$temp_dir"
    return 1
  fi

  rm -rf "$temp_dir"
}

# Install chezmoi (run in parallel with the gum bootstrap).
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

    # Only the SHA-256-verified installer; without it, refuse rather than run
    # an unverified script (the old get.chezmoi.io fallback was a hole).
    local verified_installer
    verified_installer="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/tools/ci/install-chezmoi-verified.sh"
    if [[ -x "$verified_installer" ]] || [[ -f "$verified_installer" ]]; then
      echo "   Using checksum-verified installer..."
      if ! bash "$verified_installer" "${CHEZMOI_VERSION:-2.74.1}" "$bin_dir"; then
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
    echo "   Using embedded checksum verifier..."
    if ! install_chezmoi_verified_embedded "${CHEZMOI_VERSION:-2.74.1}" "$bin_dir"; then
      echo "" >&2
      echo "   The embedded checksum-verified chezmoi bootstrap failed." >&2
      echo "   Refusing to fall back to an unverified remote script." >&2
      echo "   Install chezmoi manually from https://www.chezmoi.io/install/" >&2
      return 1
    fi
    return 0
  fi
}

# _toml_line <key> <value>: `key = "value"`; nothing for an empty value.
_toml_line() {
  [[ -z "$2" ]] || printf '%s = "%s"\n' "$1" "$(toml_escape "$2")"
}

# Seed git name/email/signingkey from `git config --global` into chezmoi data:
# sourceDir setup skips chezmoi init's prompts, and an empty identity would
# yield a ~/.gitconfig with no [user] ("Author identity unknown"). Idempotent.
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
    _toml_line name "$gname"
    _toml_line email "$gemail"
    _toml_line signingkey "$gkey"
  } >>"$cfg"
  echo "   Seeded git identity ($gname <$gemail>) into chezmoi data."
}

# parse_install_args "$@": sets the caller's version, version_set, minimal,
# provision and provision_all (main's locals, by bash's dynamic scope).
parse_install_args() {
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
      --all) provision=1 provision_all=1 ;;
      -*)
        # Catch single-dash and double-dash unknowns the same way.
        error "Unknown option: $arg"
        ;;
      *) set_version_arg "$arg" ;;
    esac
  done
}

# set_version_arg <arg>: the positional version, once. Validate it looks
# like a semver (with or without leading v): reject garbage early so an
# unknown positional like `foobar` doesn't trigger a 30s+ network download
# attempt. Caught by the install.sh fuzz harness (#881).
set_version_arg() {
  if [[ $version_set -eq 1 ]]; then
    error "Multiple versions specified: $version and $1"
  fi
  if [[ ! "$1" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+([-+][a-zA-Z0-9.-]+)?$ ]]; then
    error "Unrecognized positional argument '$1' — expected a semver version (e.g. v0.2.547)."
  fi
  version="$1"
  version_set=1
}

# Release tags are signed with these SSH keys: the key lines of KEYS.asc
# (git allowed_signers format). They are embedded so the trust root comes
# with this installer, not with the clone it is verifying: a tampered clone
# would carry a matching KEYS.asc. test_install_verify_tag.sh keeps the two
# equal.
DOTFILES_ALLOWED_SIGNERS='sebastienrousseau@users.noreply.github.com namespaces="git" ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDjGRQyeM79nAb4GHcpGzXMKq7HE3xyEOev4gVsnBN1e sebastienrousseau@users.noreply.github.com
sebastienrousseau@users.noreply.github.com namespaces="git" ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII32YuD6LxBOeFb5kG4Fqbm62kn9OkcHNPJtktO8iYVF sebastienrousseau@users.noreply.github.com
sebastienrousseau@users.noreply.github.com namespaces="git" ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDpyzi+T8b2k/LF5b5F4LpczG41nhKAa+DksbII8NDEq sebastienrousseau@users.noreply.github.com'

# verify_release_tag <repo_dir> <tag> [allowed_signers]: succeed only when
# <tag> carries a good signature from an allowed signer (default: the
# embedded list) and the checkout is exactly the tagged commit.
verify_release_tag() {
  local dir="$1" tag="$2" signers_text="${3:-$DOTFILES_ALLOWED_SIGNERS}"
  local signers rc=0 head want
  signers="$(umask 077 && mktemp)"
  printf '%s\n' "$signers_text" >"$signers"
  (cd "$dir" && git -c gpg.ssh.allowedSignersFile="$signers" verify-tag "$tag") >/dev/null 2>&1 || rc=1
  rm -f "$signers"
  [[ $rc -eq 0 ]] || return 1
  head="$(cd "$dir" && git rev-parse HEAD)" || return 1
  want="$(cd "$dir" && git rev-parse "$tag^{commit}")" || return 1
  [[ -n "$head" && "$head" == "$want" ]]
}

# clone_verified_source <tag> <dest>: clone <tag> beside <dest>, verify its
# signature, then move it into place. Fails closed: an unverified clone is
# deleted, so a re-run can never apply it as an existing local source.
clone_verified_source() {
  local tag="$1" dest="$2" url="https://github.com/sebastienrousseau/dotfiles.git" tmp
  mkdir -p "$(dirname "$dest")"
  tmp="$(mktemp -d "${dest%/}.clone.XXXXXX")"
  if ! git clone --depth 1 --branch "$tag" "$url" "$tmp/src" 2>/dev/null; then
    rm -rf "$tmp/src"
    if ! { git clone "$url" "$tmp/src" && (cd "$tmp/src" && git checkout "$tag"); }; then
      rm -rf "$tmp"
      error "Could not clone release $tag."
    fi
  fi
  if ! verify_release_tag "$tmp/src" "$tag"; then
    rm -rf "$tmp"
    error "Release $tag failed signature verification against the KEYS.asc signers embedded in install.sh, or HEAD is not the tagged commit (verification needs git >= 2.34 and ssh-keygen). Nothing was installed."
  fi
  rmdir "$dest" 2>/dev/null || true
  if [[ -e "$dest" ]]; then
    rm -rf "$tmp"
    error "$dest exists and is not empty; move it aside and re-run."
  fi
  mv "$tmp/src" "$dest"
  rm -rf "$tmp"
  echo "   Verified the signed release tag $tag."
}

# deploy_source <want_minimal>: apply from the local source, the legacy
# location, or a fresh, signature-verified clone of release $VERSION.
deploy_source() {
  local tag
  if [[ -d "$SOURCE_DIR/.git" ]]; then
    echo "   Applying from local source: $SOURCE_DIR"
  elif [[ -d "$LEGACY_SOURCE_DIR/.git" ]]; then
    echo "   Migrating from legacy source: $LEGACY_SOURCE_DIR"
    mv "$LEGACY_SOURCE_DIR" "$SOURCE_DIR"
  else
    tag="v${VERSION#v}"
    echo "   Initializing from GitHub (tag: $tag)..."
    printf '%b\n' "${CYAN}   SECURITY NOTE: Cloning the signed release $tag for supply-chain safety${NC}"
    clone_verified_source "$tag" "$SOURCE_DIR"
    ensure_chezmoi_source "$SOURCE_DIR"
    # The first install's backup: until now chezmoi had no source, so the
    # backup above found nothing, and apply would overwrite these files.
    backup_managed_files
  fi
  ensure_chezmoi_source "$SOURCE_DIR"
  apply_source "$1"
}

# provision_toolchain <provision> <want_minimal> [all]: provisioning is opt-in
# (--provision or DOTFILES_PROVISION=1): install/provision/ sits outside
# .chezmoiroot, so apply never runs it, and it installs packages and may
# change OS defaults, so it is never implicit. The minimal profile
# (--minimal, DOTFILES_MINIMAL=1 or a container) skips it. Only scripts
# changed since their last successful run are run, unless [all] is set.
provision_toolchain() {
  [[ "$2" -eq 0 ]] || return 0
  if [[ "$1" = "1" ]]; then
    step "Provisioning toolchain (packages, fonts, tools)..."
    # shellcheck source=install/lib/provision.sh
    source "$SOURCE_DIR/install/lib/provision.sh"
    run_provision "$SOURCE_DIR" ${3:+--all} ||
      error "Provisioning failed (above). Fix it, then re-run: bash \"$SOURCE_DIR/install.sh\" --provision"
  else
    step "Configs deployed. To also install the toolchain (packages, fonts, tools):"
    echo "   bash \"$SOURCE_DIR/install.sh\" --provision    # or DOTFILES_PROVISION=1"
    echo "   (or: brew bundle --file ~/.config/shell/Brewfile.cli)"
  fi
}

# print_identity_hint: with no git identity configured, commits fail with
# "Author identity unknown". Point the user at the one-line fix rather than
# letting them discover it on their first commit.
print_identity_hint() {
  if [[ -z "$(git config --global user.email 2>/dev/null || true)" ]] &&
    ! grep -q '^email' "$CHEZMOI_CONFIG_FILE" 2>/dev/null; then
    step "No git identity detected. Set yours so commits are attributed:"
    echo "   git config --global user.name  \"Your Name\""
    echo "   git config --global user.email \"you@example.com\""
    echo "   then re-run: chezmoi apply"
  fi
}

# bootstrap_tools: gum (optional) and chezmoi (required), in parallel.
bootstrap_tools() {
  local pid_gum pid_cm
  (bootstrap_gum) &
  pid_gum=$!
  (install_chezmoi) &
  pid_cm=$!
  wait "$pid_gum" || true # gum is optional
  wait "$pid_cm" || error "chezmoi installation failed"
  # Critical: add to PATH for the rest of the script to see it.
  bin_dir="$HOME/.local/bin"
  export PATH="$bin_dir:$PATH"
}

# backup_existing: point chezmoi at an existing source (if any) and back up
# what it would overwrite. On a first install there is no source yet, so
# nothing is listed here: deploy_source backs up again after the clone.
backup_existing() {
  step "Backing up existing dotfiles..."
  BACKUP_DIR="$HOME/.dotfiles.bak.$(date +"%Y%m%d_%H%M%S")"
  if [[ -d "$SOURCE_DIR/.git" ]]; then
    ensure_chezmoi_source "$SOURCE_DIR"
  elif [[ -d "$LEGACY_SOURCE_DIR/.git" ]]; then
    ensure_chezmoi_source "$LEGACY_SOURCE_DIR"
  fi
  backup_managed_files
}

main() {
  local version="v0.2.547"
  local version_set=0
  local minimal=0
  local provision="${DOTFILES_PROVISION:-0}" provision_all=""
  local _cleanup_files=()
  trap 'set +u; rm -f "${_cleanup_files[@]}" 2>/dev/null; set -u' EXIT
  parse_install_args "$@"

  # 2. Check Prerequisites & Bootstrap Package Managers
  step "Checking Prerequisites..."
  OS="$(uname -s)"
  target_os="$(detect_target_os "")" # "": the real filesystem root
  bootstrap_tools

  # 4. Prepare source directory (VERSION pinning for supply-chain security)
  step "Preparing source directory..."
  VERSION="$version"

  # 5. Backup existing dotfiles that chezmoi will overwrite
  backup_existing

  # Detect devcontainer/Codespaces environment
  if detect_container_env ""; then
    DOTFILES_MINIMAL=1
    step "Detected container environment — using minimal profile"
  fi
  # --minimal (or a container) selects the minimal profile. It is written
  # to the per-host chezmoi config after the source dir is configured and
  # the git identity is seeded, so the tracked source stays clean.
  local want_minimal=0
  if [[ $minimal -eq 1 ]] || [[ "${DOTFILES_MINIMAL:-0}" = "1" ]]; then
    want_minimal=1
  fi

  # 6. Initialize & Apply
  step "Applying Configuration..."
  # Auto-migration for the 0.2.503 reorg, then the state move (N12), before
  # apply, so the reorg's source-path moves don't delete deployed files.
  run_migration migrate-v0_2-to-v0_2_503.sh "migration exited non-zero — continuing apply" \
    "Running the 0.2.503 layout migration (idempotent; safe on fresh installs)..."
  run_migration migrate-state-to-domains.sh "some state stays in the old directory; the next apply tries again"
  deploy_source "$want_minimal"
  provision_toolchain "$provision" "$want_minimal" "$provision_all"

  success "Configuration loaded. Please restart your shell."
  print_identity_hint
  step "Run 'dot help tour' for an interactive tour of your new dotfiles."
}

# Run main if executed directly (or via bash -c where BASH_SOURCE is unset)
if [[ "${BASH_SOURCE[0]:-}" == "${0:-}" ]] || [[ -z "${BASH_SOURCE[0]:-}" ]]; then
  main "$@"
fi

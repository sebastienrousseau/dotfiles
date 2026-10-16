# SPDX-FileCopyrightText: 2026 Sebastien Rousseau
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Standards integrity sentinel - checks master standards for drift

: "${DOTFILES_STANDARDS_CHECK:=1}"

# standards-sync is a Python process (~50ms, a third of zsh startup), so a
# passing check is reused for a day. Drift leaves the stamp untouched: the
# warning repeats in every new shell until the standards are back in sync.
() {
  [[ "$DOTFILES_STANDARDS_CHECK" == "1" ]] || return 0
  command -v standards-sync >/dev/null 2>&1 || return 0
  local stamp="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles/standards-check.stamp"
  local -a fresh=($stamp(N.mh-24))
  (( $#fresh )) && return 0
  standards-sync --check --quiet || return 0
  mkdir -p "${stamp:h}" && : >|"$stamp"
}

# SPDX-FileCopyrightText: 2026 Sebastien Rousseau
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Standards integrity sentinel - checks master standards for drift

: "${DOTFILES_STANDARDS_CHECK:=1}"

if [[ "$DOTFILES_STANDARDS_CHECK" == "1" ]] && command -v standards-sync >/dev/null 2>&1; then
  standards-sync --check --quiet
fi

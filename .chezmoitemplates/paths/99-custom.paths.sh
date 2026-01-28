# shellcheck shell=bash

# macOS-specific paths
if [[ "$OSTYPE" == darwin* ]]; then
  # Add Apple binaries and TeX Live to PATH
  export PATH="/Library/Apple/usr/bin:/Library/TeX/texbin:${PATH}"

  # Application-specific paths (only if they exist)
  [[ -d "/Applications/Topaz Photo AI.app" ]] && export PATH="/Applications/Topaz Photo AI.app/Contents/Resources/bin:${PATH}"
  [[ -d "/Applications/Little Snitch.app" ]] && export PATH="/Applications/Little Snitch.app/Contents/Components:${PATH}"
  [[ -d "/Applications/iTerm.app" ]] && export PATH="/Applications/iTerm.app/Contents/Resources/utilities:${PATH}"
fi

# Cross-platform paths (user-local)
# Add Cargo binaries to PATH (check version with: cargo --version)
[[ -d "${HOME}/.cargo/bin" ]] && export PATH="${HOME}/.cargo/bin:${PATH}"

# Add Go binaries to PATH (check version with: go version)
[[ -d "${HOME}/go/bin" ]] && export PATH="${HOME}/go/bin:${PATH}"

# Add Node.js global modules binaries to PATH (check version with: node --version)
[[ -d "${HOME}/.node_modules/bin" ]] && export PATH="${HOME}/.node_modules/bin:${PATH}"

# Deduplicate PATH entries (single pass)
PATH=$(echo "$PATH" | awk -v RS=':' '!seen[$0]++ {ORS=(NR>1?":":"")} {print}')
export PATH

# shellcheck shell=bash
# Add Apple binaries and TeX Live to PATH
export PATH="/Library/Apple/usr/bin:/Library/TeX/texbin:${PATH}"

# Add Cargo binaries to PATH (check version with: cargo --version)
export PATH="${HOME}/.cargo/bin:${PATH}"

# Add Go binaries to PATH (check version with: go version)
export PATH="${HOME}/go/bin:${PATH}"

# Add Node.js global modules binaries to PATH (check version with: node --version)
export PATH="${HOME}/.node_modules/bin:${PATH}"

# Application-specific paths
export PATH="/Applications/Topaz\ Photo\ AI.app/Contents/Resources/bin:/Applications/Little\ Snitch.app/Contents/Components:/Applications/iTerm.app/Contents/Resources/utilities:${PATH}"

# Deduplicate PATH entries
deduplicate_path() {
  PATH=$(echo "$PATH" | awk -v RS=':' '!seen[$0]++ {ORS=(NR>1?":":"")} {print}')
  export PATH
}

# Call the deduplication function
PATH=$(echo "$PATH" | awk -v RS=':' '!seen[$0]++ {ORS=(NR>1?":":"")} {print}')
export PATH

deduplicate_path

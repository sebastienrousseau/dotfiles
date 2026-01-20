# Pipx Configuration
# Explicitly set home and bin dirs to avoid "spaces in path" warnings and ensure XDG compliance
export PIPX_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/pipx"
export PIPX_BIN_DIR="${XDG_BIN_HOME:-$HOME/.local/bin}"

# Ensure pipx bin is in PATH (if not already)
if [[ ":$PATH:" != *":$PIPX_BIN_DIR:"* ]]; then
    export PATH="${PIPX_BIN_DIR}:${PATH}"
fi

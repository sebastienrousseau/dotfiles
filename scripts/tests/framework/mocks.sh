#!/usr/bin/env bash
# shellcheck disable=SC2034
# Mock utilities for shell testing
# Provides functions to create mock commands, files, and directories

# Track created mocks for cleanup
MOCK_COMMANDS=()
MOCK_FILES=()
MOCK_DIRS=()
ORIGINAL_PATH="$PATH"
MOCK_BIN_DIR=""

# Initialize mock environment
mock_init() {
  MOCK_BIN_DIR=$(mktemp -d)
  export PATH="$MOCK_BIN_DIR:$PATH"
  MOCK_COMMANDS=()
  MOCK_FILES=()
  MOCK_DIRS=()
}

# Create a mock command
# Usage: mock_command "command_name" "output" [exit_code]
mock_command() {
  local cmd_name="$1"
  local output="$2"
  local exit_code="${3:-0}"

  if [[ -z "$MOCK_BIN_DIR" ]]; then
    mock_init
  fi

  local mock_script="$MOCK_BIN_DIR/$cmd_name"
  cat >"$mock_script" <<EOF
#!/usr/bin/env bash
echo "$output"
exit $exit_code
EOF
  chmod +x "$mock_script"
  MOCK_COMMANDS+=("$mock_script")
}

# Create a mock command that records arguments
# Usage: mock_command_spy "command_name" [output] [exit_code]
mock_command_spy() {
  local cmd_name="$1"
  local output="${2:-}"
  local exit_code="${3:-0}"

  if [[ -z "$MOCK_BIN_DIR" ]]; then
    mock_init
  fi

  local mock_script="$MOCK_BIN_DIR/$cmd_name"
  local spy_file="$MOCK_BIN_DIR/${cmd_name}.spy"

  cat >"$mock_script" <<EOF
#!/usr/bin/env bash
echo "\$@" >> "$spy_file"
echo "$output"
exit $exit_code
EOF
  chmod +x "$mock_script"
  touch "$spy_file"
  MOCK_COMMANDS+=("$mock_script")
  MOCK_FILES+=("$spy_file")
}

# Get spy call history
# Usage: mock_get_calls "command_name"
mock_get_calls() {
  local cmd_name="$1"
  local spy_file="$MOCK_BIN_DIR/${cmd_name}.spy"
  if [[ -f "$spy_file" ]]; then
    cat "$spy_file"
  fi
}

# Get spy call count
# Usage: mock_call_count "command_name"
mock_call_count() {
  local cmd_name="$1"
  local spy_file="$MOCK_BIN_DIR/${cmd_name}.spy"
  if [[ -f "$spy_file" ]]; then
    wc -l <"$spy_file" | tr -d ' '
  else
    echo "0"
  fi
}

# Create a temporary file with content
# Usage: mock_file "content" [filename]
mock_file() {
  local content="$1"
  local filename="${2:-}"
  local file

  if [[ -n "$filename" ]]; then
    file=$(mktemp -t "$filename.XXXXXX")
  else
    file=$(mktemp)
  fi

  echo "$content" >"$file"
  MOCK_FILES+=("$file")
  echo "$file"
}

# Create a temporary directory
# Usage: mock_dir [prefix]
mock_dir() {
  local prefix="${1:-mock}"
  local dir
  dir=$(mktemp -d -t "${prefix}.XXXXXX")
  MOCK_DIRS+=("$dir")
  echo "$dir"
}

# Create a mock archive file
# Usage: mock_archive "type" [content_file]
mock_archive() {
  local type="$1"
  local content="${2:-test content}"
  local temp_dir
  temp_dir=$(mktemp -d)
  local temp_file="$temp_dir/test_file.txt"
  local archive

  echo "$content" >"$temp_file"

  case "$type" in
    tar)
      archive=$(mktemp -t archive.XXXXXX.tar)
      tar cf "$archive" -C "$temp_dir" test_file.txt
      ;;
    tar.gz | tgz)
      archive=$(mktemp -t archive.XXXXXX.tar.gz)
      tar czf "$archive" -C "$temp_dir" test_file.txt
      ;;
    zip)
      archive=$(mktemp -t archive.XXXXXX.zip)
      (cd "$temp_dir" && zip -q "$archive" test_file.txt)
      ;;
    gz)
      archive=$(mktemp -t archive.XXXXXX.gz)
      gzip -c "$temp_file" >"$archive"
      ;;
    *)
      echo "Unsupported archive type: $type" >&2
      rm -rf "$temp_dir"
      return 1
      ;;
  esac

  rm -rf "$temp_dir"
  MOCK_FILES+=("$archive")
  echo "$archive"
}

# Restore original environment variable
# Usage: mock_env "VAR_NAME" "value"
mock_env() {
  local var_name="$1"
  local value="$2"
  export "$var_name=$value"
}

# Clean up all mocks
mock_cleanup() {
  # Restore PATH
  export PATH="$ORIGINAL_PATH"

  # Remove mock commands
  for cmd in "${MOCK_COMMANDS[@]}"; do
    rm -f "$cmd" 2>/dev/null
  done

  # Remove mock files
  for file in "${MOCK_FILES[@]}"; do
    rm -f "$file" 2>/dev/null
  done

  # Remove mock directories
  for dir in "${MOCK_DIRS[@]}"; do
    rm -rf "$dir" 2>/dev/null
  done

  # Remove mock bin directory
  if [[ -n "$MOCK_BIN_DIR" && -d "$MOCK_BIN_DIR" ]]; then
    rm -rf "$MOCK_BIN_DIR"
  fi

  MOCK_BIN_DIR=""
  MOCK_COMMANDS=()
  MOCK_FILES=()
  MOCK_DIRS=()
}

# Setup trap to cleanup on exit
trap mock_cleanup EXIT

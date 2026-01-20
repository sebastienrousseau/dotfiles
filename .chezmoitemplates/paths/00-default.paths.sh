export PATH=/usr/bin:"${PATH}"
export PATH=/bin:"${PATH}"
export PATH=/sbin:"${PATH}"

# Homebrew paths
export PATH=/opt/homebrew/bin:"${PATH}"
export PATH=/opt/homebrew/sbin:"${PATH}"

# Ruby paths

# Add Ruby homebrew binaries to PATH (check version with: ruby --version)
if command -v /opt/homebrew/opt/ruby/bin/ruby >/dev/null; then
    export PATH="/opt/homebrew/opt/ruby/bin/:${PATH}"
elif command -v /usr/bin/ruby >/dev/null; then
    export PATH="/usr/bin/:${PATH}"
fi

# Add Ruby gem binaries to PATH (check version with: gem --version)
export PATH="${HOME}/.gem/ruby/bin:${PATH}"





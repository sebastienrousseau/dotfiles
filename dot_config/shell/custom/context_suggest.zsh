# shellcheck shell=bash
# zsh_context_suggest.zsh
#
# Context Autosuggest for Predictive Shell
# Detects project type and suggests commands.
#

suggest_context_commands() {
    local suggestions=()
    
    # 1. Node.js / Javascript / TypeScript
    if [[ -f "package.json" ]]; then
        suggestions+=("npm start" "npm test" "npm run build")
        # Check for yarn
        if [[ -f "yarn.lock" ]]; then
            suggestions+=("yarn start" "yarn test" "yarn build")
        fi
        # Check for pnpm
        if [[ -f "pnpm-lock.yaml" ]]; then
             suggestions+=("pnpm start" "pnpm test")
        fi
    fi
    
    # 2. Rust
    if [[ -f "Cargo.toml" ]]; then
        suggestions+=("cargo run" "cargo test" "cargo build" "cargo check")
    fi
    
    # 3. Go
    if [[ -f "go.mod" ]]; then
        suggestions+=("go run ." "go test ./..." "go build")
    fi
    
    # 4. Python
    if [[ -f "pyproject.toml" ]] || [[ -f "requirements.txt" ]]; then
        suggestions+=("python -m venv .venv" "source .venv/bin/activate")
        if [[ -f "main.py" ]]; then
            suggestions+=("python main.py")
        fi
        if [[ -f "app.py" ]]; then
            suggestions+=("python app.py")
        fi
    fi
    
    # 5. Docker
    if [[ -f "Dockerfile" ]]; then
        suggestions+=("docker build -t . ." "docker run -it <image>")
    fi
    if [[ -f "docker-compose.yml" ]] || [[ -f "compose.yaml" ]]; then
        suggestions+=("docker compose up -d" "docker compose down")
    fi
    
    # Display suggestions
    if [[ ${#suggestions[@]} -gt 0 ]]; then
        print -P "%F{cyan} Context Suggestions:%f"
        for cmd in "${suggestions[@]}"; do
            print -P "  %F{green}%f $cmd"
        done
    else
        echo "No context-specific suggestions found for this directory."
    fi
}

# Alias for manual invocation
alias suggest="suggest_context_commands"
    
# Optional: Hook into chpwd to show suggestions on cd (commented out by default to avoid noise)
# add-zsh-hook chpwd suggest_context_commands

#!/usr/bin/env bash

################################################################################
# Shell Startup Performance Analysis
# Analyzes what's taking time during shell initialization
################################################################################

echo "=== SHELL STARTUP PERFORMANCE ANALYSIS ==="
echo ""
echo "System Info:"
uname -a
echo ""

# Function to measure startup time
measure_startup() {
    local shell="$1"
    local name="$2"
    
    echo "Testing $name..."
    
    # Run multiple times to get average (first run warms cache)
    local total=0
    local runs=3
    
    for i in $(seq 1 $runs); do
        local result=$( { time $shell -i -c 'exit' 2>&1; } 2>&1 | grep real | awk '{print $2}' )
        echo "  Run $i: $result"
    done
    
    echo ""
}

# Test Bash startup
measure_startup "bash" "Bash"

# Test Zsh startup  
measure_startup "zsh" "Zsh"

echo "=== ANALYZING DOTFILES DIRECTORY ==="
echo ""

echo "Total number of dotfiles being sourced:"
find ~/.dotfiles/lib -name "*.sh" -type f | wc -l

echo ""
echo "Size of dotfiles:"
du -sh ~/.dotfiles/lib

echo ""
echo "Files by size:"
find ~/.dotfiles/lib -name "*.sh" -type f -exec wc -l {} + | sort -rn | head -15

echo ""
echo "=== BASHRC ANALYSIS ==="
echo ""
echo "Bashrc size: $(wc -l < ~/.bashrc) lines"
echo ""
echo "Major operations in bashrc:"
grep -E "^(configure_|load_|check_)" ~/.bashrc | head -10

echo ""
echo "=== OPTIMIZATION CANDIDATES ==="
echo ""

# Check for expensive operations
echo "Command substitutions in bashrc:"
grep -c '\$(' ~/.bashrc

echo ""
echo "External command calls in bashrc:"
grep -E '^\s+(command|which|type|stat|date)' ~/.bashrc | wc -l

echo ""
echo "=== RECOMMENDATIONS ==="
echo ""
echo "1. Profile with DEBUG flag: DOTFILES_VERBOSE=3 bash -i -c 'exit'"
echo "2. Check what modules are loaded in ~/.dotfiles/lib"
echo "3. Identify unused modules and remove from sourcing"
echo "4. Consider lazy loading for:
    - NVM (node version manager)
    - pyenv (Python version manager)
    - rbenv (Ruby version manager)
    - fzf (fuzzy finder)
5. Cache expensive operations (hostname, whoami, uname)"

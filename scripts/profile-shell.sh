#!/usr/bin/env bash

################################################################################
# Shell Startup Performance Profiler
# Measures time spent in each part of shell initialization
################################################################################

echo "=== SHELL STARTUP PERFORMANCE PROFILING ==="
echo ""

# Function to run profiling with timestamps
profile_shell() {
    local shell_cmd="$1"
    local shell_name="$2"
    
    echo ">>> $shell_name Startup Profile"
    echo ""
    
    # Method 1: Simple startup time
    local start_time end_time elapsed
    start_time=$(date +%s%N)
    eval "$shell_cmd -i -c 'exit' > /dev/null 2>&1"
    end_time=$(date +%s%N)
    elapsed=$(( (end_time - start_time) / 1000000 ))  # Convert nanoseconds to milliseconds
    
    echo "Total startup time: ${elapsed}ms"
    echo ""
}

# Method 1: Time each dotfile being sourced
echo "=== IDENTIFYING SLOW STARTUP FILES ==="
echo ""

profile_shell "bash" "Bash"
profile_shell "zsh" "Zsh"

# Method 2: Profile with detailed dotfile timing
echo "=== DETAILED BASH DOTFILES TIMING ==="
echo ""

# Create a wrapper to measure each file load
bash -c '
    export DOTFILES_VERBOSE=3
    export DOTFILES_LOG_LEVEL=3
    
    # Measure baseline
    start_time=$(date +%s%N)
    
    # Source .bashrc
    source ~/.bashrc 2>&1 | grep -E "(Loading|Configuring|Dotfiles)" | head -20
    
    end_time=$(date +%s%N)
    elapsed=$(( (end_time - start_time) / 1000000 ))
    echo ""
    echo "Dotfiles load time: ${elapsed}ms"
' 2>/dev/null | head -30

echo ""
echo "=== SYSTEM INFORMATION ==="
echo "CPU: $(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo 'N/A')"
echo "Memory: $(vm_stat 2>/dev/null | grep 'Pages free' | awk '{print $3}' | tr -d '.' || echo 'N/A') free pages"
echo ""
echo "=== OPTIMIZATION OPPORTUNITIES ==="
echo ""
echo "1. Lazy loading: Defer NVM, pyenv, rbenv until first use"
echo "2. Caching: Enable dotfiles cache (already configured)"
echo "3. Parallel loading: Source independent modules in parallel"
echo "4. Reduce command substitutions: Cache system information"
echo "5. Remove unused imports: Audit which modules are actually needed"
echo ""

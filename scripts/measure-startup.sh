#!/usr/bin/env bash

################################################################################
# Startup Time Measurement Script
# Measures Bash and Zsh startup times
################################################################################

echo "=== Dotfiles Startup Performance Measurement ==="
echo ""

# Clear Bash cache
echo "Clearing Bash cache..."
rm -f ~/.bash_dotfiles_cache

echo ""
echo "=== Bash Startup Times ==="
echo ""

# Run Bash startup multiple times
for i in 1 2 3; do
    echo -n "Run $i (Bash): "
    /usr/bin/time -p bash -i -c 'exit' 2>&1 | grep real | awk '{print $2}'
done

echo ""
echo "=== Zsh Startup Times ==="
echo ""

# Run Zsh startup multiple times
for i in 1 2 3; do
    echo -n "Run $i (Zsh):  "
    /usr/bin/time -p zsh -i -c 'exit' 2>&1 | grep real | awk '{print $2}'
done

echo ""
echo "=== Interpretation ==="
echo "Run 1: Worst case (no cache)"
echo "Run 2: Cache hit (should be faster)"
echo "Run 3: Sustained performance (all caches warm)"
echo ""
echo "Expected:"
echo "  Bash Run 1: ~1000-1100ms"
echo "  Bash Run 2: ~500-600ms (50% faster due to cache)"
echo "  Bash Run 3: ~500-600ms (consistent)"
echo "  Zsh all runs: ~20-30ms"

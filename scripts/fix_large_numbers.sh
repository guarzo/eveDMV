#!/bin/bash

# Fix large number formatting issues for Credo compliance
# Part of Workstream A - Automated Credo fixes

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "🔢 Fixing large number formatting issues..."

# Find and fix common large number patterns
# Pattern: numbers with 5+ digits without underscores

# Fix patterns like 10000, 20000, 30000, 50000, 100000, etc.
find "$PROJECT_ROOT/lib" -name "*.ex" -type f -exec sed -i \
    -e 's/\b10000\b/10_000/g' \
    -e 's/\b20000\b/20_000/g' \
    -e 's/\b30000\b/30_000/g' \
    -e 's/\b40000\b/40_000/g' \
    -e 's/\b50000\b/50_000/g' \
    -e 's/\b60000\b/60_000/g' \
    -e 's/\b70000\b/70_000/g' \
    -e 's/\b80000\b/80_000/g' \
    -e 's/\b90000\b/90_000/g' \
    -e 's/\b100000\b/100_000/g' \
    -e 's/\b200000\b/200_000/g' \
    -e 's/\b300000\b/300_000/g' \
    -e 's/\b400000\b/400_000/g' \
    -e 's/\b500000\b/500_000/g' \
    -e 's/\b1000000\b/1_000_000/g' \
    -e 's/\b10000000\b/10_000_000/g' \
    -e 's/\b50000000\b/50_000_000/g' \
    -e 's/\b100000000\b/100_000_000/g' \
    -e 's/\b1000000000\b/1_000_000_000/g' \
    -e 's/\b10000000000\b/10_000_000_000/g' \
    -e 's/\b31000000\b/31_000_000/g' \
    -e 's/\b32000000\b/32_000_000/g' \
    -e 's/\b11000\b/11_000/g' \
    -e 's/\b11900\b/11_900/g' \
    -e 's/\b11963\b/11_963/g' \
    -e 's/\b11965\b/11_965/g' \
    -e 's/\b11959\b/11_959/g' \
    -e 's/\b11961\b/11_961/g' \
    -e 's/\b11957\b/11_957/g' \
    -e 's/\b11969\b/11_969/g' \
    -e 's/\b11971\b/11_971/g' \
    -e 's/\b12000\b/12_000/g' \
    -e 's/\b15000\b/15_000/g' \
    -e 's/\b25000\b/25_000/g' \
    -e 's/\b75000\b/75_000/g' \
    -e 's/\b80000\b/80_000/g' \
    -e 's/\b150000\b/150_000/g' \
    {} \;

echo "✅ Large number formatting complete!"
echo "📊 Running Credo to verify progress..."

# Show updated Credo stats for large numbers
mix credo --strict --format=oneline 2>&1 | grep -i "large\|number" | head -5 || echo "No large number issues found!"
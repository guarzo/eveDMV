#!/bin/bash

# Batch fix trailing whitespace in all Elixir files
# Part of Workstream A - Automated Credo fixes

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "🧹 Batch fixing trailing whitespace in all Elixir files..."

# Find all Elixir files and remove trailing whitespace
find "$PROJECT_ROOT/lib" -name "*.ex" -type f -print0 | while IFS= read -r -d '' file; do
    # Check if file has trailing whitespace
    if grep -q '[[:space:]]$' "$file"; then
        # Remove trailing whitespace
        sed -i 's/[[:space:]]*$//' "$file"
        echo "✓ Fixed: $file"
    fi
done

echo "🎯 Batch trailing whitespace cleanup complete!"
echo "📊 Running Credo to verify progress..."

# Show updated Credo stats
mix credo --strict 2>&1 | tail -5
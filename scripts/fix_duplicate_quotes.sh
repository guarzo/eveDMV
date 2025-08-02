#!/bin/bash

# Script to fix duplicate closing quotes in Elixir files

echo "Fixing duplicate closing quotes in Elixir files..."

# Find all files with potential duplicate quotes issue
FILES=$(find /workspace/lib -name "*.ex" -type f | head -100)

FIXED_COUNT=0

for file in $FILES; do
    # Check if file has the pattern of duplicate closing quotes
    if grep -Pzo '"""\n\s*"""\n' "$file" >/dev/null 2>&1; then
        echo "Fixing: $file"
        # Fix the duplicate quotes - remove the duplicate line
        perl -i -0pe 's/"""\n(\s*)"""\n/"""\n/g' "$file"
        ((FIXED_COUNT++))
    fi
done

echo "Fixed $FIXED_COUNT files with duplicate closing quotes"

# Now compile to check if there are more issues
echo "Checking compilation..."
mix compile 2>&1 | grep -E "^(Compiling|error:|warning:)" | head -20
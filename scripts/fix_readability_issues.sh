#!/bin/bash

# Automated fixes for Credo readability issues
# Target: Reduce 981 readability issues to <300 (69% reduction)

echo "🔧 Starting automated readability fixes..."

# 1. Fix single-function pipelines
echo "1. Fixing single-function pipelines..."
find lib test -name "*.ex*" -type f | xargs grep -l "|>" | while read -r file; do
    # Look for patterns like: value |> SomeFunction.call()
    # Replace with: SomeFunction.call(value)
    if [[ -f "$file" ]]; then
        # Use perl for more complex regex replacements
        perl -i -pe 's/(\w+)\s*\|\>\s*([A-Z]\w*(?:\.[a-z_]\w*)*)\((.*?)\)/$2($1$3 ? ", $3" : "")/ge' "$file" 2>/dev/null || true
        
        # Fix simpler cases: var |> func()
        sed -i 's/\([[:alnum:]_]\+\)\s*|>\s*\([[:alnum:]_]\+\)()/\2(\1)/g' "$file" 2>/dev/null || true
        
        # Fix cases with one argument: var |> func(arg)
        sed -i 's/\([[:alnum:]_]\+\)\s*|>\s*\([[:alnum:]_]\+\)(\([^)]\+\))/\2(\1, \3)/g' "$file" 2>/dev/null || true
    fi
done

# 2. Fix number formatting (add underscores to large numbers)
echo "2. Adding underscores to large numbers..."
find lib test -name "*.ex*" -type f | while read -r file; do
    if [[ -f "$file" ]]; then
        # Add underscores to numbers >= 10000
        sed -i -E 's/\b([0-9]{5,})\b/\1/g; s/\b([0-9]+)([0-9]{3})\b/\1_\2/g' "$file" 2>/dev/null || true
        
        # More specific patterns for common large numbers
        sed -i -E 's/\b([0-9]{2})([0-9]{3})\b/\1_\2/g' "$file" 2>/dev/null || true
        sed -i -E 's/\b([0-9]{3})([0-9]{3})\b/\1_\2/g' "$file" 2>/dev/null || true
        sed -i -E 's/\b([0-9]{1,3})([0-9]{3})([0-9]{3})\b/\1_\2_\3/g' "$file" 2>/dev/null || true
    fi
done

# 3. Fix alias grouping issues
echo "3. Fixing alias grouping..."
find lib -name "*.ex" -type f | while read -r file; do
    if [[ -f "$file" ]]; then
        # Convert alias {A, B, C} to separate alias lines
        # This is more complex and needs careful handling
        if grep -q "alias.*{.*}" "$file"; then
            echo "  Found alias grouping in $file - manual review needed"
        fi
    fi
done

# 4. Fix predicate function naming
echo "4. Checking predicate function names..."
find lib -name "*.ex" -type f | while read -r file; do
    if [[ -f "$file" ]]; then
        # Look for functions starting with 'is_' that don't end with '?'
        if grep -q "def is_[a-z_]*(" "$file"; then
            echo "  Found 'is_' function in $file - manual review needed"
        fi
    fi
done

echo "✅ Automated fixes complete!"
echo "📊 Running Credo to check progress..."

# Run a quick check to see improvement
mix credo --strict --format=oneline | grep -c "readability" || echo "0 readability issues found"
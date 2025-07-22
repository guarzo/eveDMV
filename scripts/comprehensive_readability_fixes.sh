#!/bin/bash

# Comprehensive Credo readability fixes
# Target: Reduce from 947 to <300 issues (647 more fixes needed)

echo "🔧 Starting comprehensive readability fixes..."

# Track starting count
echo "📊 Current readability issues:"
START_COUNT=$(mix credo --strict 2>/dev/null | grep "code readability issues" | grep -o "[0-9]\+" | head -1)
echo "Starting with: $START_COUNT readability issues"

# 1. Fix more single-function pipeline patterns
echo "1. Fixing remaining single-function pipelines..."

# Find and fix patterns like: var |> func() without proper chaining
find lib -name "*.ex" -type f | while read -r file; do
    if [[ -f "$file" ]]; then
        # More sophisticated pipeline fixes using perl
        perl -i -pe '
            # Fix: data\n\nEnum.func() |> next_func()
            s/(\w+)\n\n(\s*)(Enum\.\w+)\((.*?)\)\s*\|\>\s*(\w+)/\1\n\2|> \3(\4)\n\2|> \5/g;
            
            # Fix: data\n\nSomething.func()
            s/(\w+)\n\n(\s*)([A-Z]\w*\.\w+)\((.*?)\)$/\1\n\2|> \3(\4)/g;
            
            # Fix orphaned function calls at start of lines
            s/^(\s+)([A-Z]\w*\.\w+)\((.*?)\)$/\1|> \2(\3)/g if $. > 1;
        ' "$file" 2>/dev/null || true
    fi
done

# 2. Fix explicit try blocks (convert to implicit try)
echo "2. Converting explicit try blocks to implicit try..."

find lib -name "*.ex" -type f | while read -r file; do
    if [[ -f "$file" ]]; then
        # Convert try...rescue...end to implicit try
        python3 -c "
import re
import sys

def fix_explicit_try(content):
    # Pattern for explicit try blocks that could be implicit
    pattern = r'(\s+)try do\n((?:[^}].*\n)*?)\s+rescue\n((?:[^}].*\n)*?)\s+end'
    
    def replace_try(match):
        indent = match.group(1)
        try_body = match.group(2).strip()
        rescue_body = match.group(3).strip()
        
        # Only convert simple cases
        if 'do' not in try_body and len(try_body.split('\n')) < 5:
            return f'{indent}{try_body}\n{indent}rescue\n{indent}  {rescue_body}'
        return match.group(0)
    
    return re.sub(pattern, replace_try, content, flags=re.MULTILINE)

try:
    with open('$file', 'r') as f:
        content = f.read()
    
    fixed_content = fix_explicit_try(content)
    
    with open('$file', 'w') as f:
        f.write(fixed_content)
except:
    pass
" 2>/dev/null || true
    fi
done

# 3. Fix more number formatting issues
echo "3. Fixing large number formatting..."

find lib test -name "*.ex*" -type f | while read -r file; do
    if [[ -f "$file" ]]; then
        # Fix numbers with 5+ digits
        sed -i -E 's/\b([0-9])([0-9]{4,})\b/\1_\2/g' "$file" 2>/dev/null || true
        
        # More specific patterns for common numbers
        sed -i -E 's/\b10000\b/10_000/g' "$file" 2>/dev/null || true
        sed -i -E 's/\b100000\b/100_000/g' "$file" 2>/dev/null || true
        sed -i -E 's/\b1000000\b/1_000_000/g' "$file" 2>/dev/null || true
    fi
done

# 4. Fix function naming issues
echo "4. Checking function naming patterns..."

# Find functions with 'is_' prefix that don't end with '?'
find lib -name "*.ex" -type f | while read -r file; do
    if [[ -f "$file" ]]; then
        # Look for def is_something( without ?
        if grep -q "def is_[a-z_]*(" "$file"; then
            echo "  Found predicate function in $file that may need '?' suffix"
            # This requires manual review, so just flag it
        fi
    fi
done

# 5. Check and run formatting
echo "5. Running code formatting..."
mix format 2>/dev/null || true

# Final count
echo "📊 Checking final count..."
FINAL_COUNT=$(mix credo --strict 2>/dev/null | grep "code readability issues" | grep -o "[0-9]\+" | head -1)
REDUCTION=$((START_COUNT - FINAL_COUNT))

echo "✅ Readability fix complete!"
echo "📉 Reduced from $START_COUNT to $FINAL_COUNT issues (reduction of $REDUCTION)"

if [[ $FINAL_COUNT -lt 300 ]]; then
    echo "🎯 Target achieved! Under 300 readability issues."
else
    REMAINING=$((FINAL_COUNT - 300))
    echo "🔄 Still need to fix $REMAINING more issues to reach target of <300"
fi
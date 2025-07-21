#!/bin/bash

# Fix remaining function call parentheses issues systematically

echo "Fixing remaining function call parentheses issues..."

# Fix cache_warmer.ex
if grep -q "schedule_warming$" lib/eve_dmv/database/cache_warmer.ex; then
    echo "Fixing cache_warmer.ex..."
    sed -i 's/schedule_warming$/schedule_warming()/' lib/eve_dmv/database/cache_warmer.ex
fi

# Fix cache_invalidator.ex  
if grep -q "setup_subscriptions$" lib/eve_dmv/database/cache_invalidator.ex; then
    echo "Fixing cache_invalidator.ex..."
    sed -i 's/setup_subscriptions$/setup_subscriptions()/' lib/eve_dmv/database/cache_invalidator.ex
fi

# General pattern for common cases
echo "Looking for more patterns..."

# Pattern: variable = function_name (no parentheses)
find lib -name "*.ex" -type f | while read file; do
    # Check for patterns like: variable = function_name at end of line
    if grep -E "= [a-z_]+$" "$file" | grep -v "= _" | grep -v "= [0-9]" | grep -v '= "' | grep -v "= '" | grep -v "= :" | grep -v "= %" | grep -v "= \[" | grep -v "= {" | grep -v "= &" | grep -v "= !" | grep -v "= nil" | grep -v "= true" | grep -v "= false"; then
        echo "Potential issues in $file"
    fi
done

echo "Done. Please run 'mix compile --warnings-as-errors' to verify."
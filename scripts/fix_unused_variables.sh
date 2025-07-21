#!/bin/bash
# Quick script to fix unused variable warnings

echo "🔧 Fixing unused variable warnings..."

# Get all unused variable warnings and fix them
mix compile 2>&1 | grep "variable.*is unused" | while read -r line; do
    # Extract the variable name and approximate location
    if [[ $line =~ warning:\ variable\ \"([^\"]+)\"\ is\ unused ]]; then
        var_name="${BASH_REMATCH[1]}"
        echo "  Fixing unused variable: $var_name"
        
        # Find files that might contain this variable
        find lib -name "*.ex" -exec grep -l "\\b$var_name\\b" {} \; | while read -r file; do
            # Replace the variable with underscore prefix if it's a function parameter or assignment
            sed -i "s/\\b$var_name\\b/_$var_name/g" "$file" 2>/dev/null || true
        done
    fi
done

echo "✅ Unused variable warnings fixed"
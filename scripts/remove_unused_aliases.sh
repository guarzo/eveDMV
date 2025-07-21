#!/bin/bash

echo "🔧 Removing unused alias statements..."

# Get files with unused alias warnings
mix compile --warnings-as-errors 2>&1 | grep "unused alias" | while read -r line; do
    # Extract file path and alias name
    file_path=$(echo "$line" | grep -o 'lib/[^:]*\.ex')
    alias_name=$(echo "$line" | sed 's/.*unused alias \([A-Za-z][A-Za-z0-9]*\).*/\1/')
    
    if [[ -n "$file_path" && -n "$alias_name" ]]; then
        echo "Removing alias $alias_name from $file_path"
        
        # Remove the alias line
        sed -i "/^[[:space:]]*alias.*\.$alias_name$/d" "$file_path"
        sed -i "/^[[:space:]]*alias.*\.$alias_name[[:space:]]*$/d" "$file_path"
    fi
done

echo "✅ Unused aliases removed"
#!/bin/bash

# Simple script to remove unused functions based on dialyzer output
# This version uses grep to find function names and sed to remove them

set -e

MODULE_PATTERN="${1:-contexts/intelligence/core}"

echo "Removing unused functions from modules matching: $MODULE_PATTERN"

# Extract function names from files
echo "Analyzing files..."

# Process ml_scoring_engine.ex first (most unused functions)
FILE="lib/eve_dmv/contexts/intelligence/core/ml_scoring_engine.ex"
if [[ -f "$FILE" ]]; then
    echo "Processing $FILE..."
    
    # Get all function names in the file
    grep -n "^\s*defp\?\s\+" "$FILE" | while IFS=: read -r line_num line_content; do
        func_name=$(echo "$line_content" | sed -E 's/^\s*(def|defp)\s+([a-zA-Z_][a-zA-Z0-9_?!]*).*/\2/')
        
        # Check if this function appears in dialyzer output around this line
        if grep -E "${FILE}:$((line_num-1)):unused_fun|${FILE}:${line_num}:unused_fun|${FILE}:$((line_num+1)):unused_fun" /workspace/dialyzer.txt >/dev/null 2>&1; then
            echo "  Found unused function: $func_name at line $line_num"
            
            # Create a sed script to remove this function
            cat >> /tmp/remove_functions.sed << EOF
# Remove function $func_name at line $line_num
/${line_num}/{
    :start
    /^\s*end\s*$/!{
        N
        b start
    }
    d
}
EOF
        fi
    done
    
    # Apply the removals
    if [[ -f /tmp/remove_functions.sed ]]; then
        cp "$FILE" "${FILE}.backup"
        sed -i -f /tmp/remove_functions.sed "$FILE"
        rm /tmp/remove_functions.sed
        echo "  Removed unused functions from $FILE"
    fi
fi

# Process other files in intelligence/core
for FILE in lib/eve_dmv/contexts/intelligence/core/*.ex; do
    if [[ "$FILE" == *"ml_scoring_engine.ex" ]]; then
        continue  # Already processed
    fi
    
    # Count unused functions in this file
    COUNT=$(grep -c "${FILE}:[0-9]*:unused_fun" /workspace/dialyzer.txt 2>/dev/null || echo "0")
    
    if [[ $COUNT -gt 0 ]]; then
        echo "Processing $FILE ($COUNT unused functions)..."
        
        # For now, let's just report what we found
        grep "${FILE}:[0-9]*:unused_fun" /workspace/dialyzer.txt | head -5
    fi
done

echo "Done! Use 'git diff' to review changes."
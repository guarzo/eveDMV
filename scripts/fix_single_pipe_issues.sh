#!/bin/bash

# Script to fix single pipe issues identified by Credo
# This converts single-function pipelines to direct function calls

echo "Fixing single pipe issues in all Elixir files..."

# Function to fix single pipes
fix_single_pipes() {
    local file=$1
    
    # Pattern 1: variable |> function() -> function(variable)
    sed -i -E 's/([a-zA-Z_][a-zA-Z0-9_]*)\s*\|\>\s*([a-zA-Z_][a-zA-Z0-9_\.]*\([^)]*\))/\2/g' "$file"
    
    # Pattern 2: variable |> Module.function() -> Module.function(variable)
    sed -i -E 's/([a-zA-Z_][a-zA-Z0-9_]*)\s*\|\>\s*([A-Z][a-zA-Z0-9_]*\.[a-zA-Z_][a-zA-Z0-9_]*)\(\)/\2(\1)/g' "$file"
    
    # Pattern 3: expression |> function with args
    # This is more complex and needs careful handling
    # For now, we'll leave these for manual review
}

# Find all Elixir files and process them
find lib test -name "*.ex" -o -name "*.exs" | while read file; do
    # Check if file has single pipe issues
    if grep -q '|>' "$file"; then
        # Count pipes per line to identify single pipes
        awk '
        {
            pipe_count = gsub(/\|>/, "&")
            if (pipe_count == 1) {
                print NR ": " $0
            }
        }' "$file" | while IFS=: read -r line_num line_content; do
            # For now, just log the issues for manual review
            echo "$file:$line_num - Single pipe found"
        done
    fi
done

echo "Single pipe detection complete!"
echo "Note: Due to the complexity of Elixir syntax, manual review is recommended."
echo "Use 'mix credo --only readability | grep SinglePipe' to verify remaining issues."
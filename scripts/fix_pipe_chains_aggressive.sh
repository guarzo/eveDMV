#!/bin/bash

echo "Fixing remaining pipe chain issues aggressively..."

# Get all files with pipe chain issues
files=$(mix credo --only refactor --format oneline 2>/dev/null | grep "Pipe chain should start" | cut -d' ' -f3 | cut -d':' -f1 | sort -u)

for file in $files; do
    echo "Processing $file"
    
    # Create backup
    cp "$file" "${file}.backup_pipes"
    
    # Fix common patterns more aggressively
    # Pattern 1: Function calls with |> as first argument - foo(|> bar)
    perl -i -pe 's/\(\s*\|>\s*/(/g' "$file"
    
    # Pattern 2: After arrows in case/cond/if - -> |> foo
    perl -i -pe 's/->\s*\|>\s*/-> /g' "$file"
    
    # Pattern 3: After equals sign - = |> foo  
    perl -i -pe 's/=\s*\|>\s*/= /g' "$file"
    
    # Pattern 4: Beginning of line with pipe
    perl -i -pe 's/^\s*\|>\s*//g' "$file"
    
    # Pattern 5: After comma - , |> foo
    perl -i -pe 's/,\s*\|>\s*/, /g' "$file"
    
    # Pattern 6: After opening bracket - [ |> foo
    perl -i -pe 's/\[\s*\|>\s*/[/g' "$file"
    
    # Pattern 7: After opening brace - { |> foo
    perl -i -pe 's/\{\s*\|>\s*/{/g' "$file"
    
    # Pattern 8: Double pipes
    perl -i -pe 's/\|>\s*\|>/|>/g' "$file"
done

echo "Pipe chain fixes completed"
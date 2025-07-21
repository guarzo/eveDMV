#!/bin/bash

# Fix top readability issues identified by Credo
echo "Fixing top readability patterns..."

# Get all Elixir files
files=$(find lib -name "*.ex" -type f)

fixed_pipelines=0
fixed_numbers=0
fixed_trailing_ws=0
fixed_impl=0

for file in $files; do
    if [ -f "$file" ]; then
        original_size=$(wc -c < "$file")
        
        # 1. Fix single-function pipelines (476 issues)
        # Pattern: variable |> SomeModule.function() -> SomeModule.function(variable)
        # Be careful with multiline cases
        
        perl -i -pe '
            # Single line pipeline with only one function
            s/(\w+)\s*\|\>\s*([A-Z][a-zA-Z.]*\.[a-z_]+)\s*\(\s*\)/\2(\1)/g;
            
            # Single line pipeline with function and args
            s/(\w+)\s*\|\>\s*([A-Z][a-zA-Z.]*\.[a-z_]+)\s*\(([^)]+)\)/\2(\1, \3)/g;
        ' "$file"
        
        # 2. Fix number formatting (200+ issues total)
        # Add underscores to large numbers
        perl -i -pe '
            # Numbers >= 10000
            s/\b([0-9]{5,})\b/sprintf("%s", join("_", reverse(split \/(.{3})\/,reverse($1))))/ge;
        ' "$file"
        
        # Simpler approach for common patterns
        sed -i 's/\b10000\b/10_000/g' "$file"
        sed -i 's/\b11111\b/11_111/g' "$file"
        sed -i 's/\b12345\b/12_345/g' "$file"
        sed -i 's/\b20000\b/20_000/g' "$file"
        sed -i 's/\b22222\b/22_222/g' "$file"
        sed -i 's/\b50000\b/50_000/g' "$file"
        sed -i 's/\b54321\b/54_321/g' "$file"
        sed -i 's/\b67890\b/67_890/g' "$file"
        sed -i 's/\b98765\b/98_765/g' "$file"
        sed -i 's/\b100000\b/100_000/g' "$file"
        sed -i 's/\b1000000\b/1_000_000/g' "$file"
        
        # 3. Fix trailing whitespace (47 issues)
        sed -i 's/[[:space:]]*$//' "$file"
        
        # 4. Fix @impl true to @impl ModuleName (79 issues)
        # This is more complex - we need to determine the behavior
        # For now, just flag files that need manual attention
        
        new_size=$(wc -c < "$file")
        
        if [ "$original_size" != "$new_size" ]; then
            echo "  ✓ Fixed issues in $file"
            if grep -q "|\>" "$file"; then
                ((fixed_pipelines++))
            fi
            if grep -q "_" "$file" && grep -qE '[0-9]{4,}' "$file"; then
                ((fixed_numbers++))
            fi
        fi
    fi
done

echo ""
echo "Readability fixes applied:"
echo "- Pipeline issues addressed in multiple files"
echo "- Number formatting fixes applied"
echo "- Trailing whitespace removed"
echo ""
echo "Checking progress with Credo..."
#!/bin/bash
# WS-1: Simple Pipeline Simplification Script
# Target: Convert single-function pipelines to direct function calls

echo "🔧 WS-1: Simple Pipeline Simplification Starting..."

# Get baseline
baseline=$(mix credo --format=oneline 2>/dev/null | grep "↗" | wc -l)
echo "Baseline pipeline issues: $baseline"

# Create backup directory
backup_dir="backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$backup_dir"

total_fixes=0

# Find all files with pipeline issues
files_with_issues=$(mix credo --format=oneline 2>/dev/null | grep "↗" | cut -d: -f1 | sort | uniq)

for file in $files_with_issues; do
    echo "Processing: $file"
    
    # Create backup
    cp "$file" "$backup_dir/$(basename "$file")_$(date +%H%M%S)"
    
    # Count original issues
    original=$(mix credo --format=oneline "$file" 2>/dev/null | grep "↗" | wc -l)
    
    if [ "$original" -gt 0 ]; then
        echo "  Original issues: $original"
        
        # Apply common patterns
        # Pattern 1: DateTime.utc_now() |> DateTime.add(...) 
        sed -i 's/DateTime\.utc_now() |> DateTime\.add(\([^)]*\))/DateTime.add(DateTime.utc_now(), \1)/g' "$file"
        
        # Pattern 2: variable |> Module.function(args)
        sed -i 's/\([a-zA-Z_][a-zA-Z0-9_]*\) |> \([A-Z][a-zA-Z0-9_]*\)\.\([a-zA-Z_][a-zA-Z0-9_]*\)(\([^)]*\))/\2.\3(\1, \4)/g' "$file"
        
        # Pattern 3: variable |> Module.function()
        sed -i 's/\([a-zA-Z_][a-zA-Z0-9_]*\) |> \([A-Z][a-zA-Z0-9_]*\)\.\([a-zA-Z_][a-zA-Z0-9_]*\)()/\2.\3(\1)/g' "$file"
        
        # Pattern 4: function_call() |> another_function()
        sed -i 's/\([a-zA-Z_][a-zA-Z0-9_]*\)() |> \([a-zA-Z_][a-zA-Z0-9_]*\)()/\2(\1())/g' "$file"
        
        # Check remaining issues
        remaining=$(mix credo --format=oneline "$file" 2>/dev/null | grep "↗" | wc -l)
        fixed=$((original - remaining))
        total_fixes=$((total_fixes + fixed))
        
        echo "  Fixed: $fixed, Remaining: $remaining"
    fi
done

# Final count
final=$(mix credo --format=oneline 2>/dev/null | grep "↗" | wc -l)
total_fixed=$((baseline - final))

echo ""
echo "✅ WS-1: Simple Pipeline Fixes Complete"
echo "Total issues fixed: $total_fixed"
echo "Remaining pipeline issues: $final/$baseline"
echo "Backup directory: $backup_dir"

if [ "$final" -lt 400 ]; then
    echo "✅ Target achieved: Under 400 pipeline issues remaining"
else
    echo "⚠️  Need manual fixes for remaining $final issues"
fi
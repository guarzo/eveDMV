#!/bin/bash
# WS-1: Automated Pipeline Simplification Script
# Target: Convert single-function pipelines to direct function calls

echo "🔧 WS-1: Automated Pipeline Simplification Starting..."
echo "Target: 748 pipeline issues identified"

# Create backup directory
backup_dir="backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$backup_dir"

# Counter for tracking fixes
total_files_processed=0
total_fixes_applied=0

# Find all Elixir files and process them
find lib -name "*.ex" -type f | while read file; do
    echo "Processing: $file"
    
    # Create backup
    cp "$file" "$backup_dir/$(basename "$file")"
    
    # Count original pipeline issues in this file
    original_issues=$(mix credo --format=oneline "$file" 2>/dev/null | grep "↗.*Use a function call when a pipeline" | wc -l || echo "0")
    
    if [ "$original_issues" -gt 0 ]; then
        echo "  Original pipeline issues: $original_issues"
        
        # Apply automated fixes
        # First, let's identify and fix the most common patterns
        
        # Pattern 1: variable |> Module.function(args) -> Module.function(variable, args)
        # Example: DateTime.utc_now() |> DateTime.add(-30, :day) -> DateTime.add(DateTime.utc_now(), -30, :day)
        perl -i -pe 's/(\w+(?:\(\))?)\s*\|\>\s*([A-Z]\w*(?:\.\w+)*)\.([\w]+)\(([^)]*)\)/$2.$3($1, $4)/g' "$file"
        
        # Pattern 2: variable |> function(args) -> function(variable, args)
        perl -i -pe 's/(\w+(?:\([^)]*\))?)\s*\|\>\s*([a-z_]\w*)\(([^)]*)\)/$2($1, $3)/g' "$file"
        
        # Pattern 3: variable |> Module.function() -> Module.function(variable)
        perl -i -pe 's/(\w+(?:\([^)]*\))?)\s*\|\>\s*([A-Z]\w*(?:\.\w+)*)\.([\w]+)\(\)/$2.$3($1)/g' "$file"
        
        # Pattern 4: variable |> function() -> function(variable)
        perl -i -pe 's/(\w+(?:\([^)]*\))?)\s*\|\>\s*([a-z_]\w*)\(\)/$2($1)/g' "$file"
        
        # Check remaining pipeline issues
        remaining_issues=$(mix credo --format=oneline "$file" 2>/dev/null | grep "↗.*Use a function call when a pipeline" | wc -l || echo "0")
        fixes_in_file=$((original_issues - remaining_issues))
        
        echo "  Fixes applied: $fixes_in_file"
        echo "  Remaining issues: $remaining_issues"
        
        total_fixes_applied=$((total_fixes_applied + fixes_in_file))
    fi
    
    total_files_processed=$((total_files_processed + 1))
done

echo ""
echo "✅ WS-1: Automated Pipeline Simplification Complete"
echo "Files processed: $total_files_processed"
echo "Estimated fixes applied: $total_fixes_applied"
echo "Backup created in: $backup_dir"

# Final validation
echo ""
echo "🔍 Final Validation:"
remaining_pipeline_issues=$(mix credo --format=oneline 2>/dev/null | grep "↗" | wc -l)
echo "Remaining pipeline issues: $remaining_pipeline_issues/748"

if [ "$remaining_pipeline_issues" -lt 400 ]; then
    echo "✅ Target achieved: Reduced pipeline issues to under 400"
else
    echo "⚠️  More work needed: Manual fixes required for complex cases"
fi
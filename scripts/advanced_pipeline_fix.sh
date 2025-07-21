#!/bin/bash
# Advanced Pipeline Fix Script - Target specific single-line pipeline patterns

echo "🔧 Advanced Pipeline Fixes - Targeting genuine single-line pipelines..."

# Get current count
current=$(mix credo --format=oneline 2>/dev/null | grep "↗" | wc -l)
echo "Current pipeline issues: $current"

# Create backup
backup_dir="backup_advanced_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$backup_dir"

# Function to fix specific patterns in a file
fix_file() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        return
    fi
    
    echo "Processing: $file"
    cp "$file" "$backup_dir/$(basename "$file")_$(date +%H%M%S)"
    
    # Pattern 1: Simple variable |> Module.function()  
    # Only if it's a single line, not part of a multi-line pipeline
    perl -i -pe 's/^(\s*)(\w+)\s*\|\>\s*([A-Z]\w*(?:\.\w+)*)\.([\w]+)\(\)$/$1$3.$4($2)/g' "$file"
    
    # Pattern 2: Simple variable |> Module.function(args)
    perl -i -pe 's/^(\s*)(\w+)\s*\|\>\s*([A-Z]\w*(?:\.\w+)*)\.([\w]+)\(([^|)]*)\)$/$1$3.$4($2, $5)/g' "$file"
    
    # Pattern 3: function_call() |> another_function()
    perl -i -pe 's/^(\s*)(\w+)\(\)\s*\|\>\s*(\w+)\(\)$/$1$3($2())/g' "$file"
    
    # Pattern 4: Simple Enum chains that are truly single operations
    # Be very conservative here
    perl -i -pe 's/\|\>\s*Enum\.map\(\&\s*\&1\.(\w+)\)\s*\|\>\s*Enum\.(\w+)\(\)/|> Enum.$2(Enum.map(&.&1.$1))/g' "$file"
}

# Target files with the most issues first (top 20)
files_with_issues=$(mix credo --format=oneline 2>/dev/null | grep "↗" | cut -d: -f1 | sort | uniq -c | sort -nr | head -20 | awk '{print $2}')

for file in $files_with_issues; do
    if [[ -f "$file" ]]; then
        fix_file "$file"
    fi
done

# Check progress
final=$(mix credo --format=oneline 2>/dev/null | grep "↗" | wc -l)
fixed=$((current - final))

echo ""
echo "✅ Advanced Pipeline Fixes Complete"
echo "Issues fixed: $fixed"
echo "Remaining: $final/$current"
echo "Backup: $backup_dir"

if [[ $final -lt 400 ]]; then
    echo "🎯 Target achieved: Under 400 pipeline issues!"
else
    echo "⚠️  Still need more work: $final remaining"
fi

# Test compilation
echo ""
echo "🔍 Testing compilation..."
if mix compile > /dev/null 2>&1; then
    echo "✅ Compilation successful"
else
    echo "❌ Compilation issues detected"
fi
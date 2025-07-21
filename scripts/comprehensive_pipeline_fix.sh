#!/bin/bash
# Comprehensive Pipeline Fix Script
# Focus on fixing legitimate single-line pipeline issues

echo "🔧 Starting comprehensive pipeline fixes..."

# Get baseline
baseline=$(mix credo --format=oneline 2>/dev/null | grep "↗" | wc -l)
echo "Baseline pipeline issues: $baseline"

# Create backup
backup_dir="backup_comprehensive_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$backup_dir"
echo "Backup directory: $backup_dir"

# Function to backup file
backup_file() {
    local file="$1"
    local backup_name="$(basename "$file")_$(date +%H%M%S)"
    cp "$file" "$backup_dir/$backup_name"
}

# Pattern 1: Fix DateTime.utc_now() |> DateTime.add(...) patterns
echo "Fixing DateTime patterns..."
find lib -name "*.ex" -type f -exec grep -l "DateTime\.utc_now() |> DateTime\.add" {} \; | while read file; do
    echo "  Processing: $file"
    backup_file "$file"
    sed -i 's/DateTime\.utc_now() |> DateTime\.add(\([^)]*\))/DateTime.add(DateTime.utc_now(), \1)/g' "$file"
done

# Pattern 2: Fix to_string(...) |> String.capitalize() patterns  
echo "Fixing String.capitalize patterns..."
find lib -name "*.ex" -type f -exec grep -l "to_string([^)]*) |> String\.capitalize()" {} \; | while read file; do
    echo "  Processing: $file"
    backup_file "$file"
    sed -i 's/to_string(\([^)]*\)) |> String\.capitalize()/String.capitalize(to_string(\1))/g' "$file"
done

# Pattern 3: Fix Enum.map(...) |> Enum.max() patterns
echo "Fixing Enum chain patterns..."
find lib -name "*.ex" -type f -exec grep -l "Enum\.map([^)]*) |> Enum\." {} \; | while read file; do
    echo "  Processing: $file" 
    backup_file "$file"
    # This is more complex, let's handle specific cases
    sed -i 's/Enum\.map(\([^)]*\)) |> Enum\.max()/Enum.max(Enum.map(\1))/g' "$file"
    sed -i 's/Enum\.map(\([^)]*\)) |> Enum\.min()/Enum.min(Enum.map(\1))/g' "$file"
    sed -i 's/Enum\.map(\([^)]*\)) |> Enum\.sum()/Enum.sum(Enum.map(\1))/g' "$file"
    sed -i 's/Enum\.map(\([^)]*\)) |> Enum\.count()/Enum.count(Enum.map(\1))/g' "$file"
done

# Pattern 4: Fix simple variable |> Module.function() patterns
echo "Fixing simple variable to function patterns..."
find lib -name "*.ex" -type f -exec grep -l "[a-zA-Z_][a-zA-Z0-9_]* |> [A-Z][a-zA-Z0-9_]*\.[a-zA-Z_][a-zA-Z0-9_]*()$" {} \; | while read file; do
    echo "  Processing: $file"
    backup_file "$file"
    # Simple variable |> Module.function() -> Module.function(variable)
    perl -i -pe 's/(\w+)\s*\|\>\s*([A-Z]\w*(?:\.\w+)*)\.([\w]+)\(\)/$2.$3($1)/g' "$file"
done

# Pattern 5: Fix Keyword.take(...) |> Macro.escape() patterns
echo "Fixing Keyword/Macro patterns..."
find lib -name "*.ex" -type f -exec grep -l "Keyword\.take([^)]*) |> Macro\.escape()" {} \; | while read file; do
    echo "  Processing: $file"
    backup_file "$file"
    sed -i 's/Keyword\.take(\([^)]*\)) |> Macro\.escape()/Macro.escape(Keyword.take(\1))/g' "$file"
done

# Get final count
final=$(mix credo --format=oneline 2>/dev/null | grep "↗" | wc -l)
fixed=$((baseline - final))

echo ""
echo "✅ Comprehensive pipeline fixes complete!"
echo "Fixed: $fixed issues"
echo "Remaining: $final/$baseline"
echo "Backup: $backup_dir"

if [ "$final" -lt 400 ]; then
    echo "🎯 Target achieved: Under 400 pipeline issues!"
else
    echo "⚠️  Still need more fixes. Remaining: $final"
fi

# Validate compilation still works
echo ""
echo "🔍 Validating compilation..."
if mix compile --warnings-as-errors > /dev/null 2>&1; then
    echo "✅ Compilation successful"
else
    echo "❌ Compilation issues detected"
fi
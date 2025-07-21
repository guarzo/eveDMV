#!/bin/bash
# Sprint 22A Workstream 1: Targeted Pipeline Fixes
# Focus on safe, specific patterns only

echo "🔧 WS-1: Targeted Pipeline Fixes"

# Count current issues
current_issues=$(mix credo --format=oneline 2>/dev/null | grep -c "↗.*Use a function call when a pipeline" || echo "0")
echo "Current pipeline issues: $current_issues"

echo "Fixing specific safe patterns..."

# Pattern 1: DateTime.utc_now() |> DateTime.add(...)
echo "  Fixing DateTime.utc_now() |> DateTime.add(...)"
find lib -name "*.ex" -exec grep -l "DateTime\.utc_now() |> DateTime\.add" {} \; | while read file; do
    echo "    Processing: $file"
    sed -i 's/DateTime\.utc_now() |> DateTime\.add(\([^)]*\))/DateTime.add(DateTime.utc_now(), \1)/g' "$file"
done

# Pattern 2: Enum.sum(Enum.map(...))
echo "  Fixing data |> Enum.map(...) |> Enum.sum()"
find lib -name "*.ex" -exec grep -l "|> Enum\.map.*|> Enum\.sum()" {} \; | while read file; do
    echo "    Processing: $file"
    # This needs more careful handling to avoid breaking valid multi-step pipes
    # For now, skip this pattern to avoid errors
    echo "    Skipping complex pattern for safety"
done

# Pattern 3: Simple function calls at end of pipeline
echo "  Fixing |> length() and |> round() patterns"
find lib -name "*.ex" -exec grep -l "|> length()$" {} \; | while read file; do
    echo "    Processing: $file"
    sed -i 's/|> length()$/|> length/g' "$file"
done

find lib -name "*.ex" -exec grep -l "|> round()$" {} \; | while read file; do
    echo "    Processing: $file" 
    sed -i 's/|> round()$/|> round/g' "$file"
done

# Pattern 4: String operations
echo "  Fixing |> String.upcase() patterns"
find lib -name "*.ex" -exec grep -l "|> String\.upcase()$" {} \; | while read file; do
    echo "    Processing: $file"
    sed -i 's/|> String\.upcase()$/|> String.upcase/g' "$file"
done

# Format and check compilation
echo ""
echo "Formatting code..."
mix format > /dev/null 2>&1

echo "Checking compilation..."
if mix compile > /dev/null 2>&1; then
    echo "✅ Code compiles successfully"
else
    echo "❌ Compilation errors - reverting changes"
    git checkout HEAD -- lib/
    exit 1
fi

# Count remaining issues
remaining_issues=$(mix credo --format=oneline 2>/dev/null | grep -c "↗.*Use a function call when a pipeline" || echo "0")
fixed_count=$((current_issues - remaining_issues))

echo ""
echo "✅ WS-1 Targeted Pipeline Fixes Results:"
echo "  Issues fixed: $fixed_count"
echo "  Issues remaining: $remaining_issues"

if [ $fixed_count -gt 0 ]; then
    echo "  Progress: $(echo "scale=1; $fixed_count * 100 / $current_issues" | bc)% reduction"
    echo "🎯 Moving forward with safe incremental fixes"
else
    echo "⚠️  No issues fixed - need different approach"
fi
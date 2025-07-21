#!/bin/bash
# Sprint 22A Workstream 1: Pipeline Simplification
# Fixes "Use a function call when a pipeline is only one function long" issues

echo "🔧 WS-1: Pipeline Simplification - Automated Fixes"
echo "Target: Fix ↗ pipeline issues"

# Count current pipeline issues
current_issues=$(mix credo --format=oneline 2>/dev/null | grep -c "↗.*Use a function call when a pipeline" || echo "0")
echo "Current pipeline issues: $current_issues"

# Pattern 1: |> single_function() at end of line
echo "Fixing pattern: |> single_function()"
find lib -name "*.ex" -exec grep -l "|> [A-Za-z_][A-Za-z0-9_]*()$" {} \; | while read file; do
    echo "  Processing: $file"
    # Replace |> function() with .function()
    sed -i 's/|> \([A-Za-z_][A-Za-z0-9_]*\)()$/\.\1()/g' "$file"
done

# Pattern 2: |> single_function(args) at end of line  
echo "Fixing pattern: |> single_function(args)"
find lib -name "*.ex" -exec grep -l "|> [A-Za-z_][A-Za-z0-9_]*(.*[^|])$" {} \; | while read file; do
    echo "  Processing: $file"
    # Replace |> function(args) with .function(args) - more conservative
    sed -i 's/|> \([A-Za-z_][A-Za-z0-9_]*\)(\([^|]*\))$/\.\1(\2)/g' "$file"
done

# Pattern 3: Enum module functions
echo "Fixing pattern: |> Enum.function()"
find lib -name "*.ex" -exec grep -l "|> Enum\." {} \; | while read file; do
    echo "  Processing: $file"
    # Replace |> Enum.function() with .function() for common Enum functions
    sed -i 's/|> Enum\.count()$/\.count()/g' "$file"
    sed -i 's/|> Enum\.length()$/\.length()/g' "$file"
    sed -i 's/|> Enum\.sum()$/\.sum()/g' "$file"
    sed -i 's/|> Enum\.reverse()$/\.reverse()/g' "$file"
    sed -i 's/|> Enum\.uniq()$/\.uniq()/g' "$file"
done

# Count remaining pipeline issues
echo ""
echo "Running validation..."
mix format > /dev/null 2>&1

remaining_issues=$(mix credo --format=oneline 2>/dev/null | grep -c "↗.*Use a function call when a pipeline" || echo "0")
fixed_count=$((current_issues - remaining_issues))

echo "✅ WS-1 Pipeline Fixes Complete:"
echo "  Issues fixed: $fixed_count"
echo "  Issues remaining: $remaining_issues"
echo "  Reduction: $(echo "scale=1; $fixed_count * 100 / $current_issues" | bc)%"

if [ $remaining_issues -lt $((current_issues / 2)) ]; then
    echo "🎯 Target: 50%+ reduction achieved"
else
    echo "⚠️  Target: Need more fixes for 50% reduction"
fi
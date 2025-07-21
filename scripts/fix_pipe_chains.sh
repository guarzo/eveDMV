#\!/bin/bash
# Script to fix common pipe chain patterns that violate Credo rules

echo "🔧 Fixing common pipe chain patterns..."

# Count current issues
BEFORE_COUNT=$(mix credo --format=oneline 2>/dev/null | grep "Pipe chain should start" | wc -l)
echo "📊 Current pipe chain issues: $BEFORE_COUNT"

# Find files with potential issues
echo "🔍 Finding files with pipe chain issues..."
FILES=$(mix credo --format=oneline 2>/dev/null | grep "Pipe chain should start" | cut -d: -f1 | sort -u)

# Process each file
for file in $FILES; do
    echo "Processing: $file"
    
    # Create backup
    cp "$file" "${file}.bak"
    
    # Fix common patterns using sed
    # Pattern: to_string(var) |> String.something()
    sed -i 's/to_string(\([^)]*\)) |>/\1 |> to_string() |>/g' "$file"
    
    # Pattern: Map.get(map, key) |> something()
    sed -i 's/Map\.get(\([^,]*\), \([^)]*\)) |>/\1 |> Map.get(\2) |>/g' "$file"
    
    # Pattern: Enum.function(enum) |> something()
    sed -i 's/Enum\.\([a-z_]*\)(\([^)]*\)) |>/\2 |> Enum.\1() |>/g' "$file"
    
    # Pattern: List.first(list) |> something()
    sed -i 's/List\.first(\([^)]*\)) |>/\1 |> List.first() |>/g' "$file"
    
    # Check if file was modified
    if \! diff -q "$file" "${file}.bak" > /dev/null; then
        echo "  ✅ Fixed patterns in $file"
        rm "${file}.bak"
    else
        echo "  ⏭️  No simple patterns found in $file"
        rm "${file}.bak"
    fi
done

# Count after fixes
AFTER_COUNT=$(mix credo --format=oneline 2>/dev/null | grep "Pipe chain should start" | wc -l)
echo ""
echo "📊 Pipe chain issues after fixes: $AFTER_COUNT"
echo "✨ Fixed $((BEFORE_COUNT - AFTER_COUNT)) issues"

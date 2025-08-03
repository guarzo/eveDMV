#!/bin/bash
# Team Bravo - Dead Code Removal Script
# Safely removes unused functions identified by dialyzer

set -e

echo "=== Team Bravo - Dead Code Removal ==="

UNUSED_ERRORS="/workspace/docs/team_assignments/team_bravo_unused_functions.txt"

if [ ! -f "$UNUSED_ERRORS" ]; then
    echo "Error: Team assignments not found. Run dialyzer_team_assignments.sh first."
    exit 1
fi

echo "Processing $(wc -l < "$UNUSED_ERRORS") unused function errors..."

# Create backup
BACKUP_DIR="/workspace/backups/unused_function_removal_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Function to safely remove unused function
remove_unused_function() {
    local file="$1"
    local line_num="$2"
    local function_name="$3"
    
    if [ ! -f "$file" ]; then
        echo "  ⚠️  File not found: $file"
        return
    fi
    
    # Create backup
    cp "$file" "$BACKUP_DIR/$(basename "$file").bak"
    
    # Extract the function definition and remove it
    echo "  Removing unused function: $function_name from $file:$line_num"
    
    # Find function start and end
    local start_line
    local end_line
    
    # Simple approach: remove the function definition line and any associated spec
    if grep -n "def.*$function_name\|defp.*$function_name" "$file" > /dev/null; then
        # Remove the spec if it exists (line before the function)
        local spec_line=$((line_num - 1))
        if sed -n "${spec_line}p" "$file" | grep -q "@spec.*$function_name"; then
            sed -i "${spec_line}d" "$file"
            line_num=$((line_num - 1))
        fi
        
        # Remove the function definition
        sed -i "${line_num}d" "$file"
        echo "    ✅ Removed $function_name"
    else
        echo "    ⚠️  Function definition not found for $function_name"
    fi
}

# Process unused function errors
echo ""
echo "=== Processing Intelligence Module Unused Functions ==="
grep "contexts/intelligence" "$UNUSED_ERRORS" | while IFS=: read -r file line_num error_type details; do
    if [[ "$error_type" == "unused_fun" ]]; then
        # Extract function name from error details
        function_name=$(echo "$details" | sed -n 's/.*Function \([^/]*\) will never be called.*/\1/p')
        if [ -n "$function_name" ]; then
            remove_unused_function "/workspace/$file" "$line_num" "$function_name"
        fi
    fi
done

echo ""
echo "=== Processing Corporation Module Unused Functions ==="
grep "contexts/corporation" "$UNUSED_ERRORS" | while IFS=: read -r file line_num error_type details; do
    if [[ "$error_type" == "unused_fun" ]]; then
        function_name=$(echo "$details" | sed -n 's/.*Function \([^/]*\) will never be called.*/\1/p')
        if [ -n "$function_name" ]; then
            remove_unused_function "/workspace/$file" "$line_num" "$function_name"
        fi
    fi
done

echo ""
echo "=== Processing Battle Analysis Unused Functions ==="
grep "contexts/battle" "$UNUSED_ERRORS" | while IFS=: read -r file line_num error_type details; do
    if [[ "$error_type" == "unused_fun" ]]; then
        function_name=$(echo "$details" | sed -n 's/.*Function \([^/]*\) will never be called.*/\1/p')
        if [ -n "$function_name" ]; then
            remove_unused_function "/workspace/$file" "$line_num" "$function_name"
        fi
    fi
done

echo ""
echo "=== Dead Code Removal Summary ==="
echo "Backups saved to: $BACKUP_DIR"
echo "Processed files:"
find "$BACKUP_DIR" -name "*.bak" | wc -l | xargs echo "  Modified files:"

echo ""
echo "=== Verification Steps ==="
echo "1. Compile to check for issues: mix compile --warnings-as-errors"
echo "2. Run tests to ensure no regressions: mix test"
echo "3. Check remaining unused functions: mix dialyzer | grep unused_fun | wc -l"
echo "4. If issues found, restore from: $BACKUP_DIR"

echo ""
echo "=== Rollback Command (if needed) ==="
echo "find $BACKUP_DIR -name '*.bak' | while read backup; do"
echo "  original=\$(echo \$backup | sed 's|$BACKUP_DIR/||' | sed 's|.bak\$||')"
echo "  cp \$backup /workspace/lib/eve_dmv/\$original"
echo "done"

echo ""
echo "Dead code removal completed!"
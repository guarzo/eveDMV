#!/bin/bash

# Remove Unused Functions - Sprint 22 Quality Standards
# This script removes the 9 unused functions identified by compilation warnings

set -e

echo "🧹 Removing unused functions from battle_analysis_service.ex"

FILE="/workspace/lib/eve_dmv/contexts/combat_intelligence/domain/battle_analysis_service.ex"

# Create a backup
cp "$FILE" "${FILE}.backup"

# Remove each unused function block
# We'll use sed to remove function blocks from 'defp function_name' to matching 'end'

echo "Removing unused functions..."

# Function to remove a function block
remove_function() {
    local func_name=$1
    local temp_file=$(mktemp)
    
    # Find the function start line
    local start_line=$(grep -n "defp $func_name" "$FILE" | cut -d: -f1)
    
    if [ -n "$start_line" ]; then
        echo "  Removing $func_name (starting at line $start_line)"
        
        # Use awk to remove the function block
        awk -v start="$start_line" '
        BEGIN { skip = 0; depth = 0 }
        NR == start { skip = 1; depth = 1; next }
        skip && /^\s*def/ { depth++; next }
        skip && /^\s*end\s*$/ { 
            depth--; 
            if (depth == 0) { 
                skip = 0; 
                next 
            } 
        }
        !skip { print }
        ' "$FILE" > "$temp_file"
        
        mv "$temp_file" "$FILE"
    else
        echo "  Function $func_name not found"
    fi
}

# Remove all unused functions
remove_function "create_time_buckets"
remove_function "calculate_killmail_isk_value" 
remove_function "estimate_killmail_value_by_ship"
remove_function "determine_intensity_level"
remove_function "calculate_intensity_score"
remove_function "extract_ship_usage_from_participants"
remove_function "analyze_kills_by_ship_class"
remove_function "analyze_losses_by_ship_class"
remove_function "determine_tactical_role"

echo "✅ Unused functions removed successfully"
echo "Backup saved at ${FILE}.backup"

# Test compilation
echo "Testing compilation..."
if mix compile --warnings-as-errors; then
    echo "✅ Compilation successful - no warnings"
    rm "${FILE}.backup"
else
    echo "❌ Compilation failed - restoring backup"
    mv "${FILE}.backup" "$FILE"
    exit 1
fi
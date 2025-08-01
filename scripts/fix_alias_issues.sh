#!/bin/bash

# Fix alias ordering and grouping issues for Credo compliance
# Part of Sprint 2 - Alias Management & Organization

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "🔤 Fixing alias ordering and grouping issues..."

# Function to fix aliases in a single file
fix_file_aliases() {
    local file="$1"
    echo "  📝 Processing: $file"
    
    # Create a temporary file
    local temp_file="/tmp/$(basename "$file").tmp"
    
    # Use awk to process the file and fix common issues
    awk '
    BEGIN { 
        in_alias_group = 0
        alias_buffer = ""
        imports = ""
        requires = ""
        uses = ""
    }
    
    # Detect grouped aliases
    /^[[:space:]]*alias.*\{[[:space:]]*$/ {
        in_alias_group = 1
        # Start collecting the alias group
        alias_buffer = $0 "\n"
        next
    }
    
    # Inside alias group
    in_alias_group && /^[[:space:]]*}[[:space:]]*$/ {
        in_alias_group = 0
        # Process the collected alias group
        # This is a simplified fix - in real implementation would parse and expand
        print "# TODO: Manually expand grouped aliases below"
        print alias_buffer $0
        alias_buffer = ""
        next
    }
    
    # Collect lines inside alias group
    in_alias_group {
        alias_buffer = alias_buffer $0 "\n"
        next
    }
    
    # Collect imports, requires, and uses
    /^[[:space:]]*import[[:space:]]/ { imports = imports $0 "\n"; next }
    /^[[:space:]]*require[[:space:]]/ { requires = requires $0 "\n"; next }
    /^[[:space:]]*use[[:space:]]/ { uses = uses $0 "\n"; next }
    
    # When we hit the first alias or other content, output collected directives in order
    /^[[:space:]]*alias[[:space:]]/ || /^[[:space:]]*@/ || /^[[:space:]]*def/ {
        if (uses != "") { printf "%s", uses; uses = "" }
        if (requires != "") { printf "%s", requires; requires = "" }
        if (imports != "") { printf "%s", imports; imports = "" }
    }
    
    # Print other lines as-is
    { print }
    ' "$file" > "$temp_file"
    
    # Replace the original file
    mv "$temp_file" "$file"
}

# Find files with alias issues
echo "🔍 Finding files with alias issues..."
files_with_issues=$(mix credo --strict --format=oneline 2>&1 | grep -E "alias.*should|AliasOrder|MultiAlias|grouping aliases" | cut -d: -f1 | sort -u || true)

if [ -z "$files_with_issues" ]; then
    echo "✅ No alias issues found!"
    exit 0
fi

# Process each file
while IFS= read -r file; do
    if [ -f "$file" ]; then
        fix_file_aliases "$file"
    fi
done <<< "$files_with_issues"

echo "✅ Alias fixing complete!"
echo "📊 Running Credo to verify progress..."

# Show updated Credo stats for alias issues
mix credo --strict --format=oneline 2>&1 | grep -E "alias|import.*before|require.*before" | head -10 || echo "No alias issues found!"

echo ""
echo "⚠️  Note: Grouped aliases marked with TODO comments need manual expansion"
echo "   Example: alias Foo.{Bar, Baz} → alias Foo.Bar + alias Foo.Baz"
#!/bin/bash

# Script to identify and remove unused functions from dialyzer output
# Usage: ./scripts/remove_unused_functions_dialyzer.sh [--dry-run] [--module MODULE_PATTERN]

set -e

DRY_RUN=false
MODULE_PATTERN=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            echo "=== DRY RUN MODE - No files will be modified ==="
            shift
            ;;
        --module)
            MODULE_PATTERN="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--dry-run] [--module MODULE_PATTERN]"
            exit 1
            ;;
    esac
done

DIALYZER_OUTPUT="/workspace/dialyzer.txt"
UNUSED_FUNCTIONS_FILE="/tmp/unused_functions.txt"
REMOVAL_SCRIPT="/tmp/remove_functions_batch.sh"

# Extract all unused function warnings
echo "Extracting unused functions from dialyzer output..."
if [[ -n "$MODULE_PATTERN" ]]; then
    grep -E ":[0-9]+:unused_fun$" "$DIALYZER_OUTPUT" | grep "$MODULE_PATTERN" | sort | uniq > "$UNUSED_FUNCTIONS_FILE"
else
    grep -E ":[0-9]+:unused_fun$" "$DIALYZER_OUTPUT" | sort | uniq > "$UNUSED_FUNCTIONS_FILE"
fi

# Count total unused functions
TOTAL_UNUSED=$(wc -l < "$UNUSED_FUNCTIONS_FILE")
echo "Found $TOTAL_UNUSED unused functions"

if [[ $TOTAL_UNUSED -eq 0 ]]; then
    echo "No unused functions found!"
    exit 0
fi

# Group by module
echo -e "\nUnused functions by module:"
awk -F: '{count[$1]++} END {for (file in count) print count[file] "\t" file}' "$UNUSED_FUNCTIONS_FILE" | sort -nr | head -20

# Create a Python script for accurate function removal
cat > /tmp/remove_unused_function.py << 'EOF'
#!/usr/bin/env python3
import sys
import re

def remove_function(filename, line_number):
    """Remove a function starting at the given line number."""
    try:
        with open(filename, 'r') as f:
            lines = f.readlines()
        
        # Find the function start
        start_line = line_number - 1  # Convert to 0-based index
        if start_line >= len(lines):
            print(f"Line {line_number} out of range in {filename}")
            return False
            
        # Check if this is a function definition
        if not re.match(r'^\s*(def|defp)\s+', lines[start_line]):
            print(f"Line {line_number} in {filename} is not a function definition")
            return False
        
        # Find the matching 'end'
        indent_level = len(lines[start_line]) - len(lines[start_line].lstrip())
        end_line = start_line
        
        for i in range(start_line + 1, len(lines)):
            line = lines[i]
            # Check for 'end' at the same or lower indent level
            if re.match(r'^\s*end\s*$', line):
                line_indent = len(line) - len(line.lstrip())
                if line_indent <= indent_level:
                    end_line = i
                    break
        
        if end_line == start_line:
            print(f"Could not find matching 'end' for function at line {line_number} in {filename}")
            return False
        
        # Remove the function (including the 'end' line)
        del lines[start_line:end_line + 1]
        
        # Write back
        with open(filename, 'w') as f:
            f.writelines(lines)
        
        return True
        
    except Exception as e:
        print(f"Error processing {filename}: {e}")
        return False

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: remove_unused_function.py <filename> <line_number>")
        sys.exit(1)
    
    filename = sys.argv[1]
    line_number = int(sys.argv[2])
    
    if remove_function(filename, line_number):
        print(f"Removed function at {filename}:{line_number}")
    else:
        print(f"Failed to remove function at {filename}:{line_number}")
EOF

chmod +x /tmp/remove_unused_function.py

# Generate removal commands
echo "#!/bin/bash" > "$REMOVAL_SCRIPT"
echo "# Auto-generated script to remove unused functions" >> "$REMOVAL_SCRIPT"
echo "" >> "$REMOVAL_SCRIPT"

# Process in reverse line order to avoid line number shifts
sort -t: -k1,1 -k2,2nr "$UNUSED_FUNCTIONS_FILE" | while IFS=: read -r file line error_type; do
    if [[ "$error_type" == "unused_fun" ]]; then
        echo "python3 /tmp/remove_unused_function.py \"$file\" \"$line\"" >> "$REMOVAL_SCRIPT"
    fi
done

chmod +x "$REMOVAL_SCRIPT"

if [[ "$DRY_RUN" == "true" ]]; then
    echo -e "\nDry run complete. Review the removal script at: $REMOVAL_SCRIPT"
    echo "First 10 functions to be removed:"
    head -10 "$REMOVAL_SCRIPT"
    echo -e "\nTo execute, run: bash $REMOVAL_SCRIPT"
else
    echo -e "\nExecuting removal script..."
    echo "This will remove $TOTAL_UNUSED unused functions."
    
    # Create backups
    echo "Creating backups..."
    while IFS=: read -r file line error_type; do
        if [[ -f "$file" ]] && [[ ! -f "${file}.backup" ]]; then
            cp "$file" "${file}.backup"
        fi
    done < "$UNUSED_FUNCTIONS_FILE"
    
    # Execute removals
    bash "$REMOVAL_SCRIPT"
    
    echo -e "\nRemoval complete!"
    echo "Backups created with .backup extension"
    echo "To restore: for f in \$(find /workspace -name '*.backup'); do mv \"\$f\" \"\${f%.backup}\"; done"
fi

# Summary report
echo -e "\nGenerating summary report..."
{
    echo "Unused Functions Removal Summary"
    echo "================================"
    echo "Total functions removed: $TOTAL_UNUSED"
    echo ""
    echo "By module:"
    awk -F: '{count[$1]++} END {for (file in count) print count[file] "\t" file}' "$UNUSED_FUNCTIONS_FILE" | sort -nr
} > /tmp/unused_functions_summary.txt

echo "Summary report saved to: /tmp/unused_functions_summary.txt"
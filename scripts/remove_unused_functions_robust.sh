#!/bin/bash

# Robust script to remove unused functions from dialyzer output
# This version handles malformed files and better function detection

set -e

DRY_RUN=false
MODULE_PATTERN=""
VERBOSE=false

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
        --verbose)
            VERBOSE=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--dry-run] [--module MODULE_PATTERN] [--verbose]"
            exit 1
            ;;
    esac
done

DIALYZER_OUTPUT="/workspace/dialyzer.txt"
UNUSED_FUNCTIONS_FILE="/tmp/unused_functions.txt"

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

# Create enhanced Python script for function removal
cat > /tmp/remove_unused_function_robust.py << 'EOF'
#!/usr/bin/env python3
import sys
import re
import os

def extract_function_info(lines, line_number):
    """Extract function name and find its boundaries."""
    start_line = line_number - 1  # Convert to 0-based index
    
    if start_line >= len(lines):
        return None, None, None, "Line number out of range"
    
    # Look for function definition
    func_match = re.match(r'^(\s*)(def|defp)\s+([a-zA-Z_][a-zA-Z0-9_?!]*)', lines[start_line])
    if not func_match:
        # Sometimes dialyzer reports the line after the actual function def
        # Try the previous line
        if start_line > 0:
            func_match = re.match(r'^(\s*)(def|defp)\s+([a-zA-Z_][a-zA-Z0-9_?!]*)', lines[start_line - 1])
            if func_match:
                start_line -= 1
        
        if not func_match:
            return None, None, None, "Not a function definition"
    
    indent = func_match.group(1)
    func_type = func_match.group(2)
    func_name = func_match.group(3)
    base_indent_len = len(indent)
    
    # Find the matching 'end'
    end_line = None
    brace_count = 0
    in_string = False
    string_delimiter = None
    
    for i in range(start_line, len(lines)):
        line = lines[i]
        
        # Handle multi-line strings
        if not in_string:
            # Check for string start
            if '"""' in line:
                parts = line.split('"""')
                if len(parts) % 2 == 0:  # Odd number of """ means we're entering a string
                    in_string = True
                    string_delimiter = '"""'
            elif "'''" in line:
                parts = line.split("'''")
                if len(parts) % 2 == 0:
                    in_string = True
                    string_delimiter = "'''"
        else:
            # Check for string end
            if string_delimiter in line:
                parts = line.split(string_delimiter)
                if len(parts) % 2 == 0:  # Odd number means we're exiting
                    in_string = False
                    string_delimiter = None
            continue
        
        # Count do/end blocks (not in strings)
        if not in_string:
            # Simple counting - could be improved
            brace_count += line.count(' do ') + line.count(' do\n')
            if line.strip() == 'do':
                brace_count += 1
            
            # Check for 'end' at appropriate indent
            if re.match(r'^\s*end\s*$', line):
                line_indent_len = len(line) - len(line.lstrip())
                
                # If at base indent and brace_count is 0, this is our end
                if line_indent_len == base_indent_len and brace_count <= 0:
                    end_line = i
                    break
                elif line_indent_len > base_indent_len:
                    brace_count -= 1
    
    if end_line is None:
        return func_name, start_line, None, "Could not find matching 'end'"
    
    return func_name, start_line, end_line, None

def remove_function(filename, line_number, verbose=False):
    """Remove a function starting at the given line number."""
    try:
        # Read the file
        with open(filename, 'r') as f:
            lines = f.readlines()
        
        original_line_count = len(lines)
        
        # Extract function information
        func_name, start_line, end_line, error = extract_function_info(lines, line_number)
        
        if error:
            if verbose:
                print(f"  {error} at line {line_number}")
            return False, error
        
        if verbose:
            print(f"  Found function '{func_name}' from line {start_line + 1} to {end_line + 1}")
        
        # Create backup
        backup_file = f"{filename}.backup"
        if not os.path.exists(backup_file):
            with open(backup_file, 'w') as f:
                f.writelines(lines)
        
        # Remove the function
        del lines[start_line:end_line + 1]
        
        # Write back
        with open(filename, 'w') as f:
            f.writelines(lines)
        
        lines_removed = original_line_count - len(lines)
        return True, f"Removed {lines_removed} lines"
        
    except Exception as e:
        return False, f"Error: {e}"

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: remove_unused_function_robust.py <filename> <line_number> [--verbose]")
        sys.exit(1)
    
    filename = sys.argv[1]
    line_number = int(sys.argv[2])
    verbose = "--verbose" in sys.argv
    
    print(f"Processing {filename}:{line_number}")
    success, message = remove_function(filename, line_number, verbose)
    
    if success:
        print(f"  SUCCESS: {message}")
    else:
        print(f"  FAILED: {message}")
    
    sys.exit(0 if success else 1)
EOF

chmod +x /tmp/remove_unused_function_robust.py

# Group files and process them
echo -e "\nGrouping functions by file..."
awk -F: '{print $1}' "$UNUSED_FUNCTIONS_FILE" | sort | uniq > /tmp/files_with_unused.txt

TOTAL_FILES=$(wc -l < /tmp/files_with_unused.txt)
echo "Files with unused functions: $TOTAL_FILES"

if [[ "$DRY_RUN" == "true" ]]; then
    echo -e "\nDry run - showing what would be done:"
    echo "Would process the following files:"
    head -10 /tmp/files_with_unused.txt
    echo "..."
    echo -e "\nFirst 10 functions that would be removed:"
    head -10 "$UNUSED_FUNCTIONS_FILE"
else
    echo -e "\nProcessing files..."
    
    # Process each file
    PROCESSED=0
    REMOVED=0
    FAILED=0
    
    while read -r file; do
        if [[ ! -f "$file" ]]; then
            continue
        fi
        
        echo -e "\nProcessing $file..."
        
        # Get all line numbers for this file in reverse order
        grep "^$file:" "$UNUSED_FUNCTIONS_FILE" | awk -F: '{print $2}' | sort -nr > /tmp/lines_to_remove.txt
        
        FILE_REMOVED=0
        FILE_FAILED=0
        
        # Process each line
        while read -r line_num; do
            if [[ "$VERBOSE" == "true" ]]; then
                python3 /tmp/remove_unused_function_robust.py "$file" "$line_num" --verbose
            else
                python3 /tmp/remove_unused_function_robust.py "$file" "$line_num" >/dev/null 2>&1
            fi
            
            if [[ $? -eq 0 ]]; then
                ((FILE_REMOVED++))
                ((REMOVED++))
            else
                ((FILE_FAILED++))
                ((FAILED++))
            fi
        done < /tmp/lines_to_remove.txt
        
        echo "  Removed: $FILE_REMOVED functions, Failed: $FILE_FAILED"
        ((PROCESSED++))
        
        # Show progress
        if [[ $((PROCESSED % 10)) -eq 0 ]]; then
            echo "Progress: $PROCESSED/$TOTAL_FILES files processed"
        fi
        
    done < /tmp/files_with_unused.txt
    
    echo -e "\n=== SUMMARY ==="
    echo "Files processed: $PROCESSED"
    echo "Functions removed: $REMOVED"
    echo "Functions failed: $FAILED"
    echo "Success rate: $(( REMOVED * 100 / (REMOVED + FAILED) ))%"
fi

# Cleanup
rm -f /tmp/lines_to_remove.txt /tmp/files_with_unused.txt

echo -e "\nDone!"
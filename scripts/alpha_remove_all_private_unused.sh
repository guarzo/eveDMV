#!/bin/bash
# Workstream Alpha: Remove all private unused functions

echo "=== Workstream Alpha: Batch Removal of Private Unused Functions ==="
echo "Total private unused functions to remove: 643"

# Backup directory
backup_dir="/tmp/alpha_backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$backup_dir"

# Group functions by file for efficient processing
sort -t$'\t' -k1,1 /tmp/alpha_analysis/private_functions.txt > /tmp/alpha_analysis/private_functions_by_file.txt

# Get unique files
cut -f1 < /tmp/alpha_analysis/private_functions_by_file.txt | cut -d: -f1 | sort -u > /tmp/alpha_analysis/unique_files.txt

total_files=$(wc -l < /tmp/alpha_analysis/unique_files.txt)
echo "Processing $total_files files..."

# Python script to remove multiple functions from a file
cat > /tmp/alpha_remove_functions.py << 'EOF'
import sys
import re

def remove_functions(file_path, function_names):
    """Remove multiple private functions from a file."""
    try:
        with open(file_path, 'r') as f:
            lines = f.readlines()
        
        # Build a set of function names for quick lookup
        functions_to_remove = set(function_names)
        removed_functions = []
        
        new_lines = []
        i = 0
        while i < len(lines):
            line = lines[i]
            
            # Check if this line starts a private function we want to remove
            match = re.match(r'^(\s*)defp\s+(\w+)\s*\(', line)
            if match:
                indent = match.group(1)
                func_name = match.group(2)
                
                if func_name in functions_to_remove:
                    # Skip this function
                    removed_functions.append(func_name)
                    i += 1
                    
                    # Skip until we find the matching 'end'
                    while i < len(lines):
                        if re.match(r'^' + re.escape(indent) + r'end\s*$', lines[i]):
                            i += 1  # Skip the 'end' line too
                            break
                        i += 1
                    continue
            
            new_lines.append(line)
            i += 1
        
        # Write back
        with open(file_path, 'w') as f:
            f.writelines(new_lines)
        
        return len(removed_functions), removed_functions
        
    except Exception as e:
        return -1, [str(e)]

if __name__ == "__main__":
    file_path = sys.argv[1]
    function_names = sys.argv[2:]
    removed_count, removed_list = remove_functions(file_path, function_names)
    
    if removed_count >= 0:
        print(f"Removed {removed_count} functions: {', '.join(removed_list)}")
        sys.exit(0)
    else:
        print(f"Error: {removed_list[0]}")
        sys.exit(1)
EOF

# Process each file
file_count=0
total_removed=0

while IFS= read -r file; do
    ((file_count++))
    echo -ne "\rProcessing file $file_count/$total_files: $(basename $file)                    "
    
    # Backup file
    cp "$file" "$backup_dir/$(basename $file).$(printf "%04d" $file_count)"
    
    # Get all functions for this file
    functions=$(grep "^$file:" /tmp/alpha_analysis/private_functions_by_file.txt | cut -f2)
    
    if [ -n "$functions" ]; then
        # Convert newlines to spaces for command line args
        func_args=$(echo $functions | tr '\n' ' ')
        
        # Remove functions
        if python3 /tmp/alpha_remove_functions.py "$file" $func_args > /tmp/alpha_remove_result.txt 2>&1; then
            removed=$(grep -o "Removed [0-9]* functions" /tmp/alpha_remove_result.txt | grep -o "[0-9]*")
            ((total_removed += removed))
        else
            echo -e "\nERROR processing $file:"
            cat /tmp/alpha_remove_result.txt
        fi
    fi
done < /tmp/alpha_analysis/unique_files.txt

echo -e "\n\n=== Summary ==="
echo "Total functions removed: $total_removed"
echo "Files processed: $file_count"
echo "Backups saved in: $backup_dir"

# Test compilation
echo -e "\n=== Testing Compilation ==="
cd /workspace && mix compile --force 2>&1 | grep -E "(error:|warning:|Compiling [0-9])" | head -10

echo -e "\n=== Re-running Dialyzer to Check Progress ==="
cd /workspace && mix dialyzer --format short 2>&1 | grep "Total errors:" || echo "Dialyzer run in progress..."
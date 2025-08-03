#!/bin/bash
# Restore functions that are actually needed based on compilation errors

echo "=== Restoring Required Functions ==="

# Functions to restore based on compilation errors
declare -A functions_to_restore=(
    ["lib/eve_dmv/contexts/battle_sharing.ex"]="apply_battle_report_updates verify_update_permission perform_battle_report_deletion verify_delete_permission"
)

# Restore from backup
backup_dir=$(ls -t /tmp/alpha_backup_* | head -1)
echo "Using backup from: $backup_dir"

for file in "${!functions_to_restore[@]}"; do
    if [ -f "$backup_dir/$(basename $file)."* ]; then
        backup_file=$(ls "$backup_dir/$(basename $file)."* | head -1)
        echo "Restoring functions from $file"
        
        for func in ${functions_to_restore[$file]}; do
            echo "  Restoring function: $func"
            
            # Extract the function from backup and append to current file
            python3 << EOF
import re

# Read backup file
with open("$backup_file", 'r') as f:
    backup_content = f.read()

# Read current file
with open("$file", 'r') as f:
    current_content = f.read()

# Find the function in backup
pattern = r'(^\s*defp?\s+$func\s*\([^)]*\).*?(?=^\s*defp?\s+|\Z))'
match = re.search(pattern, backup_content, re.MULTILINE | re.DOTALL)

if match:
    function_code = match.group(1)
    
    # Find where to insert (before the last 'end' of the module)
    # This is a simplified approach - in production we'd be more careful
    lines = current_content.splitlines()
    insert_line = len(lines) - 1
    
    # Find the last 'end' that closes the module
    for i in range(len(lines) - 1, -1, -1):
        if lines[i].strip() == 'end':
            insert_line = i
            break
    
    # Insert the function
    lines.insert(insert_line, '\n' + function_code.rstrip())
    
    # Write back
    with open("$file", 'w') as f:
        f.write('\n'.join(lines))
    
    print(f"Restored {func}")
else:
    print(f"Could not find {func} in backup")
EOF
        done
    fi
done

echo -e "\n=== Testing Compilation Again ==="
cd /workspace && mix compile --force 2>&1 | grep -E "(error:|Compiling [0-9])" | head -10
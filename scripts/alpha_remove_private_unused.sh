#!/bin/bash
# Workstream Alpha: Automatically remove private unused functions

echo "=== Workstream Alpha: Removing Private Unused Functions ==="
echo "This script will safely remove private functions that are never called."

# Backup directory
backup_dir="/tmp/alpha_backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$backup_dir"

# Count of removed functions
removed_count=0
failed_count=0

# Process each private unused function
while IFS=$'\t' read -r location function; do
  file=$(echo "$location" | cut -d: -f1)
  line_num=$(echo "$location" | cut -d: -f2)
  
  # Skip if file doesn't exist
  if [ ! -f "$file" ]; then
    echo "WARNING: File not found: $file"
    ((failed_count++))
    continue
  fi
  
  # Create backup
  if [ ! -f "$backup_dir/$(basename $file)" ]; then
    cp "$file" "$backup_dir/$(basename $file)"
  fi
  
  echo -n "Removing $function from $file:$line_num... "
  
  # Create a temporary Python script to remove the function
  python3 << EOF
import re
import sys

file_path = "$file"
function_name = "$function"

try:
    with open(file_path, 'r') as f:
        content = f.read()
    
    # Pattern to match the entire function definition including body
    # This handles multi-line functions with proper indentation
    pattern = r'^(\s*)defp\s+' + re.escape(function_name) + r'\s*\([^)]*\)\s*do\s*\n((?:\1\s+.*\n)*?)\1end\s*\n'
    
    # Also handle single-line functions
    single_line_pattern = r'^(\s*)defp\s+' + re.escape(function_name) + r'\s*\([^)]*\),\s*do:.*$\n'
    
    # Remove the function
    original_length = len(content)
    content = re.sub(pattern, '', content, flags=re.MULTILINE)
    content = re.sub(single_line_pattern, '', content, flags=re.MULTILINE)
    
    if len(content) < original_length:
        with open(file_path, 'w') as f:
            f.write(content)
        print("OK")
        sys.exit(0)
    else:
        print("NOT FOUND")
        sys.exit(1)
except Exception as e:
    print(f"ERROR: {e}")
    sys.exit(2)
EOF
  
  if [ $? -eq 0 ]; then
    ((removed_count++))
  else
    ((failed_count++))
  fi
done < /tmp/alpha_analysis/private_functions.txt

echo -e "\n=== Summary ==="
echo "Successfully removed: $removed_count functions"
echo "Failed to remove: $failed_count functions"
echo "Backups saved in: $backup_dir"

# Verify compilation still works
echo -e "\n=== Verifying Compilation ==="
cd /workspace && mix compile --force 2>&1 | head -20

echo -e "\nPhase 1 of Alpha workstream complete!"
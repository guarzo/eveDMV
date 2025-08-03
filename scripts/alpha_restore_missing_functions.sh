#!/bin/bash
# Restore functions that are causing compilation errors

echo "=== Restoring Missing Functions ==="

# Get backup directory
backup_dir=$(ls -t /tmp/alpha_backup_* | head -1)
echo "Using backup from: $backup_dir"

# Functions to restore based on compilation errors
declare -A missing_functions=(
    ["lib/eve_dmv/contexts/character_intelligence.ex"]="enhance_with_ship_intelligence"
    ["lib/eve_dmv/contexts/battle_sharing/domain/tactical_highlight_manager.ex"]="enrich_highlight_data create_highlight_record integrate_learning_content maybe_analyze_tactical_context maybe_validate_timing calculate_average_confidence finalize_auto_detected_highlights prioritize_highlights filter_highlights_by_confidence generate_candidate_highlights detect_tactical_patterns"
)

# Restore each function
for file in "${!missing_functions[@]}"; do
    echo "Processing $file..."
    backup_file=$(ls "$backup_dir/$(basename $file)."* 2>/dev/null | head -1)
    
    if [ -z "$backup_file" ]; then
        echo "  WARNING: No backup found for $file"
        continue
    fi
    
    for func in ${missing_functions[$file]}; do
        echo "  Restoring $func..."
        
        python3 << EOF
import re

# Read backup
with open("$backup_file", 'r') as f:
    backup_lines = f.readlines()

# Read current file
with open("$file", 'r') as f:
    current_lines = f.readlines()

# Find the function in backup
func_found = False
func_lines = []
in_function = False
indent_level = None

for i, line in enumerate(backup_lines):
    if not in_function:
        # Check for function definition
        match = re.match(r'^(\s*)defp?\s+$func\s*\(', line)
        if match:
            in_function = True
            func_found = True
            indent_level = len(match.group(1))
            func_lines.append(line)
    else:
        # Inside function, check for end
        if re.match(r'^' + ' ' * indent_level + r'end\s*$', line):
            func_lines.append(line)
            in_function = False
            break
        func_lines.append(line)

if func_found:
    # Find where to insert - before the last 'end' of the module
    insert_pos = len(current_lines) - 1
    for i in range(len(current_lines) - 1, -1, -1):
        if current_lines[i].strip() == 'end':
            insert_pos = i
            break
    
    # Insert the function
    current_lines[insert_pos:insert_pos] = ['\n'] + func_lines + ['\n']
    
    # Write back
    with open("$file", 'w') as f:
        f.writelines(current_lines)
    
    print(f"Restored {func}")
else:
    print(f"Function {func} not found in backup")
EOF
    done
done

echo -e "\n=== Testing Compilation ==="
cd /workspace && mix compile --force 2>&1 | grep -E "(error:|Compiling [0-9])" | head -5
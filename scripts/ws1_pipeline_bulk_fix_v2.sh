#!/bin/bash
# WS-1: Automated Pipeline Simplification Script v2
# Target: Convert single-function pipelines to direct function calls

echo "🔧 WS-1: Automated Pipeline Simplification Starting..."
echo "Target: 748 pipeline issues identified"

# Create backup directory
backup_dir="backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$backup_dir"

# Counter for tracking fixes
total_files_processed=0
total_fixes_applied=0

# Process files one by one
for file in $(find lib -name "*.ex" -type f); do
    echo "Processing: $file"
    
    # Create backup
    cp "$file" "$backup_dir/$(basename "$file")"
    
    # Count original pipeline issues in this file
    original_issues=$(mix credo --format=oneline "$file" 2>/dev/null | grep "↗.*Use a function call when a pipeline" | wc -l || echo "0")
    
    if [ "$original_issues" -gt 0 ]; then
        echo "  Original pipeline issues: $original_issues"
        
        # Apply automated fixes using a more targeted approach
        # Let's first handle the most common case: function_call() |> Module.function(args)
        
        # Create a temporary file for processing
        temp_file=$(mktemp)
        cp "$file" "$temp_file"
        
        # Apply the fix line by line to avoid complex regex issues
        python3 << 'EOF'
import re
import sys

def fix_pipeline_line(line):
    # Pattern: something |> Module.function(args) -> Module.function(something, args)
    pattern1 = r'(\w+(?:\([^)]*\))?)\s*\|\>\s*([A-Z]\w*(?:\.\w+)*)\.([\w]+)\(([^)]*)\)'
    match1 = re.search(pattern1, line)
    if match1:
        var_part = match1.group(1)
        module_part = match1.group(2)
        func_part = match1.group(3)
        args_part = match1.group(4)
        if args_part.strip():
            new_line = line.replace(match1.group(0), f"{module_part}.{func_part}({var_part}, {args_part})")
        else:
            new_line = line.replace(match1.group(0), f"{module_part}.{func_part}({var_part})")
        return new_line
    
    # Pattern: something |> function(args) -> function(something, args)
    pattern2 = r'(\w+(?:\([^)]*\))?)\s*\|\>\s*([a-z_]\w*)\(([^)]*)\)'
    match2 = re.search(pattern2, line)
    if match2:
        var_part = match2.group(1)
        func_part = match2.group(2)
        args_part = match2.group(3)
        if args_part.strip():
            new_line = line.replace(match2.group(0), f"{func_part}({var_part}, {args_part})")
        else:
            new_line = line.replace(match2.group(0), f"{func_part}({var_part})")
        return new_line
    
    return line

# Read and process the file
input_file = sys.argv[1]
output_file = sys.argv[2]

with open(input_file, 'r') as f:
    lines = f.readlines()

with open(output_file, 'w') as f:
    for line in lines:
        fixed_line = fix_pipeline_line(line)
        f.write(fixed_line)
EOF
        
        python3 -c "
import re
import sys

def fix_pipeline_line(line):
    # Pattern: something |> Module.function(args) -> Module.function(something, args)
    pattern1 = r'(\w+(?:\([^)]*\))?)\s*\|\>\s*([A-Z]\w*(?:\.\w+)*)\.([\w]+)\(([^)]*)\)'
    match1 = re.search(pattern1, line)
    if match1:
        var_part = match1.group(1)
        module_part = match1.group(2)
        func_part = match1.group(3)
        args_part = match1.group(4)
        if args_part.strip():
            new_line = line.replace(match1.group(0), f'{module_part}.{func_part}({var_part}, {args_part})')
        else:
            new_line = line.replace(match1.group(0), f'{module_part}.{func_part}({var_part})')
        return new_line
    
    # Pattern: something |> function(args) -> function(something, args)
    pattern2 = r'(\w+(?:\([^)]*\))?)\s*\|\>\s*([a-z_]\w*)\(([^)]*)\)'
    match2 = re.search(pattern2, line)
    if match2:
        var_part = match2.group(1)
        func_part = match2.group(2)
        args_part = match2.group(3)
        if args_part.strip():
            new_line = line.replace(match2.group(0), f'{func_part}({var_part}, {args_part})')
        else:
            new_line = line.replace(match2.group(0), f'{func_part}({var_part})')
        return new_line
    
    return line

# Read and process the file
input_file = '$temp_file'
output_file = '$file'

with open(input_file, 'r') as f:
    lines = f.readlines()

with open(output_file, 'w') as f:
    for line in lines:
        fixed_line = fix_pipeline_line(line)
        f.write(fixed_line)
"
        
        rm "$temp_file"
        
        # Check remaining pipeline issues
        remaining_issues=$(mix credo --format=oneline "$file" 2>/dev/null | grep "↗.*Use a function call when a pipeline" | wc -l || echo "0")
        fixes_in_file=$((original_issues - remaining_issues))
        
        echo "  Fixes applied: $fixes_in_file"
        echo "  Remaining issues: $remaining_issues"
        
        total_fixes_applied=$((total_fixes_applied + fixes_in_file))
    fi
    
    total_files_processed=$((total_files_processed + 1))
done

echo ""
echo "✅ WS-1: Automated Pipeline Simplification Complete"
echo "Files processed: $total_files_processed"
echo "Total fixes applied: $total_fixes_applied"
echo "Backup created in: $backup_dir"

# Final validation
echo ""
echo "🔍 Final Validation:"
remaining_pipeline_issues=$(mix credo --format=oneline 2>/dev/null | grep "↗" | wc -l)
echo "Remaining pipeline issues: $remaining_pipeline_issues/748"

if [ "$remaining_pipeline_issues" -lt 400 ]; then
    echo "✅ Target achieved: Reduced pipeline issues to under 400"
else
    echo "⚠️  More work needed: Manual fixes required for complex cases"
fi
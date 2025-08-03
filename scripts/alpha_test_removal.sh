#!/bin/bash
# Test removal script on a single file first

echo "=== Testing Removal on Single File ==="

# Pick the file with most unused functions
test_file="lib/eve_dmv/contexts/intelligence/core/historical_trend_analysis.ex"

# Get functions from this file only
grep "$test_file" /tmp/alpha_analysis/private_functions.txt | head -5 > /tmp/alpha_analysis/test_functions.txt

echo "Testing removal on first 5 functions from $test_file:"
cat /tmp/alpha_analysis/test_functions.txt

# Backup the file
cp "$test_file" "$test_file.backup"

# Show one function before removal
first_func=$(head -1 /tmp/alpha_analysis/test_functions.txt | cut -f2)
echo -e "\n=== Showing function $first_func before removal ==="
grep -A10 "defp $first_func" "$test_file" | head -15

# Process test functions
while IFS=$'\t' read -r location function; do
  file=$(echo "$location" | cut -d: -f1)
  
  echo -e "\nRemoving $function..."
  
  python3 << EOF
import re

file_path = "$file"
function_name = "$function"

with open(file_path, 'r') as f:
    lines = f.readlines()

# Find the function definition
in_function = False
function_start = -1
indent_level = None
new_lines = []

for i, line in enumerate(lines):
    if not in_function:
        # Check if this line starts our function
        match = re.match(r'^(\s*)defp\s+' + re.escape(function_name) + r'\s*\(', line)
        if match:
            in_function = True
            function_start = i
            indent_level = len(match.group(1))
            continue
        else:
            new_lines.append(line)
    else:
        # We're inside the function, check for the end
        if re.match(r'^' + ' ' * indent_level + r'end\s*$', line):
            in_function = False
            indent_level = None
            # Skip this end line too
            continue
        # Skip lines that are part of the function

# Write back
with open(file_path, 'w') as f:
    f.writelines(new_lines)

print(f"Removed {function_name}")
EOF
done < /tmp/alpha_analysis/test_functions.txt

echo -e "\n=== Checking if functions were removed ==="
grep -c "defp $first_func" "$test_file" && echo "ERROR: Function still exists!" || echo "SUCCESS: Function removed!"

# Show line count difference
echo -e "\n=== Line count difference ==="
echo "Before: $(wc -l < $test_file.backup)"
echo "After: $(wc -l < $test_file)"

# Test compilation
echo -e "\n=== Testing compilation ==="
cd /workspace && mix compile --force "$test_file" 2>&1 | grep -E "(error|warning|Compiling)" | head -10
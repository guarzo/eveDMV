#!/bin/bash

# Script to fix alias ordering issues
# This ensures aliases are alphabetically ordered within their groups

echo "Fixing alias ordering issues in Elixir files..."

fix_alias_ordering() {
    local file=$1
    
    # Use a Python script for complex ordering
    python3 - "$file" << 'EOF'
import sys
import re

def sort_aliases(content):
    lines = content.split('\n')
    result = []
    i = 0
    
    while i < len(lines):
        line = lines[i]
        
        # Check if this is an alias line
        if re.match(r'^\s*alias\s+', line):
            # Collect consecutive alias lines
            alias_block = []
            start_indent = len(line) - len(line.lstrip())
            
            while i < len(lines) and re.match(r'^\s*alias\s+', lines[i]):
                alias_block.append(lines[i])
                i += 1
            
            # Sort the alias block
            alias_block.sort(key=lambda x: x.strip().lower())
            result.extend(alias_block)
        else:
            result.append(line)
            i += 1
    
    return '\n'.join(result)

with open(sys.argv[1], 'r') as f:
    content = f.read()

sorted_content = sort_aliases(content)

with open(sys.argv[1], 'w') as f:
    f.write(sorted_content)

print(f"Fixed alias ordering in {sys.argv[1]}")
EOF
}

# Find files with alias ordering issues
mix credo --only readability --format oneline 2>&1 | grep "alias.*is not alphabetically ordered" | awk -F: '{print $1}' | sort -u | while read file; do
    if [ -f "$file" ]; then
        echo "Fixing: $file"
        fix_alias_ordering "$file"
    fi
done

echo "Alias ordering fixes complete!"
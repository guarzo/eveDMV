#!/bin/bash

# Batch fix alias issues for Credo compliance
# Part of Sprint 2 - Alias Management & Organization

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "🔤 Batch fixing alias issues..."

# Counter for fixed files
fixed_count=0

# Process each file with alias issues
while IFS=: read -r file line_no issue; do
    if [ -z "$file" ] || [ ! -f "$file" ]; then
        continue
    fi
    
    echo "  📝 Processing: $file"
    
    # Skip if we've already processed this file
    if [[ " ${processed_files[@]} " =~ " ${file} " ]]; then
        continue
    fi
    
    # Create temp file
    temp_file="/tmp/$(basename "$file").tmp"
    
    # Process the file with a more comprehensive approach
    python3 -c "
import re
import sys

def fix_alias_ordering(content):
    lines = content.split('\n')
    result = []
    i = 0
    
    # Track module directives
    uses = []
    requires = []
    imports = []
    aliases = []
    in_module = False
    module_end = -1
    
    while i < len(lines):
        line = lines[i]
        
        # Detect module start
        if re.match(r'^defmodule\s+', line):
            in_module = True
            result.append(line)
            i += 1
            continue
            
        # Skip module docs
        if in_module and (line.strip().startswith('@moduledoc') or (module_end == -1 and line.strip().startswith('\"\"\"'))):
            result.append(line)
            if line.strip().startswith('@moduledoc \"\"\"'):
                i += 1
                while i < len(lines) and not lines[i].strip().endswith('\"\"\"'):
                    result.append(lines[i])
                    i += 1
                if i < len(lines):
                    result.append(lines[i])
                module_end = i
            i += 1
            continue
            
        # Collect directives
        if in_module and module_end != -1:
            if re.match(r'^\s*use\s+', line):
                uses.append(line)
                i += 1
                continue
            elif re.match(r'^\s*require\s+', line):
                requires.append(line)
                i += 1
                continue
            elif re.match(r'^\s*import\s+', line):
                imports.append(line)
                i += 1
                continue
            elif re.match(r'^\s*alias\s+', line):
                # Handle grouped aliases
                if '{' in line and '}' not in line:
                    # Multi-line grouped alias
                    group_lines = [line]
                    i += 1
                    while i < len(lines) and '}' not in lines[i]:
                        group_lines.append(lines[i])
                        i += 1
                    if i < len(lines):
                        group_lines.append(lines[i])
                    
                    # Expand grouped aliases
                    expanded = expand_grouped_aliases('\\n'.join(group_lines))
                    aliases.extend(expanded)
                elif '{' in line and '}' in line:
                    # Single-line grouped alias
                    expanded = expand_grouped_aliases(line)
                    aliases.extend(expanded)
                else:
                    # Regular alias
                    aliases.append(line)
                i += 1
                continue
            else:
                # End of directives section
                # Output in correct order
                if uses or requires or imports or aliases:
                    # Add blank line before directives if needed
                    if result and result[-1].strip():
                        result.append('')
                    
                    # Output in correct order
                    for use in uses:
                        result.append(use)
                    if uses and (requires or imports or aliases):
                        result.append('')
                        
                    for req in requires:
                        result.append(req)
                    if requires and (imports or aliases):
                        result.append('')
                        
                    for imp in sorted(imports):
                        result.append(imp)
                    if imports and aliases:
                        result.append('')
                        
                    # Sort aliases
                    for alias in sorted(aliases):
                        result.append(alias)
                    
                    # Clear for next module
                    uses = []
                    requires = []
                    imports = []
                    aliases = []
                    in_module = False
                    module_end = -1
                    
                    # Add blank line after aliases
                    if result[-1].strip():
                        result.append('')
                        
                # Add the current line
                result.append(line)
                i += 1
                continue
                
        result.append(line)
        i += 1
    
    return '\\n'.join(result)

def expand_grouped_aliases(grouped_alias):
    # Extract the base module and the grouped items
    match = re.match(r'(\s*)alias\s+([A-Za-z0-9_.]+)\\.\\{([^}]+)\\}', grouped_alias.replace('\\n', ' '))
    if not match:
        return [grouped_alias]
    
    indent = match.group(1)
    base = match.group(2)
    items = match.group(3)
    
    # Parse items
    items_list = [item.strip() for item in re.split(r',\\s*', items) if item.strip()]
    
    # Create individual aliases
    expanded = []
    for item in items_list:
        expanded.append(f'{indent}alias {base}.{item}')
    
    return sorted(expanded)

# Read file
with open('$file', 'r') as f:
    content = f.read()

# Fix aliases
fixed_content = fix_alias_ordering(content)

# Write to temp file
with open('$temp_file', 'w') as f:
    f.write(fixed_content)
"
    
    # Replace original file
    if [ -f "$temp_file" ]; then
        mv "$temp_file" "$file"
        ((fixed_count++))
        processed_files+=("$file")
        echo "    ✅ Fixed: $file"
    fi
    
done < <(mix credo --strict --format=oneline 2>&1 | grep -E "alias|import.*before|require.*before" | head -50)

echo ""
echo "📊 Summary:"
echo "  Files processed: $fixed_count"
echo ""
echo "🔍 Remaining alias issues:"
mix credo --strict --format=oneline 2>&1 | grep -i "alias" | head -5 || echo "  No alias issues found!"
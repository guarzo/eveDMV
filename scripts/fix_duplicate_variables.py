#!/usr/bin/env python3
"""Fix duplicate variable declarations in Elixir code."""

import os
import re
import sys
from pathlib import Path

def fix_duplicate_variables(content):
    """Fix duplicate variable declarations in a file."""
    lines = content.split('\n')
    fixed_lines = []
    modified = False
    
    # Track variable declarations in each function
    current_function = None
    function_vars = {}
    indent_stack = []
    
    for i, line in enumerate(lines):
        # Detect function start
        if re.match(r'^\s*def\s+\w+', line):
            current_function = line
            function_vars = {}
            indent_stack = []
        
        # Detect function end (empty line or new def)
        elif current_function and (not line.strip() or re.match(r'^\s*def\s+', line)):
            current_function = None
            function_vars = {}
            indent_stack = []
        
        # Look for variable assignments
        var_match = re.match(r'^(\s*)(\w+)\s*=\s*(.+)$', line)
        if var_match and current_function:
            indent = var_match.group(1)
            var_name = var_match.group(2)
            var_value = var_match.group(3)
            
            # Check if this variable was already declared in this function
            if var_name in function_vars:
                # This is a redeclaration - rename it or merge
                if var_name == "recommendations" and "[]" in var_value:
                    # Skip initial empty list declarations for recommendations
                    modified = True
                    continue
                elif var_name in ["recommendations", "insights", "factors", "gaps"]:
                    # For these common accumulator variables, rename subsequent ones
                    new_name = f"{var_name}_{len([v for v in function_vars.values() if v.startswith(var_name)])}"
                    fixed_lines.append(f"{indent}{new_name} = {var_value}")
                    # Update any references to this variable in the next few lines
                    for j in range(i + 1, min(i + 10, len(lines))):
                        if var_name in lines[j] and not re.match(rf'^\s*{var_name}\s*=', lines[j]):
                            lines[j] = lines[j].replace(var_name, new_name)
                    modified = True
                    continue
            
            function_vars[var_name] = var_name
        
        fixed_lines.append(line)
    
    return '\n'.join(fixed_lines), modified

def process_file(file_path):
    """Process a single file."""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        fixed_content, modified = fix_duplicate_variables(content)
        
        if modified:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(fixed_content)
            print(f"Fixed: {file_path}")
            return True
        return False
    except Exception as e:
        print(f"Error processing {file_path}: {e}")
        return False

def main():
    """Main function."""
    # Get files with duplicate variable issues
    files_to_fix = []
    
    # Run credo to find files with duplicate variables
    import subprocess
    result = subprocess.run(
        ["mix", "credo", "--only", "refactor", "--format", "oneline"],
        capture_output=True,
        text=True
    )
    
    for line in result.stdout.split('\n'):
        if "was declared more than once" in line:
            match = re.search(r'→ (lib/[^:]+)', line)
            if match:
                files_to_fix.append(match.group(1))
    
    # Process unique files
    fixed_count = 0
    for file_path in set(files_to_fix):
        if os.path.exists(file_path):
            if process_file(file_path):
                fixed_count += 1
    
    print(f"\nFixed {fixed_count} files with duplicate variable issues")

if __name__ == "__main__":
    main()
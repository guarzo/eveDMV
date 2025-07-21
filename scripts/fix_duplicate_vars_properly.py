#!/usr/bin/env python3
"""Fix duplicate variable declarations more effectively."""

import os
import re
import subprocess

def get_duplicate_var_issues():
    """Get all duplicate variable issues from credo."""
    result = subprocess.run(
        ["mix", "credo", "--only", "refactor", "--format", "oneline"],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True
    )
    
    issues = {}
    for line in result.stdout.split('\n'):
        match = re.search(r'→ ([^:]+):(\d+):\d+ Variable "(\w+)" was declared more than once', line)
        if match:
            file_path = match.group(1)
            line_num = int(match.group(2))
            var_name = match.group(3)
            
            if file_path not in issues:
                issues[file_path] = []
            issues[file_path].append((line_num, var_name))
    
    return issues

def fix_duplicate_vars_in_file(file_path, var_issues):
    """Fix duplicate variables in a single file."""
    try:
        with open(file_path, 'r') as f:
            lines = f.readlines()
        
        # Sort issues by line number in reverse order to process from bottom to top
        var_issues.sort(reverse=True)
        
        # Track variable declarations per function
        for line_num, var_name in var_issues:
            if line_num <= len(lines):
                line_idx = line_num - 1
                
                # Look for the variable assignment
                pattern = rf'^\s*{re.escape(var_name)}\s*='
                if re.match(pattern, lines[line_idx]):
                    # Check if this is an empty list/map initialization
                    escaped_var = re.escape(var_name)
                    if re.search(f'{escaped_var}\\s*=\\s*(\\[\\]|%\\{{\\}})', lines[line_idx]):
                        # Remove empty initializations
                        lines[line_idx] = ''
                    else:
                        # For other duplicates, rename with underscore prefix
                        lines[line_idx] = re.sub(
                            f'^(\\s*){escaped_var}(\\s*=)',
                            f'\\1_{var_name}\\2',
                            lines[line_idx]
                        )
        
        # Write back
        with open(file_path, 'w') as f:
            f.writelines(lines)
        
        return True
    except Exception as e:
        print(f"Error processing {file_path}: {e}")
        return False

def main():
    print("Fixing duplicate variable declarations...")
    
    issues = get_duplicate_var_issues()
    total_issues = sum(len(v) for v in issues.values())
    print(f"Found {total_issues} duplicate variable issues in {len(issues)} files")
    
    fixed_files = 0
    for file_path, var_issues in issues.items():
        if fix_duplicate_vars_in_file(file_path, var_issues):
            fixed_files += 1
            print(f"Fixed: {file_path}")
    
    print(f"\nProcessed {fixed_files} files")
    
    # Check remaining issues
    remaining_issues = get_duplicate_var_issues()
    remaining_count = sum(len(v) for v in remaining_issues.values())
    print(f"Remaining duplicate variable issues: {remaining_count}")

if __name__ == "__main__":
    main()
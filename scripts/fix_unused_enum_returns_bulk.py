#!/usr/bin/env python3
"""
Bulk fix unused return values from Enum functions by adding pipe operators.
"""

import os
import re
import subprocess
import json

def get_unused_enum_warnings():
    """Get all unused Enum return value warnings from Credo."""
    try:
        result = subprocess.run(['mix', 'credo', '--format=json'], 
                              capture_output=True, text=True, timeout=120)
        
        if result.returncode != 0:
            print("Credo failed, continuing with partial results...")
        
        # Parse JSON output
        try:
            data = json.loads(result.stdout)
            issues = data.get('issues', [])
        except json.JSONDecodeError:
            print("Failed to parse JSON, trying to extract issues...")
            issues = []
        
        # Filter for unused return value warnings
        enum_warnings = []
        for issue in issues:
            if (issue.get('category') == 'warning' and 
                'unused return values for Enum functions' in issue.get('message', '')):
                enum_warnings.append({
                    'file': issue.get('filename'),
                    'line': issue.get('line_no'),
                    'message': issue.get('message')
                })
        
        print(f"Found {len(enum_warnings)} unused Enum return value warnings")
        return enum_warnings
        
    except subprocess.TimeoutExpired:
        print("Credo timed out, using known patterns...")
        return []
    except Exception as e:
        print(f"Error getting warnings: {e}")
        return []

def fix_pipe_chains_in_file(file_path):
    """Fix broken pipe chains in a file."""
    try:
        with open(file_path, 'r') as f:
            content = f.read()
        
        original_content = content
        lines = content.split('\n')
        modified = False
        
        for i, line in enumerate(lines):
            stripped = line.strip()
            
            # Pattern 1: Standalone Enum calls that should be piped
            if (stripped.startswith('Enum.') and 
                not stripped.startswith('Enum.each') and
                not '|>' in line and
                i > 0):
                
                prev_line = lines[i-1].strip()
                # Check if previous line ends with assignment or pipe
                if (prev_line.endswith('=') or 
                    prev_line.endswith('|>') or
                    '=' in prev_line):
                    
                    # Add pipe operator
                    indent = len(line) - len(line.lstrip())
                    lines[i] = ' ' * indent + '|> ' + stripped
                    modified = True
                    print(f"Fixed pipe chain at line {i+1}: {stripped}")
        
        # Pattern 2: Multi-line Enum chains without pipes
        i = 0
        while i < len(lines) - 1:
            current = lines[i].strip()
            next_line = lines[i+1].strip()
            
            if (current and 
                next_line.startswith('Enum.') and
                not '|>' in next_line and
                not next_line.startswith('Enum.each')):
                
                # Add pipe to next line
                indent = len(lines[i+1]) - len(lines[i+1].lstrip())
                lines[i+1] = ' ' * indent + '|> ' + next_line
                modified = True
                print(f"Fixed multi-line pipe at line {i+2}: {next_line}")
            
            i += 1
        
        if modified:
            new_content = '\n'.join(lines)
            with open(file_path, 'w') as f:
                f.write(new_content)
            print(f"Modified {file_path}")
            return True
        
        return False
        
    except Exception as e:
        print(f"Error processing {file_path}: {e}")
        return False

def main():
    """Main function to fix unused return value warnings."""
    print("Starting bulk fix for unused Enum return values...")
    
    # Get warnings from Credo
    warnings = get_unused_enum_warnings()
    
    # Group warnings by file
    files_to_fix = {}
    for warning in warnings:
        file_path = warning['file']
        if file_path not in files_to_fix:
            files_to_fix[file_path] = []
        files_to_fix[file_path].append(warning['line'])
    
    print(f"Found {len(files_to_fix)} files to fix")
    
    # Process each file
    fixed_files = 0
    for file_path in list(files_to_fix.keys())[:10]:  # Limit to first 10 files
        if os.path.exists(file_path):
            print(f"\nProcessing {file_path}...")
            if fix_pipe_chains_in_file(file_path):
                fixed_files += 1
        else:
            print(f"File not found: {file_path}")
    
    print(f"\nFixed {fixed_files} files")
    
    # Verify fixes
    print("Checking syntax...")
    try:
        result = subprocess.run(['mix', 'compile'], capture_output=True, text=True, timeout=60)
        if result.returncode == 0:
            print("✅ Compilation successful")
        else:
            print("❌ Compilation errors found")
            print(result.stderr[:500])
    except subprocess.TimeoutExpired:
        print("⚠️  Compilation check timed out")

if __name__ == "__main__":
    main()
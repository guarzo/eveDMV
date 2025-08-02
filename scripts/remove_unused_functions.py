#!/usr/bin/env python3
"""
Remove unused functions from Elixir files based on dialyzer output.
"""
import re
import sys
import os
from collections import defaultdict

def parse_dialyzer_output(dialyzer_file):
    """Parse dialyzer output to get unused functions by file."""
    unused_by_file = defaultdict(list)
    
    with open(dialyzer_file, 'r') as f:
        for line in f:
            # Match lines like: lib/eve_dmv/contexts/intelligence/core/ml_scoring_engine.ex:600:unused_fun
            match = re.match(r'^(.*\.ex):(\d+):unused_fun\s*$', line)
            if match:
                file_path = match.group(1)
                line_num = int(match.group(2))
                unused_by_file[file_path].append(line_num)
    
    return unused_by_file

def find_function_at_line(lines, target_line):
    """Find the function definition near the target line."""
    # Dialyzer sometimes reports the line after the function ends
    # So we look backwards from the reported line
    
    for offset in range(0, min(10, target_line)):
        line_idx = target_line - offset - 1  # Convert to 0-based
        if line_idx < 0 or line_idx >= len(lines):
            continue
            
        line = lines[line_idx]
        match = re.match(r'^(\s*)(def|defp)\s+([a-zA-Z_][a-zA-Z0-9_?!]*)', line)
        if match:
            return {
                'line_idx': line_idx,
                'indent': match.group(1),
                'type': match.group(2),
                'name': match.group(3),
                'line': line_idx + 1  # Convert back to 1-based
            }
    
    return None

def find_function_end(lines, start_idx, base_indent):
    """Find the end of a function starting at start_idx."""
    indent_len = len(base_indent)
    
    for i in range(start_idx + 1, len(lines)):
        line = lines[i]
        
        # Check for 'end' at the same indent level
        if re.match(r'^' + re.escape(base_indent) + r'end\s*$', line):
            return i
        
        # If we hit another function at the same indent, we've gone too far
        if re.match(r'^' + re.escape(base_indent) + r'(def|defp)\s+', line):
            # Function without explicit end? Should not happen in valid Elixir
            return None
    
    return None

def remove_unused_functions(file_path, unused_lines, dry_run=False):
    """Remove unused functions from a file."""
    
    if not os.path.exists(file_path):
        print(f"File not found: {file_path}")
        return
    
    with open(file_path, 'r') as f:
        lines = f.readlines()
    
    # Sort lines in reverse order to avoid index shifts
    unused_lines.sort(reverse=True)
    
    functions_to_remove = []
    
    # Find all functions to remove
    for line_num in unused_lines:
        func_info = find_function_at_line(lines, line_num)
        if func_info:
            end_idx = find_function_end(lines, func_info['line_idx'], func_info['indent'])
            if end_idx is not None:
                functions_to_remove.append({
                    'name': func_info['name'],
                    'start': func_info['line_idx'],
                    'end': end_idx,
                    'line': func_info['line']
                })
            else:
                print(f"  Warning: Could not find end for function {func_info['name']} at line {func_info['line']}")
        else:
            print(f"  Warning: No function found near line {line_num}")
    
    if not functions_to_remove:
        print(f"  No functions to remove from {file_path}")
        return
    
    # Remove duplicates and sort by start line (descending)
    seen = set()
    unique_functions = []
    for func in sorted(functions_to_remove, key=lambda x: x['start'], reverse=True):
        key = (func['start'], func['end'])
        if key not in seen:
            seen.add(key)
            unique_functions.append(func)
    
    print(f"\n{file_path}:")
    print(f"  Found {len(unique_functions)} unused functions to remove")
    
    if dry_run:
        for func in unique_functions:
            print(f"  - {func['name']} (lines {func['start']+1}-{func['end']+1})")
        return
    
    # Remove functions
    for func in unique_functions:
        print(f"  Removing {func['name']} (lines {func['start']+1}-{func['end']+1})")
        # Remove the function lines
        del lines[func['start']:func['end']+1]
    
    # Create backup
    backup_path = f"{file_path}.backup"
    if not os.path.exists(backup_path):
        with open(backup_path, 'w') as f:
            f.writelines(lines)
    
    # Write updated file
    with open(file_path, 'w') as f:
        f.writelines(lines)
    
    print(f"  Saved updated file (backup at {backup_path})")

def main():
    if len(sys.argv) < 2:
        print("Usage: remove_unused_functions.py <dialyzer_output> [--dry-run] [--module MODULE_PATTERN]")
        sys.exit(1)
    
    dialyzer_file = sys.argv[1]
    dry_run = '--dry-run' in sys.argv
    module_pattern = None
    
    for i, arg in enumerate(sys.argv):
        if arg == '--module' and i + 1 < len(sys.argv):
            module_pattern = sys.argv[i + 1]
    
    if dry_run:
        print("=== DRY RUN MODE ===")
    
    # Parse dialyzer output
    unused_by_file = parse_dialyzer_output(dialyzer_file)
    
    # Filter by module pattern if specified
    if module_pattern:
        unused_by_file = {
            f: lines for f, lines in unused_by_file.items() 
            if module_pattern in f
        }
    
    total_files = len(unused_by_file)
    total_functions = sum(len(lines) for lines in unused_by_file.values())
    
    print(f"\nFound {total_functions} unused functions across {total_files} files")
    
    # Show top files by unused function count
    print("\nTop files by unused function count:")
    sorted_files = sorted(unused_by_file.items(), key=lambda x: len(x[1]), reverse=True)
    for file_path, lines in sorted_files[:10]:
        print(f"  {len(lines):3d} - {file_path}")
    
    # Process each file
    for file_path, unused_lines in sorted_files:
        remove_unused_functions(file_path, unused_lines, dry_run)

if __name__ == '__main__':
    main()
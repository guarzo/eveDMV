#!/usr/bin/env python3
"""Remove all functions marked with TODO: Remove unused function."""

import re
import sys

def find_function_end(lines, start_idx, base_indent):
    """Find the end of a function definition."""
    i = start_idx + 1
    in_string = False
    
    while i < len(lines):
        line = lines[i]
        
        # Skip empty lines
        if line.strip() == '':
            i += 1
            continue
        
        current_indent = len(line) - len(line.lstrip())
        
        # Check if we're at the same or lower indentation level
        if current_indent <= base_indent and line.strip():
            # If it's an 'end' at the same level, include it
            if line.strip() == 'end' and current_indent == base_indent:
                return i
            else:
                # We've gone past the function
                return i - 1
        
        i += 1
    
    return len(lines) - 1

def remove_marked_functions(content):
    """Remove all functions marked with TODO: Remove unused function."""
    lines = content.split('\n')
    
    # First pass: identify all lines to remove
    lines_to_remove = set()
    i = 0
    
    while i < len(lines):
        line = lines[i]
        
        # Check for the TODO marker
        if "# TODO: Remove unused function" in line:
            # Mark this line for removal
            lines_to_remove.add(i)
            
            # Look for the function definition after the TODO
            j = i + 1
            while j < len(lines) and lines[j].strip() == '':
                lines_to_remove.add(j)
                j += 1
            
            # Check if the next non-empty line is a function definition
            if j < len(lines) and re.match(r'^\s*defp?\s+\w+', lines[j]):
                func_start = j
                indent = len(lines[j]) - len(lines[j].lstrip())
                
                # Find the end of the function
                func_end = find_function_end(lines, func_start, indent)
                
                # Mark all lines in the function for removal
                for k in range(func_start, func_end + 1):
                    lines_to_remove.add(k)
                
                print(f"Marked function at line {func_start + 1} for removal (ends at {func_end + 1})")
                
                # Continue from after the function
                i = func_end + 1
                continue
        
        i += 1
    
    # Second pass: build the result without the marked lines
    result_lines = []
    for i, line in enumerate(lines):
        if i not in lines_to_remove:
            result_lines.append(line)
    
    # Third pass: clean up multiple blank lines
    final_lines = []
    prev_blank = False
    
    for line in result_lines:
        if line.strip() == '':
            if not prev_blank:
                final_lines.append(line)
            prev_blank = True
        else:
            final_lines.append(line)
            prev_blank = False
    
    return '\n'.join(final_lines)

def main():
    if len(sys.argv) != 2:
        print("Usage: remove_all_marked_functions.py <file>")
        sys.exit(1)
    
    file_path = sys.argv[1]
    
    try:
        with open(file_path, 'r') as f:
            content = f.read()
        
        # Count TODO markers before
        todo_count_before = content.count("# TODO: Remove unused function")
        print(f"Found {todo_count_before} TODO markers")
        
        new_content = remove_marked_functions(content)
        
        # Count TODO markers after
        todo_count_after = new_content.count("# TODO: Remove unused function")
        print(f"Remaining TODO markers: {todo_count_after}")
        
        with open(file_path, 'w') as f:
            f.write(new_content)
        
        print(f"Successfully processed {file_path}")
        
    except Exception as e:
        print(f"Error processing {file_path}: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
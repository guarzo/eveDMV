#!/usr/bin/env python3
"""Remove functions marked with TODO: Remove unused function comments."""

import re
import sys

def remove_marked_functions(content):
    """Remove functions that are marked with TODO: Remove unused function."""
    lines = content.split('\n')
    result_lines = []
    i = 0
    
    while i < len(lines):
        line = lines[i]
        
        # Check if this line has the removal marker
        if "# TODO: Remove unused function" in line:
            # Skip the comment line
            i += 1
            
            # Find the function definition
            if i < len(lines) and re.match(r'^\s*defp?\s+\w+', lines[i]):
                func_start = i
                indent = len(lines[i]) - len(lines[i].lstrip())
                
                # Skip to the end of the function
                i += 1
                while i < len(lines):
                    current_line = lines[i]
                    
                    # Skip empty lines
                    if current_line.strip() == '':
                        i += 1
                        continue
                    
                    current_indent = len(current_line) - len(current_line.lstrip())
                    
                    # Check if we've reached the end of the function
                    if current_indent <= indent and current_line.strip():
                        if current_line.strip() == 'end' and current_indent == indent:
                            i += 1  # Skip the 'end' line too
                        break
                    
                    i += 1
                
                print(f"Removed function starting at line {func_start + 1}")
                continue
        
        result_lines.append(line)
        i += 1
    
    # Clean up multiple blank lines
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
        print("Usage: remove_marked_dead_code.py <file>")
        sys.exit(1)
    
    file_path = sys.argv[1]
    
    try:
        with open(file_path, 'r') as f:
            content = f.read()
        
        new_content = remove_marked_functions(content)
        
        with open(file_path, 'w') as f:
            f.write(new_content)
        
        print(f"Successfully processed {file_path}")
        
    except Exception as e:
        print(f"Error processing {file_path}: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
#!/usr/bin/env python3
"""
Fix specific compilation errors found by mix compile.
"""

import re
import os
import glob

def fix_compilation_errors(content):
    """Fix specific patterns causing compilation errors."""
    
    fixes = [
        # Fix Map.putMap.put( -> Map.put(...) |> Map.put(
        (r'Map\.putMap\.put\(\((.*?), (.*?), (.*?)\), (.*?), (.*?)\)', r'Map.put(\1, \2, \3) |> Map.put(\4, \5)'),
        
        # Fix other double function calls that got merged
        (r'(\w+)\.(\w+)(\w+)\.(\w+)\(', r'\1.\2(...) |> \3.\4('),
        
        # Fix Enum.mapEnum.filter patterns that might have been missed
        (r'Enum\.map(\w+)\.(\w+)\(', r'Enum.map(...) |> \1.\2('),
        
        # Fix other broken chained calls
        (r'(\w+)\.(\w+)(\w+)\.(.*?)\((.*?)\)', r'\1.\2(\5) |> \3.\4()'),
        
        # Fix broken return statements in function chains
        (r'(\s+)\{(.*?)\}\s*end\s*\)', r'\1{\2}\n    end)'),
        
        # Fix specific patterns from previous errors
        (r'String\.splitEnum\.filter\(\((.*?)\), (.*?)\)', r'String.split(\1) |> Enum.filter(\2)'),
        (r'Enum\.filterEnum\.min_by\(\((.*?)\), (.*?)\)', r'Enum.filter(\1) |> Enum.min_by(\2)'),
    ]
    
    modified = False
    for pattern, replacement in fixes:
        if re.search(pattern, content, re.MULTILINE | re.DOTALL):
            content = re.sub(pattern, replacement, content, flags=re.MULTILINE | re.DOTALL)
            modified = True
    
    return content, modified

def fix_file(filepath):
    """Fix syntax errors in a single file."""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            original_content = f.read()
        
        fixed_content, was_modified = fix_compilation_errors(original_content)
        
        if was_modified:
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(fixed_content)
            print(f"Fixed: {filepath}")
            return True
        return False
        
    except Exception as e:
        print(f"Error processing {filepath}: {e}")
        return False

def main():
    """Fix all Elixir files with compilation errors."""
    print("Fixing compilation errors...")
    
    # Get all Elixir files
    elixir_files = glob.glob('lib/**/*.ex', recursive=True)
    
    fixed_count = 0
    for filepath in elixir_files:
        if fix_file(filepath):
            fixed_count += 1
    
    print(f"Fixed {fixed_count} files with compilation error patterns")

if __name__ == "__main__":
    main()
#!/usr/bin/env python3

import os
import re
import sys

def fix_pipeline_patterns(content):
    """Fix common single-function pipeline patterns"""
    
    # Pattern 1: variable |> Enum.function(args)
    content = re.sub(
        r'^(\s*)(\w+)\s*\|\>\s*Enum\.(count|empty\?|length)\(\)\s*$',
        r'\1Enum.\3(\2)',
        content,
        flags=re.MULTILINE
    )
    
    # Pattern 2: variable |> Enum.function(arg)  
    content = re.sub(
        r'^(\s*)(\w+)\s*\|\>\s*Enum\.(map|filter|reduce|flat_map|find|sort|sort_by|take|drop|join|split|reject|uniq|reverse|sum|max|min)\(([^)]+)\)\s*$',
        r'\1Enum.\3(\2, \4)',
        content,
        flags=re.MULTILINE
    )
    
    # Pattern 3: variable |> Map.function(args)
    content = re.sub(
        r'^(\s*)(\w+)\s*\|\>\s*Map\.(get|put|merge|delete|has_key\?|keys|values)\(([^)]+)\)\s*$',
        r'\1Map.\3(\2, \4)',
        content,
        flags=re.MULTILINE
    )
    
    # Pattern 4: variable |> String.function()
    content = re.sub(
        r'^(\s*)(\w+)\s*\|\>\s*String\.(trim|downcase|upcase|capitalize|reverse|length)\(\)\s*$',
        r'\1String.\3(\2)',
        content,
        flags=re.MULTILINE
    )
    
    # Pattern 5: variable |> simple_function()
    content = re.sub(
        r'^(\s*)(\w+)\s*\|\>\s*(length|hd|tl)\(\)\s*$',
        r'\1\3(\2)',
        content,
        flags=re.MULTILINE
    )
    
    # Pattern 6: variable |> elem(n)
    content = re.sub(
        r'^(\s*)(\w+)\s*\|\>\s*elem\((\d+)\)\s*$',
        r'\1elem(\2, \3)',
        content,
        flags=re.MULTILINE
    )
    
    return content

def fix_file(filepath):
    """Fix pipeline patterns in a single file"""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            original = f.read()
        
        fixed = fix_pipeline_patterns(original)
        
        if fixed != original:
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(fixed)
            print(f"Fixed: {filepath}")
            return True
        
        return False
    except Exception as e:
        print(f"Error processing {filepath}: {e}")
        return False

def main():
    """Fix all .ex files in lib directory"""
    fixed_count = 0
    
    for root, dirs, files in os.walk('lib'):
        for file in files:
            if file.endswith('.ex'):
                filepath = os.path.join(root, file)
                if fix_file(filepath):
                    fixed_count += 1
    
    print(f"Fixed {fixed_count} files")

if __name__ == '__main__':
    main()
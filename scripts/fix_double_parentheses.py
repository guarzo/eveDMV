#!/usr/bin/env python3

import os
import re
import glob

def fix_double_parentheses_in_file(filepath):
    """Fix double parentheses patterns like round(value)) -> round(value)"""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        
        original_content = content
        
        # Fix round(expression)) patterns - remove extra closing parenthesis
        content = re.sub(r'round\(([^)]+)\)\)', r'round(\1)', content)
        
        # Fix Float.round(expression)) patterns
        content = re.sub(r'Float\.round\(([^)]+)\)\)', r'Float.round(\1)', content)
        
        # Fix other common function patterns with double parentheses
        content = re.sub(r'trunc\(([^)]+)\)\)', r'trunc(\1)', content)
        content = re.sub(r'ceil\(([^)]+)\)\)', r'ceil(\1)', content)
        content = re.sub(r'floor\(([^)]+)\)\)', r'floor(\1)', content)
        
        # Fix malformed numbers with trailing underscores
        content = re.sub(r'\b(\d+)_+\b', r'\1', content)
        
        if content != original_content:
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(content)
            print(f"Fixed double parentheses in {filepath}")
            return True
        return False
            
    except Exception as e:
        print(f"Error processing {filepath}: {e}")
        return False

def main():
    """Fix double parentheses in all .ex files"""
    
    # Find all .ex files in lib directory
    pattern = '/workspace/lib/**/*.ex'
    files = glob.glob(pattern, recursive=True)
    
    fixed_count = 0
    
    for filepath in files:
        if fix_double_parentheses_in_file(filepath):
            fixed_count += 1
    
    print(f"Fixed double parentheses patterns in {fixed_count} files")

if __name__ == '__main__':
    main()
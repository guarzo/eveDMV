#!/usr/bin/env python3
"""
Comprehensive syntax error fix script for EVE DMV project.

This script fixes all patterns of syntax errors found in the codebase
after the bulk fix script caused compilation issues.
"""

import os
import re
import glob
from pathlib import Path

def fix_file_syntax_errors(file_path):
    """Fix all syntax error patterns in a single file."""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        original_content = content
        
        # Pattern 1: Fix missing closing parentheses in function calls
        content = re.sub(r'div\(length\([^)]+\), 2\b(?!\))', r'\g<0>)', content)
        
        # Pattern 2: Fix broken Enum chains like "Enum.filter() |> Enum.map((data, condition), fn)"
        content = re.sub(r'Enum\.filter\(\) \|> Enum\.map\(\(([^,]+), ([^)]+)\), (fn[^}]+})\)', r'Enum.filter(\1, \2) |> Enum.map(\3)', content)
        content = re.sub(r'Enum\.take\(\) \|> Enum\.each\(\(([^,]+), ([^)]+)\), (fn[^}]+end)\)', r'Enum.take(\1, \2) |> Enum.each(\3)', content)
        
        # Pattern 3: Fix malformed type specs
        content = re.sub(r'context_name\(\), context_name\(\(, ([^}]+}\])', r'context_name(), context_name(), \1', content)
        
        # Pattern 4: Fix broken pipe chains with function calls
        content = re.sub(r'@([A-Za-z_]+)\.([a-z_]+) \|> ([A-Za-z_]+)\.([a-z_]+)\(\(([^,]+), \), ([^)]+)\)', r'\5 |> \1.\2() |> \3.\4(\6)', content)
        content = re.sub(r'([a-zA-Z_]+)\|> String\.upcase\(\(([^,]+), ([^)]+)\), ([^)]+)\)', r'\2 |> \1 |> String.upcase() |> \4', content)
        
        # Pattern 5: Fix broken Enum.map_join calls
        content = re.sub(r'Enum\.map_join \|> String\.upcase\(\(([^,]+), ([^,]+), ([^)]+)\), ([^)]+)\)', r'\1 |> Enum.map_join(\2, \3) |> String.upcase() |> \4', content)
        
        # Pattern 6: Fix malformed Enum.filter and Enum.map chains in contexts.ex
        content = re.sub(r'@contexts \|> Enum\.filter \|> Map\.new\(\(contexts, ([^)]+)\)\)', r'@contexts |> Enum.filter(\1) |> Map.new()', content)
        content = re.sub(r'Enum\.filter\(\(contexts, ([^)]+)\)', r'@contexts |> Enum.filter(\1) |> Map.keys()', content)
        
        # Pattern 7: Fix missing parentheses in contexts.ex methods
        content = re.sub(r'context\.Enum\.filter\(subscribes, ([^)]+)\)', r'context.subscribes |> Enum.filter(\1)', content)
        content = re.sub(r'context\.Enum\.flat_map\(\) \|> Enum\.uniq\(\(subscribes, ([^)]+)\)\)', r'context.subscribes |> Enum.flat_map(\1) |> Enum.uniq()', content)
        
        # Pattern 8: Fix missing closing parentheses in various contexts
        content = re.sub(r'\bif\([^)]+, do: [^,]+, else: [^)]+\b(?!\))', r'\g<0>)', content)
        
        # Pattern 9: Fix malformed function arguments with extra commas/parentheses
        content = re.sub(r', \), ([^)]+)\)', r', \1)', content)
        content = re.sub(r'\(\(([^,]+), ([^)]+)\), ([^)]+)\)', r'(\1, \2, \3)', content)
        
        # Pattern 10: Fix and/&& syntax errors
        content = re.sub(r'\) and ([^>]+) ->', r') && \1 ->', content)
        
        # Pattern 11: Fix prepare/prepareMacro issues
        content = re.sub(r'prepareMacro\.escape\(\(', r'prepare(Macro.escape(', content)
        
        # Pattern 12: Fix missing function closures
        content = re.sub(r'(fn [^}]+)end\)\)', r'\1end))', content)
        
        # Pattern 13: Fix function call concatenations
        content = re.sub(r'([A-Za-z_]+)\.([a-z_]+)([A-Za-z_]+)\.([a-z_]+)\(\(', r'\1.\2(\3.\4(', content)
        
        # Pattern 14: Fix missing parentheses in calculate_regularity
        content = re.sub(r'defp calculate_regularity\(values do', r'defp calculate_regularity(values) do', content)
        
        # Only write if content changed
        if content != original_content:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(content)
            return True
        
        return False
            
    except Exception as e:
        print(f"Error processing {file_path}: {e}")
        return False

def main():
    """Fix syntax errors in all Elixir files."""
    base_dir = Path("/workspace")
    elixir_files = list(base_dir.glob("lib/**/*.ex"))
    
    fixed_count = 0
    
    print(f"Processing {len(elixir_files)} Elixir files...")
    
    for file_path in elixir_files:
        if fix_file_syntax_errors(file_path):
            fixed_count += 1
            print(f"Fixed: {file_path}")
    
    print(f"\nSummary:")
    print(f"Files processed: {len(elixir_files)}")
    print(f"Files with fixes: {fixed_count}")

if __name__ == "__main__":
    main()
#!/usr/bin/env python3
"""
Final comprehensive syntax error fix script for EVE DMV project.

This script fixes all remaining patterns of syntax errors that the
previous script didn't catch or were introduced by linters.
"""

import os
import re
import glob
from pathlib import Path

def fix_file_syntax_errors(file_path):
    """Fix all remaining syntax error patterns in a single file."""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        original_content = content
        
        # Pattern 1: Fix malformed function definitions
        content = re.sub(r'defp calculate_activity_change_percent\(\) do\s+\) do', r'defp calculate_activity_change_percent(\n         total_recent_activity,\n         recent_activities,\n         total_historical_activity,\n         member_activities\n       ) do', content)
        
        # Pattern 2: Fix broken Enum chains
        content = re.sub(r'Enum\.sort_by\(\) \|> Enum\.reduce\(([^,]+), ([^,]+), ([^,]+), ([^)]+)\)', r'\1\n    |> Enum.sort_by(\2)\n    |> Enum.reduce(\3, \4)', content)
        content = re.sub(r'Enum\.flat_map\(\) \|> Enum\.uniq\(([^,]+), ([^)]+), \s*$', r'\1\n      |> Enum.flat_map(\2)\n      |> Enum.uniq()', content, flags=re.MULTILINE)
        content = re.sub(r'Enum\.group_by\(\) \|> Enum\.max_by\(([^,]+), ([^,]+), ([^)]+) end, ([^)]+)\)', r'\1\n    |> Enum.group_by(\2)\n    |> Enum.max_by(\3, \4)', content)
        content = re.sub(r'Enum\.with_index\(\) \|> Enum\.find\(\(([^)]+)\), ([^)]+)\)', r'\1\n    |> Enum.with_index()\n    |> Enum.find(\2)', content)
        
        # Pattern 3: Fix broken function calls
        content = re.sub(r'round\(([^)]+)\), \s*$', r'round(\1)', content, flags=re.MULTILINE)
        content = re.sub(r'first\.NaiveDateTime\.to_string\(([^)]+)\)\)', r'NaiveDateTime.to_string(\1)', content)
        
        # Pattern 4: Fix malformed Enum.filter patterns
        content = re.sub(r'Enum\.filter\(\(([^,]+), ([^)]+)\)\s*$', r'\1 |> Enum.filter(\2)', content, flags=re.MULTILINE)
        content = re.sub(r'Enum\.map\(\(([^,]+), ([^)]+)\)\s*$', r'\1 |> Enum.map(\2)', content, flags=re.MULTILINE)
        
        # Pattern 5: Fix broken defp function headers
        content = re.sub(r'defp add_to_cluster\(\) do\s+\) do', r'defp add_to_cluster(\n    killmail,\n    [current_cluster | rest_clusters],\n    max_time_gap_minutes,\n    same_system_only\n  ) do', content)
        
        # Pattern 6: Fix missing/extra parentheses
        content = re.sub(r'length\(kills end', r'length(kills)', content)
        content = re.sub(r'\|> elem\(0\)  end', r'|> elem(0)', content)
        content = re.sub(r'round\(([^)]+)\)\)', r'round(\1)', content)
        
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
    """Fix final syntax errors in all Elixir files."""
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
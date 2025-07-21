#!/usr/bin/env python3
"""
Fix the specific remaining broken patterns from system reminders.
"""

import re
import os
import glob

def fix_specific_patterns(content):
    """Fix specific broken patterns."""
    
    fixes = [
        # Fix |> Enum.empty?(value) -> Enum.empty?(value)
        (r'if \|> Enum\.empty\?\((\w+)\) do', r'if Enum.empty?(\1) do'),
        
        # Fix case |> Map.get(map, key) -> case Map.get(map, key)
        (r'case \|> Map\.get\(', r'case Map.get('),
        
        # Fix case |> String.split(path, "_") -> case String.split(path, "_")
        (r'case \|> String\.split\(', r'case String.split('),
        
        # Fix case |> Enum.find(list, fn -> case Enum.find(list, fn
        (r'case \|> Enum\.find\(', r'case Enum.find('),
        
        # Fix @Enum.filter -> Enum.filter 
        (r'@Enum\.filter\(', r'Enum.filter('),
        
        # Fix not |> String.contains? -> not String.contains?
        (r'not \|> String\.contains\?\(', r'not String.contains?('),
        
        # Fix not |> Enum.any? -> not Enum.any?
        (r'not \|> Enum\.any\?\(', r'not Enum.any?('),
        
        # Fix Enum.filterEnum.min_by -> Enum.filter(...) |> Enum.min_by
        (r'Enum\.filterEnum\.min_by\(\((.*?)\), (.*?)\)', r'Enum.filter(\1) |> Enum.min_by(\2)'),
        
        # Fix Enum.sort_byEnum.with_index -> Enum.sort_by(...) |> Enum.with_index
        (r'Enum\.sort_byEnum\.with_index\(\((.*?)\), (.*?)\)', r'Enum.sort_by(\1) |> Enum.with_index(\2)'),
        
        # Fix other double patterns
        (r'Enum\.flat_mapEnum\.uniq\(\((.*?)\), (.*?)\)', r'Enum.flat_map(\1) |> Enum.uniq(\2)'),
        
        # Fix Enum.mapEnum.filter patterns
        (r'Enum\.map\((.*?), (.*?)\), (.*?)\)', r'Enum.map(\1, \2), \3'),
        
        # Fix length(Enum.uniq(), ) -> length(Enum.uniq())
        (r'length\(Enum\.uniq\(\), \)', 'length(Enum.uniq())'),
        
        # Fix Map.valuesEnum.sum -> Map.values(...) |> Enum.sum
        (r'Map\.valuesEnum\.sum\((.*?)\)', r'Map.values(\1) |> Enum.sum()'),
        
        # Fix | Enum.map(& &1.character_id)), & &1)
        (r'\| Enum\.map\(& &1\.character_id\)\), & &1\)', '|> Enum.map(& &1.character_id) |> Enum.filter(& &1)'),
        
        # Fix Enum.max_byelem -> Enum.max_by(..., elem(...))
        (r'Enum\.max_byelem\(\((.*?)\), (.*?)\)', r'Enum.max_by(\1) |> elem(\2)'),
        
        # Fix extract_used_modules_from_eventsMap.keys -> extract_used_modules_from_events(...) |> Map.keys
        (r'extract_used_modules_from_eventsMap\.keys\(\((.*?)\), \)', r'extract_used_modules_from_events(\1) |> Map.keys()'),
        
        # Fix Enum.map() |> Enum.uniq -> Enum.map(...) |> Enum.uniq
        (r'Enum\.map\(\) \|> Enum\.uniq\(\((.*?)\), \)', r'Enum.map(\1) |> Enum.uniq()'),
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
        
        fixed_content, was_modified = fix_specific_patterns(original_content)
        
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
    """Fix all Elixir files with remaining broken syntax."""
    print("Fixing remaining broken syntax patterns...")
    
    # Get all Elixir files
    elixir_files = glob.glob('lib/**/*.ex', recursive=True)
    
    fixed_count = 0
    for filepath in elixir_files:
        if fix_file(filepath):
            fixed_count += 1
    
    print(f"Fixed {fixed_count} files with remaining broken patterns")

if __name__ == "__main__":
    main()
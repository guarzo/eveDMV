#!/usr/bin/env python3
"""
Fix broken syntax patterns caused by aggressive pipeline fixes.
"""

import re
import os
import glob

def fix_broken_patterns(content):
    """Fix the broken patterns created by the aggressive script."""
    
    # Fix the most common broken patterns
    fixes = [
        # Fix Enum.with_indexEnum.map( -> Enum.with_index() |> Enum.map(
        (r'Enum\.with_indexEnum\.map\(', 'Enum.with_index() |> Enum.map('),
        
        # Fix Enum.mapEnum.uniq( -> Enum.map() |> Enum.uniq(  
        (r'Enum\.mapEnum\.uniq\(', 'Enum.map() |> Enum.uniq('),
        
        # Fix Enum.mapEnum.sum( -> Enum.map() |> Enum.sum(
        (r'Enum\.mapEnum\.sum\(', 'Enum.map() |> Enum.sum('),
        
        # Fix Enum.mapEnum.min_by( -> Enum.map() |> Enum.min_by(
        (r'Enum\.mapEnum\.min_by\(', 'Enum.map() |> Enum.min_by('),
        
        # Fix Enum.mapEnum.max( -> Enum.map() |> Enum.max(
        (r'Enum\.mapEnum\.max\(', 'Enum.map() |> Enum.max('),
        
        # Fix Enum.mapEnum.min( -> Enum.map() |> Enum.min(
        (r'Enum\.mapEnum\.min\(', 'Enum.map() |> Enum.min('),
        
        # Fix battle.Enum.sort_by( -> battle |> Enum.sort_by(
        (r'([a-zA-Z_][a-zA-Z0-9_]*)\.Enum\.sort_by\(', r'\1 |> Enum.sort_by('),
        
        # Fix window.Enum.count( -> window |> Enum.count(
        (r'([a-zA-Z_][a-zA-Z0-9_]*)\.Enum\.count\(', r'\1 |> Enum.count('),
        
        # Fix window.Enum.mapEnum.uniq( -> window |> Enum.map() |> Enum.uniq(
        (r'([a-zA-Z_][a-zA-Z0-9_]*)\.Enum\.mapEnum\.uniq\(', r'\1 |> Enum.map() |> Enum.uniq('),
        
        # Fix cluster.Enum.map( -> cluster |> Enum.map(
        (r'([a-zA-Z_][a-zA-Z0-9_]*)\.Enum\.map\(', r'\1 |> Enum.map('),
        
        # Fix cluster.Enum.flat_mapEnum.uniq_by( -> cluster |> Enum.flat_map() |> Enum.uniq_by(
        (r'([a-zA-Z_][a-zA-Z0-9_]*)\.Enum\.flat_mapEnum\.uniq_by\(', r'\1 |> Enum.flat_map() |> Enum.uniq_by('),
        
        # Fix Enum.group_byEnum.map( -> Enum.group_by() |> Enum.map(
        (r'Enum\.group_byEnum\.map\(', 'Enum.group_by() |> Enum.map('),
        
        # Fix Enum.sort_byEnum.take( -> Enum.sort_by() |> Enum.take(
        (r'Enum\.sort_byEnum\.take\(', 'Enum.sort_by() |> Enum.take('),
        
        # Fix Enum.zipEnum.group_by( -> Enum.zip() |> Enum.group_by(
        (r'Enum\.zipEnum\.group_by\(', 'Enum.zip() |> Enum.group_by('),
        
        # Fix Enum.mapaverage( -> Enum.map() |> average(
        (r'Enum\.mapaverage\(', 'Enum.map() |> average('),
        
        # Fix extract_all_participantslength( -> extract_all_participants() |> length(
        (r'extract_all_participantslength\(', 'extract_all_participants() |> length('),
        
        # Fix to_stringString.replace( -> to_string() |> String.replace(
        (r'to_stringString\.replace\(', 'to_string() |> String.replace('),
        
        # Fix Enum.filterEnum.min_by( -> Enum.filter() |> Enum.min_by(
        (r'Enum\.filterEnum\.min_by\(', 'Enum.filter() |> Enum.min_by('),
        
        # Fix Map.getEnum.map( -> Map.get() |> Enum.map(
        (r'Map\.getEnum\.map\(', 'Map.get() |> Enum.map('),
        
        # Fix String.splitEnum.filter( -> String.split() |> Enum.filter(  
        (r'String\.splitEnum\.filter\(', 'String.split() |> Enum.filter('),
        
        # Fix Ash.Query.filterAsh.read_one( -> Ash.Query.filter() |> Ash.read_one(
        (r'Ash\.Query\.filterAsh\.read_one\(', 'Ash.Query.filter() |> Ash.read_one('),
    ]
    
    modified = False
    for pattern, replacement in fixes:
        if re.search(pattern, content):
            content = re.sub(pattern, replacement, content)
            modified = True
    
    return content, modified

def fix_file(filepath):
    """Fix syntax errors in a single file."""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            original_content = f.read()
        
        fixed_content, was_modified = fix_broken_patterns(original_content)
        
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
    """Fix all Elixir files with broken syntax."""
    print("Fixing broken syntax patterns...")
    
    # Get all Elixir files
    elixir_files = glob.glob('lib/**/*.ex', recursive=True)
    
    fixed_count = 0
    for filepath in elixir_files:
        if fix_file(filepath):
            fixed_count += 1
    
    print(f"Fixed {fixed_count} files with broken syntax patterns")

if __name__ == "__main__":
    main()
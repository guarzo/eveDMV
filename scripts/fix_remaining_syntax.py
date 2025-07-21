#!/usr/bin/env python3
"""
Fix the remaining specific syntax issues.
"""

import re
import os
import glob

def fix_remaining_issues(content):
    """Fix the specific remaining issues."""
    
    fixes = [
        # Fix broken patterns from the system reminders
        
        # Fix: centroid: euclidean_distance(extract_numeric_features(features),
        # Should be: centroid: extract_numeric_features(features),
        (r'centroid: euclidean_distance\(extract_numeric_features\(features\),', 'centroid: extract_numeric_features(features),'),
        
        # Fix: Enum.map() |> Enum.min_by((features, fn feature_vector ->
        # Should be: features |> Enum.min_by(fn feature_vector ->
        (r'Enum\.map\(\) \|> Enum\.min_by\(\((features), (fn .*? ->)', r'\1 |> Enum.min_by(\2'),
        
        # Fix: Enum.with_index(centroids), fn {centroid, _index} ->
        # Should be: Enum.with_index(centroids) |> Enum.min_by(fn {centroid, _index} ->
        (r'Enum\.with_index\(centroids\), (fn \{centroid, _index\} ->)', r'Enum.with_index(centroids) |> Enum.min_by(\1'),
        
        # Fix Enum.sort_byDateTime.to_unix(  
        (r'Enum\.sort_byDateTime\.to_unix\(', 'clusters |> Enum.sort_by(fn cluster -> DateTime.to_unix('),
        
        # Fix: |> div(Enum.sum(), length(cluster.members))
        # Should be: |> Enum.sum() |> Kernel.div(length(cluster.members))
        (r'\|> div\(Enum\.sum\(\), length\(cluster\.members\)\)', '|> Enum.sum() |> Kernel.div(length(cluster.members))'),
        
        # Fix: |> Enum.map(Enum.with_index(), fn {cluster, phase_index} ->
        # Should be: |> Enum.with_index() |> Enum.map(fn {cluster, phase_index} ->
        (r'\|> Enum\.map\(Enum\.with_index\(\), (fn \{cluster, phase_index\} ->)', r'|> Enum.with_index() |> Enum.map(\1'),
        
        # Fix broken function definition lines that got merged
        (r'(\w+) \|> Enum\.map\((fn .*? ->)$', r'\1\n    |> Enum.map(\2'),
        
        # Fix math.log() calls - should be :math.log()
        (r'math\.log\(\)', ':math.log()'),
        
        # Fix length(window.killmails) |> :max(math.log(), 0.1)
        # Should be: max(length(window.killmails), 0.1)
        (r'length\(window\.killmails\) \|> :max\(:math\.log\(\), 0\.1\)', 'max(length(window.killmails), 0.1)'),
        
        # Fix more broken pipeline patterns
        (r'(\w+\.killmails) \|> Enum\.map\((& &1\.victim_ship_type_id)\) \|> Enum\.uniq\(\)', r'\1 |> Enum.map(\2) |> Enum.uniq()'),
        
        # Fix cases where function arguments got misplaced
        (r'Enum\.map\((.*?), &extract_numeric_features/1\)', r'Enum.map(\1, &extract_numeric_features/1)'),
        
        # Fix specific broken case in tactical_phase_detector
        (r'window \|> Enum\.map\(& &1\.victim_ship_type_id\) \|> Enum\.uniq\(\)', 'window.killmails |> Enum.map(& &1.victim_ship_type_id) |> Enum.uniq()'),
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
        
        fixed_content, was_modified = fix_remaining_issues(original_content)
        
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
    
    print(f"Fixed {fixed_count} files with remaining broken syntax patterns")

if __name__ == "__main__":
    main()
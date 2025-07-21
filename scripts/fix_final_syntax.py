#!/usr/bin/env python3
"""
Fix the final stubborn syntax issues.
"""

import re
import os
import glob

def fix_final_issues(content):
    """Fix the final stubborn issues."""
    
    fixes = [
        # Fix the broken DateTime.to_unix pattern from system reminder
        # clusters |> Enum.sort_by(fn cluster -> DateTime.to_unix((clusters, fn cluster ->
        # Should be: clusters |> Enum.sort_by(fn cluster ->
        (r'clusters \|> Enum\.sort_by\(fn cluster -> DateTime\.to_unix\(\(clusters, fn cluster ->', 'clusters |> Enum.sort_by(fn cluster ->'),
        
        # Fix broken multiline Enum.map patterns
        (r'cluster\.members\s+\|> Enum\.map\(', 'cluster.members |> Enum.map('),
        
        # Fix broken assign_points_to_centroids function 
        (r'features \|> Enum\.min_by\(fn feature_vector ->\s+closest_centroid_index =', 
         '''features |> Enum.map(fn feature_vector ->
      closest_centroid_index ='''),
        
        # Fix the broken function that should return a tuple but is missing the return
        (r'(\s+)\{feature_vector, closest_centroid_index\}\s+end\)', r'\1{feature_vector, closest_centroid_index}\n    end)'),
        
        # Fix other multiline formatting issues
        (r'(\w+\.members)\s+\|>', r'\1 |>'),
        
        # Fix specific broken pattern in outcome_recommendation_engine.ex
        (r'(\w+) =\s+\[\s*\|\s*(\w+)\]\s*end', r'\1 = [\2]'),
        
        # Fix malformed function definitions
        (r'defp (\w+)\((.*?)\) do\s+(\w+) =\s+\[\s*(\w+)\s*\|\s*(\w+)\s*\]', 
         r'defp \1(\2) do\n    \3 = [\5 | \4]'),
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
        
        fixed_content, was_modified = fix_final_issues(original_content)
        
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
    """Fix all Elixir files with final broken syntax."""
    print("Fixing final broken syntax patterns...")
    
    # Get all Elixir files
    elixir_files = glob.glob('lib/**/*.ex', recursive=True)
    
    fixed_count = 0
    for filepath in elixir_files:
        if fix_file(filepath):
            fixed_count += 1
    
    print(f"Fixed {fixed_count} files with final broken syntax patterns")

if __name__ == "__main__":
    main()
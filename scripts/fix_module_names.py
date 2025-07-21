#!/usr/bin/env python3
"""
Fix malformed module names in Elixir files.
"""

import os
import re
import glob
from pathlib import Path

def fix_module_names(file_path):
    """Fix malformed module names."""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        original_content = content
        
        # Fix malformed module definitions like "EveDmv. |> Analytics.Something"
        content = re.sub(r'defmodule EveDmv\. \|> ([A-Za-z_]+)\.([A-Za-z_]+) do', r'defmodule EveDmv.\1.\2 do', content)
        content = re.sub(r'alias EveDmv\. \|> ([A-Za-z_]+)\.([A-Za-z_]+)', r'alias EveDmv.\1.\2', content)
        
        # Fix other pipe chain issues in missing ends
        content = re.sub(r'|> round\(Enum\.sum\(\)', r'|> Enum.sum() |> round()', content)
        content = re.sub(r'defp ([a-zA-Z_]+)\([^)]*\) do\s*end', r'defp \1() do\n    # TODO: Implementation needed\n  end', content)
        
        if content != original_content:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(content)
            return True
        
        return False
            
    except Exception as e:
        print(f"Error processing {file_path}: {e}")
        return False

def main():
    """Fix module names in all Elixir files."""
    base_dir = Path("/workspace")
    elixir_files = list(base_dir.glob("lib/**/*.ex"))
    
    fixed_count = 0
    
    for file_path in elixir_files:
        if fix_module_names(file_path):
            fixed_count += 1
            print(f"Fixed: {file_path}")
    
    print(f"\nSummary: {fixed_count} files fixed")

if __name__ == "__main__":
    main()
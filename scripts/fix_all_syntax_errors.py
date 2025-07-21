#!/usr/bin/env python3
"""
Fix all common syntax errors introduced by the bulk pipeline fix.
"""

import re
import os
import glob

def fix_syntax_patterns(content):
    """Fix all identified broken syntax patterns."""
    
    # Pattern 1: Fix "if |> condition do" -> "if condition do"
    content = re.sub(r'if\s+\|\>\s+([^d][^o]+)\s+do', r'if \1 do', content)
    
    # Pattern 2: Fix "case |> expression do" -> "case expression do"  
    content = re.sub(r'case\s+\|\>\s+([^d][^o]+)\s+do', r'case \1 do', content)
    
    # Pattern 3: Fix broken Enum chains like "Enum.filterEnum.map("
    content = re.sub(r'Enum\.(\w+)Enum\.(\w+)\(', r'Enum.\1() |> Enum.\2(', content)
    
    # Pattern 4: Fix "String.splitEnum.map(" -> "String.split() |> Enum.map("
    content = re.sub(r'String\.(\w+)Enum\.(\w+)\(', r'String.\1() |> Enum.\2(', content)
    
    # Pattern 5: Fix "Map.putMap.put(" -> proper pipe chain
    content = re.sub(r'Map\.putMap\.put\(', 'Map.put() |> Map.put(', content)
    
    # Pattern 6: Fix "Ash.Changeset.change_attributeAsh.Changeset.change_attribute("
    content = re.sub(r'Ash\.Changeset\.change_attributeAsh\.Changeset\.change_attribute\(', 
                     'Ash.Changeset.change_attribute() |> Ash.Changeset.change_attribute(', content)
    
    # Pattern 7: Fix "Enum.sort_byEnum.with_index(" -> "Enum.sort_by() |> Enum.with_index("
    content = re.sub(r'Enum\.sort_byEnum\.(\w+)\(', r'Enum.sort_by() |> Enum.\1(', content)
    
    # Pattern 8: Fix "Enum.max_bythen(" -> "Enum.max_by() |> then("
    content = re.sub(r'Enum\.max_bythen\(', 'Enum.max_by() |> then(', content)
    
    # Pattern 9: Fix misplaced commas in function chains
    content = re.sub(r'\|\>\s+([A-Za-z_]\w*(?:\.[A-Za-z_]\w*)*)\(([^,)]+),\s+\)', r'|> \1(\2)', content)
    
    # Pattern 10: Fix "variable, |> function(" -> "variable |> function("
    content = re.sub(r'(\w+),\s+\|\>', r'\1 |>', content)
    
    # Pattern 11: Fix "Map.getparse_datetime(" -> "Map.get() |> parse_datetime("
    content = re.sub(r'Map\.get(\w+)\(', r'Map.get() |> \1(', content)
    
    # Pattern 12: Fix "Repo.allEnum.map(" -> "Repo.all() |> Enum.map("
    content = re.sub(r'Repo\.(\w+)Enum\.(\w+)\(', r'Repo.\1() |> Enum.\2(', content)
    
    # Pattern 13: Fix "List.firstEnum.map(" -> "List.first() |> Enum.map("
    content = re.sub(r'List\.(\w+)Enum\.(\w+)\(', r'List.\1() |> Enum.\2(', content)
    
    # Pattern 14: Fix "defp func(args) Enum.map(do," -> "defp func(args) do\n    Enum.map("
    content = re.sub(r'(defp?\s+\w+\([^)]*\))\s+(Enum\.\w+)\(([^d][^o]+)\s+do,', r'\1 do\n    \2(\3,', content)
    
    # Pattern 15: Fix misplaced pipes in case statements
    content = re.sub(r'case\s+\|\>\s+Map\.get\(([^,]+),\s*([^)]+)\)\s*do', r'case Map.get(\1, \2) do', content)
    
    return content

def fix_file(filepath):
    """Fix syntax errors in a single file."""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            original_content = f.read()
        
        fixed_content = fix_syntax_patterns(original_content)
        
        if fixed_content != original_content:
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(fixed_content)
            print(f"Fixed: {filepath}")
            return True
        return False
        
    except Exception as e:
        print(f"Error processing {filepath}: {e}")
        return False

def main():
    """Fix all Elixir files with syntax errors."""
    print("Fixing syntax errors in all Elixir files...")
    
    # Get all Elixir files
    elixir_files = glob.glob('lib/**/*.ex', recursive=True)
    elixir_files.extend(glob.glob('lib/**/*.exs', recursive=True))
    
    fixed_count = 0
    for filepath in elixir_files:
        if fix_file(filepath):
            fixed_count += 1
    
    print(f"\nFixed {fixed_count} files")

if __name__ == "__main__":
    main()
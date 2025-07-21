#!/usr/bin/env python3
"""
Fix malformed pipe operators and other syntax issues in Elixir files.
"""

import re
import os
import glob

def fix_malformed_pipes(content):
    """Fix common pipe operator issues."""
    
    # Fix: |> case pattern -> case pattern
    content = re.sub(r'\|\>\s*case\s+', 'case ', content)
    
    # Fix: Enum.something |> pattern at start of line
    content = re.sub(r'^(\s*)\|\>\s*(Enum\.|Map\.|List\.)', r'\1\2', content, flags=re.MULTILINE)
    
    # Fix: |> String.contains? pattern
    content = re.sub(r'\|\>\s*(String\.contains\?\([^)]+\))', r'\1', content)
    
    # Fix: Enum.sum( |> Enum.map(...)) patterns
    content = re.sub(r'Enum\.sum\(\s*\|\>\s*(Enum\.map\([^)]+\))\s*\)', r'Enum.sum(\1)', content)
    
    # Fix: List.first(attacks) |> ["character_name"] pattern
    content = re.sub(r'List\.first\(([^)]+)\)\s*\|\>\s*\["([^"]+)"\]', r'List.first(\1)["\\2"]', content)
    
    # Fix: |> then pattern at start of line
    content = re.sub(r'^(\s*)\|\>\s*(then\()', r'\1\2', content, flags=re.MULTILINE)
    
    # Fix patterns like: something |> Enum.sum(values) / length
    content = re.sub(r'(\|\>\s*)(Enum\.sum\([^)]+\)\s*/\s*[^|]+)', r'\2', content)
    
    # Fix case expressions that got pipe operators added incorrectly
    # Pattern: |> case ... -> case ...
    content = re.sub(r'\|\>\s+case\b', 'case', content)
    
    return content

def fix_variable_naming_issues(content):
    """Fix common variable naming readability issues."""
    
    # Fix _underscore variables that should be regular variables (but keep actual unused vars)
    # This is complex, so we'll be conservative and only fix obvious cases
    
    # Fix patterns like: _killmail when it's clearly being used
    content = re.sub(r'(\w+)\s*=\s*([A-Z]\w+)\.(\w+)\(([^)]*_killmail[^)]*)\)', 
                     lambda m: m.group(0).replace('_killmail', 'killmail'), content)
    
    return content

def fix_function_complexity_issues(content):
    """Fix simple function complexity issues."""
    
    # Break up long cond chains by adding better spacing
    content = re.sub(r'(cond do\s*\n)((?:\s*[^->\n]+\s*->[^->\n]+\n)+)', 
                     lambda m: m.group(1) + '\n'.join(
                         '  ' + line.strip() if line.strip() and not line.strip().startswith('cond') else line
                         for line in m.group(2).splitlines()
                     ) + '\n', content, flags=re.MULTILINE | re.DOTALL)
    
    return content

def process_file(file_path):
    """Process a single file to fix various issues."""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            original_content = f.read()
        
        content = original_content
        
        # Apply fixes
        content = fix_malformed_pipes(content)
        content = fix_variable_naming_issues(content)
        content = fix_function_complexity_issues(content)
        
        # Only write if changed
        if content != original_content:
            # Create backup
            backup_path = file_path + '.malformed_bak'
            with open(backup_path, 'w', encoding='utf-8') as f:
                f.write(original_content)
            
            # Write fixed content
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(content)
            
            print(f"Fixed malformed patterns in: {file_path}")
            return True
        
        return False
    
    except Exception as e:
        print(f"Error processing {file_path}: {e}")
        return False

def main():
    """Main function to process files."""
    
    # Files known to have parsing errors
    problem_files = [
        'lib/eve_dmv/contexts/battle_analysis/domain/battle_metrics_calculator.ex',
        'lib/eve_dmv/contexts/battle_analysis/domain/combat_log_parser.ex',
        'lib/eve_dmv/contexts/combat_intelligence/domain/intelligence_scoring.ex',
        'lib/eve_dmv/analytics/battle_detector.ex',
        'lib/eve_dmv/contexts/combat_intelligence/domain/battle_analysis/phases/fleet_composition_analyzer.ex',
    ]
    
    fixed_count = 0
    
    # Process specific problem files first
    for file_path in problem_files:
        if os.path.exists(file_path):
            if process_file(file_path):
                fixed_count += 1
        else:
            print(f"Warning: File not found: {file_path}")
    
    # Process all .ex and .exs files for general issues
    for pattern in ['lib/**/*.ex', 'test/**/*.exs']:
        for file_path in glob.glob(pattern, recursive=True):
            # Skip backup files
            if file_path.endswith('.bak') or file_path.endswith('.malformed_bak'):
                continue
            
            if file_path not in problem_files:  # Avoid double-processing
                if process_file(file_path):
                    fixed_count += 1
    
    print(f"Fixed malformed patterns in {fixed_count} files")

if __name__ == '__main__':
    main()
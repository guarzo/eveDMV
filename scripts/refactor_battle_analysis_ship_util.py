#!/usr/bin/env python3
"""
Refactor battle_analysis_service.ex to use ShipClassificationUtility
"""

import re
import shutil

FILE_PATH = "/workspace/lib/eve_dmv/contexts/combat_intelligence/domain/battle_analysis_service.ex"

# Functions that should be removed
FUNCTIONS_TO_REMOVE = [
    "classify_ship_type_id",
    "classify_ship",
]

# Function call replacements
REPLACEMENTS = [
    # Direct calls
    ("classify_ship_type_id(",
     "ShipClassificationUtility.classify_ship_type_id("),
    ("classify_ship(",
     "ShipClassificationUtility.classify_ship("),
]

# Backup the file
shutil.copy(FILE_PATH, FILE_PATH + ".backup_ship")

# Read the file
with open(FILE_PATH, 'r') as f:
    content = f.read()

# Add the alias if not present
lines = content.split('\n')
new_lines = []
added_alias = False
in_alias_section = False

for i, line in enumerate(lines):
    # Check if we're in the alias section
    if line.strip().startswith('alias '):
        in_alias_section = True
    elif in_alias_section and not line.strip().startswith('alias '):
        # End of alias section, add our alias if not added
        if not added_alias:
            new_lines.append('  alias EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysis.Utilities.ShipClassificationUtility')
            added_alias = True
        in_alias_section = False
    
    new_lines.append(line)

content = '\n'.join(new_lines)

# Function to find and remove a function definition
def remove_function(content, func_name):
    # Special handling for classify_ship_type_id which has two definitions
    if func_name == "classify_ship_type_id":
        # Remove the main function body
        lines = content.split('\n')
        new_lines = []
        in_function = False
        skip_count = 0
        
        i = 0
        while i < len(lines):
            line = lines[i]
            
            # Check for the start of the function
            if re.match(r'^\s*defp\s+classify_ship_type_id\s*\(ship_type_id\)\s+when\s+is_integer', line):
                in_function = True
                skip_count += 1
                i += 1
                continue
            
            # Also check for the second definition
            if re.match(r'^\s*defp\s+classify_ship_type_id\s*\(_\)', line):
                skip_count += 1
                i += 1
                continue
                
            # If we're in the main function
            if in_function:
                # Check if this is the end
                if line.strip() == 'end':
                    skip_count += 1
                    in_function = False
                    i += 1
                    continue
                else:
                    skip_count += 1
                    i += 1
                    continue
            
            new_lines.append(line)
            i += 1
        
        if skip_count > 0:
            print(f"Removed {func_name}: {skip_count} lines")
        return '\n'.join(new_lines)
    else:
        # Regular function removal
        escaped_name = re.escape(func_name)
        pattern = rf'^(\s*)defp?\s+{escaped_name}\s*\([^)]*\).*?\s+do\s*$'
        
        lines = content.split('\n')
        new_lines = []
        in_function = False
        indent_level = 0
        skip_count = 0
        
        for i, line in enumerate(lines):
            # Check if this is the start of the function to remove
            match = re.match(pattern, line, re.MULTILINE)
            if match and not in_function:
                in_function = True
                indent_level = len(match.group(1))
                skip_count += 1
                continue
                
            # If we're in a function to remove
            if in_function:
                # Check if we've reached the end of the function
                current_indent = len(line) - len(line.lstrip())
                
                # Skip empty lines
                if line.strip() == '':
                    skip_count += 1
                    continue
                    
                # Check if this line ends the function
                if current_indent <= indent_level:
                    if line.strip() == 'end':
                        skip_count += 1
                        in_function = False
                        continue
                    elif re.match(r'^\s*(defp?|@|alias|use|import|require)\\s', line):
                        # This is the start of something else, we're done
                        in_function = False
                        new_lines.append(line)
                        continue
                
                # Skip this line if we're still in the function
                skip_count += 1
                continue
                
            # Keep this line
            new_lines.append(line)
        
        if skip_count > 0:
            print(f"Removed {func_name}: {skip_count} lines")
        return '\n'.join(new_lines)

# Remove functions
for func_name in FUNCTIONS_TO_REMOVE:
    content = remove_function(content, func_name)

# Apply replacements
for old, new in REPLACEMENTS:
    count = content.count(old)
    if count > 0:
        content = content.replace(old, new)
        print(f"Replaced {count} occurrences of: {old} -> {new}")

# Count lines
with open(FILE_PATH, 'w') as f:
    f.write(content)

with open(FILE_PATH, 'r') as f:
    line_count = len(f.readlines())

print(f"\nComplete! New line count: {line_count}")
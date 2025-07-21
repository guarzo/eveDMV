#!/usr/bin/env python3
"""
Refactor fleet_composition_analyzer.ex to use extracted analyzers
"""

import re
import shutil

FILE_PATH = "/workspace/lib/eve_dmv/contexts/combat_intelligence/domain/battle_analysis/phases/fleet_composition_analyzer.ex"

# Functions that should be removed or delegated
FUNCTIONS_TO_REMOVE = [
    # These can be delegated to FleetSynergyAnalyzer
    "calculate_fleet_synergy",
    "calculate_dps_logi_synergy",
    "calculate_tackle_dps_synergy",
    "calculate_ewar_synergy",
    "calculate_class_compatibility",
    "calculate_range_coherence",
    "analyze_fleet_synergy",
    
    # These can be delegated to ShipClassificationAnalyzer
    "classify_ship_role",
    "classify_ship_type",
    "estimate_engagement_range",
    
    # These should be removed (duplicate constants)
    # We'll handle @ship_type_ranges and @ship_name_patterns separately
]

# Function call replacements
REPLACEMENTS = [
    # Fleet synergy replacements
    ("synergy_analysis = analyze_fleet_synergy(sides.side_a, sides.side_b, killmails)",
     "synergy_analysis = FleetSynergyAnalyzer.analyze_fleet_synergy(sides.side_a, sides.side_b, killmails)"),
    
    # Role classification replacements
    ("role = classify_ship_role(participant)",
     "role = ShipClassificationAnalyzer.classify_ship_role(participant)"),
    ("ship_type = classify_ship_type(participant)",
     "ship_type = ShipClassificationAnalyzer.classify_ship_type(participant)"),
    ("range = estimate_engagement_range(participant)",
     "range = ShipClassificationAnalyzer.estimate_engagement_range(participant)"),
     
    # Calculate fleet synergy
    ("calculate_fleet_synergy(participants)",
     "FleetSynergyAnalyzer.calculate_fleet_synergy(participants)"),
]

# Backup the file
shutil.copy(FILE_PATH, FILE_PATH + ".backup")

# Read the file
with open(FILE_PATH, 'r') as f:
    content = f.read()

# Remove module attributes that are duplicated
lines = content.split('\n')
new_lines = []
skip_ship_ranges = False
skip_ship_patterns = False

for i, line in enumerate(lines):
    # Skip @ship_type_ranges block
    if '@ship_type_ranges %{' in line:
        skip_ship_ranges = True
        continue
    if skip_ship_ranges:
        if '}' in line and line.strip() == '}':
            skip_ship_ranges = False
        continue
        
    # Skip @ship_name_patterns block  
    if '@ship_name_patterns %{' in line:
        skip_ship_patterns = True
        continue
    if skip_ship_patterns:
        if '}' in line and line.strip() == '}':
            skip_ship_patterns = False
        continue
    
    new_lines.append(line)

content = '\n'.join(new_lines)

# Function to find and remove a function definition
def remove_function(content, func_name):
    # Pattern to match function definition
    escaped_name = re.escape(func_name)
    pattern = rf'^(\s*)defp?\s+{escaped_name}\s*\([^)]*\)\s+do\s*$'
    
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
                elif re.match(r'^\s*(defp?|@|alias|use|import|require)\s', line):
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
    if old in content:
        content = content.replace(old, new)
        print(f"Replaced: {old} -> {new}")

# Update calls to local classify_ship_role to use analyzer
content = re.sub(r'(\s+)role = classify_ship_role\(', r'\1role = ShipClassificationAnalyzer.classify_ship_role(', content)
content = re.sub(r'classify_ship_role\(participant\)', 'ShipClassificationAnalyzer.classify_ship_role(participant)', content)

# Write the updated content
with open(FILE_PATH, 'w') as f:
    f.write(content)

# Count lines
with open(FILE_PATH, 'r') as f:
    line_count = len(f.readlines())

print(f"\nComplete! New line count: {line_count}")
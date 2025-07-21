#!/usr/bin/env python3
"""
Delegate fleet effectiveness functions to FleetEffectivenessCalculator
"""

import re
import shutil

FILE_PATH = "/workspace/lib/eve_dmv/contexts/combat_intelligence/domain/battle_analysis/phases/fleet_composition_analyzer.ex"

# Functions to delegate to FleetEffectivenessCalculator
FUNCTIONS_TO_DELEGATE = [
    "estimate_fleet_effectiveness",
    "calculate_firepower_potential", 
    "estimate_ship_dps_weight",
    "calculate_survivability_score",
    "calculate_average_tankiness",
    "calculate_force_multiplier_score",
    "calculate_mobility_score",
    "calculate_ewar_capability"
]

# Backup the file
shutil.copy(FILE_PATH, FILE_PATH + ".backup_effectiveness")

# Read the file
with open(FILE_PATH, 'r') as f:
    content = f.read()

# Add the FleetEffectivenessCalculator alias if not present
if 'FleetEffectivenessCalculator' not in content:
    # Find the last alias line
    alias_pattern = r'(\s*alias\s+[^\n]+\n)+'
    match = re.search(alias_pattern, content)
    if match:
        alias_end = match.end()
        # Insert new alias
        new_alias = '  alias EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysis.Engines.FleetEffectivenessCalculator\n'
        content = content[:alias_end] + new_alias + content[alias_end:]

# Function to replace function body with delegation
def delegate_function(content, func_name):
    # Find the function definition  
    pattern = rf'(\s*defp\s+{re.escape(func_name)}\s*\([^)]*\)\s+do)\s*\n(.*?)\n(\s*end)'
    
    def replacer(match):
        indent = match.group(1).split('defp')[0]
        func_def = match.group(1)
        end_line = match.group(3)
        
        # Extract parameters from function definition
        param_match = re.search(rf'{re.escape(func_name)}\s*\(([^)]*)\)', func_def)
        if param_match:
            params = param_match.group(1)
        else:
            params = ''
            
        # Create delegation call
        delegation = f"{func_def}\n{indent}  FleetEffectivenessCalculator.{func_name}({params})\n{end_line}"
        return delegation
    
    new_content, count = re.subn(pattern, replacer, content, flags=re.DOTALL | re.MULTILINE)
    
    if count > 0:
        print(f"Delegated {func_name} to FleetEffectivenessCalculator")
    else:
        print(f"Could not find {func_name}")
    
    return new_content

# Apply delegations
for func_name in FUNCTIONS_TO_DELEGATE:
    content = delegate_function(content, func_name)

# Write the updated content
with open(FILE_PATH, 'w') as f:
    f.write(content)

# Count final lines
with open(FILE_PATH, 'r') as f:
    line_count = len(f.readlines())

print(f"\nComplete! New line count: {line_count}")
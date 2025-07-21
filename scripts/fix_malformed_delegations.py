#!/usr/bin/env python3
"""
Fix malformed delegations in fleet_composition_analyzer.ex
"""

import re

FILE_PATH = "/workspace/lib/eve_dmv/contexts/combat_intelligence/domain/battle_analysis/phases/fleet_composition_analyzer.ex"

# Read the file
with open(FILE_PATH, 'r') as f:
    content = f.read()

# Functions to fix
FUNCTIONS_TO_FIX = [
    "estimate_fleet_effectiveness",
    "estimate_ship_dps_weight", 
    "calculate_average_tankiness"
]

for func_name in FUNCTIONS_TO_FIX:
    # Pattern to match malformed delegation with extra code
    escaped_name = re.escape(func_name)
    pattern = f'(\\s*defp\\s+{escaped_name}\\s*\\([^)]*\\)\\s+do)\\s*\\n.*?\\n\\s*FleetEffectivenessCalculator\\.{escaped_name}\\([^)]*\\)[^{{}}]*?\\n(\\s*end)'
    
    def replacer(match):
        func_def = match.group(1)
        end_line = match.group(2)
        
        # Extract parameters from function definition
        param_match = re.search(f'{escaped_name}\\s*\\(([^)]*)\\)', func_def)
        if param_match:
            params = param_match.group(1)
        else:
            params = ''
        
        # Create clean delegation
        return f"{func_def}\n    FleetEffectivenessCalculator.{func_name}({params})\n{end_line}"
    
    new_content, count = re.subn(pattern, replacer, content, flags=re.DOTALL | re.MULTILINE)
    
    if count > 0:
        content = new_content
        print(f"Fixed malformed delegation for {func_name}")
    else:
        print(f"Could not find malformed delegation for {func_name}")

# Write the fixed content
with open(FILE_PATH, 'w') as f:
    f.write(content)

# Count final lines
with open(FILE_PATH, 'r') as f:
    line_count = len(f.readlines())

print(f"\nComplete! New line count: {line_count}")
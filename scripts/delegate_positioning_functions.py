#!/usr/bin/env python3
"""
Delegate strategic positioning functions to StrategicPositioningAnalyzer
"""

import re
import shutil

FILE_PATH = "/workspace/lib/eve_dmv/contexts/combat_intelligence/domain/battle_analysis/phases/fleet_composition_analyzer.ex"

# Functions to delegate to StrategicPositioningAnalyzer
FUNCTIONS_TO_DELEGATE = [
    "get_participants_from_battle_analysis",
    "get_killmails_from_battle_analysis",
    "calculate_positioning_effectiveness",
    "count_total_losses",
    "analyze_range_control",
    "count_long_range_ships",
    "analyze_escape_route_utilization",
    "analyze_tactical_positioning_effectiveness", 
    "analyze_formation_integrity",
    "count_logistics_ships",
    "analyze_engagement_zones",
    "calculate_zone_intensity",
    "identify_positioning_advantages",
    "analyze_fleet_mobility",
    "count_fast_ships",
    "rate_mobility",
    "generate_positioning_recommendations"
]

# Backup the file
shutil.copy(FILE_PATH, FILE_PATH + ".backup_positioning")

# Read the file
with open(FILE_PATH, 'r') as f:
    content = f.read()

# Add the StrategicPositioningAnalyzer alias if not present
if 'StrategicPositioningAnalyzer' not in content:
    # Find the last alias line
    alias_pattern = r'(\s*alias\s+[^\n]+\n)+'
    match = re.search(alias_pattern, content)
    if match:
        alias_end = match.end()
        # Insert new alias
        new_alias = '  alias EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysis.Analyzers.StrategicPositioningAnalyzer\n'
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
        delegation = f"{func_def}\n{indent}  StrategicPositioningAnalyzer.{func_name}({params})\n{end_line}"
        return delegation
    
    new_content, count = re.subn(pattern, replacer, content, flags=re.DOTALL | re.MULTILINE)
    
    if count > 0:
        print(f"Delegated {func_name} to StrategicPositioningAnalyzer")
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
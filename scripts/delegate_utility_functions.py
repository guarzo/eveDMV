#!/usr/bin/env python3
"""
Final delegation: Utility and comparison functions to FleetCompositionUtilities
"""

import re
import shutil

FILE_PATH = "/workspace/lib/eve_dmv/contexts/combat_intelligence/domain/battle_analysis/phases/fleet_composition_analyzer.ex"

# Functions to delegate to FleetCompositionUtilities
FUNCTIONS_TO_DELEGATE = [
    # Comparison functions
    "calculate_numerical_advantage",
    "calculate_composition_advantage", 
    "identify_key_advantages",
    "calculate_experience_advantage",
    "compare_fleet_strength",
    "compare_doctrines",
    "compare_fleet_synergy",
    "compare_role_balance",
    "compare_logistical_support",
    # Prediction functions
    "predict_engagement_outcome",
    "score_advantage",
    "calculate_prediction_confidence",
    "identify_key_prediction_factors",
    "estimate_battle_duration",
    "estimate_casualties",
    "generate_overall_assessment",
    "calculate_assessment_confidence",
    "identify_primary_assessment_factors"
]

# Backup the file
shutil.copy(FILE_PATH, FILE_PATH + ".backup_utilities")

# Read the file
with open(FILE_PATH, 'r') as f:
    content = f.read()

# Add the FleetCompositionUtilities alias if not present
if 'FleetCompositionUtilities' not in content:
    # Find the last alias line
    alias_pattern = r'(\s*alias\s+[^\n]+\n)+'
    match = re.search(alias_pattern, content)
    if match:
        alias_end = match.end()
        # Insert new alias
        new_alias = '  alias EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysis.Analyzers.FleetCompositionUtilities\n'
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
        delegation = f"{func_def}\n{indent}  FleetCompositionUtilities.{func_name}({params})\n{end_line}"
        return delegation
    
    new_content, count = re.subn(pattern, replacer, content, flags=re.DOTALL | re.MULTILINE)
    
    if count > 0:
        print(f"Delegated {func_name} to FleetCompositionUtilities")
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

# Check if we've reached our goal
if line_count < 1000:
    print(f"🎉 SUCCESS! File is now under 1000 lines ({line_count} lines)")
    reduction = 2827 - line_count
    percentage = (reduction / 2827) * 100
    print(f"Total reduction: {reduction} lines ({percentage:.1f}%)")
else:
    remaining = line_count - 999
    print(f"Need {remaining} more lines to reach target")
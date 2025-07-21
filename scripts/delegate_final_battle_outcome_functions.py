#!/usr/bin/env python3
"""
Final delegation: Battle outcome analysis functions to BattleOutcomeAnalysisEngine
"""

import re
import shutil

FILE_PATH = "/workspace/lib/eve_dmv/contexts/combat_intelligence/domain/battle_analysis/phases/fleet_composition_analyzer.ex"

# Functions to delegate to BattleOutcomeAnalysisEngine
FUNCTIONS_TO_DELEGATE = [
    # Battle outcome and effectiveness functions
    "analyze_effectiveness_trends",
    "calculate_phase_intensity", 
    "determine_trend",
    "analyze_losses_by_composition",
    "analyze_side_losses",
    "classify_ship_by_type_id",
    "calculate_loss_ratio",
    "analyze_performance_vs_expected",
    "estimate_expected_performance",
    "calculate_actual_performance",
    # Critical moments functions
    "identify_critical_moments",
    "identify_kill_spikes",
    "identify_high_value_losses", 
    "identify_turning_points",
    "determine_battle_outcome",
    # Ship class performance integration
    "do_calculate_ship_class_performance",
    # Side classification support
    "split_single_group_by_engagement",
    "build_connected_component",
    "convert_ships_to_participants"
]

# Backup the file
shutil.copy(FILE_PATH, FILE_PATH + ".backup_final")

# Read the file
with open(FILE_PATH, 'r') as f:
    content = f.read()

# Add the BattleOutcomeAnalysisEngine alias if not present
if 'BattleOutcomeAnalysisEngine' not in content:
    # Find the last alias line
    alias_pattern = r'(\s*alias\s+[^\n]+\n)+'
    match = re.search(alias_pattern, content)
    if match:
        alias_end = match.end()
        # Insert new alias
        new_alias = '  alias EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysis.Engines.BattleOutcomeAnalysisEngine\n'
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
        delegation = f"{func_def}\n{indent}  BattleOutcomeAnalysisEngine.{func_name}({params})\n{end_line}"
        return delegation
    
    new_content, count = re.subn(pattern, replacer, content, flags=re.DOTALL | re.MULTILINE)
    
    if count > 0:
        print(f"Delegated {func_name} to BattleOutcomeAnalysisEngine")
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
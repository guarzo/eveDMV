#!/usr/bin/env python3
"""
Delegate battle phase functions to BattlePhaseAnalyzer
"""

import re
import shutil

FILE_PATH = "/workspace/lib/eve_dmv/contexts/combat_intelligence/domain/battle_analysis_service.ex"

# Functions to delegate
FUNCTIONS_TO_DELEGATE = [
    ("identify_battle_phases", "BattlePhaseAnalyzer"),
    ("determine_phase_type", "BattlePhaseAnalyzer"),
    ("calculate_dominant_side_for_phase", "BattlePhaseAnalyzer"),
    ("identify_key_events_in_phase", "BattlePhaseAnalyzer"),
    ("identify_phase_transitions", "BattlePhaseAnalyzer"),
    ("identify_critical_combat_phases", "BattlePhaseAnalyzer"),
    ("generate_timing_recommendations", "BattlePhaseAnalyzer"),
    ("calculate_optimal_duration", "BattlePhaseAnalyzer"),
    ("calculate_phase_importance", "BattlePhaseAnalyzer"),
]

# Backup the file
shutil.copy(FILE_PATH, FILE_PATH + ".backup_phase")

# Read the file
with open(FILE_PATH, 'r') as f:
    content = f.read()

# Add the alias if not present
if 'BattlePhaseAnalyzer' not in content:
    # Find the last alias line
    alias_pattern = r'(\s*alias\s+[^\n]+\n)+'
    match = re.search(alias_pattern, content)
    if match:
        alias_end = match.end()
        # Insert new alias before the first non-alias line
        new_alias = '  alias EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysis.Analyzers.BattlePhaseAnalyzer\n'
        content = content[:alias_end] + new_alias + content[alias_end:]

# Function to replace function body with delegation
def delegate_function(content, func_name, module_name):
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
        delegation = f"{func_def}\n{indent}  {module_name}.{func_name}({params})\n{end_line}"
        return delegation
    
    new_content, count = re.subn(pattern, replacer, content, flags=re.DOTALL | re.MULTILINE)
    
    if count > 0:
        print(f"Delegated {func_name} to {module_name}")
    else:
        print(f"Could not find {func_name}")
    
    return new_content

# Apply delegations
for func_name, module_name in FUNCTIONS_TO_DELEGATE:
    content = delegate_function(content, func_name, module_name)

# Write the updated content
with open(FILE_PATH, 'w') as f:
    f.write(content)

# Count final lines
with open(FILE_PATH, 'r') as f:
    line_count = len(f.readlines())

print(f"\nComplete! New line count: {line_count}")
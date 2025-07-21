#!/usr/bin/env python3
"""
Refactor battle_analysis_service.ex to use BattleAnalysisHelper
"""

import re
import shutil

FILE_PATH = "/workspace/lib/eve_dmv/contexts/combat_intelligence/domain/battle_analysis_service.ex"

# Functions that should be delegated
FUNCTIONS_TO_DELEGATE = [
    # BattleAnalysisHelper functions
    ("analyze_numerical_factors", "BattleAnalysisHelper"),
    ("analyze_tactical_factors", "BattleAnalysisHelper"),
    ("analyze_control_factors", "BattleAnalysisHelper"),
    ("check_support_ship_ratios", "BattleAnalysisHelper"),
    ("extract_confidence", "BattleAnalysisHelper"),
    ("extract_doctrine_patterns", "BattleAnalysisHelper"),
    ("extract_tactical_patterns", "BattleAnalysisHelper"),
    ("extract_timing_patterns", "BattleAnalysisHelper"),
    ("determine_overall_effectiveness_trend", "BattleAnalysisHelper"),
    ("calculate_battle_effectiveness", "BattleAnalysisHelper"),
    ("average", "BattleAnalysisHelper"),
    ("determine_doctrine_evolution_pattern", "BattleAnalysisHelper"),
    ("extract_doctrine_usage", "BattleAnalysisHelper"),
    ("calculate_doctrine_success_rates", "BattleAnalysisHelper"),
    ("expand_battle_by_doctrines", "BattleAnalysisHelper"),
    ("identify_most_used_doctrines", "BattleAnalysisHelper"),
    ("analyze_doctrine_effectiveness", "BattleAnalysisHelper"),
    ("calculate_doctrine_effectiveness_score", "BattleAnalysisHelper"),
    ("rate_doctrine_effectiveness", "BattleAnalysisHelper"),
    ("calculate_doctrine_usage_stability", "BattleAnalysisHelper"),
    ("find_dominant_doctrine", "BattleAnalysisHelper"),
]

# Backup the file
shutil.copy(FILE_PATH, FILE_PATH + ".backup_helpers")

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
        if not added_alias and 'BattleAnalysisHelper' not in content:
            new_lines.append('  alias EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysis.Helpers.BattleAnalysisHelper')
            added_alias = True
        in_alias_section = False
    
    new_lines.append(line)

content = '\n'.join(new_lines)

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
        # Try again with def instead of defp
        pattern2 = rf'(\s*def\s+{re.escape(func_name)}\s*\([^)]*\)\s+do)\s*\n(.*?)\n(\s*end)'
        new_content, count = re.subn(pattern2, replacer, new_content, flags=re.DOTALL | re.MULTILINE)
        if count > 0:
            print(f"Delegated {func_name} to {module_name}")
    
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

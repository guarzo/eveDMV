#!/usr/bin/env python3
"""
Refactor battle_analysis_service.ex to use DoctrineHelper
"""

import re
import shutil

FILE_PATH = "/workspace/lib/eve_dmv/contexts/combat_intelligence/domain/battle_analysis_service.ex"

# Functions that should be delegated
FUNCTIONS_TO_DELEGATE = [
    # DoctrineHelper functions
    ("identify_enemy_doctrine_patterns", "DoctrineHelper"),
    ("generate_counter_strategies", "DoctrineHelper"),
    ("calculate_counter_doctrine_priority", "DoctrineHelper"),
    ("generate_default_practice_scenarios", "DoctrineHelper"),
    ("generate_default_role_specializations", "DoctrineHelper"),
    ("generate_weakness_based_scenarios", "DoctrineHelper"),
    ("generate_tactical_drill_scenarios", "DoctrineHelper"),
    ("is_ewar_ship?", "DoctrineHelper"),
    ("is_command_ship?", "DoctrineHelper"),
    ("analyze_ewar_impact", "DoctrineHelper"),
    ("calculate_logistics_impact", "DoctrineHelper"),
    ("estimate_command_boost_effect", "DoctrineHelper"),
    ("analyze_positioning_advantages", "DoctrineHelper"),
    ("has_mixed_weapon_systems?", "DoctrineHelper"),
]

# Backup the file
shutil.copy(FILE_PATH, FILE_PATH + ".backup_doctrine")

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
        if not added_alias and 'DoctrineHelper' not in content:
            new_lines.append('  alias EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysis.Helpers.DoctrineHelper')
            added_alias = True
        in_alias_section = False
    
    new_lines.append(line)

content = '\n'.join(new_lines)

# Function to replace function body with delegation
def delegate_function(content, func_name, module_name):
    # Handle the ? in function names for Elixir
    escaped_name = re.escape(func_name)
    
    # Find the function definition  
    pattern = rf'(\s*defp\s+{escaped_name}\s*\([^)]*\)\s+do)\s*\n(.*?)\n(\s*end)'
    
    def replacer(match):
        indent = match.group(1).split('defp')[0]
        func_def = match.group(1)
        end_line = match.group(3)
        
        # Extract parameters from function definition
        param_match = re.search(rf'{escaped_name}\s*\(([^)]*)\)', func_def)
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

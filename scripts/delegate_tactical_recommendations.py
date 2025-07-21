#!/usr/bin/env python3
"""
Extract tactical recommendation functions to TacticalRecommendationEngine
"""

import re
import shutil

FILE_PATH = "/workspace/lib/eve_dmv/contexts/combat_intelligence/domain/battle_analysis_service.ex"

# Functions to delegate to TacticalRecommendationEngine
FUNCTIONS_TO_DELEGATE = [
    # Main recommendation functions
    "do_generate_tactical_recommendations",
    "generate_strategic_recommendations", 
    "perform_basic_strategic_recommendations",
    "generate_doctrine_recommendations",
    "perform_basic_doctrine_recommendations",
    "generate_training_recommendations",
    "perform_basic_training_recommendations",
    # Force multiplication functions
    "identify_force_multiplication_opportunities",
    "analyze_ewar_impact",
    "calculate_logistics_impact", 
    "estimate_command_boost_effect",
    "analyze_positioning_advantages",
    "generate_force_mult_actions",
    # Weakness and scenario functions
    "generate_weakness_based_scenarios",
    "generate_tactical_drill_scenarios",
    # Doctrine analysis functions
    "analyze_doctrine_composition_weaknesses",
    "determine_doctrine_adjustment_priority",
    "generate_doctrine_adjustment_actions",
    # Skill gap functions
    "analyze_tactical_execution_gaps",
    "generate_skill_gap_analysis",
    "estimate_current_skill_level",
    "determine_target_skill_level", 
    "create_skill_training_plan",
    "estimate_training_time",
    # Performance gap functions
    "analyze_performance_gaps",
    "check_role_coverage",
    "check_ship_synergy",
    "generate_weakness_analysis",
    "weakness_to_recommendation",
    "has_mixed_weapon_systems?",
    "calculate_weakness_score",
    "check_support_ship_ratios",
    # Helper functions
    "is_ewar_ship?",
    "is_command_ship?",
    "generate_positioning_actions"
]

# Backup the file
shutil.copy(FILE_PATH, FILE_PATH + ".backup_tactical")

# Read the file
with open(FILE_PATH, 'r') as f:
    content = f.read()

# Add the TacticalRecommendationEngine alias if not present
if 'TacticalRecommendationEngine' not in content:
    # Find the last alias line
    alias_pattern = r'(\s*alias\s+[^\n]+\n)+'
    match = re.search(alias_pattern, content)
    if match:
        alias_end = match.end()
        # Insert new alias
        new_alias = '  alias EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysis.Engines.TacticalRecommendationEngine\n'
        content = content[:alias_end] + new_alias + content[alias_end:]

# Function to replace function body with delegation
def delegate_function(content, func_name):
    # Try different function patterns
    patterns = [
        # Private function pattern
        rf'(\s*defp\s+{re.escape(func_name)}\s*\([^)]*\)\s+do)\s*\n(.*?)\n(\s*end)',
        # Public function pattern  
        rf'(\s*def\s+{re.escape(func_name)}\s*\([^)]*\)\s+do)\s*\n(.*?)\n(\s*end)'
    ]
    
    def replacer(match):
        indent = match.group(1).split('def')[0]
        func_def = match.group(1)
        end_line = match.group(3)
        
        # Extract parameters from function definition
        param_match = re.search(rf'{re.escape(func_name)}\s*\(([^)]*)\)', func_def)
        if param_match:
            params = param_match.group(1)
        else:
            params = ''
            
        # Create delegation call
        delegation = f"{func_def}\n{indent}  TacticalRecommendationEngine.{func_name}({params})\n{end_line}"
        return delegation
    
    for pattern in patterns:
        new_content, count = re.subn(pattern, replacer, content, flags=re.DOTALL | re.MULTILINE)
        if count > 0:
            print(f"Delegated {func_name} to TacticalRecommendationEngine")
            return new_content
    
    print(f"Could not find {func_name}")
    return content

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

# Check progress toward goal
if line_count < 1000:
    print(f"🎉 SUCCESS! File is now under 1000 lines ({line_count} lines)")
    reduction = 1701 - line_count
    percentage = (reduction / 1701) * 100
    print(f"Total reduction: {reduction} lines ({percentage:.1f}%)")
else:
    remaining = line_count - 999
    print(f"Need {remaining} more lines to reach target")
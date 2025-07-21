#!/usr/bin/env python3
"""
Fix malformed delegations in fleet_composition_analyzer.ex for BattleOutcomePredictor functions
"""

import re

FILE_PATH = "/workspace/lib/eve_dmv/contexts/combat_intelligence/domain/battle_analysis/phases/fleet_composition_analyzer.ex"

# Read the file
with open(FILE_PATH, 'r') as f:
    content = f.read()

# Functions to fix (those that have malformed delegations with extra code)
FUNCTIONS_TO_FIX = [
    "predict_engagement_outcome",
    "score_advantage", 
    "calculate_prediction_confidence",
    "identify_key_prediction_factors",
    "estimate_battle_duration",
    "estimate_casualties",
    "generate_overall_assessment",
    "calculate_assessment_confidence",
    "identify_primary_assessment_factors",
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
    "identify_critical_moments",
    "identify_kill_spikes",
    "identify_high_value_losses",
    "identify_turning_points",
    "determine_battle_outcome"
]

for func_name in FUNCTIONS_TO_FIX:
    # Pattern to match malformed delegation with extra code
    escaped_name = re.escape(func_name)
    
    # More flexible pattern to catch various malformed cases
    pattern = f'(\\s*defp\\s+{escaped_name}\\s*\\([^)]*\\)\\s+do)\\s*\\n\\s*\\n\\s*BattleOutcomePredictor\\.{escaped_name}\\([^)]*\\)[^{{}}]*?\\n(\\s*end)'
    
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
        indent = "    "  # 4 spaces for delegation
        return f"{func_def}\\n{indent}BattleOutcomePredictor.{func_name}({params})\\n{end_line}"
    
    new_content, count = re.subn(pattern, replacer, content, flags=re.DOTALL | re.MULTILINE)
    
    if count > 0:
        content = new_content
        print(f"Fixed malformed delegation for {func_name}")
    else:
        # Try alternative pattern for different malformed structures
        alt_pattern = f'(\\s*defp\\s+{escaped_name}\\s*\\([^)]*\\)\\s+do)[^\\n]*?BattleOutcomePredictor\\.{escaped_name}\\([^)]*\\)[^{{}}]*?(\\s*end)'
        
        def alt_replacer(match):
            func_def = match.group(1)
            end_line = match.group(2)
            
            # Extract parameters from function definition
            param_match = re.search(f'{escaped_name}\\s*\\(([^)]*)\\)', func_def)
            if param_match:
                params = param_match.group(1)
            else:
                params = ''
            
            # Create clean delegation
            indent = "    "  # 4 spaces for delegation
            return f"{func_def}\\n{indent}BattleOutcomePredictor.{func_name}({params})\\n{end_line}"
        
        alt_content, alt_count = re.subn(alt_pattern, alt_replacer, content, flags=re.DOTALL | re.MULTILINE)
        
        if alt_count > 0:
            content = alt_content
            print(f"Fixed malformed delegation for {func_name} (alternative pattern)")
        else:
            print(f"Could not find malformed delegation for {func_name}")

# Write the fixed content
with open(FILE_PATH, 'w') as f:
    f.write(content)

# Count final lines
with open(FILE_PATH, 'r') as f:
    line_count = len(f.readlines())

print(f"\\nComplete! New line count: {line_count}")
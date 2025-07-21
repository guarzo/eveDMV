#!/usr/bin/env python3
"""
Refactor outcome_analyzer.ex to use TacticalAnalysisEngine
"""

import re
import shutil

FILE_PATH = "/workspace/lib/eve_dmv/contexts/combat_intelligence/domain/battle_analysis/phases/outcome_analyzer.ex"

# Functions that should be removed
FUNCTIONS_TO_REMOVE = [
    "analyze_coordination_effectiveness",
    "analyze_target_selection_quality", 
    "analyze_timing_execution",
    "analyze_positioning_advantages",
    "identify_tactical_innovations",
    "identify_tactical_mistakes",
    "measure_tactical_adaptation",
    # Helper functions
    "analyze_command_structure",
    "analyze_target_calling",
    "analyze_movement_coordination",
    "analyze_communication_effectiveness",
    "analyze_response_times",
    "identify_coordination_failures",
    "calculate_priority_adherence",
    "calculate_target_switching_efficiency",
    "calculate_focus_fire_effectiveness",
    "calculate_engagement_timing_score",
    "calculate_tactical_timing_score",
    "calculate_retreat_timing_score",
    "calculate_strategic_positioning_score",
    "calculate_tactical_positioning_score",
    "calculate_range_control_score",
    "calculate_split_effectiveness",
    "calculate_alpha_strike_effectiveness",
    "calculate_feint_effectiveness",
    "calculate_ewar_coordination_effectiveness",
]

# Function call replacements
REPLACEMENTS = [
    ("coordination = analyze_coordination_effectiveness(coordination_data, tactical_patterns)",
     "coordination = TacticalAnalysisEngine.analyze_coordination_effectiveness(coordination_data, tactical_patterns)"),
    ("target_selection = analyze_target_selection_quality(targeting_data)",
     "target_selection = TacticalAnalysisEngine.analyze_target_selection_quality(targeting_data)"),
    ("timing = analyze_timing_execution(timing_data)",
     "timing = TacticalAnalysisEngine.analyze_timing_execution(timing_data)"),
    ("positioning = analyze_positioning_advantages(positioning_data)",
     "positioning = TacticalAnalysisEngine.analyze_positioning_advantages(positioning_data)"),
    ("innovations = identify_tactical_innovations(tactical_patterns)",
     "innovations = TacticalAnalysisEngine.identify_tactical_innovations(tactical_patterns)"),
    ("tactical_mistakes: identify_tactical_mistakes(tactical_patterns)",
     "tactical_mistakes: TacticalAnalysisEngine.identify_tactical_mistakes(tactical_patterns)"),
    ("adaptation_speed: measure_tactical_adaptation(tactical_patterns)",
     "adaptation_speed: TacticalAnalysisEngine.measure_tactical_adaptation(tactical_patterns)"),
]

# Backup the file
shutil.copy(FILE_PATH, FILE_PATH + ".backup4")

# Read the file
with open(FILE_PATH, 'r') as f:
    content = f.read()

# Add the alias if not present
lines = content.split('\n')
new_lines = []
added_alias = False

for i, line in enumerate(lines):
    # Add alias after ForceMultiplierAnalyzer alias
    if not added_alias and 'alias EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysis.Analyzers.ForceMultiplierAnalyzer' in line:
        new_lines.append(line)
        new_lines.append('  alias EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysis.Engines.TacticalAnalysisEngine')
        added_alias = True
        continue
    
    new_lines.append(line)

content = '\n'.join(new_lines)

# Function to find and remove a function definition
def remove_function(content, func_name):
    # Pattern to match function definition
    escaped_name = re.escape(func_name)
    pattern = rf'^(\s*)defp?\s+{escaped_name}\s*\([^)]*\).*?\s+do\s*$'
    
    lines = content.split('\n')
    new_lines = []
    in_function = False
    indent_level = 0
    skip_count = 0
    
    for i, line in enumerate(lines):
        # Check if this is the start of the function to remove
        match = re.match(pattern, line, re.MULTILINE)
        if match and not in_function:
            in_function = True
            indent_level = len(match.group(1))
            skip_count += 1
            continue
            
        # If we're in a function to remove
        if in_function:
            # Check if we've reached the end of the function
            current_indent = len(line) - len(line.lstrip())
            
            # Skip empty lines
            if line.strip() == '':
                skip_count += 1
                continue
                
            # Check if this line ends the function
            if current_indent <= indent_level:
                if line.strip() == 'end':
                    skip_count += 1
                    in_function = False
                    continue
                elif re.match(r'^\s*(defp?|@|alias|use|import|require)\\s', line):
                    # This is the start of something else, we're done
                    in_function = False
                    new_lines.append(line)
                    continue
            
            # Skip this line if we're still in the function
            skip_count += 1
            continue
            
        # Keep this line
        new_lines.append(line)
    
    if skip_count > 0:
        print(f"Removed {func_name}: {skip_count} lines")
    return '\n'.join(new_lines)

# Remove functions
for func_name in FUNCTIONS_TO_REMOVE:
    content = remove_function(content, func_name)

# Apply replacements
for old, new in REPLACEMENTS:
    if old in content:
        content = content.replace(old, new)
        print(f"Replaced: {old} -> {new}")

# Count lines
with open(FILE_PATH, 'w') as f:
    f.write(content)

with open(FILE_PATH, 'r') as f:
    line_count = len(f.readlines())

print(f"\nComplete! New line count: {line_count}")
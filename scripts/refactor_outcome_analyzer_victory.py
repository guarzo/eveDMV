#!/usr/bin/env python3
"""
Refactor outcome_analyzer.ex to use VictoryFactorAnalyzer
"""

import re
import shutil

FILE_PATH = "/workspace/lib/eve_dmv/contexts/combat_intelligence/domain/battle_analysis/phases/outcome_analyzer.ex"

# Functions that should be removed or delegated
FUNCTIONS_TO_REMOVE = [
    # These are now handled by VictoryFactorAnalyzer
    "identify_primary_victory_factors",
    "identify_secondary_victory_factors",
    "calculate_victory_probability",
    "calculate_factor_weights",
    "extract_victory_lessons",
    "analyze_counterfactuals",
    # Helper functions for victory factors
    "add_numerical_factors",
    "add_kill_efficiency_factors",
    "add_logistics_effectiveness_factors",
    "add_target_prioritization_factors",
    "add_positioning_factors",
    "add_timing_factors",
    "add_coordination_factors",
    "add_ewar_factors",
    "add_intelligence_factors",
    "add_logistics_lessons",
    "add_target_selection_lessons",
    "add_coordination_lessons",
    "add_isk_efficiency_lessons",
    "add_timing_lessons",
    "add_tactical_innovation_lessons",
]

# Function call replacements
REPLACEMENTS = [
    # Victory factor replacements
    ("primary_factors = identify_primary_victory_factors(tactical_analysis, performance_metrics)",
     "primary_factors = VictoryFactorAnalyzer.identify_primary_victory_factors(tactical_analysis, performance_metrics)"),
    ("secondary_factors = identify_secondary_victory_factors(tactical_analysis, performance_metrics)",
     "secondary_factors = VictoryFactorAnalyzer.identify_secondary_victory_factors(tactical_analysis, performance_metrics)"),
    ("victory_probability = calculate_victory_probability(primary_factors, secondary_factors)",
     "victory_probability = VictoryFactorAnalyzer.calculate_victory_probability(primary_factors, secondary_factors)"),
    ("factor_weights = calculate_factor_weights(tactical_analysis, performance_metrics)",
     "factor_weights = VictoryFactorAnalyzer.calculate_factor_weights(tactical_analysis, performance_metrics)"),
    ("lessons = extract_victory_lessons(tactical_analysis, performance_metrics)",
     "lessons = VictoryFactorAnalyzer.extract_victory_lessons(tactical_analysis, performance_metrics)"),
    ("counterfactual_analysis: analyze_counterfactuals(tactical_analysis, decisive_moments)",
     "counterfactual_analysis: VictoryFactorAnalyzer.analyze_counterfactuals(tactical_analysis, decisive_moments)"),
]

# Backup the file
shutil.copy(FILE_PATH, FILE_PATH + ".backup2")

# Read the file
with open(FILE_PATH, 'r') as f:
    content = f.read()

# Add the alias if not present
lines = content.split('\n')
new_lines = []
added_alias = False

for i, line in enumerate(lines):
    # Add alias after DecisiveMomentAnalyzer alias
    if not added_alias and 'alias EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysis.Analyzers.DecisiveMomentAnalyzer' in line:
        new_lines.append(line)
        new_lines.append('  alias EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysis.Analyzers.VictoryFactorAnalyzer')
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
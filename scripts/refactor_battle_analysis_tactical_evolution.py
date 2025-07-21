#!/usr/bin/env python3
"""
Refactor battle_analysis_service.ex to use TacticalEvolutionAnalyzer
"""

import re
import shutil

FILE_PATH = "/workspace/lib/eve_dmv/contexts/combat_intelligence/domain/battle_analysis_service.ex"

# Functions that should be removed or delegated
FUNCTIONS_TO_REMOVE = [
    "analyze_doctrine_evolution",
    "analyze_ship_composition_trends",
    "analyze_engagement_pattern_evolution",
    "analyze_tactical_adaptation",
    "compare_doctrine_usage",
    # Helper functions
    "extract_doctrines_from_battle",
    "extract_battle_timestamp",
    "calculate_doctrine_diversity",
    "identify_doctrine_changes",
    "calculate_doctrine_stability",
    "determine_doctrine_trend_direction",
    "extract_ship_composition_from_battle",
    "analyze_ship_class_distribution",
    "calculate_composition_support_ratio",
    "calculate_average_ship_value",
    "estimate_ship_class_value",
    "categorize_fleet_size",
]

# Function call replacements
REPLACEMENTS = [
    # Main function replacements
    ("doctrine_evolution = analyze_doctrine_evolution(sorted_battles)",
     "doctrine_evolution = TacticalEvolutionAnalyzer.analyze_doctrine_evolution(sorted_battles)"),
    ("composition_trends = analyze_ship_composition_trends(sorted_battles)",
     "composition_trends = TacticalEvolutionAnalyzer.analyze_ship_composition_trends(sorted_battles)"),
    ("engagement_evolution = analyze_engagement_pattern_evolution(sorted_battles)",
     "engagement_evolution = TacticalEvolutionAnalyzer.analyze_engagement_pattern_evolution(sorted_battles)"),
    ("tactical_adaptation = analyze_tactical_adaptation(sorted_battles)",
     "tactical_adaptation = TacticalEvolutionAnalyzer.analyze_tactical_adaptation(sorted_battles)"),
    # Compare doctrine usage
    ("doctrine_comparison = compare_doctrine_usage(battle_analyses)",
     "doctrine_comparison = TacticalEvolutionAnalyzer.compare_doctrine_usage(battle_analyses)"),
]

# Backup the file
shutil.copy(FILE_PATH, FILE_PATH + ".backup_evolution")

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
        if not added_alias:
            new_lines.append('  alias EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysis.Analyzers.TacticalEvolutionAnalyzer')
            added_alias = True
        in_alias_section = False
    
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
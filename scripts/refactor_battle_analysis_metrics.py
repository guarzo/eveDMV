#!/usr/bin/env python3
"""
Refactor battle_analysis_service.ex to use BattleMetricsCalculator
"""

import re
import shutil

FILE_PATH = "/workspace/lib/eve_dmv/contexts/combat_intelligence/domain/battle_analysis_service.ex"

# Functions that should be removed or delegated
FUNCTIONS_TO_REMOVE = [
    "compare_effectiveness_trends",
    "extract_kill_efficiency",
    "extract_isk_efficiency",
    "calculate_tactical_success",
    "calculate_strategic_impact",
    "calculate_metric_trend",
    "extract_patterns_from_battle",
    "calculate_pattern_confidence",
    "calculate_analysis_timespan",
    "generate_evolution_summary",
]

# Function call replacements
REPLACEMENTS = [
    # Main function replacements
    ("effectiveness_trends = compare_effectiveness_trends(battle_analyses)",
     "effectiveness_trends = BattleMetricsCalculator.compare_effectiveness_trends(battle_analyses)"),
    # Helper function replacements
    ("kill_efficiency: extract_kill_efficiency(analysis)",
     "kill_efficiency: BattleMetricsCalculator.extract_kill_efficiency(analysis)"),
    ("isk_efficiency: extract_isk_efficiency(analysis)",
     "isk_efficiency: BattleMetricsCalculator.extract_isk_efficiency(analysis)"),
    ("tactical_success: calculate_tactical_success(analysis)",
     "tactical_success: BattleMetricsCalculator.calculate_tactical_success(analysis)"),
    ("strategic_impact: calculate_strategic_impact(analysis)",
     "strategic_impact: BattleMetricsCalculator.calculate_strategic_impact(analysis)"),
    ("time_span: calculate_analysis_timespan(sorted_battles)",
     "time_span: BattleMetricsCalculator.calculate_analysis_timespan(sorted_battles)"),
    ("summary: generate_evolution_summary(",
     "summary: BattleMetricsCalculator.generate_evolution_summary("),
    # Pattern extraction
    ("extract_patterns_from_battle(analysis)",
     "BattleMetricsCalculator.extract_patterns_from_battle(analysis)"),
    ("confidence: calculate_pattern_confidence(instances)",
     "confidence: BattleMetricsCalculator.calculate_pattern_confidence(instances)"),
]

# Backup the file
shutil.copy(FILE_PATH, FILE_PATH + ".backup_metrics")

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
            new_lines.append('  alias EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysis.Engines.BattleMetricsCalculator')
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
#!/usr/bin/env python3
"""
Refactor outcome_analyzer.ex to use OutcomeRecommendationEngine
"""

import re
import shutil

FILE_PATH = "/workspace/lib/eve_dmv/contexts/combat_intelligence/domain/battle_analysis/phases/outcome_analyzer.ex"

# Functions that should be removed
FUNCTIONS_TO_REMOVE = [
    "generate_outcome_recommendations",
    "identify_critical_weaknesses",
    "identify_key_strengths", 
    "identify_improvement_opportunities",
    "generate_immediate_tactical_recommendations",
    "generate_strategic_adjustments",
    "identify_training_priorities",
    "suggest_doctrine_modifications",
    "identify_future_considerations",
    "prioritize_recommendations",
    "generate_implementation_timeline",
    "estimate_improvement_impact",
    "generate_factor_improvement",
]

# Function call replacements - none needed since this is a top-level function

# Backup the file
shutil.copy(FILE_PATH, FILE_PATH + ".backup5")

# Read the file
with open(FILE_PATH, 'r') as f:
    content = f.read()

# Add the alias if not present
lines = content.split('\n')
new_lines = []
added_alias = False

for i, line in enumerate(lines):
    # Add alias after TacticalAnalysisEngine alias
    if not added_alias and 'alias EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysis.Engines.TacticalAnalysisEngine' in line:
        new_lines.append(line)
        new_lines.append('  alias EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysis.Engines.OutcomeRecommendationEngine')
        added_alias = True
        continue
    
    new_lines.append(line)

content = '\n'.join(new_lines)

# Replace the main function definition to delegate
content = re.sub(
    r'def generate_outcome_recommendations\(outcome_analysis\) do\s*Logger\.debug.*?end\s*(?=\n\s*#|\n\s*defp|\n\s*$)',
    '''def generate_outcome_recommendations(outcome_analysis) do
    OutcomeRecommendationEngine.generate_outcome_recommendations(outcome_analysis)
  end''',
    content,
    flags=re.DOTALL
)

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

# Remove functions (skip the main function as we already replaced it)
for func_name in FUNCTIONS_TO_REMOVE[1:]:  # Skip generate_outcome_recommendations
    content = remove_function(content, func_name)

# Count lines
with open(FILE_PATH, 'w') as f:
    f.write(content)

with open(FILE_PATH, 'r') as f:
    line_count = len(f.readlines())

print(f"\nComplete! New line count: {line_count}")
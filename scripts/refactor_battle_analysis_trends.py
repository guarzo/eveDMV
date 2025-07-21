#!/usr/bin/env python3
"""
Refactor battle_analysis_service.ex to use BattleTrendAnalyzer and StrategicAnalysisEngine
"""

import re
import shutil

FILE_PATH = "/workspace/lib/eve_dmv/contexts/combat_intelligence/domain/battle_analysis_service.ex"

# Functions that should be delegated
FUNCTIONS_TO_DELEGATE = [
    # BattleTrendAnalyzer functions
    ("track_ship_class_trends", "BattleTrendAnalyzer"),
    ("track_support_ratio_trends", "BattleTrendAnalyzer"),
    ("track_value_trends", "BattleTrendAnalyzer"),
    ("analyze_duration_trends", "BattleTrendAnalyzer"),
    ("analyze_intensity_trends", "BattleTrendAnalyzer"),
    ("analyze_complexity_trends", "BattleTrendAnalyzer"),
    ("calculate_usage_trend", "BattleTrendAnalyzer"),
    ("determine_overall_ship_trend", "BattleTrendAnalyzer"),
    ("determine_duration_pattern", "BattleTrendAnalyzer"),
    
    # StrategicAnalysisEngine functions
    ("analyze_strategic_positioning", "StrategicAnalysisEngine"),
    ("identify_skill_gaps", "StrategicAnalysisEngine"),
    ("recommend_force_multiplication", "StrategicAnalysisEngine"),
    ("suggest_engagement_timing", "StrategicAnalysisEngine"),
]

# Backup the file
shutil.copy(FILE_PATH, FILE_PATH + ".backup_trends")

# Read the file
with open(FILE_PATH, 'r') as f:
    content = f.read()

# Add the aliases if not present
lines = content.split('\n')
new_lines = []
added_aliases = set()
in_alias_section = False

for i, line in enumerate(lines):
    # Check if we're in the alias section
    if line.strip().startswith('alias '):
        in_alias_section = True
    elif in_alias_section and not line.strip().startswith('alias '):
        # End of alias section, add our aliases if not added
        if 'BattleTrendAnalyzer' not in added_aliases:
            new_lines.append('  alias EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysis.Analyzers.BattleTrendAnalyzer')
            added_aliases.add('BattleTrendAnalyzer')
        if 'StrategicAnalysisEngine' not in added_aliases:
            new_lines.append('  alias EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysis.Analyzers.StrategicAnalysisEngine')
            added_aliases.add('StrategicAnalysisEngine')
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

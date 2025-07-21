#!/usr/bin/env python3
"""
Remove unused functions from battle_analysis_service.ex
"""

import re
import shutil

FILE_PATH = "/workspace/lib/eve_dmv/contexts/combat_intelligence/domain/battle_analysis_service.ex"

# Functions that are marked as UNUSED
UNUSED_FUNCTIONS = [
    "analyze_fleet_composition_gaps",
    "generate_pattern_based_recommendations",
    "identify_doctrine_weaknesses",
    "identify_common_doctrine_ships",
    "extract_typical_role_distribution",
    "analyze_doctrine_engagement_patterns",
    "suggest_counter_composition",
    "identify_counter_ships",
    "generate_enemy_counter_tactics",
    "identify_required_pilot_skills",
]

# Backup the file
shutil.copy(FILE_PATH, FILE_PATH + ".backup_unused")

# Read the file
with open(FILE_PATH, 'r') as f:
    content = f.read()

# Remove UNUSED comment markers and the functions
for func_name in UNUSED_FUNCTIONS:
    # Pattern to match the UNUSED comment and function
    pattern = rf'#\s*UNUSED:\s*defp?\s+{re.escape(func_name)}.*?(?=\n\s*(?:#\s*UNUSED:|defp?|$))'
    content = re.sub(pattern, '', content, flags=re.DOTALL)
    
# Clean up multiple blank lines
content = re.sub(r'\n\s*\n\s*\n', '\n\n', content)

# Count lines
with open(FILE_PATH, 'w') as f:
    f.write(content)

with open(FILE_PATH, 'r') as f:
    line_count = len(f.readlines())

print(f"Complete! New line count: {line_count}")
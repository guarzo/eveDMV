#!/usr/bin/env python3
"""
Delegate track_participant_flow to ParticipantFlowAnalyzer
"""

import re
import shutil

FILE_PATH = "/workspace/lib/eve_dmv/contexts/combat_intelligence/domain/battle_analysis_service.ex"

# Backup the file
shutil.copy(FILE_PATH, FILE_PATH + ".backup_participant")

# Read the file
with open(FILE_PATH, 'r') as f:
    content = f.read()

# Add the alias if not present
if 'ParticipantFlowAnalyzer' not in content:
    # Find the last alias line
    alias_pattern = r'(\s*alias\s+[^\n]+\n)+'
    match = re.search(alias_pattern, content)
    if match:
        alias_end = match.end()
        # Insert new alias before the first non-alias line
        new_alias = '  alias EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysis.Analyzers.ParticipantFlowAnalyzer\n'
        content = content[:alias_end] + new_alias + content[alias_end:]

# Replace the track_participant_flow function body with delegation
pattern = r'(\s*defp\s+track_participant_flow\s*\(timeline\)\s+do)\s*\n(.*?)\n(\s*end)'

def replacer(match):
    indent = match.group(1).split('defp')[0]
    func_def = match.group(1)
    end_line = match.group(3)
    
    delegation = f"{func_def}\n{indent}  ParticipantFlowAnalyzer.track_participant_flow(timeline)\n{end_line}"
    return delegation

content = re.sub(pattern, replacer, content, flags=re.DOTALL | re.MULTILINE)

# Write the updated content
with open(FILE_PATH, 'w') as f:
    f.write(content)

print("Delegation complete!")

# Count final lines
with open(FILE_PATH, 'r') as f:
    line_count = len(f.readlines())

print(f"New line count: {line_count}")
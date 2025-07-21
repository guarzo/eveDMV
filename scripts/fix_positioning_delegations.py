#!/usr/bin/env python3
"""
Fix malformed delegations in fleet_composition_analyzer.ex for positioning functions
"""

import re

FILE_PATH = "/workspace/lib/eve_dmv/contexts/combat_intelligence/domain/battle_analysis/phases/fleet_composition_analyzer.ex"

# Read the file
with open(FILE_PATH, 'r') as f:
    content = f.read()

# Functions to fix (those that have malformed delegations with extra code)
FUNCTIONS_TO_FIX = [
    "get_participants_from_battle_analysis",
    "get_killmails_from_battle_analysis", 
    "calculate_positioning_effectiveness",
    "count_total_losses",
    "analyze_range_control",
    "count_long_range_ships",
    "analyze_escape_route_utilization",
    "analyze_tactical_positioning_effectiveness",
    "analyze_formation_integrity", 
    "count_logistics_ships",
    "analyze_engagement_zones",
    "calculate_zone_intensity",
    "identify_positioning_advantages",
    "analyze_fleet_mobility",
    "count_fast_ships",
    "rate_mobility",
    "generate_positioning_recommendations"
]

for func_name in FUNCTIONS_TO_FIX:
    # Pattern to match malformed delegation with extra code
    escaped_name = re.escape(func_name)
    
    # More flexible pattern to catch various malformed cases
    pattern = f'(\\s*defp\\s+{escaped_name}\\s*\\([^)]*\\)\\s+do)\\s*\\n\\s*\\n\\s*StrategicPositioningAnalyzer\\.{escaped_name}\\([^)]*\\)[^{{}}]*?\\n(\\s*end)'
    
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
        return f"{func_def}\\n{indent}StrategicPositioningAnalyzer.{func_name}({params})\\n{end_line}"
    
    new_content, count = re.subn(pattern, replacer, content, flags=re.DOTALL | re.MULTILINE)
    
    if count > 0:
        content = new_content
        print(f"Fixed malformed delegation for {func_name}")
    else:
        # Try alternative pattern for different malformed structures  
        alt_pattern = f'(\\s*defp\\s+{escaped_name}\\s*\\([^)]*\\)\\s+do)[^\\n]*?StrategicPositioningAnalyzer\\.{escaped_name}\\([^)]*\\)[^{{}}]*?(\\s*end)'
        
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
            return f"{func_def}\\n{indent}StrategicPositioningAnalyzer.{func_name}({params})\\n{end_line}"
        
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
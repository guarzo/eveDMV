#!/usr/bin/env python3
"""
Remove functions that have been extracted to other modules
"""

import re
import shutil

FILE_PATH = "/workspace/lib/eve_dmv/contexts/combat_intelligence/domain/battle_analysis_service.ex"

# Functions that have been extracted to other modules
FUNCTIONS_TO_REMOVE = [
    # Participant flow functions
    "create_participant_tracking_windows",
    "analyze_participant_flow_between_windows", 
    "generate_participation_flow_summary",
    "determine_flow_type",
    "calculate_participation_stability",
    "analyze_flow_pattern",
    "identify_most_active_period",
    "format_timestamp",
    
    # Doctrine detection functions
    "analyze_ship_patterns",
    "match_known_doctrines",
    "group_ships_by_class",
    "classify_ship_by_type_id",
    "classify_ship_type_id",
    "analyze_support_ships",
    "calculate_support_ratio",
    "calculate_ship_diversity_score",
    "analyze_capital_doctrines",
    "analyze_subcap_doctrines",
    "analyze_specialized_doctrines",
    "get_class_percentage",
    "calculate_doctrine_confidence",
    "generate_doctrine_analysis",
    
    # EWAR detection functions
    "extract_all_ships_from_composition",
    "analyze_ships_for_ewar",
    "classify_ship_ewar_capability",
    "extract_ship_type_id",
    "calculate_ewar_intensity",
    "calculate_ewar_percentage",
    "generate_ewar_analysis",
    
    # Side determination functions
    "determine_side_by_alliance",
    "determine_side_by_corporation",
    "build_attack_relationships",
    "analyze_attack_patterns",
    "group_entities_by_patterns",
    "entities_are_allied?",
    "merge_target_lists",
    "merge_attacker_lists",
    "create_side_mappings",
    "generate_side_name",
    "get_entity_id",
    "extract_damage_from_attacker",
]

# Backup the file
shutil.copy(FILE_PATH, FILE_PATH + ".backup")

# Read the file
with open(FILE_PATH, 'r') as f:
    content = f.read()

# Function to find and remove a function definition
def remove_function(content, func_name):
    # Pattern to match function definition
    # Handle both regular functions and those ending with ?
    escaped_name = re.escape(func_name)
    pattern = rf'^(\s*)defp?\s+{escaped_name}\s*\([^)]*\)\s+do\s*$'
    
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
            # The end is when we find a line that starts with the same or less indentation
            # and contains 'end' or starts a new function
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
                elif re.match(r'^\s*(defp?|@|alias|use|import|require)\s', line):
                    # This is the start of something else, we're done
                    in_function = False
                    new_lines.append(line)
                    continue
            
            # Skip this line if we're still in the function
            skip_count += 1
            continue
            
        # Keep this line
        new_lines.append(line)
    
    print(f"Removed {func_name}: {skip_count} lines")
    return '\n'.join(new_lines)

# Remove all functions
for func_name in FUNCTIONS_TO_REMOVE:
    print(f"Removing {func_name}...")
    content = remove_function(content, func_name)

# Update function calls to use the extracted modules
replacements = [
    # EWAR replacements
    ("ewar_analysis = analyze_ships_for_ewar(all_ships)", 
     "ewar_analysis = EwarAnalysisEngine.analyze_ships_for_ewar(all_ships)"),
    ("ewar_intensity = calculate_ewar_intensity(ewar_analysis, length(all_ships))",
     "ewar_intensity = EwarAnalysisEngine.calculate_ewar_intensity(ewar_analysis, length(all_ships))"),
    ("ewar_percentage: calculate_ewar_percentage(ewar_analysis.ewar_ships, all_ships)",
     "ewar_percentage: EwarAnalysisEngine.calculate_ewar_percentage(ewar_analysis.ewar_ships, all_ships)"),
    ("analysis: generate_ewar_analysis(ewar_analysis, ewar_intensity)",
     "analysis: EwarAnalysisEngine.generate_ewar_analysis(ewar_analysis, ewar_intensity)"),
    
    # Participant flow replacements
    ("flow_analysis = analyze_participant_flow_between_windows(window_participants)",
     "flow_analysis = ParticipantFlowAnalyzer.analyze_participant_flow_between_windows(window_participants)"),
    ("flow_summary = generate_participation_flow_summary(window_participants, flow_analysis)",
     "flow_summary = ParticipantFlowAnalyzer.generate_participation_flow_summary(window_participants, flow_analysis)"),
     
    # Side determination replacements
    (" determine_side_by_alliance(alliance_id)",
     " SideDeterminationEngine.determine_side_by_alliance(alliance_id)"),
    (" determine_side_by_corporation(corporation_id)",
     " SideDeterminationEngine.determine_side_by_corporation(corporation_id)"),
]

for old, new in replacements:
    content = content.replace(old, new)

# Write the updated content
with open(FILE_PATH, 'w') as f:
    f.write(content)

# Count lines
with open(FILE_PATH, 'r') as f:
    line_count = len(f.readlines())

print(f"\nComplete! New line count: {line_count}")
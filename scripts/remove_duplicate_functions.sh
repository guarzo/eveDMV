#!/bin/bash

# Script to remove duplicate functions that have been extracted to other modules

FILE="/workspace/lib/eve_dmv/contexts/combat_intelligence/domain/battle_analysis_service.ex"

# Backup the file first
cp "$FILE" "$FILE.backup"

# Function to remove a function definition from line X to the next function or end
remove_function() {
    local start_line=$1
    local function_name=$2
    
    # Find the end of the function (next defp or def or end of file)
    local end_line=$(awk -v start=$start_line '
        NR > start && /^  (def|defp|end$)/ { print NR-1; exit }
        END { print NR }
    ' "$FILE")
    
    echo "Removing $function_name from line $start_line to $end_line"
    
    # Remove the lines
    sed -i "${start_line},${end_line}d" "$FILE"
}

# Remove duplicate functions (in reverse order to preserve line numbers)
# Note: These line numbers are from the grep output

# Remove helper functions that are now in extracted modules
# We'll process them in reverse order so line numbers don't shift

# First, let's find exact line ranges for each function
echo "Finding function ranges..."

# Create a temporary file with all function definitions and their line numbers
grep -n "^  defp\? " "$FILE" > /tmp/functions.txt

# Now process each function to remove
# Since we're removing large chunks, let's use a more precise approach

# Create a new file by filtering out the duplicate functions
awk '
BEGIN {
    in_function = 0
    function_to_remove = ""
}

# Functions to remove
/^  defp create_participant_tracking_windows\(/ { in_function = 1; function_to_remove = "create_participant_tracking_windows"; next }
/^  defp analyze_ship_patterns\(/ { in_function = 1; function_to_remove = "analyze_ship_patterns"; next }
/^  defp match_known_doctrines\(/ { in_function = 1; function_to_remove = "match_known_doctrines"; next }
/^  defp build_attack_relationships\(/ { in_function = 1; function_to_remove = "build_attack_relationships"; next }
/^  defp analyze_attack_patterns\(/ { in_function = 1; function_to_remove = "analyze_attack_patterns"; next }
/^  defp group_entities_by_patterns\(/ { in_function = 1; function_to_remove = "group_entities_by_patterns"; next }
/^  defp entities_are_allied\?/ { in_function = 1; function_to_remove = "entities_are_allied?"; next }
/^  defp merge_target_lists\(/ { in_function = 1; function_to_remove = "merge_target_lists"; next }
/^  defp merge_attacker_lists\(/ { in_function = 1; function_to_remove = "merge_attacker_lists"; next }
/^  defp create_side_mappings\(/ { in_function = 1; function_to_remove = "create_side_mappings"; next }
/^  defp generate_side_name\(/ { in_function = 1; function_to_remove = "generate_side_name"; next }
/^  defp get_entity_id\(/ { in_function = 1; function_to_remove = "get_entity_id"; next }
/^  defp extract_damage_from_attacker\(/ { in_function = 1; function_to_remove = "extract_damage_from_attacker"; next }

# Helper functions for participant flow
/^  defp analyze_participant_flow_between_windows\(/ { in_function = 1; function_to_remove = "analyze_participant_flow_between_windows"; next }
/^  defp generate_participation_flow_summary\(/ { in_function = 1; function_to_remove = "generate_participation_flow_summary"; next }
/^  defp determine_flow_type\(/ { in_function = 1; function_to_remove = "determine_flow_type"; next }
/^  defp calculate_participation_stability\(/ { in_function = 1; function_to_remove = "calculate_participation_stability"; next }
/^  defp analyze_flow_pattern\(/ { in_function = 1; function_to_remove = "analyze_flow_pattern"; next }
/^  defp identify_most_active_period\(/ { in_function = 1; function_to_remove = "identify_most_active_period"; next }
/^  defp format_timestamp\(/ { in_function = 1; function_to_remove = "format_timestamp"; next }

# Helper functions for doctrine detection
/^  defp group_ships_by_class\(/ { in_function = 1; function_to_remove = "group_ships_by_class"; next }
/^  defp classify_ship_by_type_id\(/ { in_function = 1; function_to_remove = "classify_ship_by_type_id"; next }
/^  defp classify_ship_type_id\(/ { in_function = 1; function_to_remove = "classify_ship_type_id"; next }
/^  defp analyze_support_ships\(/ { in_function = 1; function_to_remove = "analyze_support_ships"; next }
/^  defp calculate_support_ratio\(/ { in_function = 1; function_to_remove = "calculate_support_ratio"; next }
/^  defp calculate_ship_diversity_score\(/ { in_function = 1; function_to_remove = "calculate_ship_diversity_score"; next }
/^  defp analyze_capital_doctrines\(/ { in_function = 1; function_to_remove = "analyze_capital_doctrines"; next }
/^  defp analyze_subcap_doctrines\(/ { in_function = 1; function_to_remove = "analyze_subcap_doctrines"; next }
/^  defp analyze_specialized_doctrines\(/ { in_function = 1; function_to_remove = "analyze_specialized_doctrines"; next }
/^  defp get_class_percentage\(/ { in_function = 1; function_to_remove = "get_class_percentage"; next }
/^  defp calculate_doctrine_confidence\(/ { in_function = 1; function_to_remove = "calculate_doctrine_confidence"; next }
/^  defp generate_doctrine_analysis\(/ { in_function = 1; function_to_remove = "generate_doctrine_analysis"; next }

# Helper functions for EWAR detection (many of these)
/^  defp extract_all_ships_from_composition\(/ { in_function = 1; function_to_remove = "extract_all_ships_from_composition"; next }
/^  defp analyze_ships_for_ewar\(/ { in_function = 1; function_to_remove = "analyze_ships_for_ewar"; next }
/^  defp classify_ship_ewar_capability\(/ { in_function = 1; function_to_remove = "classify_ship_ewar_capability"; next }
/^  defp extract_ship_type_id\(/ { in_function = 1; function_to_remove = "extract_ship_type_id"; next }
/^  defp calculate_ewar_intensity\(/ { in_function = 1; function_to_remove = "calculate_ewar_intensity"; next }
/^  defp calculate_ewar_percentage\(/ { in_function = 1; function_to_remove = "calculate_ewar_percentage"; next }
/^  defp generate_ewar_analysis\(/ { in_function = 1; function_to_remove = "generate_ewar_analysis"; next }

# Helper functions for side determination  
/^  defp determine_side_by_alliance\(/ { in_function = 1; function_to_remove = "determine_side_by_alliance"; next }
/^  defp determine_side_by_corporation\(/ { in_function = 1; function_to_remove = "determine_side_by_corporation"; next }

# If we are in a function to remove, skip lines until we find the next function or end
in_function == 1 {
    # Check if this is the start of a new function or the final "end" of the module
    if (/^  (defp?|@|#|alias|use|import|require)\s/ || /^end$/) {
        in_function = 0
        function_to_remove = ""
        # Process this line normally (unless it is the module end)
        if (match($0, /^end$/) == 0) {
            print
        } else {
            # This is the final module end, keep it
            print
        }
    }
    # Skip the line if we're still in the function
    next
}

# Print all other lines
{ print }

# Make sure to print the final "end" if it exists
END {
    # The final end should be preserved by the logic above
}
' "$FILE" > "$FILE.tmp"

# Replace the original file with the filtered version
mv "$FILE.tmp" "$FILE"

# Update EWAR detection to use the EwarAnalysisEngine
sed -i 's/ewar_analysis = analyze_ships_for_ewar(all_ships)/ewar_analysis = EwarAnalysisEngine.analyze_ships_for_ewar(all_ships)/g' "$FILE"
sed -i 's/ewar_intensity = calculate_ewar_intensity(ewar_analysis, length(all_ships))/ewar_intensity = EwarAnalysisEngine.calculate_ewar_intensity(ewar_analysis, length(all_ships))/g' "$FILE"
sed -i 's/ewar_percentage: calculate_ewar_percentage(ewar_analysis.ewar_ships, all_ships)/ewar_percentage: EwarAnalysisEngine.calculate_ewar_percentage(ewar_analysis.ewar_ships, all_ships)/g' "$FILE"
sed -i 's/analysis: generate_ewar_analysis(ewar_analysis, ewar_intensity)/analysis: EwarAnalysisEngine.generate_ewar_analysis(ewar_analysis, ewar_intensity)/g' "$FILE"

# Update participant flow analysis
sed -i 's/flow_analysis = analyze_participant_flow_between_windows(window_participants)/flow_analysis = ParticipantFlowAnalyzer.analyze_participant_flow_between_windows(window_participants)/g' "$FILE"
sed -i 's/flow_summary = generate_participation_flow_summary(window_participants, flow_analysis)/flow_summary = ParticipantFlowAnalyzer.generate_participation_flow_summary(window_participants, flow_analysis)/g' "$FILE"

# Update side determination
sed -i 's/determine_side_by_alliance(alliance_id)/SideDeterminationEngine.determine_side_by_alliance(alliance_id)/g' "$FILE"
sed -i 's/determine_side_by_corporation(corporation_id)/SideDeterminationEngine.determine_side_by_corporation(corporation_id)/g' "$FILE"

echo "Cleanup complete. Checking line count..."
wc -l "$FILE"
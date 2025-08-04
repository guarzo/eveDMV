#!/bin/bash

echo "Removing unused functions to reduce dialyzer errors..."

# Extract unused function errors from dialyzer output
unused_functions=$(grep "unused_fun" /workspace/dialyzer.txt | head -50)

# Create a comprehensive list of functions to remove
declare -A functions_to_remove

# Tactical highlight manager functions (all unused)
functions_to_remove["/workspace/lib/eve_dmv/contexts/battle_sharing/domain/tactical_highlight_manager.ex"]="maybe_analyze_tactical_context analyze_tactical_context_at_timestamp extract_killmails_near_timestamp calculate_killmail_timestamp_offset analyze_tactical_situation calculate_combat_intensity classify_tactical_situation calculate_ship_diversity count_participants identify_contextual_factors intensity_change_moment phase_transition_moment calculate_tactical_significance integrate_learning_content find_related_learning_categories generate_educational_tags create_highlight_record generate_highlight_id enrich_highlight_data add_tactical_insights generate_tactical_lessons identify_related_concepts assess_difficulty_level assess_applicability add_community_features add_navigation_data generate_deep_link analyze_battle_phases detect_tactical_patterns generate_candidate_highlights filter_highlights_by_confidence prioritize_highlights finalize_auto_detected_highlights calculate_average_confidence"

# Character intelligence functions (many unused)
functions_to_remove["/workspace/lib/eve_dmv/contexts/character_intelligence.ex"]="get_combat_statistics count_recent_activity get_character_info extract_behavioral_patterns maybe_add_pattern calculate_pattern_confidence generate_behavioral_characteristics maybe_add_characteristic generate_intelligence_summary extract_key_strengths generate_tactical_recommendations calculate_pattern_confidence"

# Combat analysis threat assessment engine functions (all unused)
functions_to_remove["/workspace/lib/eve_dmv/contexts/combat_analysis/domain/threat_assessment_engine.ex"]="perform_threat_assessment fetch_combat_stats fetch_recent_activity count_kills count_losses analyze_combat_patterns calculate_combat_tempo assess_combat_capability analyze_ship_usage calculate_average_ship_value calculate_ship_diversity count_specialized_ships calculate_capability_rating assess_coordination_ability calculate_combat_threat_score"

# Function to remove unused functions from a file
remove_functions_from_file() {
    local file="$1"
    local functions="$2"
    
    if [ ! -f "$file" ]; then
        echo "File $file not found, skipping..."
        return
    fi
    
    echo "Processing $file..."
    
    # Convert space-separated functions to array
    IFS=' ' read -r -a func_array <<< "$functions"
    
    for func in "${func_array[@]}"; do
        echo "  Removing function: $func"
        # Remove the function definition and its body
        # This is a simplified approach - remove from defp/def line to next defp/def/end
        sed -i "/^[[:space:]]*defp\? $func(/,/^[[:space:]]*\(def\|end\)/{ /^[[:space:]]*\(def\|end\)/!d; }" "$file"
    done
}

# Process each file
for file in "${!functions_to_remove[@]}"; do
    remove_functions_from_file "$file" "${functions_to_remove[$file]}"
done

# Also remove some specific problematic functions individually
echo "Removing specific problematic functions..."

# Remove the broken generate_intelligence_summary function from battle_analysis.ex  
sed -i '/defp generate_intelligence_summary/,/^[[:space:]]*end/d' "/workspace/lib/eve_dmv/contexts/battle_analysis.ex" 2>/dev/null || true

# Remove the broken extract_key_timeline_events function
sed -i '/defp extract_key_timeline_events/,/^[[:space:]]*end/d' "/workspace/lib/eve_dmv/contexts/battle_analysis.ex" 2>/dev/null || true

echo "Unused function removal complete!"
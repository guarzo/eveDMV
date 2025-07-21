#!/bin/bash

# Script to fix parsing errors across files that Credo cannot parse
# Focus on missing pipe operators and common syntax issues

echo "Fixing parsing errors in files excluded by Credo..."

# List of files with parsing errors (from Credo output)
files=(
  "lib/eve_dmv/contexts/battle_analysis/domain/tactical_phase_detector/kmeans_clustering.ex"
  "lib/eve_dmv/contexts/battle_analysis/domain/tactical_phase_detector/phase_classifier.ex"
  "lib/eve_dmv/contexts/combat_intelligence/domain/battle_analysis/analyzers/attack_pattern_analyzer.ex"
  "lib/eve_dmv/contexts/combat_intelligence/domain/battle_analysis/analyzers/decisive_moment_analyzer.ex"
  "lib/eve_dmv/contexts/combat_intelligence/domain/battle_analysis/analyzers/doctrine_analysis_engine.ex"
  "lib/eve_dmv/contexts/combat_intelligence/domain/battle_analysis/analyzers/doctrine_analyzer.ex"
  "lib/eve_dmv/contexts/combat_intelligence/domain/battle_analysis/analyzers/doctrine_evolution_analyzer.ex"
  "lib/eve_dmv/contexts/combat_intelligence/domain/battle_analysis/analyzers/engagement_flow_analyzer.ex"
  "lib/eve_dmv/contexts/combat_intelligence/domain/battle_analysis/analyzers/engagement_pattern_analyzer.ex"
  "lib/eve_dmv/contexts/combat_intelligence/domain/battle_analysis/analyzers/entity_performance_analyzer.ex"
  "lib/eve_dmv/contexts/combat_intelligence/domain/battle_analysis/analyzers/ewar_analysis_engine.ex"
  "lib/eve_dmv/contexts/combat_intelligence/domain/battle_analysis/analyzers/fleet_doctrine_analyzer.ex"
  "lib/eve_dmv/contexts/combat_intelligence/domain/battle_analysis/analyzers/fleet_synergy_analyzer.ex"
  "lib/eve_dmv/contexts/combat_intelligence/domain/battle_analysis/analyzers/focus_fire_analyzer.ex"
  "lib/eve_dmv/contexts/combat_intelligence/domain/battle_analysis/analyzers/force_multiplication_analyzer.ex"
  "lib/eve_dmv/contexts/combat_intelligence/domain/battle_analysis/analyzers/participant_flow_analyzer.ex"
  "lib/eve_dmv/contexts/combat_intelligence/domain/battle_analysis/analyzers/ship_class_performance_analyzer.ex"
  "lib/eve_dmv/contexts/combat_intelligence/domain/battle_analysis/analyzers/ship_classification_analyzer.ex"
  "lib/eve_dmv/contexts/combat_intelligence/domain/battle_analysis/analyzers/side_determination_analyzer.ex"
  "lib/eve_dmv/contexts/combat_intelligence/domain/battle_analysis/engines/battle_outcome_analysis_engine.ex"
  "lib/eve_dmv/contexts/combat_intelligence/domain/battle_analysis/engines/battle_outcome_engine.ex"
  "lib/eve_dmv/contexts/combat_intelligence/domain/battle_analysis/engines/doctrine_detection_engine.ex"
  "lib/eve_dmv/contexts/combat_intelligence/domain/battle_analysis/engines/fleet_comparison_engine.ex"
  "lib/eve_dmv/contexts/combat_intelligence/domain/battle_analysis/engines/fleet_strength_analyzer.ex"
  "lib/eve_dmv/contexts/combat_intelligence/domain/battle_analysis/engines/side_classification_engine.ex"
  "lib/eve_dmv/contexts/combat_intelligence/domain/battle_analysis/engines/training_recommendation_engine.ex"
  "lib/eve_dmv/contexts/combat_intelligence/domain/battle_analysis/helpers/battle_analysis_helper.ex"
  "lib/eve_dmv/contexts/combat_intelligence/domain/battle_analysis/phases/fleet_composition/synergy_analyzer.ex"
  "lib/eve_dmv/contexts/combat_intelligence/domain/intelligence_scoring/calculators/solo_pilot_calculator.ex"
  "lib/eve_dmv/contexts/corporation_intelligence/analyzers/doctrine_classification_engine.ex"
  "lib/eve_dmv/contexts/corporation_intelligence/analyzers/doctrine_comparison_analyzer.ex"
  "lib/eve_dmv/contexts/corporation_intelligence/analyzers/doctrine_result_compiler.ex"
  "lib/eve_dmv/contexts/corporation_intelligence/analyzers/fleet_composition_analyzer.ex"
  "lib/eve_dmv/contexts/corporation_intelligence/domain/combat_data_collector.ex"
  "lib/eve_dmv/contexts/corporation_intelligence/domain/corp_intelligence_utils.ex"
  "lib/eve_dmv/contexts/fleet_operations/domain/performance/fleet_calculator.ex"
  "lib/eve_dmv/contexts/fleet_operations/domain/performance/threat_scorer.ex"
  "lib/eve_dmv/contexts/intelligence_infrastructure/domain/cross_system/correlators/activity_correlator/analyzers/correlation_analyzer.ex"
  "lib/eve_dmv/contexts/intelligence_infrastructure/domain/cross_system/correlators/activity_correlator/processors/pattern_processor.ex"
  "lib/eve_dmv/contexts/intelligence_infrastructure/domain/cross_system/correlators/activity_correlator/processors/temporal_processor.ex"
  "lib/eve_dmv/contexts/intelligence_infrastructure/domain/cross_system/correlators/activity_correlator/utilities/math_utilities.ex"
  "lib/eve_dmv/contexts/intelligence_infrastructure/domain/cross_system/correlators/activity_correlator/utilities/time_utilities.ex"
  "lib/eve_dmv/contexts/intelligence_infrastructure/domain/cross_system/correlators/quality_correlator.ex"
  "lib/eve_dmv/contexts/intelligence_infrastructure/domain/cross_system/correlators/source_correlator.ex"
  "lib/eve_dmv/contexts/surveillance/domain/matching_engine/matchers/condition_evaluator.ex"
  "lib/eve_dmv/contexts/wormhole_operations/analyzers/corporation_analyzer.ex"
  "lib/eve_dmv/contexts/wormhole_operations/domain/defense_utilities.ex"
  "lib/eve_dmv_web/live/battle_analysis/components/battle_stats_component.ex"
  "lib/eve_dmv_web/live/battle_analysis/components/battle_timeline_component.ex"
  "lib/eve_dmv_web/live/character_analysis/helpers/character_calculator.ex"
  "lib/eve_dmv_web/live/character_analysis/helpers/character_data_extractor.ex"
  "lib/eve_dmv_web/live/fleet_operations/components/fleet_composition_component.ex"
  "lib/eve_dmv_web/live/fleet_operations/components/fleet_stats_component.ex"
  "lib/eve_dmv_web/live/fleet_operations/helpers/fleet_data_loader.ex"
)

fixed_count=0
error_count=0

for file in "${files[@]}"; do
  if [ -f "$file" ]; then
    echo "Processing $file..."
    
    # Create a backup
    cp "$file" "${file}.bak"
    
    # Fix common parsing issues in the file
    
    # 1. Fix missing pipes after timeline (common pattern)
    sed -i 's/timeline$/timeline/g' "$file"
    sed -i 's/\(timeline\)\s*$/\1/g' "$file"
    
    # 2. Fix pipeline chains that are missing pipe operators
    # Pattern: variable\n    Enum.something -> variable\n    |> Enum.something
    sed -i '/timeline$/N;s/timeline\n    Enum\./timeline\n    |> Enum./g' "$file"
    sed -i '/attackers$/N;s/attackers\n    Enum\./attackers\n    |> Enum./g' "$file"
    sed -i '/entities$/N;s/entities\n    Enum\./entities\n    |> Enum./g' "$file"
    sed -i '/relationships$/N;s/relationships\n    Enum\./relationships\n    |> Enum./g' "$file"
    sed -i '/attack_relationships$/N;s/attack_relationships\n    Enum\./attack_relationships\n    |> Enum./g' "$file"
    sed -i '/alliances$/N;s/alliances\n    Enum\./alliances\n    |> Enum./g' "$file"
    sed -i '/group_analysis$/N;s/group_analysis\n    Enum\./group_analysis\n    |> Enum./g' "$file"
    
    # 3. Fix case where function call is on next line without pipe
    # Pattern: variable\n    function_call(args) -> variable |> function_call(args)
    perl -i -pe '
      s/(\w+)\s*\n\s*(Enum\.[a-z_]+)/\1\n    |> \2/g;
      s/(\w+)\s*\n\s*(Map\.[a-z_]+)/\1\n    |> \2/g;
      s/(\w+)\s*\n\s*(String\.[a-z_]+)/\1\n    |> \2/g;
    ' "$file"
    
    # 4. Fix specific issues found in attack_pattern_analyzer.ex
    sed -i 's/^    Enum\./    |> Enum./g' "$file"
    sed -i 's/^      Enum\./      |> Enum./g' "$file"
    
    # 5. Fix indentation issues with pipe operators
    sed -i 's/^  Enum\./  |> Enum./g' "$file"
    sed -i 's/^    Map\./    |> Map./g' "$file"
    
    # 6. Fix missing pipes in specific patterns
    sed -i 's/\(^\s*\)Enum\.filter(/\1|> Enum.filter(/g' "$file"
    sed -i 's/\(^\s*\)Enum\.map(/\1|> Enum.map(/g' "$file"
    sed -i 's/\(^\s*\)Enum\.flat_map(/\1|> Enum.flat_map(/g' "$file"
    sed -i 's/\(^\s*\)Enum\.reduce(/\1|> Enum.reduce(/g' "$file"
    
    # 7. Fix cond statement indentation
    sed -i 's/^  alliance_id/      alliance_id/g' "$file"
    sed -i 's/^  corporation_id/      corporation_id/g' "$file"
    sed -i 's/^  true/      true/g' "$file"
    
    # Check if file was actually modified
    if ! cmp -s "$file" "${file}.bak"; then
      ((fixed_count++))
      echo "  ✓ Fixed parsing issues in $file"
      rm "${file}.bak"
    else
      echo "  - No changes needed in $file"
      rm "${file}.bak"
    fi
    
  else
    echo "  ✗ File not found: $file"
    ((error_count++))
  fi
done

echo ""
echo "Summary:"
echo "- Files processed: ${#files[@]}"
echo "- Files fixed: $fixed_count"
echo "- Files not found: $error_count"
echo ""
echo "Re-running Credo to check progress..."
#!/bin/bash

# Fix misplaced triple quotes after alias statements
# Pattern: alias statement followed by triple quotes on next line

files=(
"/workspace/lib/eve_dmv/contexts/wormhole_operations/domain/analyzers/home_defense_analyzer.ex"
"/workspace/lib/eve_dmv/external/eve/esi_client.ex"
"/workspace/lib/eve_dmv/contexts/wormhole_operations/domain/wormhole/wh_vetting.ex"
"/workspace/lib/eve_dmv/contexts/wormhole_operations/domain/wormhole/wh_fleet_composition.ex"
"/workspace/lib/eve_dmv/external/eve/circuit_breaker.ex"
"/workspace/lib/eve_dmv/surveillance/notification.ex"
"/workspace/lib/eve_dmv/platform/workers/re_enrichment_worker.ex"
"/workspace/lib/eve_dmv/contexts/corporation_intelligence/domain/activity_metrics.ex"
"/workspace/lib/eve_dmv/core/domain/intelligence/fusion_engine.ex"
"/workspace/lib/eve_dmv/external/wanderer/wanderer_client.ex"
"/workspace/lib/eve_dmv/core/domain/intelligence/core/validation_helper.ex"
"/workspace/lib/eve_dmv/core/domain/intelligence/report_builder.ex"
"/workspace/lib/eve_dmv/contexts/combat_intelligence/domain/analyzers/tactical_pattern_detector.ex"
"/workspace/lib/eve_dmv/contexts/corporation_intelligence/domain/analyzers/member_activity_pattern_analyzer/anomaly_detector.ex"
"/workspace/lib/eve_dmv/contexts/combat_intelligence/domain/extractors/participant_extractor/activity_tracker.ex"
"/workspace/lib/eve_dmv/contexts/fleet_operations/domain/effectiveness_calculator.ex"
"/workspace/lib/eve_dmv/performance/regression_detector.ex"
"/workspace/lib/eve_dmv/contexts/fleet_operations/domain/calculators/fleet_participation_calculator.ex"
"/workspace/lib/eve_dmv/contexts/combat/core/timeline_builder.ex"
"/workspace/lib/eve_dmv/contexts/combat/core/participant_analyzer/activity_tracker.ex"
"/workspace/lib/eve_dmv/contexts/combat/core/participant_analyzer/affiliation_analyzer.ex"
"/workspace/lib/eve_dmv/contexts/corporation_analysis/formatters/member_activity_display_formatter.ex"
"/workspace/lib/eve_dmv/contexts/surveillance/infrastructure/profile_repository.ex"
"/workspace/lib/eve_dmv/contexts/surveillance/domain/chain_intelligence.ex"
"/workspace/lib/eve_dmv/contexts/intelligence_infrastructure/domain/analyzers/intelligence_quality_analyzer.ex"
"/workspace/lib/eve_dmv/contexts/intelligence_infrastructure/domain/analyzers/threat_pattern_analyzer.ex"
"/workspace/lib/eve_dmv/contexts/battle_analysis/domain/strategic/assessment_compiler.ex"
"/workspace/lib/eve_dmv/contexts/battle_analysis/domain/enhanced_combat_log_parser.ex"
"/workspace/lib/eve_dmv/contexts/battle_analysis/domain/strategic/correlation_engine.ex"
)

for file in "${files[@]}"; do
    if [ -f "$file" ]; then
        echo "Fixing $file..."
        # Use perl to remove the misplaced """ after alias statements
        perl -i -0pe 's/(alias\s+[^\n]+)\n(\s*""")\n/\1\n/g' "$file"
    fi
done

echo "Fixed $(echo ${#files[@]}) files"
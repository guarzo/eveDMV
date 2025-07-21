#!/bin/bash

echo "🔧 WS-3: Module Organization Fix Script"
echo "Fixing alias/import/require ordering and defstruct positioning"

# Get files with import/alias/require ordering issues
files_with_ordering_issues=(
"lib/eve_dmv/contexts/character_intelligence/domain/threat_scoring/engines/combat_threat_engine.ex"
"lib/eve_dmv/contexts/character_intelligence/domain/threat_scoring/engines/gang_effectiveness_engine.ex"
"lib/eve_dmv/contexts/character_intelligence/domain/threat_scoring/engines/ship_mastery_engine.ex"
"lib/eve_dmv/contexts/character_intelligence/domain/threat_scoring/engines/unpredictability_engine.ex"
"lib/eve_dmv/contexts/character_intelligence/domain/threat_scoring/threat_scoring_coordinator.ex"
"lib/eve_dmv/contexts/combat_intelligence/domain/battle_analysis/analyzers/tactical_recommendation_engine.ex"
"lib/eve_dmv/contexts/combat_intelligence/domain/battle_analysis/data_collectors/battle_data_collector.ex"
"lib/eve_dmv/contexts/combat_intelligence/domain/character_analyzer.ex"
"lib/eve_dmv/contexts/combat_intelligence/domain/streaming_battle_analyzer.ex"
"lib/eve_dmv/contexts/threat_assessment/infrastructure/threat_repository.ex"
"lib/eve_dmv/contexts/wormhole_operations/domain/chain_tracker.ex"
"lib/eve_dmv/contexts/wormhole_operations/domain/home_defense_analyzer.ex"
"lib/eve_dmv/database/incremental_view_refresher.ex"
"lib/eve_dmv/database/materialized_view_refresher.ex"
"lib/eve_dmv/database/query_performance.ex"
"lib/eve_dmv/database/surveillance_repository.ex"
"lib/eve_dmv/historical/import_progress_monitor.ex"
"lib/eve_dmv/intelligence/advanced_analytics.ex"
"lib/eve_dmv/intelligence/real_time_coordinator.ex"
"lib/eve_dmv/pagination/cursor_paginator.ex"
"lib/eve_dmv/search/search_suggestion_service.ex"
"lib/eve_dmv/static_data/system_data.ex"
"lib/eve_dmv/users/token_refresh_service.ex"
"lib/eve_dmv_web/live/character_analysis/components/paginated_activity_component.ex"
"lib/eve_dmv_web/live/killmail_live.ex"
"lib/eve_dmv_web/plugs/token_refresh_plug.ex"
"lib/mix/tasks/eve.create_indexes_async.ex"
"lib/mix/tasks/eve_dmv.import_historical.ex"
)

# Files with defstruct positioning issues
files_with_defstruct_issues=(
"lib/eve_dmv/pagination/cursor_paginator.ex"
"lib/eve_dmv/shutdown/graceful_shutdown.ex"
)

# Function to check current Credo issues
check_progress() {
    local current_issues
    current_issues=$(mix credo --format=oneline 2>/dev/null | grep -E "alias must appear|import must appear|require must appear|defstruct must appear|Module attribute" | wc -l)
    echo "Current module organization issues: $current_issues"
}

echo "Initial check:"
check_progress

echo ""
echo "🚧 Note: This script identifies files with issues. Manual fixes are being applied systematically."
echo "Progress will be tracked through individual file fixes."

# Validate the script can find the files
echo ""
echo "Validating file access:"
missing_count=0
for file in "${files_with_ordering_issues[@]}"; do
    if [[ ! -f "$file" ]]; then
        echo "❌ Missing file: $file"
        ((missing_count++))
    fi
done

for file in "${files_with_defstruct_issues[@]}"; do
    if [[ ! -f "$file" ]]; then
        echo "❌ Missing file: $file"
        ((missing_count++))
    fi
done

if [[ $missing_count -eq 0 ]]; then
    echo "✅ All identified files exist and can be processed"
else
    echo "⚠️ $missing_count files are missing or inaccessible"
fi

echo ""
echo "🎯 Ready for systematic manual fixes using Claude Code Edit tool"
echo "Target: Reduce module organization issues from current count to <10"
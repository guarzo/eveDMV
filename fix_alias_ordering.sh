#!/bin/bash

echo "Fixing alias ordering issues..."

# Function to fix alias ordering in a file
fix_aliases() {
    local file="$1"
    local temp_file="${file}.tmp"
    
    echo "Processing $file..."
    
    # Use Elixir to properly sort aliases
    elixir -e "
    content = File.read!(\"$file\")
    
    # Function to sort aliases in a block
    sort_aliases = fn text ->
      # Find blocks of aliases and sort them
      Regex.replace(~r/(  alias .+\n)+/m, text, fn match ->
        lines = String.split(match, \"\n\", trim: true)
        sorted = Enum.sort(lines)
        Enum.join(sorted, \"\n\") <> \"\n\"
      end)
    end
    
    updated = sort_aliases.(content)
    File.write!(\"$temp_file\", updated)
    "
    
    if [ -f "$temp_file" ]; then
        mv "$temp_file" "$file"
        echo "  Fixed $file"
    fi
}

# Files with alias ordering issues
files=(
    "/workspace/lib/eve_dmv_web/live/universal_search_live.ex"
    "/workspace/lib/eve_dmv_web/live/system_live.ex"
    "/workspace/lib/eve_dmv_web/live/corporation_live/data_loader.ex"
    "/workspace/lib/eve_dmv_web/live/corporation_live.ex"
    "/workspace/lib/eve_dmv_web/live/character_analysis/character_analysis_live.ex"
    "/workspace/lib/eve_dmv_web/live/admin/performance_dashboard_live.ex"
    "/workspace/lib/eve_dmv/streaming/killmail_streamer.ex"
    "/workspace/lib/eve_dmv/platform/workers/cache_warming_worker.ex"
    "/workspace/lib/eve_dmv/platform/monitoring/pipeline_monitor.ex"
    "/workspace/lib/eve_dmv/platform/monitoring/error_tracker.ex"
    "/workspace/lib/eve_dmv/platform/database/killmail_repository.ex"
    "/workspace/lib/eve_dmv/platform/database/character_repository.ex"
    "/workspace/lib/eve_dmv/platform/database/character_queries.ex"
    "/workspace/lib/eve_dmv/platform/database/cache_warmer.ex"
    "/workspace/lib/eve_dmv/platform/database/cache_invalidator.ex"
    "/workspace/lib/eve_dmv/platform/database/cache_hash_manager.ex"
    "/workspace/lib/eve_dmv/platform/cache/intelligence/intelligence_cache.ex"
    "/workspace/lib/eve_dmv/platform/cache/intelligence/analysis_cache.ex"
    "/workspace/lib/eve_dmv/platform/cache/cache.ex"
    "/workspace/lib/eve_dmv/external/eve/name_resolver/static_data_resolver.ex"
    "/workspace/lib/eve_dmv/external/eve/market_data_service.ex"
    "/workspace/lib/eve_dmv/external/eve/fallback_strategy.ex"
    "/workspace/lib/eve_dmv/core/domain/analytics/pattern_analysis.ex"
    "/workspace/lib/eve_dmv/contexts/system_analysis.ex"
    "/workspace/lib/eve_dmv/contexts/player_profile/infrastructure/player_repository.ex"
    "/workspace/lib/eve_dmv/contexts/intelligence/services/profile_service.ex"
    "/workspace/lib/eve_dmv/contexts/intelligence/services/insight_generator.ex"
    "/workspace/lib/eve_dmv/contexts/intelligence/services/comparison_service.ex"
    "/workspace/lib/eve_dmv/contexts/intelligence/core/threat_assessment_engine.ex"
    "/workspace/lib/eve_dmv/contexts/intelligence/core/ship_preference_analyzer.ex"
    "/workspace/lib/eve_dmv/contexts/intelligence/core/performance_analyzer.ex"
    "/workspace/lib/eve_dmv/contexts/intelligence/core/combat_stats_analyzer.ex"
    "/workspace/lib/eve_dmv/contexts/intelligence/core/character_analyzer.ex"
    "/workspace/lib/eve_dmv/contexts/intelligence/core/behavioral_pattern_analyzer.ex"
    "/workspace/lib/eve_dmv/contexts/corporation_intelligence/domain/analyzers/member_risk_assessment.ex"
    "/workspace/lib/eve_dmv/contexts/corporation_intelligence/domain/analyzers/member_activity_data_collector.ex"
    "/workspace/lib/eve_dmv/contexts/corporation_intelligence/domain/analyzers/member_activity_analyzer/corporation_analyzer.ex"
    "/workspace/lib/eve_dmv/contexts/corporation_intelligence/domain/analyzers/member_activity_analyzer/activity_helpers.ex"
    "/workspace/lib/eve_dmv/contexts/corporation_intelligence/api.ex"
    "/workspace/lib/eve_dmv/contexts/corporation_intelligence.ex"
    "/workspace/lib/eve_dmv/contexts/corporation/core/recruitment_analyzer.ex"
    "/workspace/lib/eve_dmv/contexts/corporation/core/organizational_health_analyzer.ex"
    "/workspace/lib/eve_dmv/contexts/combat/services/doctrine_effectiveness_service.ex"
    "/workspace/lib/eve_dmv/contexts/character_intelligence/domain/engines/gang_effectiveness_engine.ex"
    "/workspace/lib/eve_dmv/contexts/character_intelligence/analyzers/character_intelligence_analyzer.ex"
)

for file in "${files[@]}"; do
    if [ -f "$file" ]; then
        fix_aliases "$file"
    else
        echo "  Warning: $file not found"
    fi
done

echo "Alias ordering fixes complete!"
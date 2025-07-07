# Variable Redeclaration Issues Summary

## Files with Variable Redeclaration Issues (63 total)

### Test Files (2)
1. `test/support/killmails/mock_sse_server.ex` - Variable: `parts`
2. `test/support/killmails/pipeline_test_helper.ex` - Variable: `parts`

### Production Files (61)

#### Combat Intelligence Context (1)
1. `lib/eve_dmv/contexts/combat_intelligence/domain/battle_analysis_service.ex` - Variable: `factors`

#### Corporation Analysis Context (3)
1. `lib/eve_dmv/contexts/corporation_analysis/analyzers/member_activity_analyzer.ex` - Variable: `factors`
2. `lib/eve_dmv/contexts/corporation_analysis/formatters/member_activity_display_formatter.ex` - Variable: `recommendations`
3. `lib/eve_dmv/contexts/corporation_analysis/domain/corporation_analyzer.ex` - Already fixed (no longer appears in the list)

#### Fleet Operations Context (3)
1. `lib/eve_dmv/contexts/fleet_operations/analyzers/composition_analyzer.ex` - Variable: `factors`
2. `lib/eve_dmv/contexts/fleet_operations/analyzers/pilot_analyzer.ex` - Variable: `score` (multiple occurrences)
3. `lib/eve_dmv/contexts/fleet_operations/domain/fleet_analyzer.ex` - Variable: `factors`

#### Player Profile Context (2)
1. `lib/eve_dmv/contexts/player_profile/domain/player_analyzer.ex` - Variables: `factors`, `recommendations`
2. `lib/eve_dmv/contexts/player_profile/formatters/character_display_formatter.ex` - Variable: `recommendations`

#### Surveillance Context (1)
1. `lib/eve_dmv/contexts/surveillance/domain/chain_intelligence_service.ex` - Variable: `recommendations`

#### Threat Assessment Context (4)
1. `lib/eve_dmv/contexts/threat_assessment/analyzers/threat_analyzer.ex` - Variables: `factors`, `risk_factors`, `warnings`, `patterns`
2. `lib/eve_dmv/contexts/threat_assessment/analyzers/vulnerability_scanner.ex` - Variables: `confidence_factors`, `quality_score`
3. `lib/eve_dmv/contexts/threat_assessment/domain/threat_analyzer.ex` - Variables: `risk_factors`, `recommendations`

#### Database Module (7)
1. `lib/eve_dmv/database/archive_manager/restore_operations.ex` - Variable: `recommendations`
2. `lib/eve_dmv/database/performance_optimizer.ex` - Variable: `recommendations`
3. `lib/eve_dmv/database/query_plan_analyzer/table_stats_analyzer.ex` - Variables: `recommendations`, `priority`, `issues`, `actions`
4. `lib/eve_dmv/database/repository/cache_helper.ex` - Variable: `recommendations`

#### EVE Module (1)
1. `lib/eve_dmv/eve/reliability_config.ex` - Variable: `recommendations`

#### Intelligence Module (24)
1. `lib/eve_dmv/intelligence/alert_system.ex` - Variable: `alerts`
2. `lib/eve_dmv/intelligence/analyzers/corporation_analyzer.ex` - Variable: `alerts`
3. `lib/eve_dmv/intelligence/analyzers/fleet_skill_analyzer.ex` - Variables: `gaps`, `recommendations`
4. `lib/eve_dmv/intelligence/analyzers/mass_calculator.ex` - Variable: `gaps`
5. `lib/eve_dmv/intelligence/analyzers/member_activity_analyzer/recruitment_retention_analyzer.ex` - Variables: `factors`, `actions`, `suggestions`
6. `lib/eve_dmv/intelligence/analyzers/wh_fleet_analyzer/doctrine_manager.ex` - Variable: `indicators`
7. `lib/eve_dmv/intelligence/analyzers/wh_fleet_analyzer/fleet_optimizer.ex` - Variables: `anomalies`, `suggested_additions`
8. `lib/eve_dmv/intelligence/generators/recruitment_insight_generator.ex` - Variables: `insights`, `suggestions`
9. `lib/eve_dmv/intelligence/intelligence_scoring/behavioral_scoring.ex` - Variable: `areas`
10. `lib/eve_dmv/intelligence/intelligence_scoring/fleet_scoring.ex` - Variables: `recommendations`, `optimizations`
11. `lib/eve_dmv/intelligence/intelligence_scoring/intelligence_suitability.ex` - Variables: `training_recommendations`, `recommendations`
12. `lib/eve_dmv/intelligence/intelligence_scoring/recruitment_scoring.ex` - Variables: `risks`, `recommendations`
13. `lib/eve_dmv/intelligence/metrics/character_metrics.ex` - Variable: `risks`
14. `lib/eve_dmv/intelligence/performance_optimizer.ex` - Variable: `priority_improvements`
15. `lib/eve_dmv/intelligence/ship_database/doctrine_data.ex` - Variable: `strategy_score`
16. `lib/eve_dmv/intelligence/ship_database/wormhole_utils.ex` - Variable: `missing`

#### Killmails Module (1)
1. `lib/eve_dmv/killmails/display_service.ex` - Variable: `recommendations`

#### Quality Module (3)
1. `lib/eve_dmv/quality/metrics_collector/code_quality_metrics.ex` - Variable: `recommendations`
2. `lib/eve_dmv/quality/metrics_collector/documentation_metrics.ex` - Variable: `recommendations`
3. `lib/eve_dmv/quality/metrics_collector/performance_metrics.ex` - Variable: `recommendations`

#### Core Module (1)
1. `lib/eve_dmv/result.ex` - Variable: `recommendations`

#### Telemetry Module (6)
1. `lib/eve_dmv/telemetry/performance_monitor/connection_pool_monitor.ex` - Variable: `recommendations`
2. `lib/eve_dmv/telemetry/performance_monitor/health_monitor.ex` - Variables: `recommendations`, `warnings`
3. `lib/eve_dmv/telemetry/performance_monitor/index_partition_analyzer.ex` - Variable: `recommendations`
4. `lib/eve_dmv/telemetry/query_monitor.ex` - Variable: `recommendations`

#### Mix Tasks (1)
1. `lib/mix/tasks/security.audit.ex` - Variable: `report`

## Most Common Variable Names Redeclared
1. `recommendations` - 23 occurrences
2. `factors` - 5 occurrences
3. `alerts` - 3 occurrences
4. `score` - 3 occurrences (all in one file)
5. `gaps` - 2 occurrences
6. `risks` - 2 occurrences
7. `suggestions` - 2 occurrences
8. `warnings` - 2 occurrences

## Already Fixed Files
The following files from the original workstreams have been fixed and no longer appear in the credo warnings:
- `lib/eve_dmv/contexts/combat_intelligence/domain/battle_analysis_service.ex` - Fixed most issues, only `factors` remains
- `lib/eve_dmv/contexts/corporation_analysis/domain/corporation_analyzer.ex` - Fully fixed
- `lib/eve_dmv/contexts/fleet_operations/domain/fleet_analyzer.ex` - Fixed most issues, only `factors` remains
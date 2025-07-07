# Import and Alias Organization (50+ errors)

## Error Patterns

### 1. Import/Alias Order (~15 errors)
**Pattern**: "alias must appear before require" / "import must appear before require"

### 2. Consecutive Aliases (~20 errors)  
**Pattern**: "alias calls should be consecutive within a module"

### 3. Alphabetical Ordering (~15 errors)
**Pattern**: "The alias X is not alphabetically ordered among its group"

### 4. Grouped Aliases (~15 errors)
**Pattern**: "Avoid grouping aliases in '{ ... }'; please specify one fully-qualified alias per line"

## Correct Module Structure

```elixir
defmodule MyModule do
  # 1. use statements (FIRST)
  use GenServer
  
  # 2. alias statements (SECOND) - consecutive and alphabetical
  alias MyApp.FirstModule
  alias MyApp.SecondModule
  
  # 3. require statements (THIRD)
  require Logger
  
  # 4. import statements (FOURTH)
  import Ecto.Query
end
```

## Files Requiring Import/Alias Order Fixes

### Combat Intelligence Context:
- `lib/eve_dmv/contexts/combat_intelligence/domain/character_analyzer.ex:9`
- `lib/eve_dmv/contexts/combat_intelligence/domain/corporation_analyzer.ex:13`
- `lib/eve_dmv/contexts/combat_intelligence/domain/intelligence_scoring.ex:13`
- `lib/eve_dmv/contexts/combat_intelligence/domain/threat_assessor.ex:13`
- `lib/eve_dmv/contexts/combat_intelligence/infrastructure/analysis_cache.ex:9`
- `lib/eve_dmv/contexts/combat_intelligence/infrastructure/killmail_event_processor.ex:9`

### Intelligence System:
- `lib/eve_dmv/intelligence/advanced_analytics.ex:12`
- `lib/eve_dmv/intelligence/alert_system.ex:12`
- `lib/eve_dmv/intelligence/analyzers/fleet_pilot_analyzer.ex:12`
- `lib/eve_dmv/intelligence/analyzers/member_activity_data_collector.ex:12`
- `lib/eve_dmv/intelligence/analyzers/member_activity_analyzer/corporation_analyzer.ex:12`
- `lib/eve_dmv/intelligence/analyzers/member_risk_assessment.ex:15`
- `lib/eve_dmv/intelligence/core/cache_helper.ex:11`
- `lib/eve_dmv/intelligence/core/correlation_engine.ex:12`
- `lib/eve_dmv/intelligence/core/intelligence_coordinator.ex:11`
- `lib/eve_dmv/intelligence/core/query_helper.ex:11`
- `lib/eve_dmv/intelligence/core/supervisor.ex:13`
- `lib/eve_dmv/intelligence/intelligence_scoring.ex:18`
- `lib/eve_dmv/intelligence/legacy_adapter.ex:11`

### Database & Infrastructure:
- `lib/eve_dmv/database/materialized_view_manager.ex:12`
- `lib/eve_dmv/database/query_plan_analyzer.ex:14`
- `lib/eve_dmv/contexts/threat_assessment/analyzers/vulnerability_scanner.ex:13`
- `lib/eve_dmv/contexts/killmail_processing/api.ex:16` (import before require)
- `lib/eve_dmv/eve/type_resolver.ex:17` (import before require)
- `lib/eve_dmv/killmails/enriched_participant_loader.ex:16` (import before require)
- `test/eve_dmv/killmails/killmail_raw_test.exs:15` (import before require)

## Files Requiring Alphabetical Ordering

### Intelligence & Analytics:
- `lib/eve_dmv/intelligence/analysis_scheduler.ex:13:9` - ThreatAnalyzer
- `lib/eve_dmv/intelligence/analyzers/corporation_analyzer.ex:13:9` - CacheHelper
- `lib/eve_dmv/intelligence/analyzers/fleet_asset_manager/requirements_builder.ex:10:9` - ShipDatabase
- `lib/eve_dmv/intelligence/analyzers/member_activity_analyzer/recruitment_retention_analyzer.ex:9:9` - RecommendationGenerator
- `lib/eve_dmv/intelligence/analyzers/wh_fleet_analyzer/fleet_analyzer.ex:9:9` - ShipDatabase

### Database & Archive:
- `lib/eve_dmv/database/archive_manager/maintenance_scheduler.ex:9:9` - ArchiveOperations

### EVE API & Name Resolution:
- `lib/eve_dmv/eve/esi_request_client.ex:12:9` - PerformanceMonitor
- `lib/eve_dmv/eve/name_resolver.ex:17:9` - CacheManager
- `lib/eve_dmv/eve/name_resolver/performance_optimizer.ex:9:9` - StaticDataResolver

### Context & Domain:
- `lib/eve_dmv/contexts/wormhole_operations.ex:22:9` - CharacterAnalyzed
- `lib/eve_dmv/contexts/combat_intelligence/infrastructure/killmail_event_processor.ex:9:9` - KillmailEnriched

### Web & UI:
- `lib/eve_dmv_web/components/intelligence_components.ex:10:9` - Phoenix.LiveView.JS
- `lib/eve_dmv_web/live/surveillance_live/batch_operation_service.ex:9:9` - MatchingEngine

### Other:
- `lib/eve_dmv/killmails/killmail_pipeline.ex:13:9` - DataProcessor
- `lib/eve_dmv/surveillance/matching/match_evaluator.ex:9:9` - ProfileMatch
- `test/test_helper.exs:34:9` - Repo

## Files Requiring Grouped Alias Fixes

### Test Files (expand `alias Module.{A, B, C}` format):
- `test/benchmarks/intelligence_benchmark.exs:9`
- `test/eve_dmv/intelligence_engine_basic_test.exs:8:36`
- `test/eve_dmv/intelligence_engine_test.exs:9:36`
- `test/eve_dmv/killmails/killmail_pipeline_test.exs:10`
- `test/manual/manual_testing_data_generator.exs:12:27`
- `test/manual/manual_testing_data_generator.exs:13:30`
- `test/performance/performance_test_suite.exs:16:30`
- `test/performance/performance_test_suite.exs:18:27`
- `test/support/intelligence_case.ex:17`
- `test/support/killmails/pipeline_test_helper.ex:6:17`
- `test/support/killmails/pipeline_test_helper.ex:7:27`

### Application Files:
- `lib/eve_dmv/intelligence/analyzers/member_activity_analyzer.ex:10`
- `lib/eve_dmv/contexts/surveillance/domain/chain_intelligence_service.ex:19`
- `lib/eve_dmv/contexts/surveillance/domain/chain_intelligence_service.ex:27:30`
- `lib/eve_dmv/contexts/surveillance/domain/chain_intelligence_service.ex:28:30`

## Files Requiring Consecutive Alias Fixes

### Intelligence Files with Scattered Aliases:
- `lib/eve_dmv/intelligence/advanced_analytics.ex` - Lines 12, 13, 14, 15
- `lib/eve_dmv/intelligence/analyzers/member_activity_data_collector.ex` - Lines 12, 13, 14, 15, 16, 17
- `lib/eve_dmv/intelligence/analyzers/member_activity_analyzer/corporation_analyzer.ex` - Lines 12, 13, 14, 15, 16, 17
- `lib/eve_dmv/intelligence/intelligence_scoring.ex` - Lines 18, 19, 20, 21, 22

## Step-by-Step Fix Process

### Phase 1: Import/Alias Order (15 minutes)
For each file with order issues:
1. **Locate imports section** at top of module
2. **Reorganize** in order: use → alias → require → import
3. **Keep logical groupings** but maintain order

### Phase 2: Alphabetical Ordering (10 minutes)  
For each file with ordering issues:
1. **Within each alias group**, sort alphabetically
2. **Maintain namespace grouping** when logical

### Phase 3: Expand Grouped Aliases (10 minutes)
For each grouped alias:
```elixir
# BEFORE:
alias MyApp.{ModuleA, ModuleB, ModuleC}

# AFTER:
alias MyApp.ModuleA
alias MyApp.ModuleB
alias MyApp.ModuleC
```

### Phase 4: Consolidate Consecutive Aliases (10 minutes)
For each file with scattered aliases:
1. **Move all alias statements together**
2. **Remove scattered alias statements**
3. **Sort alphabetically** within consolidated group

## Time Estimates
- **Phase 1**: 15 minutes (order fixes)
- **Phase 2**: 10 minutes (alphabetical)
- **Phase 3**: 10 minutes (expand groups)
- **Phase 4**: 10 minutes (consolidate)
- **Total**: 45 minutes

## Verification Commands

```bash
# Check import/alias order
mix credo | grep -c "alias must appear before require"
mix credo | grep -c "import must appear before"

# Check alphabetical ordering
mix credo | grep -c "not alphabetically ordered"

# Check grouped aliases
mix credo | grep -c "Avoid grouping aliases"

# Check consecutive aliases
mix credo | grep -c "alias.*should be consecutive"

# Total progress
mix credo --format=oneline | wc -l
```

## Expected Results
- **Before**: ~50 import/alias errors
- **After**: 0 import/alias errors
- **Impact**: 25% reduction in total issues
- **Benefit**: Consistent, clean module organization across codebase
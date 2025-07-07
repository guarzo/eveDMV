# Import and Alias Organization - 70+ Errors

## Error Patterns

### 1. Import/Alias Order (25 errors)
**Pattern:** "alias must appear before require" / "import must appear before require"

### 2. Alias Alphabetization (20 errors) 
**Pattern:** "The alias X is not alphabetically ordered among its group"

### 3. Alias Grouping (15 errors)
**Pattern:** "Avoid grouping aliases in '{ ... }'; please specify one fully-qualified alias per line"

### 4. Consecutive Aliases (10+ errors)
**Pattern:** "alias calls should be consecutive within a module"

## Correct Order and Structure

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

### Combat Intelligence Domain:
- `lib/eve_dmv/contexts/combat_intelligence/domain/character_analyzer.ex:9`
- `lib/eve_dmv/contexts/combat_intelligence/domain/corporation_analyzer.ex:13`
- `lib/eve_dmv/contexts/combat_intelligence/domain/intelligence_scoring.ex:13`
- `lib/eve_dmv/contexts/combat_intelligence/domain/threat_assessor.ex:13`
- `lib/eve_dmv/contexts/combat_intelligence/infrastructure/analysis_cache.ex:9`
- `lib/eve_dmv/contexts/combat_intelligence/infrastructure/killmail_event_processor.ex:9`

### Database Layer:
- `lib/eve_dmv/database/connection_pool_monitor.ex:12`
- `lib/eve_dmv/database/health_check.ex:11`
- `lib/eve_dmv/database/killmail_repository.ex:15`
- `lib/eve_dmv/database/materialized_view_manager.ex:12`
- `lib/eve_dmv/database/partition_manager.ex:12`
- `lib/eve_dmv/database/performance_optimizer.ex:13`
- `lib/eve_dmv/database/query_plan_analyzer.ex:14`
- `lib/eve_dmv/database/query_utils.ex:11`

### Intelligence System:
- `lib/eve_dmv/intelligence/advanced_analytics.ex:12`
- `lib/eve_dmv/intelligence/alert_system.ex:12`
- `lib/eve_dmv/intelligence/analyzers/character_analyzer.ex:16`
- `lib/eve_dmv/intelligence/analyzers/fleet_pilot_analyzer.ex:12`
- `lib/eve_dmv/intelligence/analyzers/member_activity_analyzer/corporation_analyzer.ex:12`
- `lib/eve_dmv/intelligence/analyzers/member_activity_data_collector.ex:12`
- `lib/eve_dmv/intelligence/analyzers/member_activity_pattern_analyzer.ex:19`
- `lib/eve_dmv/intelligence/analyzers/member_risk_assessment.ex:15`
- `lib/eve_dmv/intelligence/analyzers/wh_fleet_analyzer.ex:14`
- `lib/eve_dmv/intelligence/core/cache_helper.ex:11`
- `lib/eve_dmv/intelligence/core/intelligence_coordinator.ex:11`
- `lib/eve_dmv/intelligence/core/query_helper.ex:11`
- `lib/eve_dmv/intelligence/core/supervisor.ex:13`
- `lib/eve_dmv/intelligence/intelligence_scoring.ex:18`
- `lib/eve_dmv/intelligence/legacy_adapter.ex:11`

### Other Modules:
- `lib/eve_dmv/contexts/killmail_processing/api.ex:10` (import before require)
- `lib/eve_dmv/contexts/threat_assessment/analyzers/vulnerability_scanner.ex:13`
- `lib/eve_dmv/enrichment/real_time_price_updater.ex:13`
- `lib/eve_dmv/eve/type_resolver.ex:17` (import before require)
- `lib/eve_dmv/killmails/enriched_participant_loader.ex:16` (import before require)

## Files Requiring Alias Alphabetization

### Combat Intelligence:
- `lib/eve_dmv/contexts/combat_intelligence/infrastructure/killmail_event_processor.ex:9:9`

### Wormhole Operations:
- `lib/eve_dmv/contexts/wormhole_operations.ex:22:9`
- `lib/eve_dmv/contexts/wormhole_operations/api.ex:20:9`

### Database:
- `lib/eve_dmv/database/archive_manager/maintenance_scheduler.ex:9:9`
- `lib/eve_dmv/database/killmail_repository.ex:15:9`
- `lib/eve_dmv/database/query_utils.ex:11:9`

### EVE API:
- `lib/eve_dmv/eve/esi_request_client.ex:12:9`
- `lib/eve_dmv/eve/name_resolver.ex:17:9`
- `lib/eve_dmv/eve/name_resolver/performance_optimizer.ex:9:9`

### Intelligence:
- `lib/eve_dmv/intelligence/analysis_scheduler.ex:13:9`
- `lib/eve_dmv/intelligence/analyzers/corporation_analyzer.ex:13:9`
- `lib/eve_dmv/intelligence/analyzers/fleet_asset_manager/requirements_builder.ex:10:9`
- `lib/eve_dmv/intelligence/analyzers/member_activity_analyzer/recruitment_retention_analyzer.ex:9:9`
- `lib/eve_dmv/intelligence/analyzers/wh_fleet_analyzer/fleet_analyzer.ex:9:9`

### Killmails:
- `lib/eve_dmv/killmails/killmail_pipeline.ex:13:9`

### Surveillance:
- `lib/eve_dmv/surveillance/matching/match_evaluator.ex:9:9`
- `lib/eve_dmv_web/live/surveillance_live/batch_operation_service.ex:9:9`

### Test Files:
- `test/eve_dmv/killmails/killmail_raw_test.exs:10:9`
- `test/test_helper.exs:21:9`

## Files Requiring Alias Grouping Fixes

### Test Files (expand grouped aliases):
- `test/benchmarks/intelligence_benchmark.exs:9`
- `test/eve_dmv/intelligence_engine_basic_test.exs:8:36`
- `test/eve_dmv/intelligence_engine_test.exs:9:36`
- `test/eve_dmv/killmails/killmail_pipeline_test.exs:10`
- `test/eve_dmv/killmails/killmail_raw_test.exs:10:27`
- `test/manual/manual_testing_data_generator.exs:12:27`
- `test/performance/performance_test_suite.exs:18:27`
- `test/support/factories.ex:6:17`
- `test/support/intelligence_case.ex:17`
- `test/support/killmails/pipeline_test_helper.ex:6:17`
- `test/support/killmails/pipeline_test_helper.ex:7:27`

### Intelligence Analyzer:
- `lib/eve_dmv/intelligence/analyzers/member_activity_analyzer.ex:10`

## Files Requiring Consecutive Alias Fixes

**Pattern:** Multiple scattered alias statements should be grouped together

### Intelligence Files:
- `lib/eve_dmv/intelligence/advanced_analytics.ex` - Lines 12, 13, 14, 15
- `lib/eve_dmv/intelligence/analyzers/character_analyzer.ex:16`
- `lib/eve_dmv/intelligence/analyzers/member_activity_analyzer/corporation_analyzer.ex` - Lines 12-17
- `lib/eve_dmv/intelligence/analyzers/member_activity_data_collector.ex` - Lines 12-17
- `lib/eve_dmv/intelligence/analyzers/wh_fleet_analyzer.ex` - Lines 14-25
- `lib/eve_dmv/intelligence/intelligence_scoring.ex` - Lines 18-22

## Step-by-Step Fix Process

### 1. Start with Import/Alias Order (25 fixes - 30 minutes)
1. Open each file
2. Locate the import section at top of module
3. Reorganize in order: use → alias → require → import
4. Save and verify compilation

### 2. Fix Alias Alphabetization (20 fixes - 20 minutes)
1. Within each alias group, sort alphabetically
2. Maintain grouped organization by namespace

### 3. Expand Grouped Aliases (15 fixes - 15 minutes)
```elixir
# BEFORE:
alias MyApp.{ModuleA, ModuleB, ModuleC}

# AFTER:
alias MyApp.ModuleA
alias MyApp.ModuleB  
alias MyApp.ModuleC
```

### 4. Consolidate Consecutive Aliases (10 fixes - 15 minutes)
1. Move all alias statements together
2. Remove scattered alias statements throughout module
3. Sort alphabetically within the consolidated group

## Expected Results

**Errors eliminated:** ~70 errors (23% of remaining)
**Time invested:** ~80 minutes  
**Before:** 236 errors
**After:** ~166 errors

## Verification Commands

```bash
# Check import/alias order
grep -c "alias must appear before require" /workspace/credo2.txt
grep -c "import must appear before" /workspace/credo2.txt

# Check alphabetical ordering
grep -c "not alphabetically ordered" /workspace/credo2.txt

# Check grouped aliases
grep -c "Avoid grouping aliases" /workspace/credo2.txt

# Check consecutive aliases
grep -c "alias.*should be consecutive" /workspace/credo2.txt

# Total progress
wc -l /workspace/credo2.txt
```

This phase will create consistent, well-organized import sections across the entire codebase.
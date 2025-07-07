# Structural and Logic Fixes - ~100 Remaining Errors

## Pipeline and Function Call Issues (40+ errors)

### 1. Single Function Pipelines (25+ errors)
**Pattern:** "Use a function call when a pipeline is only one function long"

#### Files to fix:
- `lib/eve_dmv/database/archive_manager/archive_operations.ex:67:7`
- `lib/eve_dmv/database/materialized_view_manager/view_definitions.ex:45:5`
- `lib/eve_dmv/database/materialized_view_manager/view_refresh_scheduler.ex:26:7`
- `lib/eve_dmv/database/materialized_view_manager/view_refresh_scheduler.ex:143:9`
- `lib/eve_dmv/eve/name_resolver/batch_processor.ex:168:5`
- `lib/eve_dmv/eve/name_resolver/performance_optimizer.ex:33:11`
- `lib/eve_dmv/intelligence/alert_system.ex:123:61`
- `lib/eve_dmv/intelligence/analyzers/fleet_asset_manager/acquisition_planner.ex:86:7`
- `lib/eve_dmv/intelligence/analyzers/fleet_pilot_analyzer.ex:347:5`
- `lib/eve_dmv/intelligence/analyzers/fleet_skill_analyzer.ex:205:7`
- `lib/eve_dmv/intelligence/analyzers/home_defense_analyzer.ex:268:7`
- `lib/eve_dmv/intelligence/analyzers/home_defense_analyzer.ex:304:7`
- `lib/eve_dmv/intelligence/analyzers/member_activity_data_collector.ex:100:11`
- `lib/eve_dmv/intelligence/core/intelligence_coordinator.ex:221:5`
- `lib/eve_dmv/intelligence/legacy_adapter.ex:65:11`
- `lib/eve_dmv/intelligence/metrics/character_metrics.ex:146:9`
- `lib/eve_dmv/intelligence/metrics/character_metrics.ex:193:7`
- `lib/eve_dmv/intelligence/metrics/character_metrics.ex:502:37`
- `lib/eve_dmv/intelligence/metrics/combat_metrics_calculator.ex:163:5`
- `lib/eve_dmv/intelligence/metrics/ship_analysis_calculator.ex:54:9`
- `lib/eve_dmv/intelligence_engine/config.ex:112:5`
- `lib/eve_dmv/market/mutamarket_client.ex:289:11`
- `lib/eve_dmv_web/live/chain_intelligence_live.ex:165:7`
- `lib/eve_dmv_web/plugs/api_auth.ex:134:9`

#### Test files:
- `test/eve_dmv/security/headers_validator_test.exs:58:9`
- `test/eve_dmv_web/controllers/auth_controller_test.exs:88:50`

**Fix Pattern:**
```elixir
# BEFORE:
data |> transform()

# AFTER:
transform(data)
```

### 2. Nested Function Calls (2 errors)
**Pattern:** "Use a pipeline instead of nested function calls"

#### Files to fix:
- `lib/eve_dmv/contexts/threat_assessment/infrastructure/threat_repository.ex:86:7`
- `test/eve_dmv/killmails/killmail_raw_test.exs:34:16`

**Fix Pattern:**
```elixir
# BEFORE:
result = transform(process(validate(data)))

# AFTER:
result = 
  data
  |> validate()
  |> process()
  |> transform()
```

### 3. with/case Conversions (8 errors)
**Pattern:** "with contains only one <- clause and an else branch, consider using case instead"

#### Files to fix:
- `lib/eve_dmv/contexts/wormhole_operations/api.ex:105:5`
- `lib/eve_dmv/contexts/wormhole_operations/api.ex:216:5`
- `lib/eve_dmv/database/materialized_view_manager/view_metrics.ex:195:7`
- `lib/eve_dmv/intelligence/intelligence_scoring.ex:76:5`
- `lib/eve_dmv/intelligence/intelligence_scoring/recruitment_scoring.ex:24:5`
- `lib/eve_dmv/workers/background_task_supervisor.ex:60:5`
- `lib/eve_dmv/workers/realtime_task_supervisor.ex:60:5`

**Fix Pattern:**
```elixir
# BEFORE:
with {:ok, data} <- fetch_data() do
  process(data)
else
  error -> handle_error(error)
end

# AFTER:
case fetch_data() do
  {:ok, data} -> process(data)
  error -> handle_error(error)
end
```

## Module Structure Issues (25+ errors)

### 1. defstruct Position (25 errors)
**Pattern:** "defstruct must appear before module attribute"

#### Files to fix:
- `lib/eve_dmv/domain_events.ex` - Lines 18, 55, 75, 99, 127, 151, 177, 203, 233, 261, 287, 313, 337, 361, 387, 432, 460, 488, 520, 548, 576, 604, 628, 656
- `lib/eve_dmv/error.ex:30`
- `lib/eve_dmv/eve/circuit_breaker.ex:33`
- `lib/eve_dmv/intelligence/chain_monitor.ex:23`
- `lib/eve_dmv/intelligence/wanderer_client.ex:21`
- `lib/eve_dmv/intelligence/wanderer_sse.ex:19`

### 2. Module Attribute Position (5 errors)
**Pattern:** "module attribute must appear before [private function/type]"

#### Files to fix:
- `lib/eve_dmv/database/performance_optimizer.ex:35`
- `lib/eve_dmv/infrastructure/event_bus.ex:21` (type before module attribute)
- `lib/eve_dmv/intelligence/wanderer_client.ex:17`
- `lib/eve_dmv/killmails/historical_killmail_fetcher.ex:23`

### 3. Type Position (2 errors)
**Pattern:** "typep must appear before public function"

#### Files to fix:
- `lib/eve_dmv/killmails/data_processor.ex:112`

### 4. Moduledoc Position (3 errors)
**Pattern:** "moduledoc must appear before module attribute"

#### Files to fix:
- `lib/eve_dmv/market/strategies/esi_strategy.ex:4`
- `lib/eve_dmv/market/strategies/mutamarket_strategy.ex:6`

### 5. Shortdoc Position (3 errors)
**Pattern:** "shortdoc must appear before alias"

#### Files to fix:
- `lib/mix/tasks/eve.analyze_performance.ex:10`
- `lib/mix/tasks/eve.load_static_data.ex:30`
- `lib/mix/tasks/security.audit.ex:22`

## Prefer Implicit Try (25+ errors)

**Pattern:** "Prefer using an implicit try rather than explicit try"

### Files to fix:
- `lib/eve_dmv/error_handler.ex:97:9`
- `lib/eve_dmv/infrastructure/event_bus.ex:303:5`
- `lib/eve_dmv/intelligence/analysis_scheduler.ex:244:5`
- `lib/eve_dmv/intelligence/analyzers/corporation_analyzer.ex:144:5`
- `lib/eve_dmv/intelligence/analyzers/corporation_analyzer.ex:163:5`
- `lib/eve_dmv/intelligence/analyzers/corporation_analyzer.ex:198:5`
- `lib/eve_dmv/intelligence/analyzers/fleet_pilot_analyzer.ex:114:5`
- `lib/eve_dmv/intelligence/analyzers/home_defense_analyzer.ex:171:5`
- `lib/eve_dmv/intelligence/analyzers/home_defense_analyzer.ex:189:5`
- `lib/eve_dmv/intelligence/analyzers/home_defense_analyzer.ex:203:5`
- `lib/eve_dmv/intelligence/cache_cleanup_worker.ex:174:5`
- `lib/eve_dmv/intelligence/metrics/character_metrics_adapter.ex:70:5`
- `lib/eve_dmv/intelligence/metrics/character_metrics_adapter.ex:91:5`
- `lib/eve_dmv/intelligence/supervisor.ex:184:5`
- `lib/eve_dmv/intelligence/supervisor.ex:204:5`
- `lib/eve_dmv/intelligence_migration_adapter.ex:106:5`
- `lib/eve_dmv/killmails/data_processor.ex:23:5`
- `lib/eve_dmv/result.ex:178:5`
- `lib/eve_dmv/surveillance/matching/profile_compiler.ex:23:5`
- `lib/eve_dmv/workers/background_task_supervisor.ex:264:5`
- `lib/eve_dmv/workers/realtime_task_supervisor.ex:302:5`
- `lib/eve_dmv/workers/ui_task_supervisor.ex:220:5`
- `lib/eve_dmv_web/live/surveillance_live/batch_operation_service.ex:96:5`
- `lib/eve_dmv_web/live/surveillance_live/export_import_service.ex:120:5`
- `lib/eve_dmv_web/live/surveillance_live/profile_service.ex:160:5`

**Fix Pattern:**
```elixir
# BEFORE:
try do
  some_operation()
rescue
  error -> handle_error(error)
end

# AFTER (implicit try):
some_operation()
rescue
  error -> handle_error(error)
```

## Minor Issues (10+ errors)

### 1. Line Length (2 errors)
- `lib/eve_dmv/contexts/wormhole_operations/api.ex:15:121` (121 > 120)
- `test/performance/performance_test_suite.exs:450:121` (121 > 120)

### 2. Unused Return Values (2 errors) 
- `lib/eve_dmv/intelligence/advanced_analytics.ex:265:9`
- `lib/eve_dmv/intelligence/analyzers/fleet_asset_manager/acquisition_planner.ex:47:5`

### 3. Logger Metadata Warnings (2 errors)
- `lib/eve_dmv/contexts/combat_intelligence/infrastructure/killmail_event_processor.ex:33:65`
- `lib/eve_dmv/contexts/fleet_operations/infrastructure/killmail_fleet_processor.ex:17:60`

### 4. Nested Module Aliases (10+ errors)
**Pattern:** "Nested modules could be aliased at the top of the invoking module"

## Step-by-Step Execution

### Phase 1: Pipeline Fixes (40 minutes)
1. **Single function pipelines** (25 fixes) - 25 minutes
2. **Nested function calls** (2 fixes) - 5 minutes  
3. **with/case conversions** (8 fixes) - 10 minutes

### Phase 2: Module Structure (30 minutes)
1. **defstruct positioning** (25 fixes) - 20 minutes
2. **Other structural fixes** (10 fixes) - 10 minutes

### Phase 3: Try/Rescue (20 minutes)
1. **Implicit try** (25 fixes) - 20 minutes

### Phase 4: Minor Issues (10 minutes)
1. **Line length, unused returns, etc.** (15 fixes) - 10 minutes

## Expected Results

**Errors eliminated:** ~90 errors (30% of remaining)
**Time invested:** ~100 minutes
**Before:** 166 errors  
**After:** ~76 errors

## Verification Commands

```bash
# Check pipelines
grep -c "Use a function call when a pipeline" /workspace/credo2.txt
grep -c "Use a pipeline instead of nested" /workspace/credo2.txt

# Check with/case
grep -c "with.*consider using.*case" /workspace/credo2.txt

# Check structure
grep -c "defstruct must appear before" /workspace/credo2.txt
grep -c "must appear before" /workspace/credo2.txt

# Check try/rescue
grep -c "implicit.*try" /workspace/credo2.txt

# Total progress
wc -l /workspace/credo2.txt
```

This phase addresses the core structural and logic organization issues in the codebase.
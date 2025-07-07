# Quick Mechanical Fixes - 302 Errors Remaining

## High Impact, Low Effort Fixes (Start Here)

### 1. Number Formatting (25 errors) - 15 minutes
**Pattern:** "Numbers larger than 9999 should be written with underscores"

#### Files to fix:
- `lib/eve_dmv/intelligence/analyzers/fleet_pilot_analyzer.ex:274:6` - 29336 → 29_336
- `lib/eve_dmv/intelligence/analyzers/fleet_pilot_analyzer.ex:274:13` - 17918 → 17_918  
- `lib/eve_dmv/intelligence/analyzers/fleet_pilot_analyzer.ex:274:20` - 24698 → 24_698
- `lib/eve_dmv/intelligence/analyzers/fleet_pilot_analyzer.ex:355:67` - 86400 → 86_400
- `lib/eve_dmv/intelligence_engine/config.ex:44:28` - 30000 → 30_000
- `lib/eve_dmv/shared/ship_database_service.ex:359:5` - 11176 → 11_176
- `lib/eve_dmv/shared/ship_database_service.ex:360:5` - 11182 → 11_182
- `lib/eve_dmv/shared/ship_database_service.ex:361:5` - 29984 → 29_984
- `lib/eve_dmv/shared/ship_database_service.ex:362:5` - 29990 → 29_990

#### Test files (16 instances):
- `test/eve_dmv/intelligence_engine_basic_test.exs` - 9 instances of 12345, 67890, 99999
- `test/eve_dmv/intelligence_engine_test.exs` - 6 instances of 12345, 67890
- `test/eve_dmv_web/helpers/time_formatter_test.exs:89:44` - 90061 → 90_061

**Fix:** Add underscores to numbers > 9999

### 2. @impl Annotations (5 errors) - 5 minutes
**Pattern:** "@impl true should be @impl MyBehaviour"

#### File: lib/eve_dmv/intelligence_engine/plugin_registry.ex
**Lines:** 37:3, 60:3, 70:3, 78:3, 92:3

**Fix:** Change `@impl true` to `@impl GenServer`

### 3. TODO Comments (11 errors) - 10 minutes
**Pattern:** "Found a TODO tag in a comment"

#### Files to fix:
- `lib/eve_dmv/contexts/combat_intelligence/domain/character_analyzer.ex` - Lines 121:5, 127:5, 133:5
- `lib/eve_dmv/contexts/combat_intelligence/domain/corporation_analyzer.ex` - Lines 91:5, 97:5
- `lib/eve_dmv/contexts/combat_intelligence/domain/threat_assessor.ex:101:5`
- `lib/eve_dmv/contexts/combat_intelligence/infrastructure/static_data_event_processor.ex:32:5`
- `lib/eve_dmv/contexts/fleet_operations/infrastructure/fleet_repository.ex:18:5`
- `lib/eve_dmv/contexts/fleet_operations/infrastructure/killmail_fleet_processor.ex:19:5`
- `lib/eve_dmv/contexts/wormhole_operations/api.ex:15:79`
- `lib/eve_dmv/database/archive_manager.ex:22:3`

**Fix:** Remove TODO comments or replace with implementation notes

### 4. Predicate Function Names (2 errors) - 5 minutes
**Pattern:** "Predicate function names should not start with 'is', and should end in a question mark"

#### Files to fix:
- `lib/eve_dmv/intelligence/analyzers/wh_vetting_analyzer.ex:646:8`
- `lib/eve_dmv/shared/ship_database_adapter.ex:120:7`

**Fix:**
```elixir
# BEFORE:
defp is_valid_ship(ship)

# AFTER:
defp valid_ship?(ship)
```

### 5. Enum.map_join Optimizations (12 errors) - 20 minutes
**Pattern:** "Enum.map_join/3 is more efficient than Enum.map/2 |> Enum.join/2"

#### Files to fix:
- `lib/eve_dmv/database/archive_manager/restore_operations.ex:255:11`
- `lib/eve_dmv/database/materialized_view_manager/view_query_service.ex:255:9`
- `lib/eve_dmv/database/repository/cache_helper.ex:129:5`
- `lib/eve_dmv/database/repository/cache_helper.ex:148:5`
- `lib/eve_dmv/shared/error_formatter.ex:42:5`
- `lib/eve_dmv/utils/time_utils.ex:289:5`
- `lib/eve_dmv_web/components/battle_timeline_component.ex:574:5`
- `lib/eve_dmv_web/components/intelligence_components.ex:603:5`
- `lib/eve_dmv_web/components/intelligence_components.ex:611:5`
- `lib/eve_dmv_web/live/battle_analysis_live.ex:905:5`
- `lib/eve_dmv_web/live/battle_analysis_live.ex:939:5`
- `lib/mix/tasks/security.audit.ex:340:5`

**Fix Pattern:**
```elixir
# BEFORE:
items |> Enum.map(&transform/1) |> Enum.join(", ")

# AFTER:
Enum.map_join(items, ", ", &transform/1)
```

### 6. Long Quote Blocks (8 errors) - 15 minutes  
**Pattern:** "Avoid long quote blocks"

#### Files to fix:
- `lib/eve_dmv/contexts/bounded_context.ex:40:5`
- `lib/eve_dmv/database/repository.ex:34:5`
- `lib/eve_dmv/error_handler.ex:68:5`
- `lib/eve_dmv/intelligence/analyzer.ex:48:5`
- `lib/eve_dmv_web.ex:41:5`
- `lib/eve_dmv_web.ex:85:5`
- `lib/eve_dmv_web/components/reusable_components.ex:25:5`
- `test/support/conn_case.ex:21:5`
- `test/support/intelligence_case.ex:11:5`
- `test/support/ui_case.ex:26:5`

**Fix:** Shorten @moduledoc strings to be more concise

### 7. Negated Conditions (3 errors) - 10 minutes
**Pattern:** "Avoid negated conditions in if-else blocks"

#### Files to fix:
- `lib/eve_dmv/intelligence/analyzers/member_activity_pattern_analyzer/timezone_analyzer.ex:34:8`
- `lib/eve_dmv/quality/metrics_collector/ci_cd_metrics.ex:67:10`
- `lib/eve_dmv/quality/metrics_collector/ci_cd_metrics.ex:77:10`

**Fix Pattern:**
```elixir
# BEFORE:
if !condition do
  do_something()
else
  do_other()
end

# AFTER:
if condition do
  do_other()
else
  do_something()
end
```

## Expected Results After Quick Fixes

**Errors eliminated:** ~66 errors (22% of total)
**Time invested:** ~70 minutes
**Remaining errors:** ~236

## Verification Commands

```bash
# Check number formatting
grep -c "should be written with underscores" /workspace/credo2.txt

# Check @impl annotations  
grep -c "@impl true.*should be" /workspace/credo2.txt

# Check TODO comments
grep -c "Found a TODO tag" /workspace/credo2.txt

# Check predicate functions
grep -c "should end in a question mark" /workspace/credo2.txt

# Check Enum.map_join
grep -c "map_join.*more efficient" /workspace/credo2.txt

# Total progress
wc -l /workspace/credo2.txt
```

Start with these high-impact, low-effort fixes to build momentum before tackling the more complex structural issues.
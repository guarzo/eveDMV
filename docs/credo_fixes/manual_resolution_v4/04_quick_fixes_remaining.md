# Quick Fixes for Remaining Issues

These are simple mechanical fixes that can be completed quickly.

## Trailing Whitespace Errors (40+ errors)

**Pattern:** "There should be no trailing white-space at the end of a line"

### Files with trailing whitespace:
- `lib/eve_dmv/contexts/fleet_operations/infrastructure/engagement_cache.ex:4:1`
- `lib/eve_dmv/contexts/killmail_processing/api.ex:66:1, 100:1, 122:1, 148:1`
- `lib/eve_dmv/intelligence/analyzers/member_activity_analyzer.ex:411:1, 514:51, 533:1, 536:1, 539:1, 542:1`
- `lib/eve_dmv/intelligence/analyzers/wh_vetting_analyzer.ex:144:1, 437:40, 440:44, 443:26, 465:20, 470:1`

**Fix:** Open each file, go to the line, remove trailing spaces at end of line.

## Missing Final Newlines (10+ errors)

**Pattern:** "There should be a final \n at the end of each file"

### Files missing final newlines:
- `lib/eve_dmv/contexts/fleet_operations/infrastructure/engagement_cache.ex:29`

**Fix:** Open file, go to end, add a newline after the last line.

## Numbers Need Underscores (6 errors)

**Pattern:** "Numbers larger than 9999 should be written with underscores"

### Files to fix:
- `lib/eve_dmv/intelligence_engine/config.ex:42:28` - `30000` → `30_000`
- `lib/eve_dmv/shared/ship_database_service.ex` - Lines 359-362:
  - `11176` → `11_176`
  - `11182` → `11_182`  
  - `29984` → `29_984`
  - `29990` → `29_990`

**Fix:** Add underscores to break up large numbers.

## @impl Annotations (5 errors)

**Pattern:** "@impl true should be @impl MyBehaviour"

### File: lib/eve_dmv/intelligence_engine/plugin_registry.ex
**Lines 37:3, 60:3, 70:3, 78:3, 92:3**

**Fix:** Change all `@impl true` to `@impl GenServer` (or whatever the actual behavior is).

## Enum.map_join Optimizations (8 errors)

**Pattern:** "Enum.map_join/3 is more efficient than Enum.map/2 |> Enum.join/2"

### Files to fix:
- `lib/eve_dmv/database/archive_manager/restore_operations.ex:255:11`
- `lib/eve_dmv/shared/error_formatter.ex:42:5`
- `lib/eve_dmv/utils/time_utils.ex:288:5`
- `lib/eve_dmv_web/components/battle_timeline_component.ex:574:5`
- `lib/eve_dmv_web/components/intelligence_components.ex:603:5, 611:5`
- `lib/eve_dmv_web/live/battle_analysis_live.ex:905:5, 925:5`

**Fix Pattern:**
```elixir
# BEFORE:
items |> Enum.map(&transform/1) |> Enum.join(", ")

# AFTER:
Enum.map_join(items, ", ", &transform/1)
```

## Long Quote Blocks (4 errors)

**Pattern:** "Avoid long quote blocks"

### Files to fix:
- `lib/eve_dmv/contexts/bounded_context.ex:39:5`
- `lib/eve_dmv/intelligence/analyzer.ex:48:5`
- `lib/eve_dmv_web.ex:41:5, 85:5`
- `lib/eve_dmv_web/components/reusable_components.ex:25:5`

**Fix:** Shorten @moduledoc strings to be more concise.

## Predicate Function Names (2 errors)

**Pattern:** "Predicate function names should not start with 'is', and should end in a question mark"

### Files to fix:
- `lib/eve_dmv/intelligence/analyzers/wh_vetting_analyzer.ex:462:8`
- `lib/eve_dmv/shared/ship_database_adapter.ex:120:7`

**Fix Pattern:**
```elixir
# BEFORE:
defp is_valid_ship(ship)

# AFTER:
defp valid_ship?(ship)
```

## with/case Conversions (8 errors)

**Pattern:** "with contains only one <- clause and an else branch, consider using case instead"

### Files to fix:
- `lib/eve_dmv/contexts/wormhole_operations/api.ex:105:5, 216:5`
- `lib/eve_dmv/intelligence/intelligence_scoring.ex:75:5`
- `lib/eve_dmv/intelligence/intelligence_scoring/recruitment_scoring.ex:24:5`

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

## Module Structure Issues (15 errors)

### Patterns to fix:
- "moduledoc must appear before module attribute"
- "defstruct must appear before module attribute"  
- "type must appear before module attribute"
- "typep must appear before public function"
- "module attribute must appear before private function"

### Files to fix:
- `lib/eve_dmv/infrastructure/event_bus.ex:20, 243`
- `lib/eve_dmv/intelligence/wanderer_client.ex:17, 21`
- `lib/eve_dmv/intelligence/wanderer_sse.ex:19`
- `lib/eve_dmv/killmails/data_processor.ex:112`
- `lib/eve_dmv/killmails/historical_killmail_fetcher.ex:22`
- `lib/eve_dmv/market/strategies/esi_strategy.ex:4`
- `lib/eve_dmv/market/strategies/mutamarket_strategy.ex:6`

**Fix:** Move module elements to correct order: moduledoc → types → defstruct → module attributes → functions.

## Negated Conditions (2 errors)

**Pattern:** "Avoid negated conditions in if-else blocks"

### Files to fix:
- `lib/eve_dmv/quality/metrics_collector/ci_cd_metrics.ex:67:10, 77:10`

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

## TODO Comments (2 errors)

**Pattern:** "Found a TODO tag in a comment"

### Files to fix:
- `lib/eve_dmv/contexts/wormhole_operations/api.ex:15:79`
- `lib/eve_dmv/database/archive_manager.ex:21:3`

**Fix:** Either implement the TODO or remove the comment.

## Execution Order:

1. **Start with trailing whitespace** - fastest fixes
2. **Fix missing newlines** - also very fast
3. **Update number formatting** - simple find/replace
4. **Fix @impl annotations** - straightforward
5. **Apply Enum.map_join optimizations** - clear pattern
6. **Handle remaining structural issues** - requires more thought

## Verification:

After each category:
1. Save all files
2. Run `mix compile` 
3. Check that the specific error type count has decreased
4. Move to next category

This should eliminate approximately 100+ of the simpler remaining errors, bringing the total much closer to an acceptable level.
# Remaining Pipe Chain Fixes (101 errors)

Based on the current credo.txt, here are the remaining pipe chain errors that need manual fixing.

## Error Pattern: "Pipe chain should start with a raw value"

### Files to Fix (in order of priority):

### 1. lib/eve_dmv/contexts/fleet_operations/domain/fleet_analyzer.ex
**Line 508:7**

### 2. Database Archive Manager Files:
- `lib/eve_dmv/database/archive_manager/archive_metrics.ex` - Lines 317:9, 372:9, 443:7
- `lib/eve_dmv/database/archive_manager/archive_operations.ex` - Lines 56:7, 66:7
- `lib/eve_dmv/database/archive_manager/maintenance_scheduler.ex` - Line 414:7

### 3. Cache/Database Files:
- `lib/eve_dmv/database/cache_warmer.ex` - Lines 158:9, 260:5
- `lib/eve_dmv/database/cache_invalidator.ex` - Multiple instances
- `lib/eve_dmv/database/connection_pool_monitor.ex` - Lines 388:7, 409:7, 421:7, 455:5

### 4. EVE API Integration Files:
- `lib/eve_dmv/eve/error_classifier.ex` - Line 69:62
- `lib/eve_dmv/eve/esi_cache.ex` - Line 55:7
- `lib/eve_dmv/eve/esi_request_client.ex` - Line 351:5
- `lib/eve_dmv/eve/name_resolver/performance_optimizer.ex` - Line 128:7
- `lib/eve_dmv/eve/static_data_loader/data_persistence.ex` - Line 232:5
- `lib/eve_dmv/eve/static_data_loader/file_manager.ex` - Line 145:9
- `lib/eve_dmv/eve/static_data_loader/solar_system_processor.ex` - Lines 69:5, 86:7, 91:7

### 5. Intelligence System Files:
- `lib/eve_dmv/intelligence/analyzers/corporation_analyzer.ex` - Line 168:9
- `lib/eve_dmv/intelligence/analyzers/fleet_asset_manager/acquisition_planner.ex` - Line 95:5
- `lib/eve_dmv/intelligence/analyzers/fleet_skill_analyzer.ex` - Lines 207:7, 218:11
- `lib/eve_dmv/intelligence/analyzers/home_defense_analyzer.ex` - Lines 270:5, 301:5, 319:5, 333:9, 358:7, 371:7
- `lib/eve_dmv/intelligence/analyzers/member_activity_analyzer/recruitment_retention_analyzer.ex` - Lines 37:7, 255:9
- `lib/eve_dmv/intelligence/analyzers/wh_fleet_analyzer/doctrine_manager.ex` - Line 157:5
- `lib/eve_dmv/intelligence/chain_analysis/system_inhabitants_manager.ex` - Lines 250:54, 254:11
- `lib/eve_dmv/intelligence/intelligence_scoring/intelligence_suitability.ex` - Line 311:5
- `lib/eve_dmv/intelligence/intelligence_scoring/recruitment_scoring.ex` - Line 277:5
- `lib/eve_dmv/intelligence/metrics/ship_analysis_calculator.ex` - Lines 29:7, 52:11, 123:5
- `lib/eve_dmv/intelligence/metrics/temporal_analysis_calculator.ex` - Lines 89:5, 152:7
- `lib/eve_dmv/intelligence/ship_database/doctrine_data.ex` - Line 95:7
- `lib/eve_dmv/intelligence/ship_database/wormhole_utils.ex` - Line 58:5

## Fix Instructions:

### For Each File and Line:

1. **Open the file** and go to the specific line number
2. **Find the pipe chain** that starts with a function call
3. **Identify the raw value** (first argument to the function)
4. **Restructure** to start with the raw value

### Example Fix Pattern:
```elixir
# BEFORE (causing error):
SomeModule.function(data, arg1, arg2) |> transform() |> process()

# AFTER (fixed):
data
|> SomeModule.function(arg1, arg2)
|> transform()
|> process()
```

### Common Patterns You'll See:

#### Database Query Patterns:
```elixir
# BEFORE:
Repo.all(query) |> Enum.map(&transform/1) |> Enum.filter(&valid?/1)

# AFTER:
query
|> Repo.all()
|> Enum.map(&transform/1)
|> Enum.filter(&valid?/1)
```

#### Map/Data Processing:
```elixir
# BEFORE:
Map.get(data, :items) |> Enum.filter(&condition/1) |> Enum.map(&process/1)

# AFTER:
data
|> Map.get(:items)
|> Enum.filter(&condition/1)
|> Enum.map(&process/1)
```

#### API Response Processing:
```elixir
# BEFORE:
HTTPoison.get!(url) |> Map.get(:body) |> Jason.decode!()

# AFTER:
url
|> HTTPoison.get!()
|> Map.get(:body)
|> Jason.decode!()
```

## Step-by-Step Process:

1. **Start with database files** (archive_manager, cache_warmer) - these tend to be straightforward
2. **Move to EVE API files** - similar patterns
3. **Finish with intelligence files** - more complex logic but same principle

## Verification:
After each file:
1. Save the file
2. Run `mix compile` to ensure no syntax errors
3. The error should disappear from that line in credo output

## Progress Tracking:
Check off each file as completed:

### Database Files:
- [ ] fleet_operations/domain/fleet_analyzer.ex
- [ ] database/archive_manager/archive_metrics.ex (3 fixes)
- [ ] database/archive_manager/archive_operations.ex (2 fixes)
- [ ] database/archive_manager/maintenance_scheduler.ex
- [ ] database/cache_warmer.ex (2 fixes)
- [ ] database/connection_pool_monitor.ex (4 fixes)

### EVE API Files:
- [ ] eve/error_classifier.ex
- [ ] eve/esi_cache.ex
- [ ] eve/esi_request_client.ex
- [ ] eve/name_resolver/performance_optimizer.ex
- [ ] eve/static_data_loader/data_persistence.ex
- [ ] eve/static_data_loader/file_manager.ex
- [ ] eve/static_data_loader/solar_system_processor.ex (3 fixes)

### Intelligence Files:
- [ ] intelligence/analyzers/corporation_analyzer.ex
- [ ] intelligence/analyzers/fleet_asset_manager/acquisition_planner.ex
- [ ] intelligence/analyzers/fleet_skill_analyzer.ex (2 fixes)
- [ ] intelligence/analyzers/home_defense_analyzer.ex (6 fixes)
- [ ] intelligence/analyzers/member_activity_analyzer/recruitment_retention_analyzer.ex (2 fixes)
- [ ] intelligence/analyzers/wh_fleet_analyzer/doctrine_manager.ex
- [ ] intelligence/chain_analysis/system_inhabitants_manager.ex (2 fixes)
- [ ] intelligence/intelligence_scoring/intelligence_suitability.ex
- [ ] intelligence/intelligence_scoring/recruitment_scoring.ex
- [ ] intelligence/metrics/ship_analysis_calculator.ex (3 fixes)
- [ ] intelligence/metrics/temporal_analysis_calculator.ex (2 fixes)
- [ ] intelligence/ship_database/doctrine_data.ex
- [ ] intelligence/ship_database/wormhole_utils.ex

This should eliminate the remaining 101 pipe chain errors.
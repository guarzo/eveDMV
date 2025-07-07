# Single Function Pipeline Fixes (25+ errors)

## Error Pattern
"Use a function call when a pipeline is only one function long"

## Files to Fix

### Core Application Files:

1. **lib/eve_dmv_web/plugs/api_auth.ex:134:9**
2. **lib/eve_dmv/intelligence/analyzers/member_activity_data_collector.ex:100:11**
3. **lib/eve_dmv/eve/name_resolver/batch_processor.ex:168:5**
4. **lib/eve_dmv/database/archive_manager/archive_operations.ex:67:7**
5. **lib/mix/tasks/security.audit.ex:329:5**
6. **lib/eve_dmv_web/live/chain_intelligence_live.ex:166:7**
7. **lib/eve_dmv/market/mutamarket_client.ex:289:11**
8. **lib/eve_dmv/intelligence_engine/config.ex:112:5**
9. **lib/eve_dmv/intelligence/metrics/ship_analysis_calculator.ex:54:9**
10. **lib/eve_dmv/intelligence/metrics/combat_metrics_calculator.ex:163:5**
11. **lib/eve_dmv/intelligence/metrics/character_metrics.ex:500:37**
12. **lib/eve_dmv/intelligence/core/intelligence_coordinator.ex:221:5**
13. **lib/eve_dmv/intelligence/analyzers/home_defense_analyzer.ex:304:7**
14. **lib/eve_dmv/intelligence/analyzers/home_defense_analyzer.ex:268:7**
15. **lib/eve_dmv/intelligence/analyzers/fleet_skill_analyzer.ex:205:7**
16. **lib/eve_dmv/intelligence/analyzers/fleet_pilot_analyzer.ex:347:5**
17. **lib/eve_dmv/intelligence/analyzers/fleet_asset_manager/acquisition_planner.ex:86:7**
18. **lib/eve_dmv/eve/name_resolver/performance_optimizer.ex:33:11**
19. **lib/eve_dmv/database/materialized_view_manager/view_refresh_scheduler.ex:143:9**
20. **lib/eve_dmv/database/materialized_view_manager/view_refresh_scheduler.ex:26:7**
21. **lib/eve_dmv/database/materialized_view_manager/view_definitions.ex:45:5**

### Surveillance Context Files:
22. **lib/eve_dmv/contexts/surveillance/domain/chain_threat_analyzer.ex:114:5**
23. **lib/eve_dmv/contexts/surveillance/domain/chain_status_service.ex:143:5**
24. **lib/eve_dmv/contexts/surveillance/domain/chain_status_service.ex:115:5**
25. **lib/eve_dmv/contexts/surveillance/domain/chain_status_service.ex:105:5**
26. **lib/eve_dmv/contexts/surveillance/domain/chain_status_service.ex:93:5**
27. **lib/eve_dmv/contexts/surveillance/domain/chain_activity_tracker.ex:166:5**
28. **lib/eve_dmv/contexts/surveillance/domain/chain_activity_tracker.ex:117:7**

### Test Files:
29. **test/eve_dmv_web/controllers/auth_controller_test.exs:88:50**
30. **test/eve_dmv/security/headers_validator_test.exs:58:9**

## Fix Pattern

### Before:
```elixir
# Single function pipeline
data |> transform()
result |> process()
items |> Enum.count()
```

### After:
```elixir
# Direct function call
transform(data)
process(result)
Enum.count(items)
```

## Step-by-Step Instructions

### For Each File:
1. **Open the file** and go to the specific line number
2. **Identify the single-function pipeline**
3. **Convert to direct function call**
4. **Save and verify compilation**

### Common Patterns:

#### Database/Query Operations:
```elixir
# BEFORE:
query |> Repo.all()
results |> Enum.count()

# AFTER:
Repo.all(query)
Enum.count(results)
```

#### Data Processing:
```elixir
# BEFORE:
data |> Map.get(:key)
items |> List.first()

# AFTER:
Map.get(data, :key)
List.first(items)
```

#### String Operations:
```elixir
# BEFORE:
text |> String.trim()
name |> String.downcase()

# AFTER:
String.trim(text)
String.downcase(name)
```

## Execution Order

### Start with Core Files (1-21):
These are the main application logic files and should be prioritized.

### Then Surveillance Context (22-28):
These are newer context-based files.

### Finish with Test Files (29-30):
Simple test-related fixes.

## Time Estimate
- **20 minutes total**
- **~30 seconds per fix** (locate, change, save)
- **Simple mechanical replacements**

## Verification

After each fix:
```bash
# Compile to check syntax
mix compile

# Verify specific error is gone
mix credo | grep -A 2 -B 2 "filename:line"
```

After all fixes:
```bash
# Count remaining pipeline errors
mix credo | grep -c "pipeline is only one function"

# Should show 0 or significantly reduced count
```

## Notes

- **No logic changes** - purely mechanical transformations
- **Safe refactoring** - functionality remains identical
- **High impact** - eliminates 15% of all credo issues quickly
- **Build momentum** for tackling more complex issues

This is the ideal starting point as it provides immediate visible progress with minimal risk.
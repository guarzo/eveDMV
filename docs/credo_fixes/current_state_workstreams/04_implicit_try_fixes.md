# Implicit Try Fixes (20+ errors)

## Error Pattern
"Prefer using an implicit try rather than explicit try"

## Files to Fix

### Intelligence System (8 files):
1. **lib/eve_dmv/intelligence/analyzers/home_defense_analyzer.ex:203:5**
2. **lib/eve_dmv/intelligence/analyzers/home_defense_analyzer.ex:171:5** 
3. **lib/eve_dmv/intelligence/analyzers/home_defense_analyzer.ex:189:5**
4. **lib/eve_dmv/intelligence/analyzers/corporation_analyzer.ex:144:5**
5. **lib/eve_dmv/intelligence/analyzers/corporation_analyzer.ex:163:5**
6. **lib/eve_dmv/intelligence/analyzers/corporation_analyzer.ex:198:5**
7. **lib/eve_dmv/intelligence/analyzers/fleet_pilot_analyzer.ex:114:5**
8. **lib/eve_dmv/intelligence/analysis_scheduler.ex:244:5**

### Intelligence Core & Metrics (4 files):
9. **lib/eve_dmv/intelligence/core/correlation_engine.ex:196:5**
10. **lib/eve_dmv/intelligence/core/correlation_engine.ex:166:5**
11. **lib/eve_dmv/intelligence/metrics/character_metrics_adapter.ex:91:5**
12. **lib/eve_dmv/intelligence/metrics/character_metrics_adapter.ex:70:5**

### Intelligence Support (3 files):
13. **lib/eve_dmv/intelligence/supervisor.ex:204:5**
14. **lib/eve_dmv/intelligence/supervisor.ex:184:5**
15. **lib/eve_dmv/intelligence/cache_cleanup_worker.ex:174:5**

### Workers & Tasks (3 files):
16. **lib/eve_dmv/workers/realtime_task_supervisor.ex:302:5**
17. **lib/eve_dmv/workers/background_task_supervisor.ex:264:5**
18. **lib/eve_dmv/workers/ui_task_supervisor.ex:220:5**

### Data Processing (3 files):
19. **lib/eve_dmv/killmails/data_processor.ex:23:5**
20. **lib/eve_dmv/intelligence_migration_adapter.ex:106:5**
21. **lib/eve_dmv/result.ex:178:5**

### Web Services (3 files):
22. **lib/eve_dmv_web/live/surveillance_live/profile_service.ex:160:5**
23. **lib/eve_dmv_web/live/surveillance_live/export_import_service.ex:120:5**
24. **lib/eve_dmv_web/live/surveillance_live/batch_operation_service.ex:96:5**

### Infrastructure (2 files):
25. **lib/eve_dmv/infrastructure/event_bus.ex:303:5**
26. **lib/eve_dmv/surveillance/matching/profile_compiler.ex:23:5**

## Fix Pattern

### Before (Explicit Try):
```elixir
def some_function do
  try do
    some_risky_operation()
    {:ok, result}
  rescue
    error -> {:error, error}
  end
end
```

### After (Implicit Try):
```elixir
def some_function do
  some_risky_operation()
  {:ok, result}
rescue
  error -> {:error, error}
end
```

## Common Patterns to Look For

### Pattern 1: Simple Error Handling
```elixir
# BEFORE:
try do
  operation()
rescue
  error -> handle_error(error)
end

# AFTER:
operation()
rescue
  error -> handle_error(error)
```

### Pattern 2: Multiple Operations
```elixir
# BEFORE:
try do
  step1()
  step2()
  step3()
rescue
  error -> {:error, error}
end

# AFTER:
step1()
step2()
step3()
rescue
  error -> {:error, error}
```

### Pattern 3: With Return Value
```elixir
# BEFORE:
try do
  result = compute_something()
  {:ok, result}
rescue
  error -> {:error, error}
end

# AFTER:
result = compute_something()
{:ok, result}
rescue
  error -> {:error, error)
```

## Step-by-Step Instructions

### For Each File:
1. **Open the file** and go to the specific line number
2. **Locate the explicit try block**
3. **Remove the `try do` line**
4. **Keep the rescue/catch clauses** in place
5. **Adjust indentation** for the try body
6. **Save and verify compilation**

### Detailed Process:
1. **Find the pattern**: Look for `try do` followed by `rescue` or `catch`
2. **Identify the try body**: Everything between `try do` and `rescue`/`catch`
3. **Remove try wrapper**: Delete `try do` line
4. **Unindent body**: Move try body content left to align with rescue
5. **Keep rescue/catch**: Leave error handling clauses unchanged

## Example Transformation

### Before:
```elixir
def get_corporation_info(corporation_id) do
  try do
    case ESI.get_corporation(corporation_id) do
      {:ok, corp_data} -> 
        {:ok, process_corporation_data(corp_data)}
      {:error, reason} -> 
        {:error, reason}
    end
  rescue
    error -> 
      Logger.error("Failed to get corporation info: #{inspect(error)}")
      {:error, :api_failure}
  end
end
```

### After:
```elixir
def get_corporation_info(corporation_id) do
  case ESI.get_corporation(corporation_id) do
    {:ok, corp_data} -> 
      {:ok, process_corporation_data(corp_data)}
    {:error, reason} -> 
      {:error, reason}
  end
rescue
  error -> 
    Logger.error("Failed to get corporation info: #{inspect(error)}")
    {:error, :api_failure}
end
```

## Execution Order

### Start with Intelligence Analyzers (8 files - 8 minutes):
These are core business logic files with similar patterns.

### Then Intelligence Support (7 files - 7 minutes):
Core, metrics, and supervisor files.

### Workers & Infrastructure (5 files - 3 minutes):  
Task supervisors and infrastructure.

### Web Services (3 files - 2 minutes):
LiveView service files.

### Data Processing (3 files - 2 minutes):
Data transformation and migration files.

## Time Estimate
- **Total**: 22 minutes
- **~1 minute per file** (locate, modify, test)
- **Simple mechanical transformation**

## Verification

After each file:
```bash
# Compile to check syntax  
mix compile

# Run tests for that module if available
mix test test/path/to/module_test.exs
```

After all fixes:
```bash
# Count remaining explicit try errors
mix credo | grep -c "implicit.*try"

# Should show 0
```

## Expected Results
- **Before**: 20+ explicit try errors
- **After**: 0 explicit try errors
- **Impact**: 10% reduction in total issues
- **Benefit**: Cleaner, more idiomatic Elixir code

## Notes
- **No logic changes** - purely stylistic improvement
- **Maintains identical error handling** behavior
- **Follows Elixir best practices** for exception handling
- **Safe transformation** with immediate verification
- **High impact-to-effort ratio** for code quality improvement
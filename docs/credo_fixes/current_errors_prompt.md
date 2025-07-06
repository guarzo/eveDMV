# Current Credo Errors - Code Quality Fixes

## Issues Overview
- **Error Count**: 50+ errors across the codebase
- **Main Issues**: Single-function pipelines, duplicate code, TODO comments, excessive dependencies
- **Priority**: High - These are the active errors that need immediate attention

## AI Assistant Prompt

Fix the following code quality issues in the EVE DMV Elixir codebase:

### 1. **Single-Function Pipelines** (30+ instances)
Replace single-function pipelines with direct function calls. Pattern:
```elixir
# Bad
data |> some_function()

# Good  
some_function(data)
```

**Key Files Affected**:
- `lib/eve_dmv/contexts/player_profile/domain/player_analyzer.ex:209:11`
- `lib/eve_dmv/intelligence/analyzers/wh_fleet_analyzer/fleet_optimizer.ex:91:7`
- `lib/eve_dmv/intelligence/analyzers/member_participation_analyzer.ex:134:7`
- `lib/eve_dmv/intelligence/analyzers/fleet_pilot_analyzer.ex:262:7`
- `lib/eve_dmv/intelligence/analyzers/fleet_asset_manager/acquisition_planner.ex:60:7`
- `lib/eve_dmv/infrastructure/event_bus.ex:225:7`
- `lib/eve_dmv/eve/static_data_loader/solar_system_processor.ex:132:5`
- `lib/eve_dmv/eve/name_resolver/batch_processor.ex:166:5`
- `lib/eve_dmv/database/materialized_view_manager/view_query_service.ex:25:41`

### 2. **Duplicate Code** (6+ instances)
Eliminate duplicate code between analyzer modules, particularly in ship preferences analyzers:

**Files Affected**:
- `lib/eve_dmv/contexts/player_profile/analyzers/ship_preferences_analyzer.ex` (multiple duplications)
- `lib/eve_dmv/intelligence_engine/plugins/character/ship_preferences.ex` (duplicated logic)

**Strategy**: Extract common functionality into shared helper modules or use composition patterns.


### 4. **Excessive Dependencies** (1 instance)
Reduce dependencies in the surveillance live module:

**File**: `lib/eve_dmv_web/live/surveillance_live.ex:1:11`
**Issue**: Module has 16 dependencies (max is 15)

**Strategy**: Extract functionality into smaller, focused modules or use dependency injection patterns.

## Implementation Priority

1. **High Priority**: Single-function pipelines (quick wins, improve readability)
2. **Medium Priority**: Excessive dependencies (architectural improvement)
3. **Medium Priority**: Duplicate code (maintainability improvement)
4. **Low Priority**: TODO comments (feature completion, can be deferred)

## Maintenance Notes

- Focus on maintaining all existing functionality while improving code quality
- Use Elixir best practices for pipe chains and module organization
- Consider extracting common patterns into shared utilities
- Ensure all changes pass existing tests before committing
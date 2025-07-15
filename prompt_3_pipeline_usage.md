# Prompt 3: Fix Single-Function Pipeline Usage

## Task
Fix all single-function pipeline usage throughout the codebase by replacing them with direct function calls.

## Context
Credo has identified 207 instances of single-function pipelines that should be replaced with direct function calls. These are marked as [R] (Refactoring) issues with the message "Use a function call when a pipeline is only one function long."

## Instructions
1. Search for single-function pipelines in the format: `value |> function()`
2. Replace them with direct function calls: `function(value)`
3. Maintain the same functionality and return values
4. Focus on these patterns:
   - `data |> String.trim()` → `String.trim(data)`
   - `result |> Map.get(:key)` → `Map.get(result, :key)`
   - `value |> Integer.to_string()` → `Integer.to_string(value)`

## Files to Focus On
Based on the credo output, these files have the most single-function pipeline issues:
- `lib/eve_dmv/contexts/combat_intelligence/domain/battle_analysis_service.ex`
- `lib/eve_dmv/contexts/character_intelligence/domain/threat_scoring_engine.ex`
- `lib/eve_dmv/contexts/surveillance/domain/chain_intelligence_helper.ex`
- `lib/eve_dmv/contexts/intelligence_infrastructure/domain/cross_system/cross_system_coordinator.ex`
- `lib/eve_dmv/killmails/killmail_data_transformer.ex`
- `lib/eve_dmv/killmails/database_inserter.ex`
- `lib/eve_dmv/performance/batch_name_resolver.ex`
- `lib/eve_dmv/eve/static_data_loader/item_type_processor.ex`
- `lib/eve_dmv_web/live/character_analysis/character_analysis_live.ex`
- `lib/eve_dmv_web/live/surveillance_dashboard_live.ex`

## Success Criteria
- All single-function pipelines are replaced with direct function calls
- Code maintains the same functionality
- No change in return values or side effects
- Code compiles without warnings
- All tests pass

## Important Notes
- This is a mechanical refactoring task
- DO NOT change multi-function pipelines (those are correct)
- DO NOT modify the logic, only the syntax
- Maintain exact same functionality and return values
- Only change pipelines that have exactly one function call
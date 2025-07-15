# Prompt 4: Fix Predicate Function Naming and Negated Conditions

## Task
Fix predicate function naming issues and refactor negated conditions in if-else blocks.

## Context
Credo has identified multiple function naming and conditional logic issues that need to be addressed for better code readability and Elixir conventions.

## Instructions

### Part 1: Negated Conditions in If-Else Blocks
1. Find all if-else blocks with negated conditions (pattern: `if !condition` or `if not condition`)
2. Refactor them to use positive conditions by swapping the if/else branches
3. Example transformation:
   ```elixir
   # Before:
   if !valid? do
     handle_invalid()
   else
     handle_valid()
   end
   
   # After:
   if valid? do
     handle_valid()
   else
     handle_invalid()
   end
   ```

### Part 2: Predicate Function Naming
1. Ensure all predicate functions (those returning boolean values) end with `?`
2. Look for functions that return true/false but don't have `?` in their name
3. Rename them to follow Elixir conventions

## Files to Focus On
Based on credo output patterns, look for these issues in:
- `lib/eve_dmv/contexts/surveillance/domain/matching_engine.ex`
- `lib/eve_dmv/contexts/battle_analysis/domain/battle_detection_service.ex`
- `lib/eve_dmv/analytics/battle_detector.ex`
- `lib/eve_dmv/eve/esi_utils.ex`
- `lib/eve_dmv/killmails/killmail_data_transformer.ex`
- `lib/eve_dmv_web/live/character_analysis/character_analysis_live.ex`

## Success Criteria
- All negated conditions in if-else blocks are refactored to positive conditions
- All predicate functions have proper naming with `?` suffix
- Code maintains the same functionality
- No logical errors introduced during refactoring
- Code compiles without warnings

## Important Notes
- This is a code quality and readability improvement
- Maintain exact same functionality, only change structure
- Be careful when swapping if/else branches to maintain correct logic
- Update all callers if function names change
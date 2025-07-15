# Prompt 5: Fix Number Formatting and Code Style Issues

## Task
Fix number formatting, variable declarations, and general code style issues identified by Credo.

## Context
Credo has identified various formatting and style issues including large numbers without underscores, variable redeclarations, and code style violations.

## Instructions

### Part 1: Number Formatting
1. Find large numbers (5+ digits) that should have underscore separators
2. Add underscores to improve readability:
   - `1000000` → `1_000_000`
   - `500000` → `500_000`
   - `86400` → `86_400`

### Part 2: Variable Redeclaration
1. Find variables that are declared multiple times in the same scope
2. Either:
   - Use different variable names if they serve different purposes
   - Combine the logic if they represent the same data at different stages
3. Common patterns to fix:
   - `names = ...` followed by `names = ...` in the same function
   - `headers = ...` followed by `headers = ...`
   - `keywords = ...` followed by `keywords = ...`

### Part 3: Pipe Chain Issues
1. Find pipe chains that don't start with a raw value
2. Refactor them to start with the actual data being transformed
3. Example:
   ```elixir
   # Before:
   SomeModule.function() |> transform() |> process()
   
   # After:
   data = SomeModule.function()
   data |> transform() |> process()
   ```

## Files to Focus On
Based on credo output, these files likely have these issues:
- `lib/eve_dmv/eve/static_data_loader/item_type_processor.ex`
- `lib/eve_dmv/performance/batch_name_resolver.ex`
- `lib/eve_dmv/killmails/killmail_data_transformer.ex`
- `lib/eve_dmv_web/components/core_components.ex`
- `lib/eve_dmv_web/live/character_analysis/character_analysis_live.ex`
- `lib/eve_dmv/users/user.ex`

## Success Criteria
- All large numbers use underscore separators for readability
- No variable redeclarations in the same scope
- All pipe chains start with raw values
- Code follows Elixir style conventions
- Code compiles without warnings

## Important Notes
- This is a pure style/formatting task
- DO NOT change functionality or logic
- Maintain all existing behavior
- Focus on readability and convention compliance
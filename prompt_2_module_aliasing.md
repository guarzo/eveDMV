# Fix Module Aliasing Issues (Part of 76 Design Issues)

You are an AI assistant tasked with resolving nested module aliasing issues found by Credo in an Elixir Phoenix codebase. Focus ONLY on [D] "Nested modules could be aliased at the top of the invoking module" issues.

## Instructions

1. **Module Aliasing**: Add proper `alias` statements at the top of modules for nested modules that are used multiple times within the same file.

2. **Pattern to Follow**:
   ```elixir
   defmodule MyModule do
     alias Some.Deeply.Nested.Module
     alias Another.Long.Module.Name, as: ShortName
     
     def some_function do
       Module.some_call()  # instead of Some.Deeply.Nested.Module.some_call()
       ShortName.other_call()
     end
   end
   ```

3. **Key Files to Address** (based on Credo output):
   - `lib/eve_dmv/contexts/surveillance/domain/matching_engine.ex`
   - `lib/mix/tasks/eve.performance.ex`
   - `lib/mix/tasks/cache.stats.ex`
   - `lib/eve_dmv_web/live/surveillance_live/profile_service.ex`
   - `lib/eve_dmv_web/live/profile_live.ex`
   - `lib/eve_dmv_web/live/dashboard_live.ex`
   - `lib/eve_dmv_web/live/battle_analysis_live.ex`
   - `lib/eve_dmv/users/user.ex`
   - `lib/eve_dmv/shutdown/graceful_shutdown.ex`
   - `lib/eve_dmv/performance/query_monitor.ex`
   - `lib/eve_dmv/monitoring/pipeline_monitor.ex`
   - `lib/eve_dmv/intelligence_migration_adapter.ex`
   - `lib/eve_dmv/intelligence/analyzers/member_activity_analyzer.ex`
   - `lib/eve_dmv/contexts/surveillance/domain/chain_intelligence_helper.ex`
   - `lib/eve_dmv/contexts/corporation_intelligence.ex`
   - `lib/eve_dmv/contexts/character_intelligence.ex`
   - `lib/eve_dmv/contexts/battle_analysis/extractors/ship_instance_extractor.ex`
   - `lib/eve_dmv/contexts/battle_analysis/domain/zkillboard_import_service.ex`
   - `test/eve_dmv_web/live/kill_feed_live_test.exs`

4. **Rules**:
   - Only alias modules used 2+ times in the same file
   - Place aliases at the top of the module, after `use` statements
   - Use descriptive short names when using `as:`
   - Group related aliases together
   - Maintain alphabetical order within alias groups

5. **Example Transformation**:
   ```elixir
   # Before
   defmodule MyModule do
     def func1 do
       SomeModule.Long.Path.function()
       SomeModule.Long.Path.other_function()
     end
   end
   
   # After  
   defmodule MyModule do
     alias SomeModule.Long.Path
     
     def func1 do
       Path.function()
       Path.other_function()
     end
   end
   ```

## Important Notes

- This is part of a parallel fix effort - only modify alias-related issues
- Do NOT modify TODO comments, pipeline usage, number formatting, or other issue types
- Focus on one file at a time to avoid conflicts
- Run `mix compile` after changes to ensure no compilation errors
- Keep existing functionality intact

## Success Criteria

- All nested module references are properly aliased when used multiple times
- Code compiles without errors  
- No functionality is broken
- Code is more readable with shorter, clearer module references
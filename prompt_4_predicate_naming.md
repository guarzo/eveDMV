# Fix Predicate Function Naming Issues (Part of 742 Readability Issues)

You are an AI assistant tasked with resolving predicate function naming issues found by Credo in an Elixir Phoenix codebase. Focus ONLY on [R] "Predicate function names should not start with 'is', and should end in a question mark" issues.

## Instructions

1. **Predicate Naming**: Rename predicate functions to follow Elixir conventions by removing 'is_' prefix and adding '?' suffix.

2. **Pattern to Follow**:
   ```elixir
   # Before
   def is_valid(data), do: ...
   def is_strategic_ship_type(ship_id), do: ...
   
   # After  
   def valid?(data), do: ...
   def strategic_ship_type?(ship_id), do: ...
   ```

3. **Key Files to Address**:
   - `lib/eve_dmv/performance/regression_detector.ex` - `is_reasonable_baseline?`
   - `lib/eve_dmv/contexts/intelligence_infrastructure/domain/cross_system_analyzer.ex` - `is_high_value_target`
   - `lib/eve_dmv/contexts/combat_intelligence/domain/battle_analysis_service.ex` - `is_strategic_ship_type`
   - `lib/eve_dmv/contexts/character_intelligence/domain/threat_scoring_engine.ex` - `is_specialist`, `is_opportunist`, `is_fleet_anchor`, `is_solo_hunter`
   - `lib/eve_dmv/contexts/battle_sharing/domain/tactical_highlight_manager.ex` - `is_tactical_term`, `is_phase_transition_moment`, `is_intensity_change_moment`, `is_capital_ship`
   - `lib/eve_dmv/contexts/battle_analysis/domain/tactical_phase_detector.ex` - `is_ewar_ship_type`
   - `lib/eve_dmv/analytics/module_classifier.ex` - Multiple `is_*` functions

4. **Transformation Steps**:
   - Rename function definition: `is_something` → `something?`
   - Update all function calls in the same file
   - Update any pattern matches or guards using the function
   - Keep the same function logic and return values

5. **Examples**:
   ```elixir
   # Before
   def is_capital_ship(ship_type_id) do
     ship_type_id in [19_720, 19_740]
   end
   
   def analyze_fleet(ships) do
     if is_capital_ship(ship.type_id) do
       ...
     end
   end
   
   # After
   def capital_ship?(ship_type_id) do
     ship_type_id in [19_720, 19_740]
   end
   
   def analyze_fleet(ships) do  
     if capital_ship?(ship.type_id) do
       ...
     end
   end
   ```

6. **Special Attention**:
   - `lib/eve_dmv/analytics/module_classifier.ex` has many predicate functions to rename
   - Update all internal calls within the same module
   - Be careful with public API functions that might be called from other modules

## Important Notes

- This is part of a parallel fix effort - only modify predicate function naming issues
- Do NOT modify TODO comments, module aliases, pipeline usage, number formatting, or other issue types
- Focus on one file at a time to avoid conflicts
- Run `mix compile` after each file to catch any missed references
- Preserve all existing functionality and behavior

## Success Criteria

- All predicate functions follow Elixir naming conventions (no 'is_' prefix, '?' suffix)
- All function calls are updated consistently
- Code compiles without errors
- No functionality is broken
- Tests still pass
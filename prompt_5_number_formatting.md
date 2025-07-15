# Fix Number Formatting Issues (Part of 742 Readability Issues)

You are an AI assistant tasked with resolving number formatting issues found by Credo in an Elixir Phoenix codebase. Focus ONLY on [R] "Numbers larger than 9999 should be written with underscores" issues.

## Instructions

1. **Number Formatting**: Add underscores to large numbers (>9999) for better readability.

2. **Pattern to Follow**:
   ```elixir
   # Before
   ship_id = 19740
   value = 50000
   timeout = 600000
   
   # After
   ship_id = 19_740  
   value = 50_000
   timeout = 600_000
   ```

3. **Key Files to Address**:
   - `lib/eve_dmv/performance/regression_detector.ex` - `10000` → `10_000`
   - `lib/eve_dmv/contexts/surveillance/domain/matching_engine.ex` - `10000` → `10_000`
   - `lib/eve_dmv/contexts/intelligence_infrastructure/domain/cross_system_analyzer.ex` - Multiple large numbers
   - `lib/eve_dmv/contexts/fleet_operations/analyzers/composition_analyzer.ex` - Many ship type IDs and values
   - `lib/eve_dmv/contexts/combat_intelligence/domain/battle_analysis_service.ex` - Ship type IDs
   - `lib/eve_dmv/contexts/battle_analysis/domain/tactical_phase_detector.ex` - Distance and HP values
   - `lib/eve_dmv/contexts/battle_analysis/calculators/performance_metrics_calculator.ex` - Range and damage values
   - `lib/eve_dmv/contexts/battle_sharing/domain/tactical_highlight_manager.ex` - Ship type IDs
   - `lib/eve_dmv/contexts/battle_analysis/resources/ship_fitting.ex` - HP and damage values
   - `lib/eve_dmv/contexts/battle_analysis/extractors/ship_instance_extractor.ex` - HP values
   - `lib/eve_dmv/analytics/fleet_analyzer.ex` - Many ship type IDs
   - `test/support/factories.ex` - Test values
   - `test/eve_dmv/analytics/fleet_analyzer_test.exs` - Test ship type IDs

4. **Common Numbers to Format**:
   - Ship Type IDs: `19720`, `19740`, `28356`, `28352`, `29990`, `29984`, `12034`, `11567`, etc.
   - Distance values: `10000`, `15000`, `25000`, `30000`, `40000`, `50000`, etc.  
   - HP values: `15000`, `25000`, `60000`, `70000`, etc.
   - ISK values: `50000`, `99999`, etc.
   - Timeouts: `600000`, etc.

5. **Transformation Examples**:
   ```elixir
   # EVE Ship Type IDs
   19740 → 19_740
   28356 → 28_356
   29990 → 29_990
   
   # Distance/Range Values  
   15000 → 15_000
   50000 → 50_000
   
   # HP/Damage Values
   70000 → 70_000
   25000 → 25_000
   
   # ISK Values
   12345 → 12_345
   99999 → 99_999
   ```

6. **Files Priority Order** (to minimize conflicts):
   1. Test files first (`test/` directory)
   2. Analytics modules (`lib/eve_dmv/analytics/`)
   3. Context modules (`lib/eve_dmv/contexts/`)
   4. Other library files

## Important Notes

- This is part of a parallel fix effort - only modify number formatting issues
- Do NOT modify TODO comments, module aliases, pipeline usage, predicate naming, or other issue types
- Numbers ≤ 9999 should remain unchanged
- Be careful not to modify version numbers, dates, or other special numeric values
- Focus on one directory at a time to avoid conflicts

## Success Criteria

- All numbers > 9999 are formatted with underscores
- Code compiles without errors
- All tests pass
- No functionality is broken
- Numbers are more readable and follow Elixir conventions
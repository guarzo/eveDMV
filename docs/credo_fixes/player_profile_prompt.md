# Player Profile Code Quality Fixes

## Issues Overview - UPDATED
- **Error Count**: 40+ errors across player profile modules
- **Main Issues**: Duplicate code, single-function pipelines, variable redeclaration, code formatting
- **Files Affected**: 
  - `lib/eve_dmv/contexts/player_profile/analyzers/*`
  - `lib/eve_dmv/intelligence_engine/plugins/character/*`

## AI Assistant Prompt

Address player profile code quality issues:

### 1. **Duplicate Code** (CRITICAL - STILL ACTIVE)
**Status**: ❌ Duplicate code issues persist in different modules
**Current duplications**:
- `lib/eve_dmv/contexts/corporation_analysis/domain/corporation_analyzer.ex:435`
- `lib/eve_dmv/contexts/player_profile/domain/player_analyzer.ex:392`  
- `lib/eve_dmv/contexts/threat_assessment/domain/threat_analyzer.ex:511`
**Mass**: 36 lines of duplicated `calculate_current_metrics` function

**NEW Strategy**: 
- Extract `calculate_current_metrics` function into shared utility
- Create `EveDmv.Shared.MetricsCalculator` module for common analysis functions
- Update all three analyzer modules to use shared implementation
- Focus on domain analyzer modules rather than ship preferences (resolved)

### 2. **Variable Redeclaration** (High Priority)
Fix repeated variable names with descriptive alternatives:
```elixir
# Bad - repeated in same function
recommendations = initial_analysis()
# ... later ...
recommendations = final_analysis()

# Good - descriptive names
initial_recommendations = initial_analysis()
# ... later ...
final_recommendations = final_analysis()
```

**Common variables to fix**:
- `recommendations` → `combat_recommendations`, `ship_recommendations`, `tactical_recommendations`
- `strengths` → `combat_strengths`, `tactical_strengths`, `strategic_strengths`
- `weaknesses` → `combat_weaknesses`, `skill_gaps`, `tactical_vulnerabilities`

### 3. **Single-Function Pipelines** (High Priority)
Convert unnecessary pipelines:
```elixir
# Bad
player_data |> analyze_combat_patterns()

# Good
analyze_combat_patterns(player_data)
```

### 4. **Performance Optimization** (Medium Priority)
Replace inefficient operations:
```elixir
# Bad - double enumeration
data |> Enum.map(&transform/1) |> Enum.map(&process/1)

# Good - single pass
data |> Enum.map(&(&1 |> transform() |> process()))
```

### 5. **Code Formatting** (Quick Wins)
- Remove trailing whitespace
- Add final newlines to files
- Format large numbers with underscores
- Fix alias/require ordering

## Implementation Steps

### **Phase 1: Duplicate Code Resolution (PRIORITY)**
1. **Analyze duplicated functions** in ship preferences modules
2. **Create shared module**: `lib/eve_dmv/shared/ship_analysis.ex`
3. **Extract common functions**:
   - Role specialization calculation
   - Ship preference scoring
   - Combat effectiveness analysis
4. **Update both modules** to use shared functions
5. **Test thoroughly** to ensure behavior unchanged

### **Phase 2: Variable Naming**
1. **Identify all redeclared variables** in analyzer modules
2. **Create naming convention**:
   - Prefix with context: `combat_`, `ship_`, `tactical_`
   - Use descriptive suffixes: `_analysis`, `_recommendations`, `_patterns`
3. **Rename systematically** with find/replace
4. **Verify no breaking changes** in function signatures

### **Phase 3: Performance & Style**
1. **Convert single-function pipelines** to direct calls
2. **Optimize double enumerations** to single pass
3. **Apply code formatting** automatically
4. **Fix import organization**

## Files Requiring Immediate Attention

**Critical (Duplicate Code)**:
- `ship_preferences_analyzer.ex` (lines 96, 142, 665, 667)
- `ship_preferences.ex` (lines 142, 144, and corresponding duplicates)

**High Priority (Variables)**:
- `combat_stats_analyzer.ex` (multiple recommendation variables)
- Player analysis modules with repeated variable names

**Medium Priority**:
- Pipeline and formatting issues across player profile modules
- Performance optimizations in enumeration-heavy functions

## Success Criteria

1. **Zero duplicate code** between ship preferences modules
2. **No variable redeclaration** warnings in any player profile module  
3. **All single-function pipelines** converted to direct calls
4. **Performance improvements** measurable in analysis time
5. **All tests passing** with no behavioral changes

Focus on maintaining all player analysis functionality while eliminating code duplication and improving maintainability.

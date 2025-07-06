# Fleet Operations Code Quality Fixes

## Issues Overview - UPDATED
- **Error Count**: 25+ errors across fleet operation modules
- **Main Issues**: Variable redeclaration, single-function pipelines, code formatting, @impl annotations
- **Files Affected**: 
  - `lib/eve_dmv/contexts/fleet_operations/domain/*`
  - `lib/eve_dmv/intelligence/analyzers/fleet_*`
  - `lib/eve_dmv/intelligence/analyzers/wh_fleet_analyzer/*`

## AI Assistant Prompt

Address fleet operations code quality issues:

### 1. **Variable Redeclaration** (High Priority - 15+ instances)
Fix repeated variable names in fleet analysis modules:
```elixir
# Bad - variable reused in same function
recommendations = analyze_initial_fleet()
# ... processing ...
recommendations = generate_final_recommendations()

# Good - descriptive names
fleet_analysis = analyze_initial_fleet()
# ... processing ...
optimization_recommendations = generate_final_recommendations()
```

**Common variables to fix**:
- `recommendations` → `fleet_recommendations`, `composition_recommendations`, `tactical_recommendations`, `optimization_recommendations`
- `areas` → `improvement_areas`, `weakness_areas`, `focus_areas`
- `lessons` → `tactical_lessons`, `strategic_lessons`, `operational_lessons`
- `comp_recs` → `composition_suggestions`, `fleet_adjustments`
- `factors` → `effectiveness_factors`, `performance_factors`, `risk_factors`
- `validation_results` → `doctrine_validation`, `composition_validation`

### 2. **Single-Function Pipelines** (High Priority - 10+ instances)
Convert unnecessary pipelines in fleet analyzers:
```elixir
# Bad
fleet_data |> FleetAnalyzer.calculate_effectiveness()

# Good
FleetAnalyzer.calculate_effectiveness(fleet_data)
```

**Key areas**:
- Fleet composition analysis
- Effectiveness calculations
- Doctrine validation
- Optimization recommendations

### 3. **Code Formatting** (Quick Wins)
- Remove trailing whitespace
- Add final newlines to files
- Format large numbers with underscores
- Fix alias/require ordering

### 4. **@impl Annotations** (Medium Priority)
Replace `@impl true` with specific behavior names in fleet workers and supervisors.

## Implementation Steps

### **Phase 1: Variable Naming Cleanup**
1. **Fleet Analyzer Module**:
   - `recommendations` at lines 427, 864 → `tactical_recommendations`, `composition_recommendations`
   - `areas` at line 799 → `improvement_areas`
   - `lessons` at line 773 → `strategic_lessons`
   - `comp_recs` at line 864 → `composition_suggestions`

2. **Effectiveness Calculator**:
   - `recommendations` at lines 663, 871 → `performance_recommendations`, `optimization_recommendations`
   - `factors` at line 826 → `effectiveness_factors`

3. **Doctrine Manager**:
   - `validation_results` at line 630 → `doctrine_validation`
   - `recommendations` at line 535 → `compliance_recommendations`

### **Phase 2: Pipeline Conversion**
Target files with pipeline issues:
- `fleet_analyzer.ex` (lines 604, 1077)
- `effectiveness_calculator.ex` (lines 684, 705, 715)
- Fleet optimization and wormhole fleet analyzer modules

### **Phase 3: Formatting & Organization**
1. **Apply code formatter** to all fleet operation modules
2. **Fix import organization** (alias before require)
3. **Update @impl annotations** in fleet workers

## Fleet Analysis Context

When renaming variables, consider EVE Online fleet operation context:
- **Tactical**: Short-term combat decisions, ship positioning
- **Strategic**: Long-term fleet planning, doctrine development
- **Operational**: Day-to-day fleet management, pilot assignments
- **Composition**: Ship types, fits, roles within fleet
- **Effectiveness**: Combat performance metrics, success rates
- **Optimization**: Improvements to current fleet setups

## Files Requiring Immediate Attention

**High Priority (Variable Issues)**:
- `fleet_analyzer.ex` - Multiple variable redeclarations affecting analysis logic
- `effectiveness_calculator.ex` - Performance calculation variable conflicts
- `doctrine_manager.ex` - Validation and recommendation variable overlap

**Medium Priority (Pipelines)**:
- Fleet optimization modules with single-function pipelines
- Wormhole fleet analyzer pipeline issues
- Fleet pilot assignment and optimization functions

**Quick Wins (Formatting)**:
- All fleet operation modules for whitespace cleanup
- Import organization across fleet analysis components

## Success Criteria

1. **Zero variable redeclaration warnings** in fleet modules
2. **All single-function pipelines converted** to direct calls
3. **Consistent variable naming** reflecting fleet operation context
4. **All tests passing** with no behavioral changes in fleet analysis
5. **Performance maintained** in fleet effectiveness calculations

Focus on preserving all fleet analysis algorithms and tactical intelligence while improving code maintainability and readability.

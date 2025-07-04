# EVE DMV Cleanup Action Plan

## Overview
This document provides a comprehensive action plan to address all issues identified in the codebase cleanup analysis. Items are prioritized by severity and impact, with specific file paths, line numbers, and implementation steps.

## Critical Priority Items (Fix Immediately)

### 1. Fix Application Startup Failure
**Priority**: CRITICAL  
**Estimated Effort**: 30 minutes  
**Impact**: Application won't start without this fix

**Issue**: Missing `provisions/0` function in TelemetryHook prevents application startup

**Files to Fix**:
- `/workspace/lib/eve_dmv/intelligence/analysis_cache.ex` (lines 300-310)

**Action Steps**:
1. Add missing `provisions/0` function to TelemetryHook module
2. Implement proper Cachex hook provisions callback
3. Test application startup to verify fix

**Implementation**:
```elixir
defmodule EveDmv.Intelligence.AnalysisCache.TelemetryHook do
  def provisions do
    [:cache_name, :cache_size, :cache_hit_rate]
  end
end
```

### 2. Add Missing ExCoveralls Dependency
**Priority**: CRITICAL  
**Estimated Effort**: 15 minutes  
**Impact**: Test coverage cannot be measured

**Issue**: ExCoveralls dependency missing from mix.exs

**Files to Fix**:
- `/workspace/mix.exs` (deps section)

**Action Steps**:
1. Add `{:excoveralls, "~> 0.18", only: :test}` to dependencies
2. Run `mix deps.get`
3. Test coverage generation with `mix coveralls`

### 3. Remove Debug Statements from Production Config
**Priority**: HIGH  
**Estimated Effort**: 10 minutes  
**Impact**: Performance and security concern

**Issue**: Debug statements in production configuration

**Files to Fix**:
- `/workspace/config/runtime.exs` (lines 32, 74, 77)

**Action Steps**:
1. Replace `IO.puts` and `IO.warn` with proper logging
2. Use `Logger.info` or `Logger.warn` instead
3. Ensure no debug output in production

## High Priority Items (Next Sprint)

### 4. Refactor Correlation Engine
**Priority**: HIGH  
**Estimated Effort**: 2-3 days  
**Impact**: Massive performance and maintainability improvement

**Issue**: 1,436 lines with 478 lines per function average

**Files to Fix**:
- `/workspace/lib/eve_dmv/intelligence/correlation_engine.ex`

**Action Steps**:
1. **Extract Corporation Analysis Module**:
   - Create `EveDmv.Intelligence.CorporationAnalyzer`
   - Move lines 597-620 (`perform_actual_corporation_analysis`)
   - Simplify to basic data aggregation

2. **Extract Doctrine Analysis Module**:
   - Create `EveDmv.Intelligence.DoctrineAnalyzer` 
   - Move lines 1086-1225 (`analyze_doctrine_adherence`)
   - Replace complex doctrine matching with ship categorization

3. **Extract Statistical Analysis Module**:
   - Create `EveDmv.Intelligence.StatisticalAnalyzer`
   - Move lines 694-808 (statistical calculations)
   - Consider using a proper math library

4. **Remove Placeholder Functions**:
   - Delete lines 542-570 (functions returning empty lists)
   - Remove hardcoded return values

5. **Simplify Main Module**:
   - Reduce to coordination logic only
   - Delegate to extracted modules
   - Target <200 lines total

### 5. Refactor WH Vetting Analyzer
**Priority**: HIGH  
**Estimated Effort**: 2 days  
**Impact**: Major simplification of vetting logic

**Issue**: 2,349 lines with over-engineered validation workflow

**Files to Fix**:
- `/workspace/lib/eve_dmv/intelligence/wh_vetting_analyzer.ex`

**Action Steps**:
1. **Simplify Main Analysis Function** (lines 65-79):
   - Replace complex `with` chains with simple validation
   - Remove unnecessary data collection steps
   - Focus on essential risk factors only

2. **Consolidate Data Collection** (lines 90-107):
   - Merge `collect_all_analysis_data` into main function
   - Remove requirement for all analyses to succeed
   - Implement graceful degradation

3. **Extract Risk Scoring**:
   - Create `EveDmv.Intelligence.RiskScorer` module
   - Move risk calculation logic
   - Use simple weighted scoring algorithm

4. **Simplify Data Structures**:
   - Replace complex nested maps with flat structures
   - Use standardized response format
   - Remove redundant data transformations

### 6. Refactor Home Defense Analyzer
**Priority**: HIGH  
**Estimated Effort**: 2 days  
**Impact**: Removal of unnecessary enterprise patterns

**Issue**: 1,975 lines with over-engineered analytics pipeline

**Files to Fix**:
- `/workspace/lib/eve_dmv/intelligence/home_defense_analyzer.ex`

**Action Steps**:
1. **Remove Configuration Objects** (lines 40-54):
   - Replace with simple function parameters
   - Remove enterprise-style builders
   - Use direct data access

2. **Simplify Data Collection** (lines 56-88):
   - Remove complex processing pipeline
   - Use direct database queries
   - Eliminate unnecessary batching

3. **Extract System Analytics**:
   - Create `EveDmv.Intelligence.SystemAnalytics` module
   - Move system-specific analysis
   - Use simple aggregation functions

4. **Remove Premature Optimizations**:
   - Remove complex caching for unproven scale needs
   - Simplify to straightforward analytics
   - Focus on current requirements

### 7. Consolidate Character Intelligence LiveViews
**Priority**: HIGH  
**Estimated Effort**: 1 day  
**Impact**: Eliminate duplication and route confusion

**Issue**: Duplicate LiveViews with overlapping functionality

**Files to Fix**:
- `/workspace/lib/eve_dmv_web/live/character_intel_live.ex` (437 lines)
- `/workspace/lib/eve_dmv_web/live/character_intelligence_live.ex` (362 lines)
- `/workspace/lib/eve_dmv_web/router.ex` (route definitions)

**Action Steps**:
1. **Choose Primary LiveView**:
   - Keep `character_intel_live.ex` as primary
   - Use `/intel/:character_id` route (shorter, cleaner)
   

2. **Merge Functionality**:
   - Copy unique features from `character_intelligence_live.ex`
   - Ensure no functionality is lost
   - Test all features work correctly

3. **Update Routes**:
   - Remove `/character-intelligence/:character_id` route
   - Add redirect from old route to new route
   - Update all internal links

4. **Remove Duplicate File**:
   - Delete `character_intelligence_live.ex`
   - Update any references in tests
   - Clean up unused templates

### 8. Reorganize Intelligence Context
**Priority**: HIGH  
**Estimated Effort**: 1-2 days  
**Impact**: Better organization and maintainability

**Issue**: 37 files with mixed concerns and overlapping responsibilities

**Files to Reorganize**:
- All files in `/workspace/lib/eve_dmv/intelligence/`

**Action Steps**:
1. **Create Sub-Contexts**:
   ```
   intelligence/
   ├── analyzers/           # All *_analyzer modules
   ├── formatters/          # All *_formatter modules  
   ├── metrics/             # All *_metrics modules
   ├── wormhole/            # All wh_* modules
   ├── cache/               # All *_cache modules
   └── core/                # Main coordination modules
   ```

2. **Move Files to Appropriate Directories**:
   - Move all `*_analyzer.ex` files to `analyzers/`
   - Move all `wh_*.ex` files to `wormhole/`
   - Move all `*_formatter.ex` files to `formatters/`
   - Move all `*_metrics.ex` files to `metrics/`
   - Move cache-related files to `cache/`

3. **Update Module Names**:
   - Update module declarations to match new paths
   - Update all imports and references
   - Maintain backward compatibility where needed

4. **Remove Duplicate Modules**:
   - Delete `character_analyzer_simplified.ex`
   - Consolidate similar functionality
   - Ensure no functionality is lost

## Medium Priority Items (Future Improvements)

### 9. Standardize Naming Conventions
**Priority**: MEDIUM  
**Estimated Effort**: 1 day  
**Impact**: Improved code consistency

**Issue**: Mixed American/British English spelling (179 vs 37 functions)

**Action Steps**:
1. **Create Bulk Rename Script**:
   - Find all instances of `analyse` -> `analyze`
   - Find all instances of `analyses` -> `analysis_results`
   - Update variable names for consistency

2. **Update Function Names**:
   - Rename all `analyse_*` functions to `analyze_*`
   - Update all function calls
   - Update tests and documentation

3. **Standardize Other Patterns**:
   - Choose `get_` vs `fetch_` consistently
   - Standardize error handling patterns
   - Use consistent naming for similar operations

### 10. Extract Large LiveView Components
**Priority**: MEDIUM  
**Estimated Effort**: 2 days  
**Impact**: Better component reusability

**Issue**: Several LiveViews over 700 lines

**Files to Fix**:
- `/workspace/lib/eve_dmv_web/live/player_profile_live.ex` (798 lines)
- `/workspace/lib/eve_dmv_web/live/surveillance_live.ex` (708 lines)

**Action Steps**:
1. **Extract Player Profile Components**:
   - Create `PlayerStatsComponent`
   - Create `PlayerAnalysisComponent`
   - Create `PlayerChartsComponent`

2. **Extract Surveillance Components**:
   - Create `SurveillanceProfileComponent`
   - Create `NotificationComponent`
   - Create `MatchingEngineComponent`

3. **Create Shared Components**:
   - Create `IntelligenceChartsComponent`
   - Create `DataTableComponent`
   - Create `FilterComponent`

### 11. Improve Test Coverage
**Priority**: MEDIUM  
**Estimated Effort**: 3-4 days  
**Impact**: Better code reliability

**Issue**: Low test coverage (~14.7% estimated)

**Action Steps**:
1. **Add Missing Tests**:
   - Test all intelligence analyzer modules
   - Test all LiveView functionality
   - Test error handling paths

2. **Improve Existing Tests**:
   - Add comments to skipped tests explaining why
   - Add property-based tests for complex calculations
   - Add integration tests for critical workflows

3. **Set Coverage Goals**:
   - Target 70% minimum coverage
   - Set up coverage reports in CI
   - Add coverage badges to README

### 12. Refactor Remaining Large Modules
**Priority**: MEDIUM  
**Estimated Effort**: 2-3 days  
**Impact**: Better maintainability

**Files to Fix**:
- `/workspace/lib/eve_dmv/intelligence/wh_fleet_analyzer.ex` (1,876 lines)
- `/workspace/lib/eve_dmv/intelligence/member_activity_analyzer.ex` (1,538 lines)
- `/workspace/lib/eve_dmv/intelligence/character_metrics.ex` (1,102 lines)
- `/workspace/lib/eve_dmv/intelligence/chain_monitor.ex` (1,084 lines)

**Action Steps**:
1. **WH Fleet Analyzer**:
   - Extract composition analysis to separate module
   - Extract fleet classification logic
   - Simplify ship categorization

2. **Member Activity Analyzer**:
   - Consolidate 4 separate modules into 1
   - Remove unnecessary abstractions
   - Simplify activity calculations

3. **Character Metrics**:
   - Extract calculation logic to utility module
   - Simplify metric collection
   - Remove redundant calculations

4. **Chain Monitor**:
   - Extract monitoring logic to separate module
   - Simplify chain tracking
   - Remove complex state management

## Low Priority Items (Nice to Have)

### 13. Clean Up Commented Code
**Priority**: LOW  
**Estimated Effort**: 2 hours  
**Impact**: Cleaner codebase

**Action Steps**:
1. Review all commented-out code
2. Remove non-documentation comments
3. Keep only explanatory comments

### 14. Consolidate Cache Systems
**Priority**: LOW  
**Estimated Effort**: 1 day  
**Impact**: Better cache management

**Action Steps**:
1. Create unified cache system
2. Remove duplicate cache implementations
3. Standardize cache TTL configurations

### 15. Optimize Database Queries
**Priority**: LOW  
**Estimated Effort**: 1 day  
**Impact**: Better performance

**Action Steps**:
1. Review all database queries for optimization
2. Add appropriate indexes where needed
3. Optimize complex aggregations

## Implementation Timeline

### Week 1: Critical Issues
- [ ] Fix application startup failure
- [ ] Add ExCoveralls dependency
- [ ] Remove debug statements

### Week 2-3: High Priority Refactoring
- [ ] Refactor correlation engine
- [ ] Refactor WH vetting analyzer
- [ ] Consolidate character intelligence LiveViews

### Week 4-5: Organization and Structure
- [ ] Reorganize intelligence context
- [ ] Refactor home defense analyzer
- [ ] Standardize naming conventions

### Week 6-8: Medium Priority Items
- [ ] Extract large LiveView components
- [ ] Improve test coverage
- [ ] Refactor remaining large modules

### Week 9-10: Polish and Optimization
- [ ] Clean up commented code
- [ ] Consolidate cache systems
- [ ] Optimize database queries

## Success Metrics

### Code Quality Metrics
- [ ] Reduce largest file from 2,349 to <500 lines
- [ ] Achieve 70%+ test coverage
- [ ] Maintain 0 Credo violations
- [ ] Reduce intelligence module count from 37 to <25 files

### Performance Metrics
- [ ] Reduce application startup time
- [ ] Improve analysis performance by 50%+
- [ ] Reduce memory usage in intelligence modules

### Maintainability Metrics
- [ ] Reduce cyclomatic complexity
- [ ] Improve module cohesion
- [ ] Eliminate code duplication

## Risk Mitigation

### Testing Strategy
- [ ] Create comprehensive test suite before major refactoring
- [ ] Use feature flags for gradual rollout
- [ ] Maintain backward compatibility during transitions

### Rollback Plan
- [ ] Create feature branches for each major change
- [ ] Maintain working main branch at all times
- [ ] Document rollback procedures for each change

### Communication Plan
- [ ] Update team on progress weekly
- [ ] Document architectural decisions
- [ ] Create migration guides for breaking changes

## Notes

- This action plan should be executed in order of priority
- Each item includes specific file paths and line numbers for easy reference
- Estimated efforts are based on a single developer working full-time
- Success metrics should be measured after each phase
- Regular code reviews are recommended during implementation

---

*Last updated: 2025-01-04*
*Total estimated effort: 4-6 weeks*
*Priority items: 8 critical/high, 8 medium/low*
# Manual Resolution Plan V5 - Current State: 302 Errors

## Progress Update
- **Started with**: 791 errors (v4 baseline)
- **After v4 + formatting**: 302 errors
- **Progress made**: 489 errors eliminated (62% reduction)
- **Remaining work**: 302 errors to address

## Current Error Breakdown (412 total)

Based on analysis of current credo.txt:

### By Error Type:
1. **Trailing Whitespace**: ~80 errors (19%) - Quick mechanical fixes
2. **Import/Alias Ordering**: ~70 errors (17%) - Structural reorganization  
3. **Missing Final Newlines**: ~15 errors (4%) - One-line fixes
4. **@impl Annotations**: 5 errors (1%) - Simple replacements
5. **Enum.map_join**: ~12 errors (3%) - Performance optimizations
6. **Number Formatting**: ~25 errors (6%) - Add underscores
7. **TODO Comments**: ~10 errors (2%) - Remove or implement
8. **Long Quote Blocks**: ~8 errors (2%) - Shorten documentation
9. **Function Structure**: ~25 errors (6%) - Module organization
10. **Pipeline Issues**: ~50 errors (12%) - Function call vs pipeline
11. **with/case Conversions**: ~8 errors (2%) - Logic restructuring
12. **Complex Issues**: ~104 errors (25%) - Deep nesting, dependencies, etc.

### By File Location:
1. **combat_intelligence/domain**: ~90 errors (heavy whitespace issues)
2. **intelligence/analyzers**: ~80 errors (mixed issues)
3. **database**: ~40 errors (mostly structural)
4. **test files**: ~50 errors (formatting and aliases)
5. **eve_dmv_web**: ~30 errors (pipeline and formatting)
6. **Other modules**: ~122 errors (scattered issues)

## Execution Strategy V5

### Phase 5A: Mechanical Quick Fixes (1-2 hours)
**Target: 412 → 250 errors**

1. **Trailing Whitespace** (80 errors) - 30 minutes
   - Especially heavy in combat_intelligence/domain files
   - Automated find/replace possible

2. **Missing Final Newlines** (15 errors) - 10 minutes
   - Simple end-of-file additions

3. **Number Formatting** (25 errors) - 20 minutes
   - Add underscores to large numbers

4. **@impl Annotations** (5 errors) - 10 minutes
   - Change `@impl true` to `@impl GenServer`

5. **TODO Comments** (10 errors) - 20 minutes
   - Remove or replace with implementation notes

6. **Enum.map_join** (12 errors) - 30 minutes
   - Replace pipe chains with optimized calls

### Phase 5B: Structural Organization (45-60 minutes)  
**Target: 250 → 150 errors**

7. **Import/Alias Ordering** (70 errors) - 45 minutes
   - Fix use/alias/require/import order
   - Alphabetize alias groups

8. **Module Structure** (25 errors) - 15 minutes
   - Move moduledoc, defstruct, types to correct positions

### Phase 5C: Logic and Flow (45-60 minutes)
**Target: 150 → 100 errors**

9. **Pipeline Issues** (50 errors) - 45 minutes
   - Convert single-function pipelines to direct calls
   - Fix nested function calls to pipelines

### Phase 5D: Complex Issues (60-90 minutes)
**Target: 100 → <50 errors**

10. **with/case Conversions** (8 errors) - 15 minutes
11. **Long Quote Blocks** (8 errors) - 15 minutes  
12. **Function Complexity** (42 errors) - 60 minutes
    - Reduce nesting depth
    - Split complex functions
    - Reduce module dependencies
    - Fix parameter counts

## Priority File Groups

### High Impact, Low Effort (Start Here):
1. `lib/eve_dmv/contexts/combat_intelligence/domain/*.ex` - 90 errors, mostly whitespace
2. `test/**/*.exs` - 50 errors, mostly formatting
3. Number formatting across all files - 25 errors

### Medium Effort, High Impact:
1. `lib/eve_dmv/intelligence/analyzers/*.ex` - 80 errors, mixed types
2. `lib/eve_dmv/database/*.ex` - 40 errors, structural
3. Import ordering across all files - 70 errors

### Complex Issues (Save for Last):
1. Function nesting and complexity - 42 errors
2. Module dependency issues - scattered
3. Logic restructuring - case/with conversions

## Time Estimates

- **Phase 5A (Mechanical)**: 1-2 hours → 162 errors eliminated
- **Phase 5B (Structural)**: 45-60 minutes → 100 errors eliminated  
- **Phase 5C (Logic)**: 45-60 minutes → 50 errors eliminated
- **Phase 5D (Complex)**: 60-90 minutes → 50+ errors eliminated

**Total Time**: 3.5-5 hours to reach <50 errors

## Success Metrics

### After Phase 5A:
- [ ] No trailing whitespace errors
- [ ] All files have final newlines
- [ ] All numbers properly formatted
- [ ] **Target: <250 errors**

### After Phase 5B:
- [ ] All imports properly ordered
- [ ] Module structure consistent
- [ ] **Target: <150 errors**

### After Phase 5C:
- [ ] Pipeline usage optimized
- [ ] Function calls vs pipelines correct
- [ ] **Target: <100 errors**

### After Phase 5D:
- [ ] Function complexity acceptable
- [ ] Logic structures optimized
- [ ] **Target: <50 errors**

## Verification Commands

```bash
# Check total progress
wc -l /workspace/credo.txt

# Check specific error types
grep -c "trailing white-space" /workspace/credo.txt
grep -c "alias must appear before" /workspace/credo.txt
grep -c "final \\\\n" /workspace/credo.txt
grep -c "should be written with underscores" /workspace/credo.txt
grep -c "map_join.*more efficient" /workspace/credo.txt

# Verify compilation
mix compile --warnings-as-errors
```

## Next Steps

Begin with **Phase 5A** focusing on the combat_intelligence domain files for maximum immediate impact, then proceed systematically through the phases.

The goal is to achieve <50 total errors, representing a 94%+ reduction from the original baseline.
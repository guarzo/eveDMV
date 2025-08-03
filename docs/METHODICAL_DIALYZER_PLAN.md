# Methodical Dialyzer Resolution Plan

## Current Status
- **Baseline**: 1,840 errors (down from 1,901)
- **Target**: <200 errors
- **Errors to fix**: 1,640+

## 🎯 Three-Pronged Systematic Approach

### Script 1: Methodical Resolution (`methodical_dialyzer_resolution.sh`)
**Purpose**: Systematic extraction and fixing of all error types
**Approach**: 
- Extract all 1,840 errors into categorized database
- Apply targeted fixes for each error type
- Verify compilation after each batch
- Track progress with before/after comparison

### Script 2: Iterative Fixer (`iterative_dialyzer_fixer.sh`)
**Purpose**: Fix errors in small, safe batches with rollback capability
**Approach**:
- Process 20 errors at a time
- Create git snapshots before each batch
- Verify compilation after each batch
- Rollback failed batches automatically
- Continue until <200 errors or max iterations

### Script 3: Focused Hunter (`focused_error_hunter.sh`)
**Purpose**: Target high-impact error types for maximum reduction
**Approach**:
- Hunt errors in priority order (unused_fun → guard_fail → pattern_match...)
- Apply specialized fixes for each error type
- Focus on easiest wins first for rapid progress

## 🚀 Execution Strategy

### Phase 1: Quick Wins (Target: 500+ errors fixed)
```bash
# Start with the focused hunter for maximum impact
bash /workspace/scripts/focused_error_hunter.sh
```
Expected results:
- unused_fun errors: ~400 fixed (add @compile directives)
- guard_fail errors: ~50 fixed (fix guard clauses)
- pattern_match errors: ~100 fixed (add error clauses)

### Phase 2: Systematic Resolution (Target: 800+ errors fixed)
```bash
# Use methodical approach for comprehensive fixing
bash /workspace/scripts/methodical_dialyzer_resolution.sh
```
Expected results:
- Complete analysis of all remaining errors
- Targeted fixes for each error category
- Progress tracking and verification

### Phase 3: Iterative Cleanup (Target: <200 errors)
```bash
# Use iterative approach for final cleanup
bash /workspace/scripts/iterative_dialyzer_fixer.sh
```
Expected results:
- Safe, incremental fixes with rollback
- Careful verification at each step
- Final push to <200 errors

## 📊 Error Type Priorities

### Priority 1: High Impact, Easy Fix
1. **unused_fun** (~400 errors) - Add @compile directives
2. **guard_fail** (~50 errors) - Fix guard expressions
3. **extra_range** (~30 errors) - Fix type specifications

### Priority 2: Medium Impact, Medium Difficulty  
4. **pattern_match** (~100 errors) - Add missing error clauses
5. **invalid_contract** (~20 errors) - Fix function specs
6. **call** (~80 errors) - Fix function arguments

### Priority 3: Low Impact, Hard Fix
7. **no_return** (~15 errors) - Add return values/error handling
8. **Other errors** (~1,145 errors) - Context-specific fixes

## 🔧 Common Fix Patterns

### Unused Functions
```bash
# Add module-level directive
@compile {:nowarn_unused_function}
```

### Guard Failures
```elixir
# Before: when x === nil
# After:  when is_nil(x)

# Before: when x != false  
# After:  when is_boolean(x)
```

### Pattern Matches
```elixir
# Add missing error clauses
case some_function() do
  {:ok, result} -> process(result)
  error -> error  # <- Add this
end
```

### Extra Range
```elixir
# Remove impossible return types from specs
@spec function() :: {:ok, result} | {:error, reason}
# Remove: | :ok  (if function never returns :ok)
```

### Function Calls
```elixir
# Fix DateTime.truncate
DateTime.truncate(dt, :second)  # not :minute

# Fix Ash.bulk_destroy
Ash.bulk_destroy(query, :destroy, domain: Api)
```

## 📈 Progress Tracking

### Measurement Points
1. **After Phase 1**: Expect ~1,340 errors remaining
2. **After Phase 2**: Expect ~1,040 errors remaining  
3. **After Phase 3**: Target <200 errors

### Verification Commands
```bash
# Quick compilation check
mix compile --warnings-as-errors

# Quick dialyzer progress (60s timeout)
timeout 60 mix dialyzer --format short | grep "Total errors:"

# Full analysis (when needed)
mix dialyzer > dialyzer_new.txt
```

## 🛡️ Safety Measures

### Automated Rollback
- Git snapshots before each batch
- Compilation verification after each change
- Automatic rollback on compilation failure

### Incremental Verification
- Small batch sizes (20 errors max)
- Compilation check after each batch
- Progress measurement between phases

### Manual Review Points
- Review git diff after each phase
- Test critical functionality manually
- Run full test suite before final commit

## 🎯 Success Criteria

### Phase Success
- ✅ Compilation successful after each script
- ✅ Error count reduction measurable
- ✅ No functionality regressions

### Final Success
- 🎯 **<200 total dialyzer errors**
- ✅ All tests passing
- ✅ Application starts successfully
- ✅ Core functionality verified

## 🚀 Quick Start

```bash
# Make all scripts executable
chmod +x /workspace/scripts/methodical_dialyzer_resolution.sh
chmod +x /workspace/scripts/iterative_dialyzer_fixer.sh  
chmod +x /workspace/scripts/focused_error_hunter.sh

# Start with focused hunting for maximum impact
bash /workspace/scripts/focused_error_hunter.sh

# Check progress
mix compile --warnings-as-errors
timeout 60 mix dialyzer --format short | grep "Total errors:"

# Continue with methodical approach
bash /workspace/scripts/methodical_dialyzer_resolution.sh

# Final cleanup with iterative approach
bash /workspace/scripts/iterative_dialyzer_fixer.sh
```

This methodical approach ensures systematic resolution of all dialyzer errors with proper verification and rollback capabilities.
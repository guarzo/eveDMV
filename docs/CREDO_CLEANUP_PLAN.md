# Multi-Workstream Credo Cleanup Plan

**Project**: EVE DMV  
**Current Issues**: 620 total (347 refactoring + 270 readability + 3 design)  
**Progress**: 167 issues resolved (787→620, 21% reduction)  
**Target**: <50 issues remaining  
**Updated Timeline**: 4-5 days (ahead of schedule)  
**Teams**: 11 developers across 3 active workstreams + final cleanup  

## 📊 Issue Analysis Summary

After configuration optimization and Workstream A execution, we reduced issues from **980→787→620** (37% total reduction). The updated `.credo.exs` excludes high-noise, low-value rules:

- ✅ Disabled `AppendSingleItem` (~250 fewer issues)
- ✅ Disabled `NegatedIsNil` (~50 fewer issues)  
- ✅ Relaxed `AliasUsage` thresholds (~100 fewer issues)
- ✅ Increased `DuplicatedCode` thresholds

**Completed patterns:**
- ✅ Alias alphabetical ordering (DONE - 0 remaining)
- ✅ Line length violations (DONE - 0 remaining)
- ✅ Function parentheses (DONE - 0 remaining)
- ✅ Major grouped alias expansions (DONE)

**Remaining patterns:**
- Import/require/alias positioning (12 remaining - final Workstream A cleanup)
- Implicit try blocks (98 remaining - moved to Workstream B)
- Negated conditions in if-else blocks
- Variable rebinding
- Function nesting depth

## 🎯 Workstream Structure (Conflict-Free Design)

### **Workstream A: Pure Readability (No Logic Changes)** - 85% COMPLETE
**Target**: ~300 issues | **Progress**: 255+ issues completed | **Risk**: Very Low | **Timeline**: 3 hours remaining

**Completed Focus Areas:**
- ✅ Alias alphabetical ordering (`AliasOrder`) - DONE
- ✅ Line length violations (`MaxLineLength`) - DONE
- ✅ Parentheses cleanup (`ParenthesesOnZeroArityDefs`) - DONE
- ✅ Grouped alias expansion - DONE

**Remaining Focus (12 issues):**
- Import/require/alias positioning (`StrictModuleLayout`) - Final cleanup

**Final Cleanup Assignment (12 issues remaining):**
```
Team A-Final: Single developer, 3 hours
- lib/eve_dmv/contexts/combat_analysis/domain/battle_detection_service.ex
- lib/eve_dmv/contexts/combat_analysis/domain/battle_sharing_service.ex
- lib/eve_dmv/contexts/combat_analysis/domain/character_analysis_engine.ex  
- lib/eve_dmv/contexts/combat_analysis/domain/fleet_analysis_engine.ex
- lib/eve_dmv/contexts/combat_analysis/domain/threat_assessment_engine.ex

Task: Move alias statements before require statements
```

### **Workstream B: Logic Improvements (Safe Refactoring)** - ENHANCED SCOPE
**Target**: ~350 issues (expanded) | **Risk**: Low-Medium | **Timeline**: 3-4 days

**Enhanced Focus Areas:**
- 🆕 **98 implicit try blocks** (`PreferImplicitTry`) - transferred from Workstream A
- Negated conditions (`NegatedConditionsWithElse`)
- Variable rebinding (`VariableRebinding`)
- With clause improvements (`WithClauses`)
- Zero-arity function parentheses (remaining cases)

**Enhanced File Assignment Strategy:**
```
Team B1: lib/eve_dmv/shared/* (strategic, monitoring, intelligence)
         + 25 implicit try issues from these files
Team B2: lib/eve_dmv/database/* + lib/eve_dmv/performance/*
         + 20 implicit try issues from these files
Team B3: lib/eve_dmv/intelligence/* + lib/eve_dmv/workers/*
         + 25 implicit try issues from these files  
Team B4: lib/eve_dmv/contexts/wormhole_* + lib/eve_dmv/contexts/market_*
         + remaining implicit try issues
Team B5: NEW - Combat Analysis implicit try issues (28 issues)
         lib/eve_dmv/contexts/combat_analysis/* + contexts/battle_sharing/*
```

### **Workstream C: Complex Issues (Careful Refactoring)**  
**Target**: ~200 issues | **Risk**: Medium | **Timeline**: 2-3 days (parallel with B)

**Focus Areas:**
- Function nesting depth (`Nesting`)
- Duplicate code resolution (`DuplicatedCode`)
- Pipeline optimizations (`FilterFilter`, `MapMap`)
- Nested function calls (`NestedFunctionCalls`)

**File Assignment Strategy:**
```
Team C1: lib/eve_dmv/contexts/intelligence_infrastructure/*
Team C2: lib/eve_dmv/contexts/threat_* + surveillance matching
Team C3: Large analysis files (battle_metrics, ship_performance)
```

### **Workstream D: Design & Architecture**
**Target**: ~35 remaining issues | **Risk**: High | **Timeline**: 1 day (post B-C)

**Focus Areas:**
- Final duplicate code resolution
- Complex nested module refactoring
- Any remaining edge cases

## 📋 Updated Detailed Workstream Assignments

### **Workstream A: Final Readability Cleanup** (1 developer, 3 hours)

**✅ MAJOR WORK COMPLETED:**
- Alias alphabetical ordering: DONE (0 issues remaining)
- Line length violations: DONE (0 issues remaining) 
- Function parentheses: DONE (0 issues remaining)
- Grouped alias expansions: DONE

**Final Cleanup Tasks (12 issues, ~20 min each):**
```
Files requiring alias/require positioning fixes:
1. lib/eve_dmv/contexts/combat_analysis/domain/battle_detection_service.ex
2. lib/eve_dmv/contexts/combat_analysis/domain/battle_sharing_service.ex ✅ 
3. lib/eve_dmv/contexts/combat_analysis/domain/character_analysis_engine.ex ✅
4. lib/eve_dmv/contexts/combat_analysis/domain/fleet_analysis_engine.ex ✅
5. lib/eve_dmv/contexts/combat_analysis/domain/threat_assessment_engine.ex ✅
6. ~7 additional files (run: mix credo --strict --format=oneline | grep "alias.*before.*require")

Task: Move alias statements above require statements in module header
Estimated time: 3 hours total
```

### **Workstream B: Logic Improvements** (Teams B1-B4)

**Team B1 - Shared Infrastructure + Implicit Try:**
```
Files: 25-30 files + implicit try conversions
- lib/eve_dmv/shared/strategic/*
- lib/eve_dmv/shared/monitoring/*  
- lib/eve_dmv/shared/intelligence/*
- lib/eve_dmv/shared/correlation/*

Enhanced Priority fixes:
1. 🆕 Convert explicit try-rescue to implicit try (~25 issues)
2. Convert negated if-else to positive conditions
3. Fix variable rebinding patterns
4. Optimize with clauses
```

**Team B2 - Database & Performance:**
```
Files: 15-20 files
- lib/eve_dmv/database/*
- lib/eve_dmv/performance/*
- lib/eve_dmv/telemetry/*

Focus: Query optimization and monitoring logic improvements
```

**Team B3 - Intelligence & Workers:**
```
Files: 20-25 files
- lib/eve_dmv/intelligence/*
- lib/eve_dmv/workers/*

Focus: Background job and analysis logic improvements
```

**Team B4 - Context Modules:**
```
Files: 10-15 files + implicit try conversions
- lib/eve_dmv/contexts/wormhole_operations/*
- lib/eve_dmv/contexts/market_intelligence/*
- lib/eve_dmv/contexts/killmail_processing/*

Focus: Business logic improvements and error handling
```

**Team B5 - Combat Analysis Implicit Try (NEW):**
```
Files: Combat analysis modules with 28 implicit try issues
- lib/eve_dmv/contexts/combat_analysis/* 
- lib/eve_dmv/contexts/battle_sharing/*
- lib/eve_dmv/contexts/threat_surveillance/*

Special focus: 28 implicit try conversions in combat modules
- battle_analysis_coordinator.ex: 1 issue
- battle_sharing_service.ex: 2 issues  
- character_analysis_engine.ex: 5 issues
- Additional files as identified
```

### **Workstream C: Complex Refactoring** (Teams C1-C3)

**Team C1 - Intelligence Infrastructure:**
```
Files: 15-20 files (largest, most complex)
- lib/eve_dmv/contexts/intelligence_infrastructure/domain/cross_system/*

Special attention to:
1. Reducing function nesting depth (max 3 levels)
2. Extract helper functions for deeply nested code
3. Resolve duplicate code by creating shared utilities
```

**Team C2 - Threat Surveillance:**
```
Files: 10-15 files
- lib/eve_dmv/contexts/threat_surveillance/domain/*
- lib/eve_dmv/surveillance/matching/*

Focus on pipeline optimizations and nested function calls
```

**Team C3 - Large Analysis Files:**
```
Files: 5-10 files (but very large)
- battle_metrics_calculator.ex (1000+ lines)
- ship_performance_analyzer.ex (1500+ lines)
- tactical_pattern_detector.ex (900+ lines)

Focus: Breaking down large functions and reducing complexity
```

## 🔒 Conflict Prevention Protocol

### **File Assignment Rules**
1. **No overlapping files** between workstreams
2. **Single-file focus** per team member per day
3. **Related modules assigned to same team** (avoid cross-dependencies)
4. **Alphabetical assignment within teams** to prevent conflicts



### **Daily Validation Cycle**
```bash
# Before starting work (MANDATORY)
mix compile --warnings-as-errors  # MUST pass
mix credo --strict | grep "$(pwd)/lib/path/to/your/files"

# After each file (MANDATORY)
mix compile --warnings-as-errors  # Must pass!
mix test path/to/relevant/tests    # Must pass!
mix credo path/to/your/file        # Check progress

# Before committing (MANDATORY)
mix credo --strict | wc -l         # Track total reduction
git add single_file.ex             # ONE FILE ONLY
git commit -m "fix(credo): specific changes in filename.ex"
```

## ⚠️ Critical Safety Protocols

### **Before Starting Any Work:**
```bash
# 2. Baseline compile check
mix compile --warnings-as-errors  # MUST pass
mix test --only integration       # MUST pass

# 3. Get your baseline issue count  
mix credo lib/your/assigned/path/* --format=oneline | wc -l
```

### **After Each File:**
```bash
# 1. MANDATORY compile check
mix compile --warnings-as-errors  # If this fails, revert immediately

# 2. Run related tests
mix test test/path/to/related/test.exs

# 3. Check credo improvement
mix credo path/to/your/file.ex --format=oneline | wc -l  # Should be lower

# 4. Commit single file immediately  
git add path/to/your/file.ex
git commit -m "fix(credo): resolve readability issues in filename.ex

- Fix alias alphabetical ordering
- Move imports before requires
- Remove grouped aliases"
```

### **Example Transformation Patterns**

#### Alias Ordering Fix:
```elixir
# Before
alias EveDmv.Shared.Intelligence
alias EveDmv.Analytics.BattleDetector
alias EveDmv.Contexts.BattleAnalysis

# After (alphabetical)
alias EveDmv.Analytics.BattleDetector
alias EveDmv.Contexts.BattleAnalysis
alias EveDmv.Shared.Intelligence
```

#### Grouped Alias Expansion:
```elixir
# Before
alias EveDmv.Contexts.{BattleAnalysis, CombatIntelligence, FleetOperations}

# After
alias EveDmv.Contexts.BattleAnalysis
alias EveDmv.Contexts.CombatIntelligence
alias EveDmv.Contexts.FleetOperations
```

#### Negated Condition Fix:
```elixir
# Before (Negated condition)
if !is_nil(data) do
  process(data)
else  
  handle_error()
end

# After (Positive condition)
if is_nil(data) do
  handle_error()
else
  process(data)
end
```

#### Implicit Try Conversion (NOW WORKSTREAM B - 98 issues):
```elixir
# Before (Explicit try)
def process_data(data) do
  try do
    dangerous_operation(data)
  rescue
    error -> handle_error(error)
  end
end

# After (Implicit try - only if function body is just try-rescue)
def process_data(data) do
  dangerous_operation(data)
rescue
  error -> handle_error(error)
end

# IMPORTANT: Only convert if the try block is the entire function body!
# Do NOT convert if there's other logic before/after the try block.
```

#### Variable Rebinding Fix:
```elixir
# Before (Variable rebinding)
def calculate_metrics(data) do
  metrics = initial_metrics()
  metrics = add_kills(metrics, data)
  metrics = add_deaths(metrics, data)
  metrics
end

# After (Pipeline or different variable names)
def calculate_metrics(data) do
  data
  |> initial_metrics()
  |> add_kills(data)
  |> add_deaths(data)
end
```

## 🚨 Emergency Protocols

### **If Compile Errors Occur:**
```bash
# 1. IMMEDIATELY revert the file
git checkout HEAD~1 -- path/to/problematic/file.ex

# 2. Verify compile success
mix compile --warnings-as-errors

# 3. Report to team lead with specific error
# 4. Skip that file and move to next assigned file
```

### **If Tests Fail:**
```bash
# 1. Check if test was already failing
git checkout HEAD~1 -- path/to/file.ex
mix test path/to/failing/test.exs

# If test was already failing: proceed with credo fixes
# If your change broke it: revert and report
```

### **If Merge Conflicts:**
```bash
# 1. NEVER resolve conflicts yourself
# 2. Immediately notify team lead
# 3. Create new branch: git checkout -b fix/credo-conflicts-YOURNAME
# 4. Continue work on branch until conflict resolution
```

### **Validation Commands for Each Team:**

#### Team A (Final Cleanup - 12 issues):
```bash
# Check for remaining alias/require issues
mix credo --strict --format=oneline | grep -E "alias.*before.*require"

# After fixing each file
mix compile --warnings-as-errors  # Must pass!
mix credo path/to/file.ex --format=oneline | grep "alias.*before.*require"  # Should be empty

# Quick validation - should show 0:
mix credo --strict --format=oneline | grep -E "alias.*before.*require" | wc -l
```

#### Team B (Enhanced Logic - now includes 98 implicit try issues):
```bash
# Check logic improvements including new implicit try issues
mix credo lib/eve_dmv/shared/* --format=oneline | grep -E "(NegatedConditions|PreferImplicitTry|VariableRebinding)"

# Count remaining implicit try issues
mix credo --strict --format=oneline | grep -E "implicit.*try" | wc -l

# After logic fixes
mix test test/path/to/related/tests/  # Must pass!
mix compile --warnings-as-errors     # Must pass!

# Validate implicit try conversion is safe:
# - Only convert if try block is entire function body
# - Preserve rescue/catch clauses exactly
# - Test error handling still works
```

#### Team C (Complex):
```bash
# Check complexity improvements  
mix credo lib/eve_dmv/contexts/intelligence_infrastructure/* --format=oneline | grep -E "(Nesting|DuplicatedCode)"

# After refactoring
mix test --cover --only unit  # Coverage should not decrease
```

## 📈 Success Metrics & Timeline

### **Updated Daily Targets:**
- **Day 1**: ✅ Workstream A major completion (255+ issues resolved)
- **Day 1-2**: Workstream A final cleanup (12 remaining issues)
- **Day 2-4**: Workstream B enhanced scope (~350 issues including 98 implicit try)
- **Day 4-6**: Workstream C complex refactoring (~200 issues)
- **Day 6**: Workstream D handles remaining edge cases (~35 issues)

### **Quality Gates:**
- ✅ **Zero compile warnings** at all times
- ✅ **Zero test regressions** 
- ✅ **50+ issues resolved per team per day**
- ✅ **Individual file commits** (no multi-file commits)
- ✅ **Daily progress reports** with issue count reduction

### **Updated Progress Tracking:**
```bash
# Daily team lead check
mix credo --strict | tail -5
# Current: 620 issues (167 resolved from original 787)
# Revised target progression:
# Day 1-2: ~608 issues (12 more from Workstream A final)
# Day 4: ~260 issues (350 from enhanced Workstream B)  
# Day 6: ~60 issues (200 from Workstream C)
# Day 6: <50 issues (final cleanup)
```

### **Final Validation:**
```bash
# Target: <50 total issues remaining
mix credo --strict | tail -5
# Should show: "found <50 refactoring opportunities"

# All tests pass
mix test

# No compile warnings  
mix compile --warnings-as-errors

# Coverage maintained
mix test --cover
# Should show >=70% coverage maintained
```

## 📞 Communication Channels

### **Daily Standups** (Required):
1. **Issue count progress** from each team
2. **Blocker identification** (compile failures, test failures)
3. **File assignment conflicts** (if discovered)
4. **Merge coordination** for shared utility creation

### **Slack Channels**:
- `#credo-workstream-a` - Readability fixes
- `#credo-workstream-b` - Logic improvements  
- `#credo-workstream-c` - Complex refactoring
- `#credo-emergency` - Immediate help needed

### **Escalation Path**:
1. **Team member blocked** → Team lead
2. **Team blocked** → Workstream lead  
3. **Cross-workstream conflict** → Project lead
4. **Emergency (broken main)** → All hands

---

**Remember**: The goal is **code quality improvement**, not just issue reduction. Every change should make the code more readable, maintainable, and robust. When in doubt, prefer safety over speed.
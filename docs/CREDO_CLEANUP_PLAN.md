# Multi-Workstream Credo Cleanup Plan

**Project**: EVE DMV  
**Current Issues**: 787 total (397 refactoring + 376 readability + 14 design)  
**Target**: <50 issues remaining  
**Timeline**: 6 days  
**Teams**: 12 developers across 4 workstreams  

## 📊 Issue Analysis Summary

After configuration optimization, we reduced issues from **980 to 787** (20% reduction). The updated `.credo.exs` excludes high-noise, low-value rules:

- ✅ Disabled `AppendSingleItem` (~250 fewer issues)
- ✅ Disabled `NegatedIsNil` (~50 fewer issues)  
- ✅ Relaxed `AliasUsage` thresholds (~100 fewer issues)
- ✅ Increased `DuplicatedCode` thresholds

**Remaining patterns:**
- Alias alphabetical ordering
- Import/require/alias positioning
- Negated conditions in if-else blocks
- Variable rebinding
- Implicit try blocks
- Function nesting depth

## 🎯 Workstream Structure (Conflict-Free Design)

### **Workstream A: Pure Readability (No Logic Changes)**
**Target**: ~300 issues | **Risk**: Very Low | **Timeline**: 1-2 days

**Focus Areas:**
- Alias alphabetical ordering (`AliasOrder`)
- Import/require/alias positioning (`StrictModuleLayout`) 
- Line length violations (`MaxLineLength`)
- Parentheses cleanup (`ParenthesesOnZeroArityDefs`)
- Grouped alias expansion

**File Assignment Strategy:**
```
Team A1: lib/eve_dmv/analytics/* + lib/eve_dmv/contexts/battle_*
Team A2: lib/eve_dmv/contexts/character_* + lib/eve_dmv/contexts/combat_*  
Team A3: lib/eve_dmv/contexts/fleet_* + lib/eve_dmv/contexts/surveillance_*
Team A4: lib/eve_dmv_web/live/* + lib/eve_dmv_web/components/*
```

### **Workstream B: Logic Improvements (Safe Refactoring)**
**Target**: ~250 issues | **Risk**: Low-Medium | **Timeline**: 2-3 days

**Focus Areas:**
- Negated conditions (`NegatedConditionsWithElse`)
- Implicit try blocks (`PreferImplicitTry`)
- Variable rebinding (`VariableRebinding`)
- With clause improvements (`WithClauses`)

**File Assignment Strategy:**
```
Team B1: lib/eve_dmv/shared/* (strategic, monitoring, intelligence)
Team B2: lib/eve_dmv/database/* + lib/eve_dmv/performance/*
Team B3: lib/eve_dmv/intelligence/* + lib/eve_dmv/workers/*
Team B4: lib/eve_dmv/contexts/wormhole_* + lib/eve_dmv/contexts/market_*
```

### **Workstream C: Complex Issues (Careful Refactoring)**  
**Target**: ~200 issues | **Risk**: Medium | **Timeline**: 3-4 days

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
**Target**: ~35 remaining issues | **Risk**: High | **Timeline**: 1 day (post A-C)

**Focus Areas:**
- Remaining alias usage optimization
- Final duplicate code resolution
- Complex nested module refactoring

## 📋 Detailed Workstream Assignments

### **Workstream A: Readability Fixes** (Teams A1-A4)

**Team A1 - Analytics & Battle Analysis:**
```
Files: 15-20 files
- lib/eve_dmv/analytics/character_comparison_service.ex
- lib/eve_dmv/contexts/battle_analysis/domain/battle_metrics_calculator.ex  
- lib/eve_dmv/contexts/battle_analysis/domain/enhanced_combat_log_parser.ex
- lib/eve_dmv/contexts/battle_analysis/domain/ship_performance_analyzer.ex
- lib/eve_dmv/contexts/battle_analysis/domain/tactical_*.ex

Tasks per file:
1. Fix alias alphabetical ordering
2. Move imports before requires  
3. Split grouped aliases: alias {A, B, C} → separate lines
4. Fix line length > 120 chars
5. Remove parentheses from zero-arity defs
```

**Team A2 - Character & Combat Intelligence:**
```
Files: 20-25 files  
- lib/eve_dmv/contexts/character_intelligence/domain/threat_scoring/*
- lib/eve_dmv/contexts/combat_analysis/domain/*
- lib/eve_dmv/contexts/combat_intelligence/domain/*

Focus: Same readability tasks as A1, high concentration of alias issues
```

**Team A3 - Fleet & Surveillance:**
```
Files: 15-20 files
- lib/eve_dmv/contexts/fleet_operations/*
- lib/eve_dmv/contexts/surveillance/*
- lib/eve_dmv/contexts/wormhole_operations/*

Focus: Module layout and alias ordering fixes
```

**Team A4 - Web Interface:**
```
Files: 10-15 files
- lib/eve_dmv_web/live/*
- lib/eve_dmv_web/components/*

Focus: Line length and parentheses cleanup in LiveView modules
```

### **Workstream B: Logic Improvements** (Teams B1-B4)

**Team B1 - Shared Infrastructure:**
```
Files: 25-30 files
- lib/eve_dmv/shared/strategic/*
- lib/eve_dmv/shared/monitoring/*  
- lib/eve_dmv/shared/intelligence/*
- lib/eve_dmv/shared/correlation/*

Priority fixes:
1. Convert negated if-else to positive conditions
2. Replace explicit try-rescue with implicit try
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
Files: 10-15 files
- lib/eve_dmv/contexts/wormhole_operations/*
- lib/eve_dmv/contexts/market_intelligence/*
- lib/eve_dmv/contexts/killmail_processing/*

Focus: Business logic improvements and error handling
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

### **Branch Strategy**
```
main
├── workstream/a-readability
├── workstream/b-logic-improvements  
├── workstream/c-complex-refactoring
└── workstream/d-final-cleanup

Each team member works on: workstream/X-teamY-DEVELOPER_NAME
```

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

#### Implicit Try Conversion:
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

#### Team A (Readability):
```bash
# Check your assigned files only
mix credo lib/eve_dmv/analytics/* --format=oneline | grep -E "(AliasOrder|StrictModuleLayout|MaxLineLength)"

# After fixing aliases in a file  
mix compile --warnings-as-errors  # Must pass!
grep -n "alias.*{" your_file.ex    # Should return nothing
```

#### Team B (Logic):
```bash
# Check logic improvements
mix credo lib/eve_dmv/shared/* --format=oneline | grep -E "(NegatedConditions|PreferImplicitTry|VariableRebinding)"

# After logic fixes
mix test test/path/to/related/tests/  # Must pass!
```

#### Team C (Complex):
```bash
# Check complexity improvements  
mix credo lib/eve_dmv/contexts/intelligence_infrastructure/* --format=oneline | grep -E "(Nesting|DuplicatedCode)"

# After refactoring
mix test --cover --only unit  # Coverage should not decrease
```

## 📈 Success Metrics & Timeline

### **Daily Targets:**
- **Day 1**: Workstream A completes readability fixes (~300 issues)
- **Day 2-3**: Workstream B completes logic improvements (~250 issues)  
- **Day 4-5**: Workstream C completes complex refactoring (~200 issues)
- **Day 6**: Workstream D handles remaining edge cases (~37 issues)

### **Quality Gates:**
- ✅ **Zero compile warnings** at all times
- ✅ **Zero test regressions** 
- ✅ **50+ issues resolved per team per day**
- ✅ **Individual file commits** (no multi-file commits)
- ✅ **Daily progress reports** with issue count reduction

### **Progress Tracking:**
```bash
# Daily team lead check
mix credo --strict | tail -5
# Target progression:
# Day 1: ~487 issues (300 reduction)
# Day 3: ~237 issues (250 more reduction)  
# Day 5: ~37 issues (200 more reduction)
# Day 6: <10 issues (final cleanup)
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
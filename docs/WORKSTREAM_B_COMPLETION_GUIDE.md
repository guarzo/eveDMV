# Workstream B: Logic Improvements - Completion Guide

**Status**: **30% COMPLETE** - Need focused execution  
**Progress**: 83 issues resolved (620→537), but 347 Workstream B issues remain  
**Updated Timeline**: 3-4 more days needed with proper team coordination  

## 📊 Current Workstream B Status Analysis

### ✅ **Successfully Completed:**
- **Alias/require positioning**: DONE (0 issues remaining)
- **Partial implicit try conversions**: 20 completed (visible in system reminders)

### ❌ **Major Work Remaining (347 issues):**
- **🔴 78 implicit try issues** (target was 98, 20% done)
- **🔴 174 negated condition issues** (0% progress visible)
- **🔴 91 variable rebinding issues** (0% progress visible)  
- **🟡 4 with clause issues** (minor scope)

## 🎯 **Revised Team Assignments & Priorities**

### **Priority 1: Implicit Try Conversions (78 remaining)**

#### **Team B1: Combat Analysis Implicit Try** (2 developers, high-impact area)
**Target**: 25-30 implicit try issues in combat analysis modules

**Specific files needing conversion**:
```bash
# Find remaining combat analysis implicit try issues:
mix credo lib/eve_dmv/contexts/combat_analysis/* --format=oneline | grep "implicit.*try"
mix credo lib/eve_dmv/contexts/battle_* --format=oneline | grep "implicit.*try"

# Priority files (visible in recent output):
- lib/eve_dmv/contexts/battle_sharing.ex (3 issues: lines 274, 362, 394)
- lib/eve_dmv/contexts/combat_analysis/domain/fleet_analysis_engine.ex (3+ issues: lines 152, 189, 222)
- lib/eve_dmv/contexts/combat_analysis/domain/battle_detection_service.ex
```

#### **Team B2: Shared Infrastructure Implicit Try** (2 developers)
**Target**: 25-30 implicit try issues in shared modules

**Focus areas**:
```bash
# Find remaining shared infrastructure implicit try issues:
mix credo lib/eve_dmv/shared/* --format=oneline | grep "implicit.*try"
mix credo lib/eve_dmv/database/* --format=oneline | grep "implicit.*try"
mix credo lib/eve_dmv/intelligence/* --format=oneline | grep "implicit.*try"
```

#### **Team B3: Context Modules Implicit Try** (1 developer)
**Target**: Remaining 20-25 implicit try issues

**Focus areas**:
```bash
# Find remaining context module implicit try issues:
mix credo lib/eve_dmv/contexts/threat_* --format=oneline | grep "implicit.*try"
mix credo lib/eve_dmv/contexts/surveillance/* --format=oneline | grep "implicit.*try"
mix credo lib/eve_dmv/contexts/wormhole_* --format=oneline | grep "implicit.*try"
```

### **Priority 2: Negated Conditions (174 remaining)**

#### **Team B4: Negated Conditions - High Volume** (2 developers)
**Target**: 50-60 negated condition fixes per day

**Pattern to fix**:
```elixir
# Before (negated condition):
if !is_nil(data) do
  process(data)
else
  handle_nil()
end

# After (positive condition):
if is_nil(data) do
  handle_nil()
else
  process(data)
end
```

**Find files**:
```bash
# Find negated condition issues:
mix credo --strict --format=oneline | grep "negated.*if-else" | head -20
```

### **Priority 3: Variable Rebinding (91 remaining)**

#### **Team B5: Variable Rebinding** (1 developer)
**Target**: 15-20 variable rebinding fixes per day

**Pattern to fix**:
```elixir
# Before (variable rebinding):
def process_data(input) do
  data = transform_input(input)
  data = add_metadata(data)
  data = validate_data(data)
  data
end

# After (pipeline or different names):
def process_data(input) do
  input
  |> transform_input()
  |> add_metadata()
  |> validate_data()
end

# Or with different variable names:
def process_data(input) do
  transformed_data = transform_input(input)
  enriched_data = add_metadata(transformed_data)
  validated_data = validate_data(enriched_data)
  validated_data
end
```

## 🛠️ **Critical Implementation Guidelines**

### **For Implicit Try Conversions (MOST IMPORTANT):**

#### ✅ **Safe to Convert** (entire function body is try-rescue):
```elixir
# Before:
def process_data(data) do
  try do
    risky_operation(data)
    more_processing()
    final_result()
  rescue
    error -> handle_error(error)
  end
end

# After:
def process_data(data) do
  risky_operation(data)
  more_processing()
  final_result()
rescue
  error -> handle_error(error)
end
```

#### ❌ **DO NOT Convert** (try block is not entire function):
```elixir
# DO NOT CONVERT this pattern:
def process_data(data) do
  setup_operation()
  
  result = try do
    risky_operation(data)
  rescue
    error -> handle_error(error)
  end
  
  cleanup_operation()
  result
end
# This should stay as explicit try!
```

#### **Validation Process for Each Implicit Try Conversion:**
1. **Verify entire function body**: Only convert if try block is 95%+ of function
2. **Preserve rescue clauses exactly**: Don't change error handling logic
3. **Test compilation**: `mix compile --warnings-as-errors` must pass
4. **Test functionality**: Run relevant tests to ensure error handling works

### **For Negated Conditions:**

#### **Safe Patterns to Convert:**
```elixir
# Simple negation:
if !condition do -> if condition do (swap blocks)
unless condition do -> if condition do (remove unless)
if !is_nil(x) do -> if is_nil(x) do (swap blocks)
```

#### **DO NOT Convert Complex Negations:**
```elixir
# Keep these as-is (complex logic):
if !(complex_condition && other_condition) do
if !Enum.any?(list, &complex_predicate/1) do
```

## ⚡ **Accelerated Workflow for Teams**

### **Daily Team Targets:**
- **Team B1-B3** (Implicit Try): 10-12 conversions per developer per day
- **Team B4** (Negated Conditions): 25-30 fixes per developer per day  
- **Team B5** (Variable Rebinding): 15-20 fixes per developer per day

### **File-by-File Process (15-20 minutes per file):**

#### **1. Pre-work (5 minutes):**
```bash
# Get your assigned file list:
mix credo lib/your/assigned/path/* --format=oneline | grep "your_issue_type"

# Pick next file and check issues:
mix credo path/to/specific/file.ex --format=oneline
```

#### **2. Fix issues (10 minutes):**
- **Implicit try**: Check entire function scope before converting
- **Negated conditions**: Simple pattern swaps  
- **Variable rebinding**: Consider pipeline vs. different names

#### **3. Validation (5 minutes):**
```bash
# MANDATORY safety checks:
mix compile --warnings-as-errors  # Must pass
mix test test/path/to/related/test.exs  # Must pass
mix credo path/to/file.ex --format=oneline | grep "your_issue_type" # Should show fewer issues
```

#### **4. Commit immediately:**
```bash
git add path/to/file.ex
git commit -m "fix(credo): resolve logic issues in $(basename path/to/file.ex)

- Convert explicit try to implicit try (X issues)
- Fix negated conditions (Y issues)  
- Resolve variable rebinding (Z issues)"
```

## 🚨 **Enhanced Safety Protocols**

### **For Implicit Try Conversions (High Risk):**
```bash
# BEFORE touching any function with try-rescue:
# 1. Read the ENTIRE function
# 2. Verify try block is 95%+ of function body
# 3. Check there's no logic before/after try block
# 4. If unsure, SKIP the file and ask team lead

# AFTER conversion:
# 1. Run specific test for that module
# 2. Check error handling still works correctly
# 3. If compilation fails, IMMEDIATELY revert
```

### **If Compilation Fails:**
```bash
# 1. IMMEDIATE revert:
git checkout HEAD~1 -- path/to/file.ex
mix compile --warnings-as-errors  # Verify fix

# 2. Report issue to team lead
# 3. Skip that file, move to next
# 4. Do NOT attempt complex debugging
```

### **Daily Progress Tracking:**
```bash
# Morning check - team leads run:
echo "Implicit try remaining: $(mix credo --strict --format=oneline | grep 'implicit.*try' | wc -l)"
echo "Negated conditions remaining: $(mix credo --strict --format=oneline | grep 'negated.*if-else' | wc -l)"  
echo "Variable rebinding remaining: $(mix credo --strict --format=oneline | grep 'Variable.*declared.*more.*once' | wc -l)"

# Target daily reductions:
# - Implicit try: -25 per day (3 days to complete)
# - Negated conditions: -60 per day (3 days to complete)  
# - Variable rebinding: -30 per day (3 days to complete)
```

## 📈 **Success Metrics & Timeline**

### **3-Day Sprint Plan:**
- **Day 1**: 
  - Implicit try: 78→53 (25 conversions)
  - Negated conditions: 174→114 (60 fixes)
  - Variable rebinding: 91→61 (30 fixes)
- **Day 2**:
  - Implicit try: 53→28 (25 conversions)  
  - Negated conditions: 114→54 (60 fixes)
  - Variable rebinding: 61→31 (30 fixes)
- **Day 3**:
  - Implicit try: 28→0 (28 conversions)
  - Negated conditions: 54→0 (54 fixes)  
  - Variable rebinding: 31→0 (31 fixes)

### **Quality Gates:**
- ✅ **Zero compilation failures** (most critical for implicit try)
- ✅ **Zero test regressions** (especially error handling tests)
- ✅ **No complex conversions** (skip ambiguous cases)
- ✅ **Team lead review** for first 3 implicit try conversions per developer

### **Final Validation Commands:**
```bash
# Target: All Workstream B issues resolved
mix credo --strict --format=oneline | grep -E "(implicit.*try|negated.*if-else|Variable.*declared.*more.*once)" | wc -l
# Should show: 0

# Overall progress check:
mix credo --strict | tail -5
# Target: ~190 total issues (from current 537)
```

## 🔧 **Quick Reference Commands**

```bash
# Find all Workstream B issues:
mix credo --strict --format=oneline | grep -E "(implicit.*try|negated.*if-else|Variable.*declared.*more.*once|with.*clause)"

# Count by type:
echo "Implicit try: $(mix credo --strict --format=oneline | grep 'implicit.*try' | wc -l)"
echo "Negated conditions: $(mix credo --strict --format=oneline | grep 'negated.*if-else' | wc -l)"
echo "Variable rebinding: $(mix credo --strict --format=oneline | grep 'Variable.*declared.*more.*once' | wc -l)"

# Find files for specific teams:
mix credo lib/eve_dmv/contexts/combat_analysis/* --format=oneline | grep "implicit.*try"  # Team B1
mix credo lib/eve_dmv/shared/* --format=oneline | grep "implicit.*try"  # Team B2
mix credo --strict --format=oneline | grep "negated.*if-else" | head -20  # Team B4
```

---

**Key Message**: Workstream B has made minimal progress on core scope. The team needs focused coordination and proper tooling to tackle the 347 remaining logic improvement issues efficiently. Implicit try conversions require special care due to compilation risks.
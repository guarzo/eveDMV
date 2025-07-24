# Sprint 30: Compilation-Only Focus - Zero Tolerance

- **Duration**: 1 week (7 days)
- **Start Date**: 2025-10-11
- **End Date**: 2025-10-17
- **Sprint Goal**: ONLY fix compilation - 1 error + 139 warnings = 140 issues to zero

---

## 🎯 SINGLE OBJECTIVE

**ONE GOAL: Get to `mix compile --warnings-as-errors` SUCCESS**

- Current: 1 error, 139 warnings
- Target: 0 errors, 0 warnings
- Timeline: 7 days
- Focus: NOTHING ELSE - No Credo, no tests, no features

---

## ⚡ SIMPLIFIED APPROACH

### **NO MORE COMPLEX PLANS**
- No multi-phase strategies
- No Credo work
- No test fixes
- No documentation
- **ONLY COMPILATION**

### **SIMPLE RULES**
1. Fix the 1 error first (Day 1)
2. Fix warnings one at a time (Days 2-7)
3. Validate after EVERY change
4. Commit after EVERY successful fix

---

## 📋 CURRENT STATE

**THE ONE ERROR:**
```
undefined function timestamp/1 in EveDmv.Contexts.Surveillance.Infrastructure.MatchCache
```

**WARNING CATEGORIES:**
- Variable "no effect": ~60
- Unused variables: ~20
- Unused functions: ~20
- Unused imports: ~10
- Other: ~29

---

## 👥 SIMPLE WORKSTREAM ASSIGNMENTS

### **Day 1: Everyone Fixes THE ERROR**
**All hands on deck until error is fixed**
- Find MatchCache module
- Fix undefined function issue
- Ensure compilation succeeds

### **Days 2-7: Warning Assignments**

**Person A: Web Layer (35 warnings)**
- All files in `lib/eve_dmv_web/`
- Fix one file at a time
- ~6 warnings per day

**Person B: Contexts (35 warnings)**
- All files in `lib/eve_dmv/contexts/`
- Fix one file at a time
- ~6 warnings per day

**Person C: Database (35 warnings)**
- All files in `lib/eve_dmv/database/`
- All files in `lib/eve_dmv/killmails/`
- ~6 warnings per day

**Person D: Everything Else (34 warnings)**
- `lib/eve_dmv/intelligence/`
- `lib/eve_dmv/infrastructure/`
- `lib/mix/tasks/`
- Other files
- ~6 warnings per day

---

## 🔨 SIMPLE DAILY PROCESS

### **Every Morning (5 minutes):**
```bash
echo "Starting count: $(mix compile 2>&1 | grep -c 'warning:') warnings"
```

### **For Each Fix:**
```bash
# Before changing anything
mix compile 2>&1 | grep -c "warning:" > before.txt

# Make ONE fix in ONE file

# After the fix
mix compile 2>&1 | grep -c "warning:" > after.txt

# Check it worked
if [ $(cat after.txt) -lt $(cat before.txt) ]; then
  echo "✅ Good fix! Commit it."
  git add [file]
  git commit -m "fix: compilation warning in [file]"
else
  echo "❌ Bad fix! Revert it."
  git checkout -- [file]
fi
```

### **Every Evening (5 minutes):**
```bash
echo "Ending count: $(mix compile 2>&1 | grep -c 'warning:') warnings"
echo "Fixed today: $((starting_count - ending_count))"
```

---

## 📊 SIMPLE TRACKING

### **Daily Status (One Line):**
```
Day 1: 1 error → 0 errors ✅
Day 2: 139 warnings → 115 warnings (24 fixed)
Day 3: 115 warnings → 90 warnings (25 fixed)
Day 4: 90 warnings → 65 warnings (25 fixed)
Day 5: 65 warnings → 40 warnings (25 fixed)
Day 6: 40 warnings → 20 warnings (20 fixed)
Day 7: 20 warnings → 0 warnings (20 fixed) 🎉
```

---

## 🚫 WHAT NOT TO DO

**DO NOT:**
- Try to fix multiple files at once
- Run any automated tools
- Worry about code style
- Refactor anything
- Add new features
- Fix tests
- Update documentation

**ONLY DO:**
- Fix compilation errors
- Fix compilation warnings
- Validate each fix
- Commit working fixes

---

## ✅ SUCCESS CRITERIA

**Sprint is complete when:**
```bash
mix compile --warnings-as-errors
# Returns exit code 0 with no output
```

**That's it. Nothing else.**

---

## 🆘 IF STUCK

**On the error (Day 1):**
1. Find where `timestamp/1` should be defined
2. Either define it or remove the call
3. Ask for help within 30 minutes if stuck

**On warnings:**
1. Pick the easiest warnings first (unused imports)
2. If a fix breaks something, revert immediately
3. Move to the next warning
4. Don't overthink it

---

## 📝 EXAMPLE FIXES

**Unused import:**
```elixir
# Before
import Ecto.Query  # warning: unused import

# After
# Just delete the line
```

**Variable no effect:**
```elixir
# Before
result = some_function()  # warning: no effect

# After
_result = some_function()  # prefix with underscore
```

**Unused variable:**
```elixir
# Before
def foo(bar) do  # warning: bar is unused

# After
def foo(_bar) do  # prefix with underscore
```

---

## 🎯 FINAL REMINDER

**This sprint is about DISCIPLINE, not complexity.**

- One fix at a time
- Validate every change
- Commit working fixes
- No side quests
- No overthinking
- Just fix compilation

**In 7 days, we should have a fully compiling codebase.**

---

_Sprint 30 strips away all complexity. One week, one goal: zero compilation issues. No distractions, no extra work, just systematic fixing with validation._
# Comprehensive Code Review Plan for EVE DMV

This document outlines a systematic approach to reviewing the EVE DMV codebase for quality, consistency, idiomatic Elixir patterns, and opportunities for simplification.

## Executive Summary

| Metric | Value |
|--------|-------|
| Source Files | 847 |
| Test Files | 58 |
| Bounded Contexts | 20 |
| Largest File | 2,644 lines (combat_doctrine_analyzer.ex) |
| Files > 1,000 lines | 30+ |
| Undocumented Modules | 22 (@moduledoc false) |

---

## Phase 1: Large File Analysis (High Priority)

### Objective
Identify files that have grown too large and should be refactored into smaller, focused modules.

### Files Requiring Immediate Review

#### Critical (> 2,000 lines)
| File | Lines | Concern |
|------|-------|---------|
| `contexts/corporation_intelligence/domain/combat_doctrine_analyzer.ex` | 2,644 | Massive analyzer - likely doing too much |
| `contexts/battle_analysis/domain/ship_performance_analyzer.ex` | 2,064 | May contain duplicated ship logic |
| `contexts/combat_intelligence/domain/phases/outcome_analyzer.ex` | 2,030 | Large phase module |

#### High (1,500-2,000 lines)
| File | Lines | Concern |
|------|-------|---------|
| `contexts/character_intelligence/analyzers/character_intelligence_analyzer.ex` | 1,894 | Core analyzer - check for extraction opportunities |
| `contexts/character_intelligence/domain/threat_scoring_engine.ex` | 1,791 | Complex scoring logic |
| `contexts/combat_intelligence/domain/battle_analyzer.ex` | 1,698 | Battle analysis core |
| `contexts/battle_analysis/domain/strategic/patterns/tactical_patterns.ex` | 1,560 | Pattern definitions |

#### Review Questions for Large Files
1. Can this be split into multiple focused modules?
2. Are there private functions that could be extracted to helper modules?
3. Is there duplicated logic between this file and others?
4. Are the module boundaries aligned with single responsibility?

---

## Phase 2: API Module Consistency Review

### Objective
Ensure all context API modules follow consistent patterns and appropriate sizes.

### API Module Size Analysis

| Context API | Lines | Assessment |
|-------------|-------|------------|
| `corporation_intelligence/api.ex` | 471 | **Too large** - consider splitting |
| `fleet_operations/api.ex` | 422 | **Too large** - consider splitting |
| `system_analysis/api.ex` | 420 | **Too large** - review responsibilities |
| `combat_intelligence/api.ex` | 393 | **Large** - evaluate |
| `killmail_processing/api.ex` | 356 | **Large** - evaluate |
| `surveillance/api.ex` | 340 | Acceptable |
| `market_intelligence/api.ex` | 232 | Acceptable |
| `threat_surveillance/api.ex` | 134 | Good |
| `corporation/api.ex` | 113 | Good |
| `intelligence/api.ex` | 102 | Good |
| `combat_analysis/api.ex` | 73 | Good |
| `combat/api.ex` | 64 | Good |
| `battle_analysis/api.ex` | 62 | Good |
| `intelligence_infrastructure/api.ex` | 41 | Good |
| `player_profile/api.ex` | 34 | Good |
| `corporation_analysis/api.ex` | 28 | Good |
| `threat_assessment/api.ex` | 26 | Good |

### Review Checklist for API Modules
- [ ] Does the API only expose public interface functions?
- [ ] Is business logic delegated to domain modules?
- [ ] Are there functions that should be private or moved?
- [ ] Is the documentation complete and accurate?
- [ ] Are typespec annotations present for all public functions?

---

## Phase 3: Duplicate/Overlapping Context Analysis

### Objective
Identify contexts with overlapping responsibilities that could be consolidated.

### Potentially Overlapping Contexts

#### Combat-Related (5 contexts)
```
contexts/
├── combat/                    # Core combat logic
├── combat_analysis/           # Combat analysis
├── combat_intelligence/       # Combat intelligence
├── battle_analysis/           # Battle analysis
└── threat_assessment/         # Threat assessment
```

**Review Questions:**
1. What distinguishes `combat` from `combat_analysis`?
2. Is `combat_intelligence` just a combination of `combat` + `intelligence`?
3. Could `battle_analysis` be merged into `combat_analysis`?
4. Does `threat_assessment` overlap with `character_intelligence` threat scoring?

#### Corporation-Related (3 contexts)
```
contexts/
├── corporation/               # Core corporation logic
├── corporation_analysis/      # Corporation analysis
└── corporation_intelligence/  # Corporation intelligence
```

**Review Questions:**
1. Are these three contexts truly distinct domains?
2. Could `corporation_analysis` be a subdomain of `corporation`?

#### Intelligence-Related (4 contexts)
```
contexts/
├── intelligence/              # Core intelligence
├── intelligence_infrastructure/  # Infrastructure correlation
├── character_intelligence/    # Character-specific
└── combat_intelligence/       # Combat-specific
```

**Review Questions:**
1. Is there a clear hierarchy between these?
2. Are there shared intelligence utilities that could be consolidated?

---

## Phase 4: Non-Idiomatic Elixir Patterns

### Patterns to Search For

#### 4.1 Nested Case/With Statements
```bash
# Find deeply nested case/with statements
grep -r "case.*do\s*$" lib/ --include="*.ex" -A 20 | grep -E "^\s+case|^\s+with"
```

**Better Pattern:** Use `with` chains or extract to separate functions.

#### 4.2 Excessive Pattern Matching in Function Heads
Look for functions with many pattern-matched clauses that could use guards or be refactored.

#### 4.3 String Concatenation vs Interpolation
```bash
# Find string concatenation that should use interpolation
grep -r '<> "' lib/ --include="*.ex"
```

#### 4.4 Imperative vs Functional Style
Search for:
- Assignments followed by mutations (`variable = ...; variable = variable + ...`)
- `Enum.each` when `Enum.map` or `for` comprehensions are more appropriate
- Mutable state patterns outside of GenServers/Agents

#### 4.5 Error Handling Consistency
Check for consistent use of:
- `{:ok, result}` / `{:error, reason}` tuples
- `with` expressions for happy path
- Proper error propagation

#### 4.6 Pipe Operator Misuse
- Single-expression pipes (`value |> function()`)
- Overly long pipe chains (> 7-8 steps)
- Pipes broken by intermediate variable assignments

### Recommended Review Commands
```bash
# Find potential issues with map access
grep -r "\[:\w*\]" lib/ --include="*.ex" | grep -v "@" | head -50

# Find potential nil checks that could use pattern matching
grep -r "!= nil\|== nil" lib/ --include="*.ex"

# Find string building that might need iodata
grep -r "Enum.join\|<>" lib/ --include="*.ex" | head -30
```

---

## Phase 5: Documentation Quality Review

### 5.1 Undocumented Modules
22 modules have `@moduledoc false`. Review each:

```bash
grep -r "@moduledoc false" lib/ --include="*.ex" -l
```

**Decision Framework:**
- Public API modules: Must have documentation
- Internal helper modules: `@moduledoc false` is acceptable
- Domain logic modules: Should have documentation

### 5.2 Missing Function Documentation
Check for public functions without `@doc`:
```bash
# Find public functions without @doc
grep -rB2 "def \w" lib/ --include="*.ex" | grep -v "@doc\|defp\|defmodule"
```

### 5.3 Stale Documentation
Look for documentation that references:
- Non-existent modules or functions
- Outdated examples
- Incorrect return types

---

## Phase 6: Redundant/Unnecessary Comments

### Patterns to Remove

#### 6.1 Obvious Comments
```elixir
# BAD: Comment states the obvious
# Increment the counter
counter = counter + 1

# GOOD: No comment needed, code is self-explanatory
counter = counter + 1
```

#### 6.2 Dead/Commented Code
```bash
# Find commented-out code blocks
grep -r "# \s*def\|# \s*defp\|# \s*if\|# \s*case" lib/ --include="*.ex"
```

#### 6.3 Changelog Comments
```elixir
# BAD: Git handles this
# Modified by John on 2024-01-15 to fix bug #123

# GOOD: Use git blame instead
```

#### 6.4 Section Dividers
```elixir
# BAD: Unnecessary visual separators
# ================================
# Private Functions
# ================================
```

---

## Phase 7: Unnecessary Complexity

### 7.1 Over-Abstraction Indicators

**Check for:**
- Modules with only 1-2 public functions that wrap simple operations
- Deep inheritance/behavior chains
- Configuration that could be hardcoded
- Wrapper functions that add no value

### 7.2 Premature Optimization

**Look for:**
- Caching where it's not needed
- Complex data structures for simple data
- Pool/GenServer where simple function calls suffice

### 7.3 Dead Code Detection

```bash
# Find potentially unused modules
mix xref graph --format stats

# Find unreferenced functions
mix xref unreachable
```

### 7.4 Feature Flag Remnants
Check for feature flags or conditional code that's always enabled/disabled.

---

## Phase 8: Test Coverage Analysis

### Current State
- **Source Files:** 847
- **Test Files:** 58
- **Ratio:** ~7% test file coverage (should aim for 1:1 ratio on critical paths)

### Priority Areas for Test Review

| Area | Files | Test Priority |
|------|-------|---------------|
| contexts/combat_intelligence/ | 45 | Critical |
| contexts/battle_analysis/ | 48 | Critical |
| contexts/character_intelligence/ | 26 | High |
| contexts/surveillance/ | 27 | High |
| platform/database/ | ~30 | High |
| external/eve/ | ~20 | Medium |

### Test Quality Checklist
- [ ] Are edge cases covered?
- [ ] Are error paths tested?
- [ ] Are integration tests present for critical paths?
- [ ] Are there tests for the API modules?

---

## Phase 9: Specific Review Areas

### 9.1 LiveView Modules

**Files to Review:**
- `eve_dmv_web/live/surveillance_profiles_live.ex` (1,393 lines - **too large**)
- `eve_dmv_web/live/fleet_operations_live.ex` (1,289 lines - **too large**)
- `eve_dmv_web/live/battle_analysis_live.ex` (1,257 lines - **too large**)

**LiveView Best Practices Check:**
- [ ] Are event handlers extracted to separate modules?
- [ ] Is state management clean?
- [ ] Are components properly extracted?
- [ ] Is `assign_async` used appropriately?

### 9.2 Database Queries

**Review Points:**
- N+1 query patterns
- Missing indexes for common queries
- Overly complex raw SQL that could use Ecto
- Transaction boundaries

### 9.3 External API Integrations

**Modules:**
- `external/eve/` - ESI API client
- `external/killmails/` - SSE producer
- `external/market/` - Market APIs

**Review Points:**
- [ ] Circuit breaker patterns
- [ ] Retry logic
- [ ] Timeout handling
- [ ] Error logging

---

## Phase 10: Consistency Audit

### 10.1 Naming Conventions
- [ ] Module names follow Elixir conventions
- [ ] Function names are consistent across contexts
- [ ] Variable names are descriptive

### 10.2 File Organization
- [ ] Each context follows the same structure
- [ ] Helper modules are in consistent locations
- [ ] No orphaned files

### 10.3 Error Handling
- [ ] Consistent error tuple format
- [ ] Proper use of `with` expressions
- [ ] Error messages are informative

### 10.4 Logging
**Observation:** 491+ files use `require Logger`

**Check for:**
- Consistent log levels (debug, info, warn, error)
- Structured logging format
- Appropriate metadata

---

## Execution Plan

### Week 1: Foundation
1. Run `mix credo --strict` and address all issues
2. Run `mix dialyzer` and fix type errors
3. Review and fix the 30+ files over 1,000 lines

### Week 2: Context Review
1. Review the 5 combat-related contexts for overlap
2. Review the 3 corporation-related contexts
3. Consolidate or document distinctions

### Week 3: Code Quality
1. Hunt for non-idiomatic patterns
2. Remove unnecessary comments
3. Document undocumented public modules

### Week 4: Testing & Cleanup
1. Add tests for untested critical paths
2. Remove dead code
3. Final consistency pass

---

## Automated Tools

### Run Before Each Session
```bash
# Full quality check
./scripts/quality_check.sh

# Quick format and lint
mix format && mix credo --strict

# Type checking
mix dialyzer
```

### Useful One-Time Commands
```bash
# Find large functions (> 50 lines)
# Custom script needed

# Check for circular dependencies
mix xref graph --format cycles

# Find unused dependencies
mix deps.unlock --unused

# Security audit
mix deps.audit
```

---

## Success Criteria

After completing this review, the codebase should:

1. **No file exceeds 1,000 lines** (extract to multiple modules)
2. **All API modules under 300 lines** (delegate to domain modules)
3. **100% of public modules documented** (remove unnecessary @moduledoc false)
4. **Zero non-idiomatic patterns** (per Credo strict)
5. **Clear context boundaries** (no overlapping responsibilities)
6. **Consistent patterns** across all 20 contexts
7. **Test coverage > 70%** on critical paths

---

## Appendix A: File Inventory by Size

### Files > 1,000 Lines (Refactoring Candidates)

1. `combat_doctrine_analyzer.ex` - 2,644 lines
2. `ship_performance_analyzer.ex` - 2,064 lines
3. `outcome_analyzer.ex` - 2,030 lines
4. `character_intelligence_analyzer.ex` - 1,894 lines
5. `threat_scoring_engine.ex` - 1,791 lines
6. `battle_analyzer.ex` - 1,698 lines
7. `tactical_patterns.ex` - 1,560 lines
8. `composition_analyzer.ex` - 1,469 lines
9. `surveillance_profiles_live.ex` - 1,393 lines
10. `timeline_analyzer.ex` - 1,332 lines
11. `fleet_operations_live.ex` - 1,289 lines
12. `recruitment_service.ex` - 1,289 lines
13. `advanced_fleet_analyzer.ex` - 1,285 lines
14. `battle_analysis_live.ex` - 1,257 lines
15. `recommendation_engine.ex` - 1,254 lines
16. `combat_doctrine_analyzer.ex` (corporation/core) - 1,249 lines
17. `assessment_compiler.ex` - 1,225 lines
18. `participation_analyzer.ex` - 1,170 lines
19. `security_analyzer.ex` - 1,158 lines
20. `organizational_health_analyzer.ex` - 1,155 lines
21. `member_activity_analyzer.ex` - 1,149 lines
22. `threat_detector.ex` - 1,125 lines
23. `intelligence_correlator.ex` - 1,110 lines
24. `performance_calculator.ex` - 1,104 lines
25. `vulnerability_scanner.ex` - 1,096 lines
26. `character_comparison_service.ex` - 1,089 lines
27. `matching_engine.ex` - 1,044 lines
28. `performance_analyzer.ex` - 1,044 lines
29. `detection_service.ex` - 1,018 lines
30. `chain_intelligence.ex` - 1,015 lines

---

## Appendix B: Context Mapping

```
lib/eve_dmv/contexts/
├── battle_analysis/          (48 files) - Battle detection, timeline, ships
├── battle_sharing/           (5 files)  - Battle report sharing
├── character_intelligence/   (26 files) - Character threat scoring
├── combat/                   (20 files) - Core combat logic
├── combat_analysis/          (8 files)  - Combat analysis
├── combat_intelligence/      (45 files) - Combat intelligence
├── corporation/              (22 files) - Corporation core
├── corporation_analysis/     (8 files)  - Corporation analysis
├── corporation_intelligence/ (23 files) - Corporation intelligence
├── fleet_operations/         (31 files) - Fleet composition
├── intelligence/             (21 files) - Core intelligence engine
├── intelligence_infrastructure/ (16 files) - Regional analysis
├── killmail_processing/      (9 files)  - Killmail pipeline
├── market_intelligence/      (6 files)  - Market data
├── player_profile/           (6 files)  - Player profiles
├── surveillance/             (27 files) - Entity tracking
├── system_analysis/          (6 files)  - System analysis
├── threat_assessment/        (6 files)  - Threat scoring
└── threat_surveillance/      (8 files)  - Threat monitoring
```

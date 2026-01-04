# Phase 2: API Module Consistency Review

**Review Date:** 2026-01-04
**Reviewer:** Claude Code
**Status:** Complete

---

## Executive Summary

This document presents a comprehensive review of all context API modules in EVE DMV, evaluating them against the Phase 2 objectives from the Code Review Plan:

- ✅ **17 API modules reviewed**
- ⚠️ **4 modules exceed 300-line target** (need refactoring)
- ⚠️ **2 modules borderline** (need evaluation)
- ✅ **11 modules appropriately sized**

---

## API Module Inventory by Size

| Rank | Context | Lines | Assessment | Pattern Used |
|------|---------|-------|------------|--------------|
| 1 | `corporation_intelligence/api.ex` | 471 | 🔴 **Too Large** | Inline logic |
| 2 | `fleet_operations/api.ex` | 422 | 🔴 **Too Large** | Inline logic + validation |
| 3 | `system_analysis/api.ex` | 420 | 🔴 **Too Large** | Inline logic |
| 4 | `combat_intelligence/api.ex` | 393 | 🟠 **Large** | Delegation + validation |
| 5 | `killmail_processing/api.ex` | 356 | 🟠 **Large** | Delegation + validation |
| 6 | `surveillance/api.ex` | 340 | 🟡 Acceptable | Delegation + validation |
| 7 | `market_intelligence/api.ex` | 232 | 🟢 Good | Delegation + validation |
| 8 | `threat_surveillance/api.ex` | 134 | 🟢 Good | Pure `defdelegate` |
| 9 | `corporation/api.ex` | 113 | 🟢 Good | Pure `defdelegate` |
| 10 | `intelligence/api.ex` | 102 | 🟢 Good | Pure `defdelegate` |
| 11 | `combat_analysis/api.ex` | 73 | 🟢 Good | Mixed |
| 12 | `combat/api.ex` | 64 | 🟢 Good | `defdelegate` |
| 13 | `battle_analysis/api.ex` | 62 | 🟢 Good | Ash Domain |
| 14 | `intelligence_infrastructure/api.ex` | 41 | 🟢 Good | `defdelegate` |
| 15 | `player_profile/api.ex` | 34 | 🟢 Good | `defdelegate` |
| 16 | `corporation_analysis/api.ex` | 28 | 🟢 Good | `defdelegate` |
| 17 | `threat_assessment/api.ex` | 26 | 🟢 Good | Pure `defdelegate` |

---

## Detailed Analysis

### 🔴 Critical: Modules Requiring Immediate Refactoring

#### 1. `corporation_intelligence/api.ex` (471 lines)

**Location:** `lib/eve_dmv/contexts/corporation_intelligence/api.ex`

**Issues Found:**

| Issue | Severity | Description |
|-------|----------|-------------|
| Business logic in API | High | ~250 lines of helper functions belong in domain modules |
| Large private function block | High | Lines 218-471 contain extensive comparison/health logic |
| Mixed responsibilities | Medium | API module handles both orchestration AND computation |

**Specific Problems:**
- `generate_executive_summary/4` (lines 220-231): Builds data structures - move to domain
- `compare_member_counts/1`, `compare_activity_levels/1`, etc. (lines 233-285): Comparison logic - extract to `CorporationComparator` module
- `calculate_composite_score/1` (lines 301-321): Scoring algorithm - move to `PerformanceAnalyzer`
- `calculate_health_score/3` (lines 323-351): Health scoring - move to `HealthAssessor`
- `identify_strengths/3`, `identify_weaknesses/3` (lines 363-410): Assessment logic - extract to dedicated module
- `generate_recommendations/3` (lines 412-438): Recommendation engine - should be separate service

**Recommended Refactoring:**
```
corporation_intelligence/
├── api.ex                          # ~100 lines (delegation only)
├── domain/
│   ├── corporation_comparator.ex   # ~80 lines (comparison logic)
│   ├── health_assessor.ex          # ~100 lines (health scoring)
│   └── recommendation_engine.ex    # ~60 lines (recommendations)
```

---

#### 2. `fleet_operations/api.ex` (422 lines)

**Location:** `lib/eve_dmv/contexts/fleet_operations/api.ex`

**Issues Found:**

| Issue | Severity | Description |
|-------|----------|-------------|
| Excessive validation logic | High | ~170 lines of validation code in API module |
| Validation functions too detailed | Medium | Field-level validation should be in validators |

**Specific Problems:**
- `validate_fleet_data/1` (lines 251-258): Should delegate to `FleetValidator`
- `validate_engagement_data/1` (lines 260-268): Should delegate to `EngagementValidator`
- `validate_doctrine_data/1` (lines 270-279): Should delegate to `DoctrineValidator`
- `validate_participants/1`, `validate_participant_structure/1` (lines 299-321): Complex participant validation
- `validate_killmails/1`, `validate_killmail_structure/1` (lines 323-345): Killmail validation
- `validate_doctrine_name/1` (lines 347-357): Name validation rules
- `validate_ship_requirements/1` (lines 359-374): Ship requirement validation
- `validate_role_requirements/1` (lines 388-400): Role validation

**Recommended Refactoring:**
```
fleet_operations/
├── api.ex                          # ~150 lines (simplified)
├── validators/
│   ├── fleet_validator.ex          # Fleet data validation
│   ├── doctrine_validator.ex       # Doctrine validation
│   └── engagement_validator.ex     # Engagement validation
```

---

#### 3. `system_analysis/api.ex` (420 lines)

**Location:** `lib/eve_dmv/contexts/system_analysis/api.ex`

**Issues Found:**

| Issue | Severity | Description |
|-------|----------|-------------|
| Business logic in API | High | ~250 lines of analysis/aggregation logic |
| Risk assessment logic | High | `assess_combined_risk/3` and helpers are domain logic |
| Data transformation | Medium | Regional dashboard building should be in presenter/formatter |

**Specific Problems:**
- `build_timeframe/1` (lines 156-167): Utility function - move to `TimeframeUtils`
- `assess_combined_risk/3` (lines 169-201): Risk calculation - move to `RiskAssessor`
- `classify_combined_risk/1` (lines 203-210): Risk classification logic
- `identify_primary_risk/3` (lines 213-223): Risk identification
- `calculate_risk_confidence/3` (lines 225-240): Confidence calculation
- `generate_recommendations/3` (lines 242-289): Recommendations - move to `RecommendationEngine`
- `generate_regional_summary/2` (lines 291-307): Summary generation
- `rank_regional_hotspots/2` (lines 309-337): Ranking logic
- `analyze_network_effects/1` (lines 339-369): Network analysis
- `identify_propagation_patterns/1` (lines 372-401): Pattern identification
- `analyze_directional_patterns/1` (lines 403-416): Directional analysis

**Recommended Refactoring:**
```
system_analysis/
├── api.ex                          # ~100 lines (delegation only)
├── domain/
│   ├── risk_assessor.ex            # ~80 lines (risk logic)
│   ├── network_analyzer.ex         # ~100 lines (network effects)
│   └── regional_summarizer.ex      # ~60 lines (summary/ranking)
```

---

#### 4. `combat_intelligence/api.ex` (393 lines)

**Location:** `lib/eve_dmv/contexts/combat_intelligence/api.ex`

**Issues Found:**

| Issue | Severity | Description |
|-------|----------|-------------|
| Result transformation in API | Medium | ~50 lines of map transformations |
| Validation is appropriate | Low | Validation logic is reasonable for API boundary |

**Specific Problems:**
- `analyze_character/2` (lines 71-99): Contains result transformation that could be in analyzer
- `get_character_intelligence/1` (lines 107-134): Duplicate transformation logic
- `analyze_corporation/2` (lines 142-162): Similar transformation pattern
- `get_corporation_intelligence/1` (lines 167-184): Duplicate transformation

**Recommendation:** Extract `IntelligenceResultFormatter` to handle transformations. This is borderline - could remain as-is, but extraction would improve maintainability.

---

### 🟠 Borderline: Modules Needing Evaluation

#### 5. `killmail_processing/api.ex` (356 lines)

**Assessment:** Slightly over 300-line target but reasonably structured.

**What's Good:**
- Clear separation between public API and validation
- Good use of `with` expressions
- Proper error handling

**Minor Issues:**
- `format_for_display/1` (lines 335-354): Display formatting could be in presenter module
- Validation functions (lines 276-331): Could be extracted to `KillmailValidator`

**Recommendation:** Consider extracting validation to a dedicated module, but not critical.

---

#### 6. `surveillance/api.ex` (340 lines)

**Assessment:** Just over 300-line target but well-organized.

**What's Good:**
- Proper delegation to domain modules
- Clean validation separation
- Good documentation

**Minor Issues:**
- Validation functions (lines 250-339): Could be extracted

**Recommendation:** Acceptable as-is. Could extract validators if module grows further.

---

### 🟢 Well-Structured: Examples to Follow

#### `threat_surveillance/api.ex` (134 lines) - **Best Practice Example**

This module demonstrates the ideal API pattern:

```elixir
defmodule EveDmv.Contexts.ThreatSurveillance.Api do
  @moduledoc """API for unified Threat Surveillance context."""

  alias EveDmv.Contexts.ThreatSurveillance

  @doc """Assess threat level for a character."""
  defdelegate assess_character_threat(character_id, options \\ []), to: ThreatSurveillance

  # ... pure delegation with documentation
end
```

**Why it's good:**
- Pure `defdelegate` pattern
- No business logic
- Clean documentation
- Single responsibility

---

#### `corporation/api.ex` (113 lines) - **Good Organization**

Well-organized delegation with clear sections:
- Corporation Analysis
- Member Activity Analysis
- Member Risk Assessment
- Participation Analysis
- Recruitment Analysis
- Combat Doctrine Analysis
- Organizational Health
- Services (CRUD)
- Batch Operations
- Cache Management
- Real-time Updates

---

#### `intelligence/api.ex` (102 lines) - **Good Organization**

Similar clean organization pattern with logical groupings.

---

#### `threat_assessment/api.ex` (26 lines) - **Minimal & Focused**

The smallest API - demonstrates that APIs should be thin:
```elixir
defmodule EveDmv.Contexts.ThreatAssessment.Api do
  alias EveDmv.Contexts.ThreatAssessment.Analyzers.ThreatAnalyzer
  alias EveDmv.Contexts.ThreatAssessment.Analyzers.VulnerabilityScanner

  defdelegate analyze_character_threat(character_id, base_data \\ %{}, opts \\ []),
    to: ThreatAnalyzer, as: :analyze
  # ...
end
```

---

## Pattern Comparison

### Pattern 1: Pure Delegation (Recommended) ✅

Used by: `threat_surveillance`, `corporation`, `intelligence`, `threat_assessment`

```elixir
defdelegate function_name(args), to: DomainModule
```

**Pros:**
- Zero business logic in API
- Single source of truth
- Easy to maintain
- Clear boundaries

---

### Pattern 2: Delegation with Validation (Acceptable) ⚠️

Used by: `combat_intelligence`, `killmail_processing`, `surveillance`, `market_intelligence`

```elixir
def function_name(args) do
  with :ok <- validate_args(args),
       {:ok, result} <- DomainModule.function(args) do
    {:ok, result}
  end
end
```

**Pros:**
- Input validation at boundary
- Consistent error handling

**Cons:**
- Validation can grow large
- Should extract validators if > 50 lines

---

### Pattern 3: Inline Business Logic (Not Recommended) ❌

Used by: `corporation_intelligence`, `fleet_operations`, `system_analysis`

```elixir
def function_name(args) do
  # 50+ lines of business logic here
end

defp helper_function1(data) do
  # More business logic
end
```

**Cons:**
- Violates single responsibility
- Hard to test
- Duplicates logic
- API modules grow too large

---

## Checklist Results

### Does the API only expose public interface functions?

| Module | Pass | Notes |
|--------|------|-------|
| corporation_intelligence | ❌ | Contains ~250 lines of private helpers |
| fleet_operations | ❌ | Contains ~170 lines of validation logic |
| system_analysis | ❌ | Contains ~250 lines of analysis logic |
| combat_intelligence | ⚠️ | Contains transformation logic |
| killmail_processing | ⚠️ | Contains validation + formatting |
| surveillance | ⚠️ | Contains validation logic |
| market_intelligence | ✅ | Clean validation, minimal |
| threat_surveillance | ✅ | Pure delegation |
| corporation | ✅ | Pure delegation |
| intelligence | ✅ | Pure delegation |
| battle_analysis | ✅ | Ash Domain pattern |
| threat_assessment | ✅ | Pure delegation |

---

### Is business logic delegated to domain modules?

| Module | Pass | Issues |
|--------|------|--------|
| corporation_intelligence | ❌ | Health scoring, comparisons, recommendations in API |
| fleet_operations | ⚠️ | Validation only (acceptable) |
| system_analysis | ❌ | Risk assessment, network analysis in API |
| combat_intelligence | ⚠️ | Result transformation in API |
| killmail_processing | ✅ | Logic in domain services |
| surveillance | ✅ | Logic in MatchingEngine, NotificationService |
| Others | ✅ | Properly delegated |

---

### Are typespec annotations present for all public functions?

| Module | Coverage | Notes |
|--------|----------|-------|
| combat_intelligence | ✅ 100% | Full typespecs including custom types |
| killmail_processing | ✅ 100% | Full typespecs |
| market_intelligence | ✅ 100% | Full typespecs with custom types |
| surveillance | ❌ 0% | **Missing all typespecs** |
| fleet_operations | ❌ 0% | **Missing all typespecs** |
| corporation_intelligence | ✅ 100% | Full typespecs |
| system_analysis | ❌ 0% | **Missing all typespecs** |
| threat_surveillance | ❌ 0% | Missing (but uses defdelegate) |
| corporation | ❌ 0% | Missing (but uses defdelegate) |
| intelligence | ❌ 0% | Missing (but uses defdelegate) |

---

### Is documentation complete and accurate?

| Module | Quality | Notes |
|--------|---------|-------|
| combat_intelligence | ⭐⭐⭐⭐⭐ | Excellent - examples, options, types |
| killmail_processing | ⭐⭐⭐⭐⭐ | Excellent - examples, returns |
| fleet_operations | ⭐⭐⭐⭐ | Good - parameters, returns |
| market_intelligence | ⭐⭐⭐⭐ | Good - examples, types |
| surveillance | ⭐⭐⭐⭐ | Good - options, returns |
| corporation_intelligence | ⭐⭐⭐⭐ | Good - returns documented |
| system_analysis | ⭐⭐⭐ | Adequate - basic descriptions |
| threat_surveillance | ⭐⭐⭐ | Adequate - basic @doc per function |
| corporation | ⭐⭐ | Minimal - section comments only |
| intelligence | ⭐⭐ | Minimal - section comments only |
| threat_assessment | ⭐⭐ | Minimal - no descriptions |

---

## Recommendations

### Immediate Actions (Priority 1)

1. **Refactor `corporation_intelligence/api.ex`**
   - Extract health assessment logic to `HealthAssessor`
   - Extract comparison logic to `CorporationComparator`
   - Extract recommendation logic to `RecommendationEngine`
   - Target: ~100 lines

2. **Refactor `system_analysis/api.ex`**
   - Extract risk assessment to `RiskAssessor`
   - Extract network analysis to `NetworkAnalyzer`
   - Extract summarization to `RegionalSummarizer`
   - Target: ~100 lines

3. **Refactor `fleet_operations/api.ex`**
   - Extract validation to `FleetValidator`, `DoctrineValidator`
   - Keep only high-level input validation in API
   - Target: ~150 lines

### Short-term Actions (Priority 2)

4. **Add missing typespecs to:**
   - `surveillance/api.ex`
   - `fleet_operations/api.ex`
   - `system_analysis/api.ex`

5. **Improve documentation in:**
   - `corporation/api.ex` - Add function descriptions
   - `intelligence/api.ex` - Add function descriptions
   - `threat_assessment/api.ex` - Add function descriptions

### Long-term Actions (Priority 3)

6. **Standardize API patterns:**
   - All modules should follow `threat_surveillance` pattern where possible
   - Extract validators to dedicated modules when > 50 lines
   - Document return types for all delegated functions

7. **Add integration tests for all API modules**

---

## Metrics Summary

| Metric | Current | Target | Status |
|--------|---------|--------|--------|
| Modules under 300 lines | 11/17 (65%) | 17/17 (100%) | 🟡 Needs work |
| Modules with full typespecs | 4/17 (24%) | 17/17 (100%) | 🔴 Critical |
| Modules with good docs | 6/17 (35%) | 17/17 (100%) | 🟠 Needs work |
| Pure delegation pattern | 6/17 (35%) | 12/17 (70%) | 🟡 Acceptable |

---

## Appendix: Recommended Module Structure

```
context_name/
├── api.ex                          # Public interface (< 150 lines ideal, < 300 max)
│   ├── @moduledoc with overview
│   ├── Type definitions (if needed)
│   ├── defdelegate calls (preferred)
│   ├── OR: with validation -> delegation pattern
│   └── NO private business logic functions
│
├── domain/                         # Business logic
│   ├── analyzer.ex                 # Analysis algorithms
│   ├── calculator.ex               # Calculations
│   └── service.ex                  # Orchestration
│
├── validators/                     # Input validation (if extracted)
│   └── input_validator.ex
│
└── infrastructure/                 # External concerns
    └── repository.ex
```

---

*Generated as part of EVE DMV Code Review - Phase 2*

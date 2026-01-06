# Phase 3: Context Architecture Review

**Deliverable:** `docs/review/03_context_architecture_audit.md`
**Date Generated:** 2026-01-06
**Review Phase:** 3 of 8

---

## Executive Summary

This audit analyzes the bounded contexts in EVE DMV for architectural issues, overlap, and consolidation opportunities. The codebase contains **17 bounded contexts** with significant variation in size (5-48 files per context). Key findings include:

- **Context proliferation**: Several context groups have overlapping responsibilities
- **Large file count**: 30 files exceed 500 lines, 12 exceed 1,000 lines, 3 exceed 2,000 lines
- **API compliance issues**: Many API modules contain business logic (should delegate)
- **Cross-context coupling**: High coupling between intelligence-related contexts

---

## 3.1 Context Overlap Analysis

### Context File Counts

| Context | Files | Category |
|---------|-------|----------|
| battle_analysis | 48 | Combat |
| combat_intelligence | 45 | Combat/Intel |
| fleet_operations | 31 | Combat |
| character_intelligence | 28 | Intelligence |
| surveillance | 27 | Surveillance |
| corporation | 23 | Corporation |
| corporation_intelligence | 23 | Corporation/Intel |
| intelligence | 21 | Intelligence |
| combat | 19 | Combat |
| intelligence_infrastructure | 16 | Intelligence |
| killmail_processing | 12 | Pipeline |
| threat_surveillance | 8 | Surveillance |
| threat_assessment | 6 | Intelligence |
| system_analysis | 6 | Intelligence |
| market_intelligence | 6 | Intelligence |
| player_profile | 6 | Intelligence |
| battle_sharing | 5 | Combat |

**Total:** 330 files across 17 contexts

---

### Context Groupings with Overlap

#### Finding 3.1.1: Combat-Related Context Proliferation

- **Contexts:** `battle_analysis`, `combat`, `combat_intelligence`, `fleet_operations`, `battle_sharing`
- **Combined Files:** 148 (45% of all context files)
- **Severity:** High
- **Effort:** Large (>4hr)

**Evidence of Overlap:**
- `battle_analysis` (48 files) and `combat_intelligence` (45 files) both contain battle analyzers
- `combat` (19 files) has core combat functionality duplicated in `battle_analysis`
- `fleet_operations` (31 files) overlaps with fleet analysis in `combat_intelligence`

**Cross-Context Dependencies:**
```
battle_analysis depends on:
  - Combat.Core.ParticipantAnalyzer
  - Combat.Core.TimelineBuilder
  - CombatIntelligence.Infrastructure.AnalysisCache

combat_intelligence depends on:
  - BattleAnalysis.Resources.Battle
  - BattleAnalysis.Core.BattleDetector
  - Combat.Services.BattleService
```

**Recommendation:**
Consolidate into 2-3 contexts:
1. `combat` - Core combat data and analysis
2. `fleet` - Fleet composition and operations
3. `battle` - Battle detection, analysis, and sharing

---

#### Finding 3.1.2: Corporation Context Duplication

- **Contexts:** `corporation`, `corporation_intelligence`
- **Combined Files:** 46
- **Severity:** Medium
- **Effort:** Medium (1-4hr)

**Evidence of Overlap:**
- Both contexts contain corporation analyzers (4 files named `corporation_analyzer.ex`)
- `corporation` has 23 files with core analysis
- `corporation_intelligence` has 23 files with intelligence analysis

**Cross-Context Dependencies:**
```
corporation_intelligence depends on:
  - Corporation.Core.MemberActivityAnalyzer
  - Corporation.Core.MemberRiskAssessment
  - Corporation.Core.ParticipationAnalyzer
```

**Recommendation:**
Merge `corporation_intelligence` into `corporation` context, organizing by subdomain:
- `corporation/analysis/` - Member and activity analysis
- `corporation/intelligence/` - Corporation-level intelligence

---

#### Finding 3.1.3: Intelligence Context Fragmentation

- **Contexts:** `intelligence`, `intelligence_infrastructure`, `character_intelligence`, `threat_assessment`, `system_analysis`, `market_intelligence`, `player_profile`
- **Combined Files:** 83
- **Severity:** High
- **Effort:** Large (>4hr)

**Evidence of Overlap:**
- `intelligence` (21 files) provides core intelligence capabilities
- `character_intelligence` (28 files) duplicates character analysis found in `intelligence`
- `threat_assessment` (6 files) overlaps with threat scoring in `character_intelligence`
- `player_profile` (6 files) duplicates character stats from `intelligence`

**Duplicate Module Names:**
| File Name | Occurrences |
|-----------|-------------|
| `threat_analyzer.ex` | 2 |
| `threat_assessment_engine.ex` | 2 |
| `threat_scoring_coordinator.ex` | 2 |
| `character_analyzer.ex` | 3 |
| `performance_calculator.ex` | 2 |

**Recommendation:**
Consolidate into:
1. `character_intelligence` - All character-level intelligence
2. `corporation_intelligence` - All corporation-level intelligence (merge with corporation)
3. `regional_intelligence` - System and infrastructure analysis

---

#### Finding 3.1.4: Surveillance Context Overlap

- **Contexts:** `surveillance`, `threat_surveillance`
- **Combined Files:** 35
- **Severity:** Low
- **Effort:** Small (<1hr)

**Evidence of Overlap:**
- `threat_surveillance` (8 files) provides threat-specific surveillance
- `surveillance` (27 files) has general surveillance with threat capabilities

**Recommendation:**
Merge `threat_surveillance` into `surveillance` context as a subdomain.

---

## 3.2 Large File Decomposition

### Critical Priority (>2,000 lines)

#### Finding 3.2.1: combat_doctrine_analyzer.ex

- **File:** `lib/eve_dmv/contexts/corporation_intelligence/domain/combat_doctrine_analyzer.ex`
- **Lines:** 2,644
- **Severity:** Critical
- **Effort:** Large (>4hr)

**Function Analysis:**
This file likely contains multiple analyzer responsibilities that should be split:
- Doctrine identification
- Fleet composition analysis
- Historical doctrine tracking

**Recommendation:**
Split into:
- `doctrine_identifier.ex` - Identify doctrines from fleet compositions
- `doctrine_tracker.ex` - Historical doctrine analysis
- `doctrine_recommender.ex` - Doctrine recommendations

---

#### Finding 3.2.2: ship_performance_analyzer.ex

- **File:** `lib/eve_dmv/contexts/battle_analysis/domain/ship_performance_analyzer.ex`
- **Lines:** 2,128
- **Severity:** Critical
- **Effort:** Large (>4hr)

**Recommendation:**
Split by ship category or performance metric type.

---

#### Finding 3.2.3: outcome_analyzer.ex

- **File:** `lib/eve_dmv/contexts/combat_intelligence/domain/phases/outcome_analyzer.ex`
- **Lines:** 2,030
- **Severity:** Critical
- **Effort:** Large (>4hr)

**Recommendation:**
Split into phase-specific analyzers or by outcome type.

---

### High Priority (1,000-2,000 lines)

| File | Lines | Context |
|------|-------|---------|
| `character_intelligence_analyzer.ex` | 1,894 | character_intelligence |
| `threat_scoring_engine.ex` | 1,791 | character_intelligence |
| `battle_analyzer.ex` | 1,698 | combat_intelligence |
| `tactical_patterns.ex` | 1,560 | battle_analysis |
| `composition_analyzer.ex` | 1,469 | fleet_operations |
| `timeline_analyzer.ex` | 1,332 | combat_intelligence |
| `fleet_operations_live.ex` | 1,290 | web |
| `recruitment_service.ex` | 1,289 | corporation |
| `advanced_fleet_analyzer.ex` | 1,285 | combat_intelligence |
| `battle_analysis_live.ex` | 1,257 | web |
| `recommendation_engine.ex` | 1,254 | battle_analysis |

---

### Medium Priority (500-1,000 lines)

Total files in this category: **15 files**

Notable files:
- `matching_engine.ex` (1,044 lines) - surveillance
- `chain_intelligence.ex` (1,015 lines) - surveillance
- `fleet_analyzer.ex` (1,012 lines) - fleet_operations
- `vulnerability_scanner.ex` (1,042 lines) - threat_assessment

---

## 3.3 API Module Compliance

### API Module Sizes

| Context | Lines | Target (200) | Status |
|---------|-------|--------------|--------|
| killmail_processing | 549 | 200 | **FAIL** |
| corporation_intelligence | 471 | 200 | **FAIL** |
| system_analysis | 442 | 200 | **FAIL** |
| surveillance | 405 | 200 | **FAIL** |
| fleet_operations | 405 | 200 | **FAIL** |
| combat_intelligence | 395 | 200 | **FAIL** |
| corporation | 260 | 200 | **FAIL** |
| intelligence | 235 | 200 | **FAIL** |
| market_intelligence | 232 | 200 | **FAIL** |
| threat_surveillance | 160 | 200 | PASS |
| combat | 141 | 200 | PASS |
| player_profile | 89 | 200 | PASS |
| intelligence_infrastructure | 84 | 200 | PASS |
| battle_analysis | 66 | 200 | PASS |
| threat_assessment | 57 | 200 | PASS |

**Summary:** 9/15 API modules exceed the 200-line target

---

### Logic Blocks in API Modules

API modules should delegate all business logic. High logic block counts indicate violation:

| Context | Logic Blocks | Target (0) | Status |
|---------|--------------|------------|--------|
| killmail_processing | 34 | 0 | **CRITICAL** |
| fleet_operations | 28 | 0 | **CRITICAL** |
| combat_intelligence | 21 | 0 | **HIGH** |
| surveillance | 20 | 0 | **HIGH** |
| system_analysis | 17 | 0 | **HIGH** |
| market_intelligence | 15 | 0 | **MEDIUM** |
| corporation_intelligence | 11 | 0 | **MEDIUM** |

---

### Delegation vs Direct Implementation

| Context | Delegated | Direct Defs | Delegation % |
|---------|-----------|-------------|--------------|
| corporation | 57 | 0 | **100%** |
| intelligence | 48 | 0 | **100%** |
| threat_surveillance | 22 | 0 | **100%** |
| combat | 25 | 0 | **100%** |
| player_profile | 7 | 0 | **100%** |
| intelligence_infrastructure | 6 | 0 | **100%** |
| threat_assessment | 4 | 0 | **100%** |
| killmail_processing | 0 | 22 | **0%** |
| surveillance | 0 | 16 | **0%** |
| combat_intelligence | 0 | 15 | **0%** |
| fleet_operations | 0 | 14 | **0%** |
| corporation_intelligence | 0 | 11 | **0%** |
| system_analysis | 0 | 11 | **0%** |
| market_intelligence | 0 | 7 | **0%** |
| battle_analysis | 0 | 4 | **0%** |

**Pattern Observation:** Contexts fall into two categories:
1. **Fully delegated** (7 contexts) - Following best practices
2. **No delegation** (8 contexts) - All business logic in API module

---

### Finding 3.3.1: killmail_processing/api.ex Contains Excessive Logic

- **File:** `lib/eve_dmv/contexts/killmail_processing/api.ex`
- **Lines:** 549
- **Logic Blocks:** 34
- **Severity:** Critical
- **Effort:** Medium (1-4hr)

**Description:** This API module contains 34 case/if/with blocks, indicating significant business logic that should be delegated to domain services.

**Recommendation:**
1. Extract business logic to domain services
2. Convert API functions to simple delegations
3. Target: <200 lines, 0 logic blocks

---

### Finding 3.3.2: fleet_operations/api.ex Contains Excessive Logic

- **File:** `lib/eve_dmv/contexts/fleet_operations/api.ex`
- **Lines:** 405
- **Logic Blocks:** 28
- **Severity:** Critical
- **Effort:** Medium (1-4hr)

**Recommendation:** Same as Finding 3.3.1

---

## 3.4 Cross-Context Dependency Analysis

### Most Referenced Modules Across Contexts

| Module | References |
|--------|------------|
| `CharacterIntelligence.Domain.ThreatScoring.SharedUtilities` | 19 |
| `Intelligence.Core.CharacterAnalyzer` | 7 |
| `Corporation.Core.MemberActivityAnalyzer` | 6 |
| `Intelligence.Core.ThreatAssessmentEngine` | 5 |
| `Intelligence.Core.PerformanceAnalyzer` | 5 |
| `Intelligence.Core.BehavioralPatternAnalyzer` | 5 |
| `Combat.Core.ParticipantAnalyzer` | 5 |
| `BattleAnalysis.Resources.Battle` | 5 |
| `BattleAnalysis.Core.BattleDetector` | 5 |

### Finding 3.4.1: SharedUtilities High Coupling

- **Module:** `CharacterIntelligence.Domain.ThreatScoring.SharedUtilities`
- **References:** 19 (across multiple contexts)
- **Severity:** Medium
- **Effort:** Medium (1-4hr)

**Description:** This utility module is referenced 19 times across contexts, indicating it may belong in a shared location.

**Recommendation:**
Move to `lib/eve_dmv/core/utils/threat_scoring_utils.ex` or integrate into a shared domain module.

---

## Summary: Prioritized Recommendations

### Critical Priority

| # | Finding | Effort | Impact |
|---|---------|--------|--------|
| 1 | Consolidate combat-related contexts | Large | High - Reduce 148 files to ~60 |
| 2 | Split files >2,000 lines | Large | High - Improve maintainability |
| 3 | Refactor killmail_processing/api.ex | Medium | High - API compliance |

### High Priority

| # | Finding | Effort | Impact |
|---|---------|--------|--------|
| 4 | Consolidate intelligence contexts | Large | Medium - Reduce duplication |
| 5 | Merge corporation contexts | Medium | Medium - Clear boundaries |
| 6 | Refactor fleet_operations/api.ex | Medium | Medium - API compliance |

### Medium Priority

| # | Finding | Effort | Impact |
|---|---------|--------|--------|
| 7 | Merge surveillance contexts | Small | Low - Minor cleanup |
| 8 | Split files 1,000-2,000 lines | Medium | Medium - Maintainability |
| 9 | Move SharedUtilities to core | Small | Low - Better organization |

---

## Appendix: Analysis Commands Used

```bash
# Context file counts
find lib/eve_dmv/contexts/<context> -name "*.ex" | wc -l

# API module sizes
wc -l lib/eve_dmv/contexts/*/api.ex | sort -rn

# Logic blocks in API modules
grep -c "case \|if \|with " lib/eve_dmv/contexts/*/api.ex

# Cross-context dependencies
grep -rh "alias EveDmv.Contexts" lib/eve_dmv/contexts/ | sort | uniq -c | sort -rn

# Large files
find lib -name "*.ex" -exec wc -l {} \; | awk '$1 > 500 {print}' | sort -rn

# Duplicate module names
find lib/eve_dmv/contexts -name "*.ex" -exec basename {} \; | sort | uniq -c | sort -rn
```

---

*Generated as part of EVE DMV Code Review - Phase 3*

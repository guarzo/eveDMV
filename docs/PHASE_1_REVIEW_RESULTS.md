# Phase 1: Large File Analysis Review Results

**Date:** 2026-01-04
**Reviewer:** Claude Code
**Scope:** Files > 1,500 lines requiring refactoring consideration

---

## Executive Summary

| File | Lines | Recommendation | Priority |
|------|-------|----------------|----------|
| `combat_doctrine_analyzer.ex` | 2,644 | Split into 3-4 submodules | Critical |
| `ship_performance_analyzer.ex` | 2,064 | Extract helper modules | Critical |
| `outcome_analyzer.ex` | 2,030 | Good structure, extract utilities | Critical |
| `character_intelligence_analyzer.ex` | 1,894 | Already consolidated; keep as-is | Low |
| `threat_scoring_engine.ex` | 1,791 | Well-structured; minor extractions | Medium |
| `battle_analyzer.ex` | 1,698 | Good consolidation pattern | Low |
| `tactical_patterns.ex` | 1,560 | Extract pattern-specific modules | Medium |

---

## Detailed Analysis

### 1. CombatDoctrineAnalyzer (2,644 lines)

**Location:** `lib/eve_dmv/contexts/corporation_intelligence/domain/combat_doctrine_analyzer.ex`

**Current Responsibilities:**
- Doctrine recognition (shield kiting, armor brawling, EWAR, etc.)
- Fleet composition analysis
- Tactical pattern detection
- Doctrine evolution tracking
- Threat assessment and counter-strategy

**Review Assessment:**

| Question | Assessment |
|----------|------------|
| Can be split? | **Yes** - Already mentions submodules in @moduledoc but code is monolithic |
| Private function extraction? | **Yes** - Many private functions for each doctrine type |
| Duplicated logic? | **Possible** - Pattern matching logic similar to tactical_patterns.ex |
| Single responsibility? | **No** - Combines analysis, classification, and threat assessment |

**Recommended Refactoring:**

```
combat_doctrine_analyzer/
├── combat_doctrine_analyzer.ex      # Public API (< 200 lines)
├── fleet_analyzer.ex                # Fleet composition and engagement (~400 lines)
├── doctrine_classifier.ex           # Doctrine classification and scoring (~500 lines)
├── threat_assessor.ex               # Threat assessment and counter-strategy (~400 lines)
├── evolution_tracker.ex             # Doctrine evolution over time (~300 lines)
└── helpers/
    └── doctrine_patterns.ex         # @doctrine_patterns definitions (~150 lines)
```

**Priority:** Critical - Largest file, doing too much

---

### 2. ShipPerformanceAnalyzer (2,064 lines)

**Location:** `lib/eve_dmv/contexts/battle_analysis/domain/ship_performance_analyzer.ex`

**Current Responsibilities:**
- DPS efficiency analysis
- Survivability analysis
- Tactical contribution (EWAR, tackle, logistics)
- Role effectiveness evaluation
- Performance optimization suggestions

**Review Assessment:**

| Question | Assessment |
|----------|------------|
| Can be split? | **Yes** - Clear functional boundaries exist |
| Private function extraction? | **Yes** - extract_*, calculate_*, estimate_* functions |
| Duplicated logic? | **Yes** - Ship classification duplicates ShipTypes utility |
| Single responsibility? | **Partial** - Focused on ship performance but too many concerns |

**Recommended Refactoring:**

```
ship_performance_analyzer/
├── ship_performance_analyzer.ex     # Public API (~150 lines)
├── performance_calculator.ex        # DPS efficiency, metrics (~400 lines)
├── survivability_analyzer.ex        # Time alive, damage taken analysis (~350 lines)
├── tactical_contribution.ex         # EWAR, tackle, logistics contribution (~350 lines)
├── role_effectiveness.ex            # Role fulfillment scoring (~300 lines)
└── helpers/
    ├── ship_instance_extractor.ex   # create_victim_ship_instance, create_attacker_ship_instances (~200 lines)
    └── battle_context_builder.ex    # extract_battle_context, calculate_battle_intensity (~150 lines)
```

**Priority:** Critical - Many helper functions could be extracted

---

### 3. OutcomeAnalyzer (2,030 lines)

**Location:** `lib/eve_dmv/contexts/combat_intelligence/domain/phases/outcome_analyzer.ex`

**Current Responsibilities:**
- Victory factor analysis (primary/secondary)
- Numerical factors (fleet sizes, K/D ratios)
- Tactical factors (coordination, targeting, positioning)
- Post-battle metrics and recommendations

**Review Assessment:**

| Question | Assessment |
|----------|------------|
| Can be split? | **Yes** - Clear separation between factor types |
| Private function extraction? | **Yes** - add_*_factors helpers are repetitive |
| Duplicated logic? | **Moderate** - Similar pattern to other phase analyzers |
| Single responsibility? | **Partial** - Focused on outcomes but spans multiple dimensions |

**Recommended Refactoring:**

```
outcome_analyzer/
├── outcome_analyzer.ex              # Public API (~150 lines)
├── victory_factor_analyzer.ex       # Primary/secondary victory factors (~400 lines)
├── numerical_factor_analyzer.ex     # Fleet sizes, K/D, ISK efficiency (~350 lines)
├── tactical_factor_analyzer.ex      # Coordination, targeting, positioning (~350 lines)
├── recommendation_generator.ex      # generate_outcome_recommendations (~300 lines)
└── helpers/
    └── factor_builders.ex           # add_*_factors helper functions (~200 lines)
```

**Priority:** Critical - Clear extraction opportunities

---

### 4. CharacterIntelligenceAnalyzer (1,894 lines)

**Location:** `lib/eve_dmv/contexts/character_intelligence/analyzers/character_intelligence_analyzer.ex`

**Current Responsibilities:**
- Ship loadout analysis
- Weapon preference analysis
- Ship preference analysis
- Gang pattern analysis
- Activity stats analysis
- ISK efficiency analysis

**Review Assessment:**

| Question | Assessment |
|----------|------------|
| Can be split? | **No** - Already a consolidation of 6 smaller modules |
| Private function extraction? | **Minimal** - Most helpers are domain-specific |
| Duplicated logic? | **Low** - Uses shared KillmailQueries |
| Single responsibility? | **Yes** - All about character intelligence gathering |

**Current State:**
The @moduledoc explicitly states this is a consolidation of previously split modules:
- WeaponPreferenceAnalyzer
- ShipPreferenceAnalyzer
- GangPatternAnalyzer
- ActivityStatsAnalyzer
- IskEfficiencyAnalyzer
- IntelligenceSummaryAnalyzer

**Recommendation:** Keep as-is. This is a conscious design decision to consolidate related analysis functions. The module follows a consistent pattern with:
- Cache key generation
- QueryCache.get_or_compute wrapper
- SQL query execution
- Result transformation

**Priority:** Low - Intentional consolidation, well-structured

---

### 5. ThreatScoringEngine (1,791 lines)

**Location:** `lib/eve_dmv/contexts/character_intelligence/domain/threat_scoring_engine.ex`

**Current Responsibilities:**
- Multi-dimensional threat scoring (5 dimensions)
- Threat level comparison
- Threat trend analysis
- Context-aware scoring

**Review Assessment:**

| Question | Assessment |
|----------|------------|
| Can be split? | **Partial** - Each dimension could be its own module |
| Private function extraction? | **Yes** - Already uses SharedUtilities |
| Duplicated logic? | **Low** - Good use of ThreatConfig for constants |
| Single responsibility? | **Yes** - All threat scoring related |

**Current Structure Strengths:**
- Uses `SharedUtilities` for common operations
- Uses `ThreatConfig` for documented configuration constants
- Clear 5-dimension scoring model (combat_skill, ship_mastery, gang_effectiveness, unpredictability, recent_activity)

**Recommended Minor Refactoring:**

```
threat_scoring_engine/
├── threat_scoring_engine.ex         # Public API + orchestration (~300 lines)
├── dimensions/
│   ├── combat_skill_scorer.ex       # (~250 lines)
│   ├── ship_mastery_scorer.ex       # (~250 lines)
│   ├── gang_effectiveness_scorer.ex # (~250 lines)
│   ├── unpredictability_scorer.ex   # (~200 lines)
│   └── recent_activity_scorer.ex    # (~200 lines)
└── threat_config.ex                 # Already exists - good pattern
```

**Priority:** Medium - Works well but could benefit from dimension extraction

---

### 6. BattleAnalyzer (1,698 lines)

**Location:** `lib/eve_dmv/contexts/combat_intelligence/domain/battle_analyzer.ex`

**Current Responsibilities:**
- Fleet effectiveness analysis
- Target selection analysis
- Timing pattern analysis
- Formation analysis
- Battle phase analysis
- Ship classification

**Review Assessment:**

| Question | Assessment |
|----------|------------|
| Can be split? | **No** - Already consolidates specialized analyzers |
| Private function extraction? | **Minimal** - Uses DateTimeUtils, ShipTypes |
| Duplicated logic? | **Low** - Good abstraction of shared utilities |
| Single responsibility? | **Yes** - Consolidated battle analysis |

**Current State:**
The @moduledoc states this combines:
- FleetEffectivenessAnalyzer
- TargetSelectionAnalyzer
- TimingAnalyzer
- FormationAnalyzer
- BattlePhaseAnalyzer
- ShipClassificationAnalyzer

**Recommendation:** Keep as-is. This follows the same consolidation pattern as CharacterIntelligenceAnalyzer. The module provides a unified battle analysis API while internally organizing functions by concern.

**Priority:** Low - Good consolidation pattern

---

### 7. TacticalPatterns (1,560 lines)

**Location:** `lib/eve_dmv/contexts/battle_analysis/domain/strategic/patterns/tactical_patterns.ex`

**Current Responsibilities:**
- Chokepoint dominance detection
- Harassment campaign identification
- Reconnaissance operation detection
- Supply line disruption analysis
- Offensive preparation identification

**Review Assessment:**

| Question | Assessment |
|----------|------------|
| Can be split? | **Yes** - Each pattern type is independent |
| Private function extraction? | **Yes** - Many pattern-specific helpers |
| Duplicated logic? | **Possible** - Similar detection algorithms across patterns |
| Single responsibility? | **Partial** - All tactical patterns but 5 distinct concerns |

**Recommended Refactoring:**

```
tactical_patterns/
├── tactical_patterns.ex             # Public API + pattern registry (~200 lines)
├── patterns/
│   ├── chokepoint_pattern.ex        # Chokepoint dominance (~250 lines)
│   ├── harassment_pattern.ex        # Harassment campaigns (~250 lines)
│   ├── reconnaissance_pattern.ex    # Recon operations (~250 lines)
│   ├── supply_disruption_pattern.ex # Supply line attacks (~200 lines)
│   └── offensive_prep_pattern.ex    # Offensive preparation (~200 lines)
└── helpers/
    └── pattern_detection_utils.ex   # Shared detection algorithms (~150 lines)
```

**Priority:** Medium - Clear pattern-based extraction opportunities

---

## Cross-Cutting Observations

### Positive Patterns Found

1. **SharedUtilities Usage:** Multiple files correctly use `SharedUtilities` for common operations
2. **ThreatConfig Pattern:** Well-documented configuration constants with rationale
3. **DateTimeUtils/ShipTypes:** Good extraction of common utilities
4. **QueryCache Pattern:** Consistent caching approach across analyzers
5. **Intentional Consolidation:** Some large files are conscious consolidations, not accidental growth

### Areas of Concern

1. **Doctrine Pattern Duplication:** `combat_doctrine_analyzer.ex` and `tactical_patterns.ex` have overlapping pattern detection logic
2. **Ship Classification:** Multiple files implement ship classification; should use `ShipTypes` consistently
3. **Factor Builder Functions:** `outcome_analyzer.ex` has 10+ `add_*_factors` functions with similar structure
4. **Analyzer Proliferation:** Many *_analyzer.ex files with similar query-cache-transform patterns

### Recommended Shared Extractions

| Module | Purpose | Used By |
|--------|---------|---------|
| `PatternDetectionUtils` | Common detection algorithms | tactical_patterns, combat_doctrine_analyzer |
| `FactorAnalysisHelpers` | Factor building and scoring | outcome_analyzer, threat_scoring_engine |
| `PerformanceMetricsBuilder` | Common metric calculations | ship_performance_analyzer, battle_analyzer |

---

## Action Items

### Immediate (This Sprint)

1. [ ] Extract `combat_doctrine_analyzer.ex` into submodules (highest impact)
2. [ ] Create `PatternDetectionUtils` to reduce duplication
3. [ ] Extract `ship_instance_extractor.ex` from `ship_performance_analyzer.ex`

### Short-term (Next Sprint)

4. [ ] Extract `outcome_analyzer.ex` factor analyzers
5. [ ] Create dimension-specific scorers for `threat_scoring_engine.ex`
6. [ ] Extract `tactical_patterns.ex` into pattern-specific modules

### Validation

7. [ ] Do NOT split `character_intelligence_analyzer.ex` - intentional consolidation
8. [ ] Do NOT split `battle_analyzer.ex` - intentional consolidation
9. [ ] Document consolidation decisions in module @moduledocs

---

## Success Metrics

After refactoring:
- No file exceeds 1,000 lines
- Each module has single clear responsibility
- Shared utilities extracted and reused
- No duplicated pattern detection logic
- Consolidation decisions documented

---

## Appendix: Line Count Verification Commands

```bash
# Verify current line counts
wc -l lib/eve_dmv/contexts/corporation_intelligence/domain/combat_doctrine_analyzer.ex
wc -l lib/eve_dmv/contexts/battle_analysis/domain/ship_performance_analyzer.ex
wc -l lib/eve_dmv/contexts/combat_intelligence/domain/phases/outcome_analyzer.ex
wc -l lib/eve_dmv/contexts/character_intelligence/analyzers/character_intelligence_analyzer.ex
wc -l lib/eve_dmv/contexts/character_intelligence/domain/threat_scoring_engine.ex
wc -l lib/eve_dmv/contexts/combat_intelligence/domain/battle_analyzer.ex
wc -l lib/eve_dmv/contexts/battle_analysis/domain/strategic/patterns/tactical_patterns.ex
```

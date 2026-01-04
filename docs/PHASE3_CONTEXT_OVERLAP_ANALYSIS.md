# Phase 3: Duplicate/Overlapping Context Analysis

**Date:** January 2026
**Status:** Complete
**Analyst:** Code Review Automation

---

## Executive Summary

This analysis examines 12 potentially overlapping bounded contexts across three domain areas:
- **Combat-related:** 5 contexts
- **Corporation-related:** 3 contexts
- **Intelligence-related:** 4 contexts

### Key Findings

| Area | Contexts | Overlap Severity | Recommendation |
|------|----------|------------------|----------------|
| Combat | 5 | **High** | Consolidate to 2 contexts |
| Corporation | 3 | **Medium** | Consolidate to 2 contexts |
| Intelligence | 4 | **High** | Consolidate to 2 contexts |

**Total reduction potential:** 12 contexts → 6 contexts (50% reduction)

---

## 1. Combat-Related Contexts (5 Contexts)

### Current Structure

```
contexts/
├── combat/                    # 64 lines API - Battle operations
├── combat_analysis/           # 73 lines API - Unified combat analysis
├── combat_intelligence/       # 393 lines API - Combat intelligence
├── battle_analysis/           # 62 lines API - Ash Domain for resources
└── threat_assessment/         # 26 lines API - Threat/vulnerability analysis
```

### Detailed Analysis

#### 1.1 `combat/api.ex` (64 lines)

**Purpose:** Battle detection, analysis, timeline, participants, fleet composition

**Key Functions:**
- `detect_battles/2` - Battle detection from killmails
- `analyze_battle/1` - Battle analysis
- `build_battle_timeline/1` - Timeline construction
- `analyze_participants/1` - Participant analysis
- `analyze_composition/1` - Fleet composition
- `detect_patterns/2` - Tactical pattern detection
- `create_battle/1`, `get_battle/1`, `list_battles/1` - Battle CRUD

**Dependencies:** Delegates to modules in `BattleAnalysis.Core` and `Combat.Core`

#### 1.2 `combat_analysis/api.ex` (73 lines)

**Purpose:** Unified combat analysis facade

**Key Functions:**
- `analyze_battle/2` - Battle analysis (duplicates combat/api)
- `get_battle_timeline/1` - Timeline (duplicates combat/api)
- `analyze_fleet_composition/1` - Fleet composition (duplicates combat/api)
- `analyze_character_combat/2` - Character combat analysis
- `assess_threat/3` - Threat assessment
- `get_combat_intelligence/2` - Combat intelligence
- `create_battle_report/3`, `rate_battle_report/3` - Battle reports

**Overlap with:** `combat/api.ex` (battle analysis, timeline, fleet composition)

#### 1.3 `combat_intelligence/api.ex` (393 lines)

**Purpose:** Intelligence analysis for characters and corporations in combat context

**Key Functions:**
- `analyze_character/2` - Character analysis with intelligence focus
- `get_character_intelligence/1` - Cached intelligence data
- `analyze_corporation/2` - Corporation analysis
- `assess_threat/2` - Context-aware threat assessment
- `calculate_intelligence_score/2` - Various scoring types (danger, hunter, FC, solo, awox)
- `get_character_recommendations/1` - Tactical recommendations
- `search_characters_by_criteria/1` - Criteria-based search
- `get_external_groups/2` - External group analysis

**Overlap with:**
- `intelligence/api.ex` (character analysis, threat assessment)
- `threat_assessment/api.ex` (threat analysis)
- `character_intelligence.ex` (character threat analysis)

#### 1.4 `battle_analysis/api.ex` (62 lines)

**Purpose:** Ash Domain definition for battle resources

**Resources Managed:**
- `Battle`, `BattleKillmail`, `BattleReport`, `BattleReportRating`, `BattleReportComment`
- `CombatLog`, `ShipFitting`
- Also includes Combat context resources (duplication)

**Issue:** Contains resources from BOTH `BattleAnalysis` AND `Combat` contexts

#### 1.5 `threat_assessment/api.ex` (26 lines)

**Purpose:** Threat and vulnerability analysis

**Key Functions:**
- `analyze_character_threat/3` - Character threat analysis
- `analyze_pilots/3` - Multi-pilot analysis
- `analyze_system_threats/4` - System-level threat analysis
- `analyze_vulnerabilities/3` - Vulnerability scanning

**Overlap with:**
- `combat_intelligence/api.ex` (`assess_threat`)
- `intelligence/api.ex` (`assess_threat`)
- `character_intelligence.ex` (`analyze_character_threat`)

### Combat Overlap Matrix

| Function | combat | combat_analysis | combat_intel | battle_analysis | threat_assess |
|----------|--------|-----------------|--------------|-----------------|---------------|
| Battle detection | ✓ | | | | |
| Battle analysis | ✓ | ✓ | | | |
| Battle timeline | ✓ | ✓ | | | |
| Fleet composition | ✓ | ✓ | | | |
| Participant analysis | ✓ | | | | |
| Tactical patterns | ✓ | | | | |
| Character combat | | ✓ | ✓ | | |
| Threat assessment | | ✓ | ✓ | | ✓ |
| Intelligence scoring | | | ✓ | | |
| Battle resources | | | | ✓ | ✓ (Ash) |
| Battle reports | | ✓ | | ✓ (Ash) | |
| Vulnerability scan | | | | | ✓ |

### Combat Context Recommendations

**Recommendation: Consolidate to 2 contexts**

1. **`battle_analysis/`** - Battle detection, analysis, timeline, participants, resources
   - Merge: `combat/api.ex` + `battle_analysis/api.ex`
   - Owns: Battle lifecycle, detection, timeline, participant analysis
   - Ash Domain for battle resources

2. **`combat_intelligence/`** - Combat-focused intelligence and threat assessment
   - Merge: `combat_analysis/api.ex` + `threat_assessment/api.ex`
   - Owns: Character combat analysis, threat scoring, vulnerability scanning
   - Delegates to `character_intelligence` for deep character analysis

**Contexts to deprecate:**
- `combat/` - Merge into `battle_analysis/`
- `combat_analysis/` - Merge into `combat_intelligence/`
- `threat_assessment/` - Merge into `combat_intelligence/`

---

## 2. Corporation-Related Contexts (3 Contexts)

### Current Structure

```
contexts/
├── corporation/               # 113 lines API - Core corporation operations
├── corporation_analysis/      # 28 lines API - Subset analysis
└── corporation_intelligence/  # 471 lines API - Comprehensive intelligence
```

### Detailed Analysis

#### 2.1 `corporation/api.ex` (113 lines)

**Purpose:** Core corporation operations and analysis

**Key Functions:**
- Corporation Analysis: `analyze_corporation/2`, `get_corporation_stats/1`, `get_corporation_profile/1`
- Member Activity: `analyze_member_activity/2`, `get_member_activity_summary/1`, `get_top_performers/2`
- Member Risk: `assess_member_risks/1`, `identify_flight_risks/1`
- Participation: `analyze_participation/2`, `analyze_timezone_coverage/1`
- Recruitment: `analyze_recruitment_pipeline/1`, `get_recruitment_metrics/1`
- Combat Doctrine: `analyze_combat_doctrine/1`, `get_fleet_compositions/1`
- Organizational Health: `assess_organizational_health/1`, `get_health_metrics/1`
- CRUD: `create_corporation_profile/1`, `update_corporation_data/2`, `get_corporation/1`
- Member Management: `add_member/2`, `update_member/2`, `remove_member/1`

#### 2.2 `corporation_analysis/api.ex` (28 lines)

**Purpose:** Subset of corporation analysis functions

**Note in moduledoc:** "For comprehensive corporation analysis, prefer using `EveDmv.Contexts.Corporation.Core.CorporationAnalyzer`"

**Key Functions:**
- `analyze_member_activity/2` - Member activity (duplicates corporation/api)
- `analyze_character_participation/3` - Character participation
- `analyze_corporation_participation/3` - Corporation participation

**Issue:** This context explicitly recommends using a different module, indicating it may be deprecated or redundant.

#### 2.3 `corporation_intelligence/api.ex` (471 lines)

**Purpose:** Comprehensive corporation intelligence

**Key Functions:**
- `analyze_corporation/2` - Corporation analysis (duplicates corporation/api)
- `analyze_combat_doctrines/2` - Doctrine analysis (duplicates corporation/api)
- `analyze_operational_patterns/2` - Operational patterns
- `analyze_performance/2` - Performance metrics
- `get_intelligence_report/2` - Comprehensive report
- `analyze_member_correlations/1` - Member correlations
- `analyze_activity_patterns/1` - Activity patterns
- `compare_corporations/2` - Corporation comparison
- `assess_corporation_health/2` - Health assessment (duplicates corporation/api)

### Corporation Overlap Matrix

| Function | corporation | corp_analysis | corp_intelligence |
|----------|-------------|---------------|-------------------|
| Corporation analysis | ✓ | | ✓ |
| Member activity | ✓ | ✓ | |
| Member participation | | ✓ | |
| Combat doctrine | ✓ | | ✓ |
| Organizational health | ✓ | | ✓ |
| Operational patterns | | | ✓ |
| Performance analysis | | | ✓ |
| Intelligence reports | | | ✓ |
| Member correlations | | | ✓ |
| Corporation comparison | | | ✓ |
| CRUD operations | ✓ | | |
| Member management | ✓ | | |

### Corporation Context Recommendations

**Recommendation: Consolidate to 2 contexts**

1. **`corporation/`** - Core corporation operations
   - Keep: CRUD, member management, basic analysis
   - Owns: Corporation lifecycle, member roster

2. **`corporation_intelligence/`** - Intelligence and analytics
   - Keep: All intelligence functions
   - Absorb: `corporation_analysis/` participation functions
   - Owns: All analytical/intelligence capabilities

**Context to deprecate:**
- `corporation_analysis/` - Merge into `corporation_intelligence/`

---

## 3. Intelligence-Related Contexts (4 Contexts)

### Current Structure

```
contexts/
├── intelligence/              # 102 lines API - Core intelligence
├── intelligence_infrastructure/  # 41 lines API - Regional/cross-system
├── character_intelligence/    # 908 lines module - Character-focused
└── combat_intelligence/       # 393 lines API - Combat-focused (also in combat)
```

### Detailed Analysis

#### 3.1 `intelligence/api.ex` (102 lines)

**Purpose:** Core character intelligence operations

**Key Functions:**
- Threat Assessment: `assess_threat/2`, `get_threat_score/1`, `calculate_danger_rating/1`
- Character Analysis: `analyze_character/2`, `get_character_stats/1`, `classify_pilot_type/1`
- Combat Stats: `analyze_combat_stats/2`, `get_kill_death_ratio/1`, `get_isk_efficiency/1`
- Ship Preferences: `analyze_ship_preferences/1`, `get_favorite_ships/2`
- Performance: `analyze_performance/2`, `get_performance_metrics/1`
- Behavioral: `analyze_behavior/1`, `get_activity_patterns/1`, `get_timezone_estimate/1`
- Comparison: `compare_characters/2`, `find_similar_characters/2`

#### 3.2 `intelligence_infrastructure/api.ex` (41 lines)

**Purpose:** Geographic/regional intelligence infrastructure

**Key Functions:**
- `analyze_region/2` - Regional pattern analysis
- `analyze_constellation/2` - Constellation pattern analysis
- `analyze_system/2` - Single system analysis
- `analyze_cross_system/2` - Cross-system strategic patterns
- `correlate_threats/2` - Threat correlation
- `correlate_activity/2` - Activity correlation

**Distinct Domain:** This context has minimal overlap - focuses on geographic/spatial intelligence.

#### 3.3 `character_intelligence.ex` (908 lines - Context Module)

**Purpose:** Comprehensive character intelligence and threat analysis

**Key Functions:**
- `analyze_character_threat/1` - Character threat (duplicates intelligence/api)
- `detect_behavioral_patterns/1` - Behavioral detection
- `calculate_threat_trends/2` - Threat trends over time
- `compare_character_threats/1` - Threat comparison
- `get_character_intelligence_report/1` - Full report
- Ship Intelligence: `get_character_ship_intelligence/1`, `get_detailed_ship_preferences/2`
- Activity: `get_activity_timeline/2`, `calculate_activity_stats/2`
- Gang Analysis: `analyze_gang_synergy/1`, `analyze_gang_effectiveness/1`
- Cross-Character: `analyze_character_relationships/1`, `predict_group_behavior/1`

**Note:** This is a context module, not an API module - no dedicated `api.ex`

#### 3.4 `combat_intelligence/api.ex` (393 lines)

Already analyzed in Combat section. Overlaps with both combat and intelligence domains.

### Intelligence Overlap Matrix

| Function | intelligence | intel_infra | char_intel | combat_intel |
|----------|-------------|-------------|------------|--------------|
| Character analysis | ✓ | | ✓ | ✓ |
| Threat assessment | ✓ | | ✓ | ✓ |
| Combat stats | ✓ | | ✓ | |
| Ship preferences | ✓ | | ✓ | |
| Behavioral patterns | ✓ | | ✓ | |
| Activity patterns | ✓ | | ✓ | ✓ |
| Comparison | ✓ | | ✓ | ✓ |
| Regional analysis | | ✓ | | |
| Cross-system | | ✓ | | |
| Threat correlation | | ✓ | | |
| Gang synergy | | | ✓ | |
| Group prediction | | | ✓ | |
| Corporation intel | | | | ✓ |

### Intelligence Context Recommendations

**Recommendation: Consolidate to 2 contexts**

1. **`character_intelligence/`** - All character-focused intelligence
   - Absorb: `intelligence/api.ex` character functions
   - Add: Proper `api.ex` file following context conventions
   - Owns: All character analysis, threat scoring, behavioral patterns

2. **`intelligence_infrastructure/`** - Geographic and cross-entity intelligence
   - Keep as-is: Distinct geographic focus
   - Consider rename: `spatial_intelligence/` or `regional_intelligence/`
   - Owns: Regional, constellation, system, cross-system analysis

**Context to deprecate:**
- `intelligence/` - Merge into `character_intelligence/`
- `combat_intelligence/` - Split between `character_intelligence/` (character functions) and `combat_intelligence/` for combat-specific scoring

---

## 4. Cross-Cutting Concerns

### 4.1 Threat Assessment Fragmentation

Threat assessment is currently spread across **5 different contexts**:

| Context | Threat Function |
|---------|-----------------|
| `threat_assessment/api.ex` | `analyze_character_threat/3` |
| `combat_intelligence/api.ex` | `assess_threat/2` |
| `intelligence/api.ex` | `assess_threat/2` |
| `character_intelligence.ex` | `analyze_character_threat/1` |
| `combat_analysis/api.ex` | `assess_threat/3` |

**Recommendation:** Consolidate all threat assessment into `character_intelligence/` with a single entry point.

### 4.2 Corporation Analysis Fragmentation

Corporation analysis appears in **4 contexts**:

| Context | Corporation Function |
|---------|---------------------|
| `corporation/api.ex` | `analyze_corporation/2` |
| `corporation_intelligence/api.ex` | `analyze_corporation/2` |
| `combat_intelligence/api.ex` | `analyze_corporation/2` |
| `corporation_analysis/api.ex` | (subset functions) |

**Recommendation:** Corporation analysis should live in `corporation_intelligence/` only.

### 4.3 Character Analysis Fragmentation

Character analysis appears in **5 contexts**:

| Context | Character Function |
|---------|-------------------|
| `intelligence/api.ex` | `analyze_character/2` |
| `combat_intelligence/api.ex` | `analyze_character/2` |
| `character_intelligence.ex` | `analyze_character_threat/1` |
| `combat_analysis/api.ex` | `analyze_character_combat/2` |
| `player_profile/api.ex` | `analyze_player/2` |

**Recommendation:** Consolidate into `character_intelligence/` as the authoritative source.

---

## 5. Recommended Context Architecture

### Proposed Structure (After Consolidation)

```
contexts/
├── battle_analysis/           # Battle detection, analysis, timeline, resources
│   ├── api.ex
│   ├── core/
│   └── resources/
│
├── character_intelligence/    # All character intelligence and threat scoring
│   ├── api.ex                 # NEW: Add proper API file
│   ├── domain/
│   └── analyzers/
│
├── corporation/               # Core corporation CRUD and member management
│   ├── api.ex
│   ├── core/
│   └── services/
│
├── corporation_intelligence/  # Corporation intelligence and analytics
│   ├── api.ex
│   └── domain/
│
├── intelligence_infrastructure/  # Geographic/regional intelligence
│   ├── api.ex
│   └── domain/
│
├── surveillance/              # Real-time monitoring (unchanged)
├── fleet_operations/          # Fleet operations (unchanged)
├── killmail_processing/       # Killmail pipeline (unchanged)
├── market_intelligence/       # Market data (unchanged)
└── player_profile/            # Player profiles (unchanged)
```

### Contexts to Deprecate/Merge

| Current Context | Action | Target |
|-----------------|--------|--------|
| `combat/` | MERGE | → `battle_analysis/` |
| `combat_analysis/` | MERGE | → `battle_analysis/` |
| `threat_assessment/` | MERGE | → `character_intelligence/` |
| `intelligence/` | MERGE | → `character_intelligence/` |
| `corporation_analysis/` | MERGE | → `corporation_intelligence/` |
| `combat_intelligence/` | SPLIT | → `character_intelligence/` + `battle_analysis/` |

---

## 6. Migration Strategy

### Phase 1: Create Facade APIs (Low Risk)
1. Create `character_intelligence/api.ex` that delegates to existing functions
2. Update documentation to point to canonical APIs
3. Add deprecation warnings to redundant contexts

### Phase 2: Consolidate Logic (Medium Risk)
1. Move analyzers to canonical locations
2. Update internal imports/aliases
3. Maintain old paths as deprecated delegates

### Phase 3: Remove Deprecated Contexts (High Risk)
1. Update all external callers
2. Run full test suite
3. Remove deprecated modules
4. Update documentation

---

## 7. Answers to Review Questions

### Combat-Related

**Q1: What distinguishes `combat` from `combat_analysis`?**
**A:** Minimal distinction. `combat` focuses on battle operations (detection, timeline, participants) while `combat_analysis` adds character combat analysis and threat assessment. These should be merged.

**Q2: Is `combat_intelligence` just a combination of `combat` + `intelligence`?**
**A:** Yes, essentially. It provides character/corporation intelligence with a combat focus. Should be merged with `character_intelligence` for characters and `corporation_intelligence` for corporations.

**Q3: Could `battle_analysis` be merged into `combat_analysis`?**
**A:** Yes, and this is recommended. `battle_analysis` is an Ash Domain for resources, `combat_analysis` is the functional API. They serve the same domain.

**Q4: Does `threat_assessment` overlap with `character_intelligence` threat scoring?**
**A:** Yes, significantly. Both provide character threat analysis. `threat_assessment` should be merged into `character_intelligence`.

### Corporation-Related

**Q1: Are these three contexts truly distinct domains?**
**A:** No. `corporation` handles CRUD and basic analysis, `corporation_intelligence` handles comprehensive analysis, `corporation_analysis` is a redundant subset.

**Q2: Could `corporation_analysis` be a subdomain of `corporation`?**
**A:** It should be merged into `corporation_intelligence` instead, as the moduledoc already recommends.

### Intelligence-Related

**Q1: Is there a clear hierarchy between these?**
**A:** Not currently. `intelligence` and `character_intelligence` significantly overlap. `intelligence_infrastructure` is distinct (geographic focus). `combat_intelligence` spans both combat and intelligence.

**Q2: Are there shared intelligence utilities that could be consolidated?**
**A:** Yes. Threat scoring, behavioral analysis, and activity pattern analysis are duplicated across contexts and should be consolidated in `character_intelligence`.

---

## 8. Risk Assessment

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Breaking external callers | High | Medium | Maintain deprecated delegates |
| Test failures | Medium | High | Comprehensive test coverage first |
| Performance regression | Low | Low | Profile before/after |
| Developer confusion | Medium | Medium | Clear documentation and migration guide |

---

## 9. Success Metrics

After consolidation:

- [ ] Context count reduced from 12 to 6
- [ ] No duplicate function names across context APIs
- [ ] Each context has single, clear responsibility
- [ ] All API modules under 300 lines
- [ ] Zero cross-context circular dependencies
- [ ] Documentation updated with clear ownership

---

## Appendix A: Full Function Inventory

### Threat Assessment Functions (Currently Fragmented)

| Function | Location | Recommendation |
|----------|----------|----------------|
| `analyze_character_threat/3` | `threat_assessment/api.ex` | → `character_intelligence/` |
| `assess_threat/2` | `combat_intelligence/api.ex` | → `character_intelligence/` |
| `assess_threat/2` | `intelligence/api.ex` | → `character_intelligence/` |
| `analyze_character_threat/1` | `character_intelligence.ex` | KEEP (canonical) |
| `assess_threat/3` | `combat_analysis/api.ex` | → `character_intelligence/` |

### Battle Analysis Functions (Currently Fragmented)

| Function | Location | Recommendation |
|----------|----------|----------------|
| `detect_battles/2` | `combat/api.ex` | → `battle_analysis/` |
| `analyze_battle/2` | `combat_analysis/api.ex` | → `battle_analysis/` |
| `analyze_battle/1` | `combat/api.ex` | → `battle_analysis/` |
| `build_battle_timeline/1` | `combat/api.ex` | → `battle_analysis/` |
| `get_battle_timeline/1` | `combat_analysis/api.ex` | → `battle_analysis/` |

### Corporation Analysis Functions (Currently Fragmented)

| Function | Location | Recommendation |
|----------|----------|----------------|
| `analyze_corporation/2` | `corporation/api.ex` | KEEP (basic) |
| `analyze_corporation/2` | `corporation_intelligence/api.ex` | KEEP (comprehensive) |
| `analyze_corporation/2` | `combat_intelligence/api.ex` | REMOVE (delegate) |
| `analyze_member_activity/2` | `corporation/api.ex` | KEEP |
| `analyze_member_activity/2` | `corporation_analysis/api.ex` | REMOVE (duplicate) |

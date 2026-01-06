# Phase 2: Ash Framework Optimization Audit

**Deliverable:** `docs/review/02_ash_framework_audit.md`
**Generated:** 2026-01-06
**Objective:** Audit all Ash resources for completeness and identify opportunities to migrate raw SQL to Ash patterns.

---

## Executive Summary

| Metric | Count | Status |
|--------|-------|--------|
| Total Ash Resources | 49 | - |
| Resources with Domain | 43 | Good |
| Resources Missing Domain | 6 | Review Needed |
| Ash Domains | 7 | - |
| Raw SQL Query Files | 13 | Review Needed |
| Raw SQL Query Instances | ~47 | High |
| API Modules > 200 lines | 9 | High Priority |

---

## 2.1 Resource Definition Audit

### 2.1.1 Domain Configuration Summary

| Domain | Resources | Location |
|--------|-----------|----------|
| `EveDmv.Api` | 19 | `/lib/eve_dmv/api.ex` |
| `EveDmv.Api.SurveillanceApi` | 3 | `/lib/eve_dmv/api/surveillance_api.ex` |
| `EveDmv.Api.AnalyticsApi` | 2 | `/lib/eve_dmv/api/analytics_api.ex` |
| `EveDmv.Api.BattleAnalysisApi` | 4 | `/lib/eve_dmv/api/battle_analysis_api.ex` |
| `EveDmv.Contexts.FleetOperations.Domain` | 1 | `/lib/eve_dmv/contexts/fleet_operations/domain.ex` |
| `EveDmv.Domains.Intelligence` | 4 | `/lib/eve_dmv/domains/intelligence.ex` |
| `EveDmv.Contexts.BattleAnalysis.Api` | 3 | `/lib/eve_dmv/contexts/battle_analysis/api.ex` |

### 2.1.2 Resources Missing Domain Registration

#### Finding 2.1.1: SimpleFilter Missing Domain

- **File:** `lib/eve_dmv/surveillance/simple_filter.ex`
- **Lines:** 50-52
- **Severity:** Low
- **Effort:** Small (<1hr)
- **Description:** The `SimpleFilter` resource uses `data_layer: :embedded` but has no `domain:` option. Embedded resources don't require domain registration, so this is acceptable for its use case.
- **Status:** Acceptable - embedded resources don't need domain registration

#### Finding 2.1.2: Ash Extension Modules

The following files contain `use Ash.Resource` but are **not actual resources** - they are Ash extensions:

| File | Purpose | Domain Needed? |
|------|---------|----------------|
| `lib/eve_dmv/ash/changes/soft_delete.ex` | Change module | No (Extension) |
| `lib/eve_dmv/ash/preparations/soft_delete_filter.ex` | Preparation | No (Extension) |
| `lib/eve_dmv/ash/preparations/query_safety.ex` | Preparation | No (Extension) |
| `lib/eve_dmv/ash/notifiers/pubsub_notifier.ex` | Notifier | No (Extension) |
| `lib/eve_dmv/ash/notifiers/telemetry_notifier.ex` | Notifier | No (Extension) |
| `lib/eve_dmv/calculations/base.ex` | Calculation base | No (Extension) |

- **Recommendation:** These are correctly implemented as Ash extensions and do not need domain registration.

### 2.1.3 Resource Completeness Matrix

| Resource | Domain | Data Layer | Actions | Attributes | Relationships | Validations | Calculations | Aggregates | Identities |
|----------|--------|------------|---------|------------|---------------|-------------|--------------|------------|------------|
| **Surveillance** | | | | | | | | | |
| `Profile` | YES | YES | YES | YES | YES | YES | YES | NO | YES |
| `ProfileMatch` | YES | YES | YES | YES | YES | NO | YES | NO | YES |
| `Notification` | YES | YES | YES | YES | YES | NO | YES | NO | YES |
| `SimpleFilter` | NO* | YES | YES | YES | NO | YES | NO | NO | NO |
| **Killmails** | | | | | | | | | |
| `KillmailRaw` | YES | YES | YES | YES | YES | NO | YES | YES | YES |
| `Participant` | YES | YES | YES | YES | YES | NO | YES | YES | YES |
| **EVE Static Data** | | | | | | | | | |
| `ItemType` | YES | YES | YES | YES | YES | NO | YES | YES | YES |
| `SolarSystem` | YES | YES | YES | YES | NO | NO | YES | NO | YES |
| `ShipAttributes` | YES | YES | YES | YES | YES | NO | YES | NO | YES |
| **Combat** | | | | | | | | | |
| `Combat.Battle` | YES | YES | YES | YES | YES | YES | NO | NO | YES |
| `Combat.BattleKillmail` | YES | YES | YES | YES | YES | YES | NO | NO | YES |
| `Combat.CombatLog` | YES | YES | YES | YES | NO | NO | NO | NO | NO |
| `Combat.ShipFitting` | YES | YES | YES | YES | NO | NO | NO | NO | NO |
| **Battle Analysis** | | | | | | | | | |
| `Battle` | YES | YES | YES | YES | YES | YES | NO | NO | YES |
| `BattleKillmail` | YES | YES | YES | YES | YES | YES | NO | NO | YES |
| `BattleReport` | YES | YES | YES | YES | YES | YES | NO | NO | NO |
| `BattleReportComment` | YES | YES | YES | YES | YES | YES | NO | NO | NO |
| `BattleReportRating` | YES | YES | YES | YES | YES | YES | NO | NO | YES |
| `CombatLog` | YES | YES | YES | YES | NO | NO | NO | NO | NO |
| `ShipFitting` | YES | YES | YES | YES | NO | NO | NO | NO | NO |
| **Corporation** | | | | | | | | | |
| `Corporation` | YES | YES | YES | YES | YES | YES | YES | YES | YES |
| `Alliance` | YES | YES | YES | YES | YES | YES | YES | YES | YES |
| `CorporationMember` | YES | YES | YES | YES | YES | YES | YES | NO | YES |
| `ActivityMetric` | YES | YES | YES | YES | YES | YES | YES | NO | YES |
| `MemberActivityLog` | YES | YES | YES | YES | YES | YES | YES | NO | NO |
| `MemberPerformanceSnapshot` | YES | YES | YES | YES | YES | YES | YES | NO | YES |
| `RecruitmentApplication` | YES | YES | YES | YES | YES | YES | YES | NO | YES |
| `RecruitmentCampaign` | YES | YES | YES | YES | YES | YES | YES | NO | NO |
| **Intelligence** | | | | | | | | | |
| `CharacterStats` (domain) | YES | YES | YES | YES | YES | NO | YES | NO | NO |
| `CharacterStats` (resources) | YES | YES | YES | YES | NO | NO | YES | NO | NO |
| `PlayerStats` | YES | YES | YES | YES | YES | NO | NO | NO | YES |
| `CharacterProfile` | YES | YES | YES | YES | NO | YES | NO | NO | YES |
| `MemberActivityIntelligence` | YES | YES | YES | YES | NO | NO | YES | NO | NO |
| **Chain Analysis** | | | | | | | | | |
| `ChainConnection` | YES | YES | YES | YES | YES | NO | YES | NO | NO |
| `ChainTopology` | YES | YES | YES | YES | YES | NO | YES | NO | NO |
| `SystemInhabitant` | YES | YES | YES | YES | YES | NO | YES | NO | NO |
| **Auth** | | | | | | | | | |
| `User` | YES | YES | YES | YES | YES | NO | NO | NO | YES |
| `Token` | YES | YES | NO | NO | NO | NO | NO | NO | NO |
| `ApiAuthentication` | YES | YES | YES | YES | NO | YES | NO | NO | YES |
| `Account` | YES | YES | YES | YES | YES | NO | YES | YES | YES |
| **Fleet Operations** | | | | | | | | | |
| `FleetDoctrine` | YES | YES | YES | YES | NO | YES | YES | NO | YES |
| **Killmail Processing** | | | | | | | | | |
| `HistoricalFetchStatus` | YES | YES | YES | YES | NO | NO | YES | NO | YES |

\* Embedded resource - domain not required

### 2.1.4 Resources Needing Enhancement

#### Finding 2.1.3: Token Resource Incomplete

- **File:** `lib/eve_dmv/platform/auth/token.ex`
- **Severity:** Medium
- **Effort:** Medium (1-4hr)
- **Description:** The Token resource has `use Ash.Resource` but no `actions`, `attributes`, or other DSL blocks defined.
- **Recommendation:** Either complete the resource definition or remove Ash.Resource if unused.

#### Finding 2.1.4: Combat Resources Missing Calculations

- **Files:**
  - `lib/eve_dmv/contexts/combat/resources/combat_log.ex`
  - `lib/eve_dmv/contexts/combat/resources/ship_fitting.ex`
- **Severity:** Low
- **Effort:** Medium (1-4hr)
- **Description:** Combat-related resources lack calculations that could provide derived values.
- **Recommendation:** Consider adding calculations for common computed values like kill counts, efficiency metrics.

#### Finding 2.1.5: Duplicate Resources Between Contexts

- **Severity:** High
- **Effort:** Large (>4hr)
- **Description:** There are duplicate resource definitions between `contexts/combat/resources/` and `contexts/battle_analysis/resources/`:
  - `Battle` - defined in both combat and battle_analysis
  - `BattleKillmail` - defined in both combat and battle_analysis
  - `CombatLog` - defined in both combat and battle_analysis
  - `ShipFitting` - defined in both combat and battle_analysis
- **Files:**
  - `lib/eve_dmv/contexts/combat/resources/battle.ex`
  - `lib/eve_dmv/contexts/battle_analysis/resources/battle.ex`
  - `lib/eve_dmv/contexts/combat/resources/battle_killmail.ex`
  - `lib/eve_dmv/contexts/battle_analysis/resources/battle_killmail.ex`
- **Recommendation:** Consolidate to single resource definitions. The `combat` context resources may be candidates for removal in favor of `battle_analysis`.

---

## 2.2 Raw SQL Migration Inventory

### 2.2.1 Files with Raw SQL Usage

| File | SQL Queries | Migration Priority | Category |
|------|-------------|-------------------|----------|
| `platform/database/materialized_view_optimizer.ex` | 15 | Keep SQL | DDL/Admin |
| `contexts/character_intelligence/analyzers/character_intelligence_analyzer.ex` | 12 | Consider | Analytics |
| `eve_dmv_web/live/admin/system_live.ex` | 5 | Keep SQL | Admin |
| `platform/database/queries/analytics_queries.ex` | 5 | Consider | Analytics |
| `sql.ex` | 2 | Keep SQL | Wrapper |
| `search/search_suggestion_service.ex` | 2 | Consider | Search |
| `platform/utilities/query_helpers.ex` | 2 | Keep SQL | Utility |
| `contexts/combat_intelligence/domain/battle_analysis/data_collectors/battle_data_collector.ex` | 2 | Consider | Analytics |
| `contexts/combat_intelligence/domain/battle_analysis/battle_analysis_coordinator.ex` | 2 | Consider | Analytics |
| `contexts/battle_analysis/core/optimized_battle_analyzer.ex` | 2 | Consider | Analytics |
| `application.ex` | 2 | Keep SQL | Health Check |
| `surveillance/matching_engine.ex` | 1 | Keep SQL | Health Check |
| `contexts/combat_intelligence/domain/streaming_battle_analyzer.ex` | 1 | Consider | Analytics |

### 2.2.2 SQL Query Categories

| Category | Count | Recommendation |
|----------|-------|----------------|
| DDL/Admin (CREATE, VACUUM, REINDEX) | ~10 | Keep as SQL - Ash doesn't support DDL |
| Health Checks (SELECT 1) | ~3 | Keep as SQL - Simple connectivity checks |
| Complex Analytics (CTEs, Window Functions) | ~25 | Review case-by-case |
| Simple Aggregations | ~5 | Could migrate to Ash aggregates |
| Search Queries | ~4 | Could migrate to Ash read actions |

### 2.2.3 Migration Recommendations

#### Finding 2.2.1: Character Intelligence Analyzer - Complex CTEs

- **File:** `lib/eve_dmv/contexts/character_intelligence/analyzers/character_intelligence_analyzer.ex`
- **Lines:** 56-119, 159-214, etc.
- **Severity:** Low
- **Effort:** Large (>4hr)
- **Query Types:** Complex CTEs with window functions, JSONB extraction, lateral joins
- **Current Code:**
  ```sql
  WITH character_kills AS (
    SELECT DISTINCT p.killmail_id, p.killmail_time
    FROM participants p
    WHERE p.character_id = $3
      AND p.killmail_time >= $2
      AND p.is_victim = false
  ),
  character_weapons AS (
    -- Complex JSONB extraction
    SELECT (attacker->>'weapon_type_id')::integer as weapon_type_id
    FROM killmails_raw k
    CROSS JOIN LATERAL jsonb_array_elements(k.raw_data->'attackers') as attacker
    -- ...
  )
  ```
- **Recommendation:** Keep as raw SQL. These queries use:
  - Complex CTEs with multiple levels
  - JSONB extraction (`->>`, `jsonb_array_elements`)
  - Lateral joins
  - Window functions

  Ash doesn't support this level of query complexity. The performance optimizations (indexed lookups, query planning) are also important to preserve.

#### Finding 2.2.2: Analytics Queries - Potential Migration

- **File:** `lib/eve_dmv/platform/database/queries/analytics_queries.ex`
- **Lines:** 98, 158, 210, 276, 328
- **Severity:** Medium
- **Effort:** Medium (1-4hr)
- **Description:** Some simpler queries could potentially be Ash read actions with filters
- **Current Pattern:**
  ```elixir
  case Ecto.Adapters.SQL.query(Repo, query, [search_pattern, limit]) do
    {:ok, %{rows: rows}} -> process_rows(rows)
    {:error, _} -> {:error, :query_failed}
  end
  ```
- **Recommendation:** Review individual queries. Search queries with ILIKE patterns could potentially use Ash expressions, but may lose performance optimizations.

#### Finding 2.2.3: Materialized View Operations - Keep SQL

- **File:** `lib/eve_dmv/platform/database/materialized_view_optimizer.ex`
- **Severity:** N/A
- **Description:** All 15 SQL queries in this file are DDL operations (CREATE MATERIALIZED VIEW, REFRESH, DROP, pg_cron scheduling).
- **Recommendation:** Keep as SQL - Ash does not support DDL operations.

#### Finding 2.2.4: Health Checks - Keep SQL

- **Files:** `application.ex`, `matching_engine.ex`
- **Description:** Simple `SELECT 1` connectivity checks
- **Recommendation:** Keep as SQL - minimal overhead, standard pattern for health checks.

### 2.2.4 SQL Migration Priority Matrix

| Priority | Query Type | Count | Recommendation |
|----------|------------|-------|----------------|
| High | Simple COUNT/SUM on single table | 0 | Migrate to Ash aggregates |
| Medium | Search with filters | ~4 | Could migrate to Ash read actions |
| Low | Complex analytics with CTEs | ~25 | Keep as SQL |
| Skip | DDL/Admin operations | ~10 | Keep as SQL (no Ash support) |
| Skip | Health checks | ~3 | Keep as SQL |

---

## 2.3 Action Refactoring Opportunities

### 2.3.1 Large API Modules with Business Logic

| API Module | Lines | Logic Blocks | Status |
|------------|-------|--------------|--------|
| `killmail_processing/api.ex` | 549 | 34 | Critical - Needs Refactoring |
| `corporation_intelligence/api.ex` | 471 | 11 | High |
| `system_analysis/api.ex` | 442 | 17 | High |
| `fleet_operations/api.ex` | 405 | 28 | High |
| `surveillance/api.ex` | 405 | 20 | High |
| `combat_intelligence/api.ex` | 395 | 21 | High |
| `corporation/api.ex` | 260 | - | Medium |
| `intelligence/api.ex` | 235 | - | Medium |
| `market_intelligence/api.ex` | 232 | 15 | Medium |

**Standard:** API modules should be <200 lines with 0 logic blocks (delegate all).

### 2.3.2 Validation Logic Outside Resources

#### Finding 2.3.1: Surveillance API Validation

- **File:** `lib/eve_dmv/contexts/surveillance/api.ex`
- **Lines:** 287-360
- **Severity:** Medium
- **Effort:** Medium (1-4hr)
- **Description:** Multiple validation functions defined in the API module that should be in resource validations:
  - `validate_profile_data/1`
  - `validate_profile_updates/1`
  - `validate_profile_name/1`
  - `validate_criteria_structure/1`
  - `validate_update_fields/1`
- **Current Code:**
  ```elixir
  defp validate_profile_data(profile_data) do
    with :ok <- validate_required_keys(:profile_data, profile_data, [:name, :criteria, :user_id]),
         :ok <- validate_profile_name(profile_data[:name]),
         :ok <- validate_criteria_structure(profile_data[:criteria]),
         :ok <- validate_positive_integer(:user_id, profile_data[:user_id]) do
      {:ok, profile_data}
    end
  end
  ```
- **Recommendation:** Move validations into the `Profile` resource's `validations do` block using Ash's built-in validation DSL.

---

## 2.4 Domain Consolidation

### 2.4.1 Current Domain Structure

```
EveDmv.Api (Main Domain)
├── 19 core resources
│
├── EveDmv.Api.SurveillanceApi
│   └── 3 resources (Profile, ProfileMatch, Notification)
│
├── EveDmv.Api.AnalyticsApi
│   └── 2 resources (ShipStats, PlayerStats)
│
├── EveDmv.Api.BattleAnalysisApi
│   └── 4 resources (Battle, BattleKillmail, CombatLog, ShipFitting)
│
├── EveDmv.Contexts.FleetOperations.Domain
│   └── 1 resource (FleetDoctrine)
│
├── EveDmv.Domains.Intelligence
│   └── 4 resources (ChainTopology, SystemInhabitant, ChainConnection, MemberActivityIntelligence)
│
└── EveDmv.Contexts.BattleAnalysis.Api (Also a domain!)
    └── 3 resources (Battle, BattleKillmail, BattleReport... duplicates?)
```

### 2.4.2 Domain Issues

#### Finding 2.4.1: Duplicate Battle Analysis Domains

- **Severity:** High
- **Effort:** Medium (1-4hr)
- **Description:** Two domains handle battle analysis:
  1. `EveDmv.Api.BattleAnalysisApi` - 4 resources
  2. `EveDmv.Contexts.BattleAnalysis.Api` - 3 resources (acts as both API and Domain)
- **Recommendation:** Consolidate into a single battle analysis domain.

#### Finding 2.4.2: Single-Resource Domain

- **File:** `lib/eve_dmv/contexts/fleet_operations/domain.ex`
- **Severity:** Low
- **Effort:** Small (<1hr)
- **Description:** The FleetOperations domain contains only 1 resource (FleetDoctrine).
- **Recommendation:** Consider merging into main API or keeping if fleet operations will grow.

#### Finding 2.4.3: Inconsistent Domain Naming

- **Severity:** Low
- **Effort:** Medium (1-4hr)
- **Description:** Domains use inconsistent naming patterns:
  - `EveDmv.Api.*` - Sub-APIs under main API
  - `EveDmv.Contexts.*.Api` - API module also acting as domain
  - `EveDmv.Domains.*` - Dedicated domain namespace
- **Recommendation:** Standardize on one pattern. Suggested: `EveDmv.Api.*` for all domains.

---

## 2.5 Recommendations Summary

### High Priority (Do First)

| ID | Finding | Effort | Impact |
|----|---------|--------|--------|
| 2.1.5 | Consolidate duplicate Battle/Combat resources | Large | High - Reduces confusion |
| 2.4.1 | Consolidate battle analysis domains | Medium | High - Cleaner architecture |
| 2.3.1 | Move surveillance validations to resource | Medium | Medium - Better Ash patterns |

### Medium Priority

| ID | Finding | Effort | Impact |
|----|---------|--------|--------|
| 2.1.3 | Complete Token resource definition | Medium | Medium |
| 2.3.1 | Refactor large API modules | Large | Medium - Better maintainability |
| 2.4.3 | Standardize domain naming | Medium | Low - Consistency |

### Low Priority / Skip

| ID | Finding | Effort | Recommendation |
|----|---------|--------|----------------|
| 2.2.1 | Character Intelligence SQL | Large | Keep SQL - Complex CTEs |
| 2.2.3 | Materialized view SQL | N/A | Keep SQL - DDL operations |
| 2.1.4 | Add calculations to combat resources | Medium | Optional enhancement |
| 2.4.2 | Single-resource domain | Small | Keep if fleet ops will grow |

---

## Appendix A: Analysis Commands Used

```bash
# List all Ash resources
grep -rln "use Ash.Resource" lib/ --include="*.ex"

# List all Ash domains
grep -rln "use Ash.Domain" lib/ --include="*.ex"

# Find raw SQL usage
grep -rn "Ecto.Adapters.SQL.query" lib/ --include="*.ex"

# Check API module sizes
wc -l lib/eve_dmv/contexts/*/api.ex | sort -rn

# Find business logic in API modules
grep -c "case \|if \|with " lib/eve_dmv/contexts/*/api.ex

# Count resources per domain
grep -c "resource " lib/eve_dmv/api*.ex lib/eve_dmv/domains/*.ex
```

---

## Appendix B: Resource DSL Coverage

Full resource audit output showing which DSL sections are present in each resource file is available in the analysis logs.

Key:
- YES = Section present in resource
- NO = Section not present (may or may not be needed depending on resource type)
- N/A = Not applicable (e.g., embedded resources don't need domain)

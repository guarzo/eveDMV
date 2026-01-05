# Phase 10: Consistency Audit Report

**Date:** 2026-01-04
**Scope:** EVE DMV Codebase - All 20 Bounded Contexts
**Auditor:** Automated Code Review

---

## Executive Summary

| Category | Status | Issues Found |
|----------|--------|--------------|
| Naming Conventions | **GOOD** | 2 minor issues |
| File Organization | **MIXED** | 4 inconsistencies |
| Error Handling | **NEEDS WORK** | Multiple patterns in use |
| Logging Practices | **GOOD** | Minor inconsistencies |

---

## 10.1 Naming Conventions Audit

### Module Naming ✅ CONSISTENT

All 17 context API modules follow the standard naming convention:

```
EveDmv.Contexts.<ContextName>.Api
```

**Verified Modules:**
- `EveDmv.Contexts.BattleAnalysis.Api`
- `EveDmv.Contexts.CharacterIntelligence.Api` (Note: no Api module, uses top-level)
- `EveDmv.Contexts.Combat.Api`
- `EveDmv.Contexts.CombatAnalysis.Api`
- `EveDmv.Contexts.CombatIntelligence.Api`
- `EveDmv.Contexts.Corporation.Api`
- `EveDmv.Contexts.CorporationAnalysis.Api`
- `EveDmv.Contexts.CorporationIntelligence.Api`
- `EveDmv.Contexts.FleetOperations.Api`
- `EveDmv.Contexts.Intelligence.Api`
- `EveDmv.Contexts.IntelligenceInfrastructure.Api`
- `EveDmv.Contexts.KillmailProcessing.Api`
- `EveDmv.Contexts.MarketIntelligence.Api`
- `EveDmv.Contexts.PlayerProfile.Api`
- `EveDmv.Contexts.Surveillance.Api`
- `EveDmv.Contexts.SystemAnalysis.Api`
- `EveDmv.Contexts.ThreatAssessment.Api`
- `EveDmv.Contexts.ThreatSurveillance.Api`

### Function Naming Patterns

**Consistent Patterns Found:**
| Pattern | Usage | Assessment |
|---------|-------|------------|
| `analyze_*` | Character/corporation/fleet analysis | ✅ Consistent |
| `get_*` | Data retrieval operations | ✅ Consistent |
| `calculate_*` | Computational operations | ✅ Consistent |
| `assess_*` | Assessment/evaluation operations | ✅ Consistent |
| `create_*` / `update_*` / `delete_*` | CRUD operations | ✅ Consistent |
| `validate_*` | Validation functions | ✅ Consistent (private) |

**Sample Function Names by Context:**

```elixir
# Combat Intelligence
analyze_character/2, get_character_intelligence/1, assess_threat/2

# Corporation
analyze_corporation/2, get_corporation_stats/1, assess_member_risks/1

# Surveillance
create_profile/1, update_profile/2, delete_profile/1, get_profile/1
```

### Issues Found

#### Issue 1: Inconsistent Verb Usage
Some contexts use different verbs for similar operations:

| Operation | Used In | Alternative |
|-----------|---------|-------------|
| `fetch_historical_killmails` | KillmailProcessing | `get_historical_killmails` would be more consistent |
| `ingest_killmail` | KillmailProcessing | Acceptable - distinct operation |

#### Issue 2: Mixed Singular/Plural
- `compare_characters` (plural) ✅
- `get_character_intelligence` (singular) ✅
- Pattern is consistent: singular for single entity, plural for collections

### Recommendations

1. ✅ No action needed - naming conventions are largely consistent
2. Consider standardizing on `get_*` for all retrieval operations

---

## 10.2 File Organization Audit

### Context Subdirectory Structure

**Subdirectory Usage Frequency:**

| Subdirectory | Count | Purpose |
|--------------|-------|---------|
| `domain/` | 16 | Core business logic |
| `infrastructure/` | 8 | External integrations |
| `analyzers/` | 5 | Analysis algorithms |
| `core/` | 5 | Core utilities |
| `resources/` | 5 | Ash resources |
| `services/` | 4 | Application services |
| `formatters/` | 2 | Output formatting |
| `extractors/` | 1 | Data extraction |
| `calculators/` | 1 | Calculation modules |

### Structure Analysis by Context

#### Well-Organized Contexts ✅

**combat_intelligence/** - Clean structure
```
├── api.ex
├── domain/
│   ├── battle_analyzer.ex
│   ├── character_analyzer.ex
│   ├── corporation_analyzer.ex
│   └── extractors/
│       └── killmail_extractor.ex
└── infrastructure/
```

**surveillance/** - Well-separated concerns
```
├── api.ex
├── domain/
│   ├── matching_engine.ex
│   ├── notification_service.ex
│   └── profile_manager.ex
└── infrastructure/
```

#### Inconsistent Structures ⚠️

**Issue 1: Mixed `core/` vs `domain/` Usage**

Some contexts use `core/`:
- `corporation/core/`
- `combat/core/`
- `fleet_operations/core/`

Others use `domain/`:
- `combat_intelligence/domain/`
- `surveillance/domain/`
- `system_analysis/domain/`

**Recommendation:** Standardize on `domain/` for business logic (16 contexts already use this).

**Issue 2: Inconsistent Service Placement**

- `corporation/services/` - Services inside context
- `intelligence/services/` - Services inside context
- No `services/` in: `combat_intelligence`, `surveillance`, `system_analysis`

**Issue 3: Some Contexts Lack api.ex Pattern**

Top-level context modules exist alongside `api.ex`:
- `lib/eve_dmv/contexts/character_intelligence.ex` (958 lines)
- `lib/eve_dmv/contexts/corporation_intelligence.ex` (1,092 lines)
- `lib/eve_dmv/contexts/battle_analysis.ex` (782 lines)
- `lib/eve_dmv/contexts/system_analysis.ex` (788 lines)

These appear to duplicate functionality with the `api.ex` modules within them.

**Issue 4: Orphaned/Duplicate Resource Files**

Found duplicate files:
- `contexts/combat/resources/ship_fitting.ex`
- `contexts/battle_analysis/resources/ship_fitting.ex`

Both contain identical `parse_eft/1` implementation.

### Recommendations

1. **Standardize on `domain/` over `core/`** - Refactor 5 contexts using `core/`
2. **Consolidate top-level context modules** - Move logic into `api.ex` or subdirectories
3. **Remove duplicate files** - Consolidate `ship_fitting.ex` to a shared location
4. **Document structure expectations** - Add context structure guidelines

---

## 10.3 Error Handling Audit

### Error Tuple Formats Found

#### Pattern 1: Atom Errors ✅ (Preferred)
```elixir
{:error, :not_found}
{:error, :query_failed}
{:error, :battle_not_found}
{:error, :invalid_user_id}
{:error, :rate_limited}
```

**Used In:** `surveillance/`, `battle_sharing.ex`, `battle_analysis.ex`

#### Pattern 2: String Errors ⚠️ (Inconsistent)
```elixir
{:error, "Invalid kill URL format"}
{:error, "Missing required fields: #{Enum.join(missing_fields, ", ")}"}
{:error, "zKillboard API integration not implemented"}
{:error, "Invalid corporation ID"}
{:error, "Failed to generate insights: #{inspect(error)}"}
```

**Used In:** `combat_analysis.ex`, `threat_surveillance/`, `character_intelligence/`, `corporation_intelligence/`

#### Pattern 3: Tuple Errors (Structured)
```elixir
{:error, {:invalid_notification_types, keys}}
{:error, {:invalid_field, field}}
{:error, {:invalid_boolean_option, key}}
```

**Used In:** `surveillance/api.ex`

### Error Pattern Distribution

| Pattern | Count | Assessment |
|---------|-------|------------|
| Atom errors (`:atom`) | ~60% | ✅ Recommended |
| String errors (`"string"`) | ~30% | ⚠️ Should convert |
| Tuple errors (`{:reason, data}`) | ~10% | ✅ Acceptable for structured data |

### Specific Issues

#### Issue 1: Inconsistent Error Atoms
```elixir
# Different atoms for similar conditions:
{:error, :not_found}           # surveillance/
{:error, :battle_not_found}    # battle_analysis.ex
{:error, :report_not_found}    # battle_sharing.ex
{:error, :profile_not_found}   # threat_surveillance/
{:error, :alert_not_found}     # surveillance/domain/alert_service.ex
```

**Recommendation:** Use structured errors like `{:error, {:not_found, :battle}}` or standardize atoms.

#### Issue 2: String Errors Leak Implementation Details
```elixir
# Bad - exposes internal details
{:error, "Update failed: #{inspect(exception)}"}
{:error, "Database query failed"}

# Good - user-friendly
{:error, :update_failed}
{:error, :database_error}
```

#### Issue 3: Missing Error Type Specs

Some API functions have incomplete error specs:

```elixir
# Missing specific error types
@spec get_activity_patterns(integer(), keyword()) :: {:error, :analysis_failed}

# Should enumerate possible errors
@spec get_activity_patterns(integer(), keyword()) ::
  {:ok, map()} | {:error, :analysis_failed | :invalid_character_id | :timeout}
```

### Recommendations

1. **Convert string errors to atoms** - Create error atom module
2. **Standardize `:not_found` pattern** - Use `{:error, {:not_found, entity_type}}`
3. **Add error translation layer** - Convert internal errors to user-friendly messages at API boundary
4. **Complete error typespecs** - Document all possible error returns

---

## 10.4 Logging Audit

### Logger Usage Statistics

| Level | Count | Percentage |
|-------|-------|------------|
| `Logger.error` | 280 | 34% |
| `Logger.info` | 247 | 30% |
| `Logger.debug` | 203 | 25% |
| `Logger.warning` | 93 | 11% |

**Total Logger calls in contexts:** 253 files with `require Logger`

### Logging Patterns Found

#### Pattern 1: String Interpolation (Most Common)
```elixir
Logger.info("Starting surveillance matching engine")
Logger.debug("Compiled profile #{profile.name} (#{profile.id})")
Logger.error("Failed to load surveillance profiles: #{inspect(error)}")
```

#### Pattern 2: Structured Logging (HTTP Client)
```elixir
Logger.debug("Making POST request", url: url, headers: headers)
Logger.warning("POST request failed", url: url, status: status)
```

#### Pattern 3: Multi-line Logging
```elixir
Logger.info("""
Memory Profiler: Process Summary
=====================================
Top #{top_n} Processes by Memory Usage:
#{format_processes(top_processes)}
""")
```

### Consistency Analysis

#### Good Practices ✅

1. **Consistent level usage:**
   - `error` for failures and exceptions
   - `warning` for recoverable issues
   - `info` for significant events (startup, completion)
   - `debug` for detailed tracing

2. **Using `inspect/1` for complex data:**
   ```elixir
   Logger.error("Failed to record matches: #{inspect(errors)}")
   ```

3. **Including context in messages:**
   ```elixir
   Logger.warning("Profile not found for notification: #{profile_id}")
   ```

#### Issues Found ⚠️

**Issue 1: Inconsistent Structured vs Unstructured Logging**

HTTP client uses structured logging:
```elixir
Logger.debug("Making GET request", url: url, headers: headers)
```

Most other modules use string interpolation:
```elixir
Logger.debug("Compiled profile #{profile.name} (#{profile.id})")
```

**Issue 2: Emoji in Log Messages**
```elixir
Logger.info("📝 Recording batch of #{length(state.pending_matches)} surveillance matches")
```

**Recommendation:** Remove emojis from production logs.

**Issue 3: Inconsistent Error Message Format**

```elixir
# Some include colon after context
Logger.error("Failed to create notification: #{inspect(error)}")

# Others use dash
Logger.warning("Profile not found for notification: #{profile_id} - #{inspect(error)}")

# Some include full stop
Logger.info("Updated notification config for profile: #{profile_id}")
```

### Log Level Appropriateness

| Current | Message | Recommendation |
|---------|---------|----------------|
| `debug` | "Unexpected message: #{inspect(msg)}" | ⚠️ Should be `warning` |
| `info` | "Reloading surveillance profiles" | ✅ Appropriate |
| `error` | "Exception recording matches" | ✅ Appropriate |
| `warning` | "Database may not be ready yet" | ✅ Appropriate |

### Recommendations

1. **Standardize on structured logging** - Use keyword metadata consistently
2. **Remove emojis** - Keep logs clean and parseable
3. **Create logging guidelines** - Document format expectations
4. **Consider OpenTelemetry spans** - For tracing complex operations

---

## Summary of All Issues

### High Priority 🔴

| Issue | Location | Impact |
|-------|----------|--------|
| String errors instead of atoms | Multiple contexts | Inconsistent error handling |
| Duplicate `ship_fitting.ex` | combat/, battle_analysis/ | Maintenance burden |
| Mixed `core/` vs `domain/` | 5 contexts | Developer confusion |

### Medium Priority 🟡

| Issue | Location | Impact |
|-------|----------|--------|
| Top-level context modules | 4 contexts | Unclear API boundaries |
| Inconsistent `:not_found` atoms | Multiple contexts | Error handling complexity |
| Mixed structured/unstructured logs | Entire codebase | Log parsing difficulties |

### Low Priority 🟢

| Issue | Location | Impact |
|-------|----------|--------|
| Emoji in logs | surveillance/ | Minor aesthetics |
| Inconsistent log punctuation | Multiple files | Minor readability |
| `fetch_` vs `get_` naming | KillmailProcessing | Minor inconsistency |

---

## Action Items

### Immediate (This Sprint)

- [ ] Create `EveDmv.Core.Errors` module with standard error atoms
- [ ] Remove duplicate `ship_fitting.ex` - consolidate to shared location
- [ ] Remove emojis from log messages

### Short-term (Next 2 Sprints)

- [ ] Convert string errors to atoms in:
  - `combat_analysis.ex`
  - `threat_surveillance/domain/`
  - `character_intelligence/domain/`
  - `corporation_intelligence/domain/`
- [ ] Rename `core/` to `domain/` in 5 contexts:
  - `corporation/core/` → `corporation/domain/`
  - `combat/core/` → `combat/domain/`
  - `fleet_operations/core/` → `fleet_operations/domain/`
  - `intelligence/core/` → `intelligence/domain/`
  - `battle_analysis/core/` → `battle_analysis/domain/`

### Long-term (Backlog)

- [ ] Consolidate top-level context modules into `api.ex` pattern
- [ ] Add structured logging throughout codebase
- [ ] Create comprehensive error handling documentation
- [ ] Add complete typespecs for all error returns

---

## Appendix: Context Structure Reference

### Recommended Structure

```
context_name/
├── api.ex                    # Public interface (REQUIRED)
├── domain/                   # Business logic (REQUIRED)
│   ├── primary_service.ex
│   └── support_modules/
├── resources/               # Ash resources (if applicable)
├── infrastructure/          # External integrations (if applicable)
├── analyzers/              # Analysis modules (if applicable)
└── services/               # Application services (if applicable)
```

### Current State by Context

| Context | Has api.ex | Has domain/ | Has core/ | Top-level .ex |
|---------|------------|-------------|-----------|---------------|
| battle_analysis | ✅ | ✅ | ✅ | ✅ (782 lines) |
| battle_sharing | ❌ | ✅ | ❌ | ✅ |
| character_intelligence | ❌ | ✅ | ❌ | ✅ (958 lines) |
| combat | ✅ | ❌ | ✅ | ❌ |
| combat_analysis | ✅ | ✅ | ❌ | ✅ |
| combat_intelligence | ✅ | ✅ | ❌ | ✅ |
| corporation | ✅ | ❌ | ✅ | ❌ |
| corporation_analysis | ✅ | ✅ | ❌ | ❌ |
| corporation_intelligence | ✅ | ✅ | ❌ | ✅ (1,092 lines) |
| fleet_operations | ✅ | ✅ | ✅ | ✅ |
| intelligence | ✅ | ❌ | ✅ | ❌ |
| intelligence_infrastructure | ✅ | ✅ | ❌ | ❌ |
| killmail_processing | ✅ | ✅ | ❌ | ✅ |
| market_intelligence | ✅ | ✅ | ❌ | ✅ |
| player_profile | ✅ | ✅ | ❌ | ❌ |
| surveillance | ✅ | ✅ | ❌ | ✅ |
| system_analysis | ✅ | ✅ | ❌ | ✅ (788 lines) |
| threat_assessment | ✅ | ✅ | ❌ | ❌ |
| threat_surveillance | ✅ | ✅ | ❌ | ✅ |

---

*Report generated as part of EVE DMV Code Review Plan - Phase 10*

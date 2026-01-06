# Migration Adapter Cleanup Implementation Plan

This document outlines the implementation plan for removing the temporary migration adapters and migrating all callers to use bounded context APIs directly.

## Overview

Two migration adapters exist to provide backward compatibility during the transition from the monolithic `IntelligenceEngine` to bounded contexts:

1. **`EveDmv.Intelligence.LegacyAdapter`** (`lib/eve_dmv/core/infrastructure/legacy_adapter.ex`)
   - Bridges old analyzer interfaces to the new Intelligence Engine plugin system
   - Primary caller: `CharacterAnalyzer`

2. **`EveDmv.IntelligenceMigrationAdapter`** (`lib/eve_dmv/intelligence_migration_adapter.ex`)
   - Routes `IntelligenceEngine` calls to bounded context implementations
   - Callers: `IntelligenceEngine`, `Pipeline`, `StatsGenerator`, `CacheWarmer`

## Current State Analysis

### Adapter 1: LegacyAdapter

**File:** `lib/eve_dmv/core/infrastructure/legacy_adapter.ex`

**Functions provided:**
- `analyze_character/1` - Single character analysis
- `analyze_characters/1` - Batch character analysis
- `analyze_corporation/1` - Corporation analysis
- `analyze_fleet/1` - Fleet analysis
- `analyze_threat/2` - Threat analysis
- `invalidate_character_cache/1` - Cache invalidation
- `get_comprehensive_character_analysis/1` - Full character analysis

**Current callers:**

| File | Usage |
|------|-------|
| `lib/eve_dmv/contexts/character_intelligence/domain/analyzers/character_analyzer.ex` | `analyze_character/1`, `analyze_characters/1`, `get_comprehensive_character_analysis/1`, `invalidate_character_cache/1` |

### Adapter 2: IntelligenceMigrationAdapter

**File:** `lib/eve_dmv/intelligence_migration_adapter.ex`

**Functions provided:**
- `analyze/3` - Generic entity analysis routing
- `batch_analyze/3` - Batch analysis
- `invalidate_cache/2` - Cache invalidation routing
- `should_migrate?/2` - Migration check
- `get_migration_status/0` - Status reporting

**Current callers:**

| File | Usage |
|------|-------|
| `lib/eve_dmv/intelligence_engine.ex:20` | `analyze/3` |
| `lib/eve_dmv/intelligence_engine.ex:30` | `invalidate_cache/2` |
| `lib/eve_dmv/intelligence_engine/pipeline.ex:81` | `analyze/3` |
| `lib/eve_dmv/player_profile/stats_generator.ex:23` | `analyze/3` |
| `lib/eve_dmv/platform/database/cache_warmer.ex:333,389` | `analyze/3` |

---

## Implementation Plan

### Phase 1: Migrate CharacterAnalyzer (LegacyAdapter removal)

**Goal:** Update `CharacterAnalyzer` to call bounded context APIs directly instead of through `LegacyAdapter`.

#### Step 1.1: Identify Target APIs

The `LegacyAdapter` currently routes to `IntelligenceEngine.analyze/3`. The target bounded context APIs are:

| IntelligenceMigrationAdapter Function | Target Bounded Context API |
|---------------------------------------|---------------------------|
| `analyze/3` | Routes to context-specific analyzers based on domain parameter |
| `batch_analyze/3` | Batch wrapper around context-specific analyzers |
| `analyze_character/2` (private, `scope: :full`) | `PlayerAnalyzer.analyze_character/2` with `scope: :full` |
| `invalidate_cache/2` | Dispatches to `invalidate_character_cache/1` → `EveDmv.Contexts.CombatIntelligence.Infrastructure.AnalysisCache` + `EveDmv.Contexts.ThreatAssessment.Infrastructure.ThreatCache` |

#### Step 1.2: Update CharacterAnalyzer

**File:** `lib/eve_dmv/contexts/character_intelligence/domain/analyzers/character_analyzer.ex`

**Changes required:**

```elixir
# BEFORE
alias EveDmv.Intelligence.LegacyAdapter

def analyze(character_id), do: LegacyAdapter.analyze_character(character_id)

# AFTER
alias EveDmv.Contexts.PlayerProfile.Domain.PlayerAnalyzer
alias EveDmv.Contexts.CombatIntelligence.Infrastructure.AnalysisCache
alias EveDmv.Contexts.ThreatAssessment.Infrastructure.ThreatCache

def analyze(character_id) do
  case PlayerAnalyzer.analyze_character(character_id, scope: :basic) do
    {:ok, analysis} -> {:ok, transform_to_character_format(analysis)}
    error -> error
  end
end
```

#### Step 1.3: Add Format Transformation

Move the format transformation logic from `LegacyAdapter.convert_to_legacy_character_format/1` into `CharacterAnalyzer` or a dedicated formatter module.

#### Step 1.4: Update Cache Invalidation

```elixir
# BEFORE
def invalidate_cache(character_id), do: LegacyAdapter.invalidate_character_cache(character_id)

# AFTER
def invalidate_cache(character_id) do
  AnalysisCache.invalidate_character(character_id)
  AnalysisCache.invalidate_threat_assessment(character_id)
  AnalysisCache.invalidate_intelligence_scores(character_id)
  ThreatCache.invalidate_entity(character_id, :character)
  :ok
end
```

#### Step 1.5: Remove LegacyAdapter

After all callers are updated:
1. Delete `lib/eve_dmv/core/infrastructure/legacy_adapter.ex`
2. Run full test suite to verify no regressions

---

### Phase 2: Migrate IntelligenceEngine Callers (IntelligenceMigrationAdapter removal)

**Goal:** Update all callers of `IntelligenceEngine` to use bounded context APIs directly.

#### Step 2.1: Update IntelligenceEngine

**File:** `lib/eve_dmv/intelligence_engine.ex`

#### Option A: Remove entirely

(Recommended if no external consumers)

- Delete the module and update all callers to use bounded context APIs directly

#### Option B: Make it a thin facade
- Keep `IntelligenceEngine` but have it call bounded contexts directly without the adapter

```elixir
# BEFORE
def analyze(domain, entity_id, opts \\ []) do
  IntelligenceMigrationAdapter.analyze(domain, entity_id, opts)
end

# AFTER (Option B)
def analyze(:character, character_id, opts) do
  PlayerAnalyzer.analyze_character(character_id, opts)
end

def analyze(:corporation, corporation_id, opts) do
  CorporationAnalyzer.analyze_corporation(corporation_id, opts)
end

def analyze(:fleet, fleet_id, opts) do
  FleetAnalyzer.analyze_composition(%{fleet_id: fleet_id})
end

def analyze(:threat, entity_id, opts) do
  entity_type = Keyword.get(opts, :entity_type, :character)
  ThreatAnalyzer.assess_threat(entity_id, entity_type)
end
```

#### Step 2.2: Update Pipeline

**File:** `lib/eve_dmv/intelligence_engine/pipeline.ex`

Update line 81 to call bounded context APIs directly:

```elixir
# BEFORE
case EveDmv.IntelligenceMigrationAdapter.analyze(domain, entity_id, [scope: scope] ++ opts) do

# AFTER
case analyze_via_bounded_context(domain, entity_id, [scope: scope] ++ opts) do

# Add private function
defp analyze_via_bounded_context(:character, entity_id, opts) do
  PlayerAnalyzer.analyze_character(entity_id, opts)
end
# ... other domains
```

#### Step 2.3: Update StatsGenerator

**File:** `lib/eve_dmv/player_profile/stats_generator.ex`

```elixir
# BEFORE
alias EveDmv.IntelligenceMigrationAdapter

case IntelligenceMigrationAdapter.analyze(:character, character_id, scope: :standard) do

# AFTER
alias EveDmv.Contexts.PlayerProfile.Domain.PlayerAnalyzer

case PlayerAnalyzer.analyze_character(character_id, scope: :standard) do
```

#### Step 2.4: Update CacheWarmer

**File:** `lib/eve_dmv/platform/database/cache_warmer.ex`

```elixir
# BEFORE
alias EveDmv.IntelligenceMigrationAdapter

case IntelligenceMigrationAdapter.analyze(:character, character_id, scope: :basic) do

# AFTER
alias EveDmv.Contexts.PlayerProfile.Domain.PlayerAnalyzer

case PlayerAnalyzer.analyze_character(character_id, scope: :basic) do
```

#### Step 2.5: Remove IntelligenceMigrationAdapter

After all callers are updated:
1. Delete `lib/eve_dmv/intelligence_migration_adapter.ex`
2. Run full test suite to verify no regressions

---

### Phase 3: Cleanup and Verification

#### Step 3.1: Remove Unused Modules

If `IntelligenceEngine` is no longer needed:
1. Delete `lib/eve_dmv/intelligence_engine.ex`
2. Delete `lib/eve_dmv/intelligence_engine/` directory if empty

#### Step 3.2: Update Documentation

1. Update `ARCHITECTURE.md` to reflect the new direct bounded context usage
2. Remove references to migration adapters from `CLAUDE.md` if any

#### Step 3.3: Run Quality Checks

```bash
mix compile --warnings-as-errors
mix credo --strict
mix dialyzer
mix test --cover
```

---

## Bounded Context API Reference

### PlayerProfile Context

```elixir
# Character analysis
EveDmv.Contexts.PlayerProfile.Domain.PlayerAnalyzer.analyze_character(character_id, opts)
# Options: scope: :basic | :standard | :full
# Returns: {:ok, analysis_map} | {:error, reason}
```

### Corporation Context

```elixir
# Corporation analysis
EveDmv.Contexts.Corporation.Core.CorporationAnalyzer.analyze_corporation(corporation_id, opts)
# Options: scope: :basic | :standard | :full
# Returns: {:ok, analysis_map} | {:error, reason}
```

### FleetOperations Context

```elixir
# Fleet composition analysis
EveDmv.Contexts.FleetOperations.Domain.FleetAnalyzer.analyze_composition(fleet_data)
# Returns: {:ok, analysis_map} | {:error, reason}
```

### ThreatAssessment Context

```elixir
# Threat analysis
EveDmv.Contexts.ThreatAssessment.Domain.ThreatAnalyzer.assess_threat(entity_id, entity_type)
# entity_type: :character | :corporation
# Returns: {:ok, analysis_map} | {:error, reason}
```

### Cache Infrastructure

```elixir
# Combat Intelligence cache
EveDmv.Contexts.CombatIntelligence.Infrastructure.AnalysisCache
  .invalidate_character(character_id)
  .invalidate_corporation(corporation_id)
  .invalidate_threat_assessment(entity_id)
  .invalidate_intelligence_scores(entity_id)

# Threat Assessment cache
EveDmv.Contexts.ThreatAssessment.Infrastructure.ThreatCache
  .invalidate_entity(entity_id, entity_type)
```

---

## Risk Assessment

### Low Risk

- Format transformation logic is well-documented in adapters
- Bounded context APIs already exist and are tested
- Migration can be done incrementally

### Medium Risk

- Some callers may depend on specific legacy format fields
- Cache invalidation may need coordination across contexts

### Mitigation Strategies
1. Add comprehensive tests before migration
2. Use feature flags if needed for gradual rollout
3. Keep adapters in place until all tests pass with direct calls

---

## Estimated Effort

| Phase | Estimated Effort | Dependencies |
|-------|------------------|--------------|
| Phase 1: CharacterAnalyzer | 2-4 hours | None |
| Phase 2: IntelligenceEngine callers | 3-5 hours | Phase 1 |
| Phase 3: Cleanup | 1-2 hours | Phase 2 |
| **Total** | **6-11 hours** | |

---

## Success Criteria

1. All tests pass without migration adapters
2. No runtime errors in production
3. No performance regression in analysis operations
4. Code coverage maintained or improved
5. Dialyzer passes with no new warnings
6. Both adapter files are deleted from the codebase

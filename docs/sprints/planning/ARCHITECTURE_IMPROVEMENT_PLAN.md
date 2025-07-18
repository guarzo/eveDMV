# EVE DMV Architecture Improvement Plan

## Current State Analysis

**Structure Issues Identified:**
- Deep nesting: `contexts/*/domain/*` creates 4+ level hierarchies  
- Excessive modularity: 350+ files for a single-app domain
- Duplicated concepts: Multiple analyzers, engines, and services doing similar work
- Configuration sprawl: 7 separate config modules in `config/`
- Utility fragmentation: Small utils spread across multiple directories

**What's Working Well:**
- Ash Framework provides good domain boundaries
- Clear separation of web/business logic
- Comprehensive test coverage
- Good documentation structure

## Recommended Improvements

### Phase 1: Flatten Deep Hierarchies (Week 1)
**Target: Reduce nesting from 4+ levels to max 2 levels**

```
# BEFORE
lib/eve_dmv/contexts/character_intelligence/domain/threat_scoring/engines/combat_threat_engine.ex

# AFTER  
lib/eve_dmv/intelligence/combat_threat_engine.ex
```

**Actions:**
- [ ] Flatten `contexts/*/domain/*` → `contexts/*`
- [ ] Move `contexts/*/infrastructure/*` → `contexts/*/infra`
- [ ] Consolidate `contexts/*/analyzers/*` into main context files
- [ ] Remove single-file directories

### Phase 2: Consolidate Similar Modules (Week 1-2)
**Target: Reduce module count by ~30% through consolidation**

**Merge Candidates:**
- `analytics/` + `intelligence/analyzers/` → `analytics/`
- `database/query_*` modules → `database/queries.ex`
- `config/*` → `config.ex` (single unified config)
- `utils/*` → `shared/utils.ex`
- `cache/` + `cache_*` files → `cache.ex`

### Phase 3: Add Boundary Enforcement (Week 2)
**Target: Prevent circular dependencies and enforce clean architecture**

```elixir
# Add to mix.exs
{:boundary, "~> 0.10", runtime: false}
```

**Boundary Definitions:**
```elixir
# In each major context module
use Boundary,
  deps: [EveDmv.Repo, EveDmv.Api],
  exports: [PublicAPI]
```

### Phase 4: Streamline Configuration (Week 2)
**Target: Single source of truth for configuration**

```elixir
# Before: 7 separate config modules
config/api.ex, config/cache.ex, config/http.ex, etc.

# After: Unified configuration
lib/eve_dmv/config.ex
```

### Phase 5: Extract Reusable Libraries (Week 3)
**Target: Identify truly reusable components for potential extraction**

**Extract Only If:**
- Used by multiple contexts AND
- Has no EVE DMV-specific business logic AND  
- Could benefit other Elixir projects

**Candidates:**
- `eve/esi_client.ex` → `esi_client` package
- `performance/query_monitor.ex` → `ecto_performance` package

## Detailed Restructuring Plan

### New Directory Structure

```
lib/eve_dmv/
├── analytics/           # Consolidate all analysis engines
│   ├── battle_analyzer.ex
│   ├── fleet_analyzer.ex
│   ├── ship_analyzer.ex
│   └── player_analyzer.ex
├── intelligence/        # Character & corp intelligence
│   ├── character_intelligence.ex
│   ├── corporation_intelligence.ex
│   ├── threat_scoring.ex
│   └── behavioral_analysis.ex
├── surveillance/        # Monitoring & alerting
│   ├── profile_manager.ex
│   ├── matching_engine.ex
│   └── notification_service.ex
├── killmails/          # Killmail processing pipeline
│   ├── pipeline.ex
│   ├── processor.ex
│   └── enrichment.ex
├── market/             # Market data & pricing
│   ├── pricing_service.ex
│   ├── janice_client.ex
│   └── valuation.ex
├── eve/               # EVE API integration
│   ├── esi_client.ex
│   ├── static_data.ex
│   └── name_resolver.ex
├── database/          # Data layer
│   ├── repo.ex
│   ├── queries.ex
│   ├── performance.ex
│   └── partitions.ex
├── shared/            # Common utilities
│   ├── cache.ex
│   ├── utils.ex
│   └── config.ex
└── users/             # Authentication
    ├── user.ex
    └── token.ex
```

### Migration Steps

#### Week 1: Core Restructuring
```bash
# 1. Flatten contexts
git mv lib/eve_dmv/contexts/character_intelligence/domain/* lib/eve_dmv/intelligence/
git mv lib/eve_dmv/contexts/surveillance/domain/* lib/eve_dmv/surveillance/
git mv lib/eve_dmv/contexts/killmail_processing/domain/* lib/eve_dmv/killmails/

# 2. Consolidate configs
cat lib/eve_dmv/config/*.ex > lib/eve_dmv/config.ex
rm -rf lib/eve_dmv/config/

# 3. Merge analytics
git mv lib/eve_dmv/intelligence/analyzers/* lib/eve_dmv/analytics/
```

#### Week 2: Module Consolidation
```bash
# 1. Add boundary checking
echo '{:boundary, "~> 0.10", runtime: false}' >> mix.exs

# 2. Consolidate utilities
cat lib/eve_dmv/utils/*.ex > lib/eve_dmv/shared/utils.ex
rm -rf lib/eve_dmv/utils/

# 3. Merge database modules
# Manual consolidation of query_* files into queries.ex
```

#### Week 3: Testing & Cleanup
```bash
# 1. Update all imports/aliases
# 2. Run comprehensive test suite
# 3. Update documentation
# 4. Performance benchmarking
```

## Success Metrics

- **Module Count**: Reduce from 350+ to ~200 files
- **Max Directory Depth**: From 5+ levels to 2 levels
- **Build Time**: Target 20% improvement
- **Circular Dependencies**: Zero (enforced by boundary)
- **Import Complexity**: Reduce average import statements per file

## Risk Mitigation

1. **Incremental Changes**: Each phase can be committed separately
2. **Comprehensive Testing**: Run full test suite after each major move
3. **Git History**: Preserve file history with `git mv`
4. **Rollback Plan**: Each phase is a separate branch for easy reversion
5. **Documentation**: Update module references immediately after moves

## Implementation Commands

```bash
# Phase 1: Setup boundary checking
mix deps.get boundary

# Phase 2: Create new structure (example)
mkdir -p lib/eve_dmv/{analytics,intelligence,surveillance}
mkdir -p lib/eve_dmv/{killmails,market,shared}

# Phase 3: Mass file moves (use git mv to preserve history)
git mv lib/eve_dmv/contexts/character_intelligence/domain/threat_scoring_engine.ex \
       lib/eve_dmv/intelligence/threat_scoring.ex

# Phase 4: Update module names (use global find/replace)
find lib -name "*.ex" -exec sed -i 's/EveDmv.Contexts.CharacterIntelligence/EveDmv.Intelligence/g' {} \;

# Phase 5: Verify no broken imports
mix compile --warnings-as-errors
```

## Timeline

- **Week 1**: Core restructuring and flattening
- **Week 2**: Module consolidation and boundary enforcement  
- **Week 3**: Testing, cleanup, and documentation updates

**Total estimated effort: 3 weeks with 1 developer**

**Benefits:**
- Simpler mental model for developers
- Faster navigation and file discovery
- Reduced cognitive load from deep nesting
- Enforced architectural boundaries
- Better module cohesion

This plan maintains your current Ash-based architecture while dramatically simplifying the folder structure and reducing unnecessary complexity.
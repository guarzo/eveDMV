# Detailed File Organization Issues

## Duplicate Functionality Analysis

### 1. Analyzer Proliferation

Found 12 separate `analyzers` directories with overlapping functionality:

```
1. contexts/battle_analysis/analyzers/
2. contexts/character_intelligence/analyzers/
3. contexts/combat_intelligence/domain/analyzers/
4. contexts/corporation_analysis/analyzers/
5. contexts/corporation_intelligence/domain/analyzers/
6. contexts/fleet_operations/analyzers/
7. contexts/intelligence_infrastructure/domain/analyzers/
8. contexts/player_profile/analyzers/
9. contexts/threat_assessment/analyzers/
10. contexts/wormhole_operations/domain/analyzers/
11. utilities/analyzers/
12. platform/monitoring/metrics/ (contains analyzer-like modules)
```

**Duplicate Examples:**
- `character_analyzer.ex` appears in 3 locations
- `fleet_analyzer.ex` in multiple contexts
- Ship analysis spread across 5+ modules

### 2. Cache Implementation Chaos

Multiple cache implementations without clear hierarchy:

```
├── cache.ex (top level)
├── cache/ (top level directory)
├── platform/cache/
│   ├── analysis_cache.ex
│   ├── intelligence/
│   │   ├── analysis_cache.ex (duplicate!)
│   │   └── intelligence_cache.ex
│   ├── query_cache.ex
│   └── static_data_cache.ex
├── contexts/combat_intelligence/infrastructure/analysis_cache.ex
├── contexts/corporation_analysis/infrastructure/analysis_cache.ex
├── external/eve/esi_cache.ex
├── external/market/price_cache.ex
```

### 3. Repository Pattern Inconsistency

Repositories scattered across different patterns:

```
├── platform/database/
│   ├── character_repository.ex
│   ├── killmail_repository.ex
│   └── surveillance_repository.ex
├── contexts/corporation_analysis/infrastructure/corporation_repository.ex
├── contexts/fleet_operations/infrastructure/fleet_repository.ex
├── contexts/surveillance/infrastructure/profile_repository.ex
├── contexts/wormhole_operations/infrastructure/vetting_repository.ex
```

### 4. Event Handling Fragmentation

Event-related code spread across:

```
├── domain_events.ex
├── core/infrastructure/events.ex
├── core/infrastructure/event_publisher.ex
├── infrastructure/event_bus.ex
├── infrastructure/event_bus_supervisor.ex
├── contexts/killmail_processing/infrastructure/event_publisher.ex
├── contexts/surveillance/domain/chain_analysis/chain_event_handlers.ex
```

### 5. Backup and Temporary Files

Files that should be removed:
```
1. static_data/ship_types.ex.backup
2. combat_intelligence/domain/extractors/participant_extractor.ex.backup
3. intelligence_infrastructure/domain/cross_system_analyzer/activity_correlator.ex.backup
4. intelligence_infrastructure/domain/cross_system_analyzer/monitoring_engine.ex.backup
5. intelligence_infrastructure/domain/cross_system_analyzer/monitoring_engine.ex.bak
```

### 6. Confusing Context Boundaries

#### Combat-related contexts (3 separate contexts for similar functionality):
- `battle_analysis/` - Has battle detection, metrics, timeline
- `combat_analysis/` - Has battle detection, character analysis, threat assessment
- `combat_intelligence/` - Has battle analysis, fleet analysis, intelligence scoring

#### Character-related contexts (2 overlapping contexts):
- `character_intelligence/` - Threat scoring, player stats
- `player_profile/` - Combat stats, ship preferences

#### Corporation-related contexts (2 duplicate contexts):
- `corporation_analysis/` - Member activity, participation
- `corporation_intelligence/` - Member activity (again!), risk assessment

#### Threat-related contexts (2 overlapping contexts):
- `threat_assessment/` - Threat analysis, vulnerability scanning
- `threat_surveillance/` - Threat analysis (again!), behavioral patterns

### 7. Inconsistent Directory Depths

Deepest paths found:
```
8 levels: lib/eve_dmv/contexts/character_intelligence/domain/threat_scoring/threat_scoring_coordinator/generators/
7 levels: lib/eve_dmv/contexts/intelligence_infrastructure/domain/cross_system_analyzer/
7 levels: lib/eve_dmv/platform/database/query_plan_analyzer/
6 levels: lib/eve_dmv/external/eve/static_data_loader/
```

### 8. Utility Sprawl

Utility/helper modules in multiple locations:
```
├── utilities/
│   ├── analyzers/
│   ├── calculators/
│   ├── formatters/
│   ├── generators/
│   └── query_helpers/
├── utils/
│   ├── fleet_utils.ex
│   ├── killmail_utils.ex
│   └── surveillance_utils.ex
├── shared_kernel/
├── core/domain/intelligence/core/ (has helpers)
```

### 9. Infrastructure vs Platform Confusion

Two top-level directories with overlapping concerns:
```
├── infrastructure/
│   └── event_bus related files
├── platform/
│   ├── auth/
│   ├── cache/
│   ├── database/
│   ├── monitoring/
│   └── workers/
```

### 10. Naming Inconsistencies

Different naming patterns for similar concepts:
- `*_analyzer.ex` vs `*_analysis.ex` vs `*_analytics.ex`
- `*_service.ex` vs `*_manager.ex` vs `*_engine.ex`
- `*_calculator.ex` vs `*_calculation.ex`
- Some contexts use `domain/`, others don't
- Some have `api.ex`, others don't

## Impact Analysis

### Development Velocity Impact
- **Finding code**: Developers waste time searching across multiple locations
- **Making changes**: Need to update multiple files for single feature
- **Code reviews**: Difficult to ensure changes don't break duplicate functionality

### Testing Impact
- Duplicate test files for duplicate functionality
- Hard to achieve good test coverage with scattered code
- Integration tests become complex with unclear boundaries

### Performance Impact
- Multiple cache implementations may conflict
- Duplicate queries to database
- Inefficient module loading with deep nesting

### Onboarding Impact
- New developers confused by multiple ways to do same thing
- No clear pattern to follow
- Documentation becomes outdated quickly

## Recommended Immediate Actions

1. **Delete backup files** (5 files) - No risk, immediate cleanup
2. **Consolidate analyzers** - Move to respective context core modules
3. **Unify cache strategy** - Single cache module with clear interfaces
4. **Merge duplicate contexts** - Start with corporation contexts
5. **Flatten deep nesting** - Max 4 levels from lib/eve_dmv/
# File Organization Improvement Plan

## Executive Summary

After reviewing the refactored codebase, I've identified significant organizational issues that need addressing:
- **12 separate `analyzers` directories** scattered across contexts
- **17 `domain` directories** with inconsistent structures
- **5 backup files** (`.ex.backup`, `.ex.bak`) that should be removed
- **Overlapping contexts** with unclear boundaries
- **Inconsistent naming patterns** and directory depths
- **Duplicate functionality** across multiple modules

## Current Issues

### 1. Context Overlap and Confusion

Multiple contexts handle similar responsibilities:
- `battle_analysis`, `combat_analysis`, `combat_intelligence` - all analyze battles
- `character_intelligence`, `player_profile` - both analyze characters
- `threat_assessment`, `threat_surveillance` - overlapping threat functionality
- `corporation_analysis`, `corporation_intelligence` - duplicate corporation logic

### 2. Inconsistent Structure Patterns

Different organizational approaches used simultaneously:
```
contexts/
├── battle_analysis/
│   ├── domain/       # DDD pattern
│   ├── api.ex        # Context API
│   └── resources/    # Ash resources
├── player_profile/   # No domain directory
│   ├── analyzers/
│   └── formatters/
core/                 # Separate core directory
platform/            # Infrastructure concerns
utilities/           # Utility modules
```

### 3. Scattered Functionality

Similar modules exist in multiple locations:
- Cache implementations in: `cache/`, `platform/cache/`, `contexts/*/infrastructure/`
- Analyzers in 12 different directories
- Repository pattern inconsistently applied
- Event handling spread across multiple locations

### 4. Deep Nesting

Some paths are excessively deep:
```
lib/eve_dmv/contexts/intelligence_infrastructure/domain/cross_system_analyzer/
lib/eve_dmv/platform/telemetry/performance_monitor/
lib/eve_dmv/external/eve/static_data_loader/
```

## Proposed Structure

### Phase 1: Clean Architecture with Clear Boundaries

```
lib/eve_dmv/
├── contexts/                    # Business domains (bounded contexts)
│   ├── combat/                  # Unified combat analysis
│   │   ├── core/               # Domain logic
│   │   │   ├── battle_detector.ex
│   │   │   ├── battle_analyzer.ex
│   │   │   ├── timeline_builder.ex
│   │   │   └── participant_analyzer.ex
│   │   ├── services/           # Application services
│   │   │   ├── battle_service.ex
│   │   │   ├── zkillboard_importer.ex
│   │   │   └── combat_log_parser.ex
│   │   ├── resources/          # Ash resources
│   │   │   ├── battle.ex
│   │   │   ├── combat_log.ex
│   │   │   └── ship_fitting.ex
│   │   └── api.ex              # Public context API
│   │
│   ├── intelligence/            # Character & threat intelligence
│   │   ├── core/
│   │   │   ├── threat_scorer.ex
│   │   │   ├── character_analyzer.ex
│   │   │   └── pattern_detector.ex
│   │   ├── services/
│   │   │   ├── threat_service.ex
│   │   │   └── comparison_service.ex
│   │   └── api.ex
│   │
│   ├── surveillance/            # System monitoring & alerts
│   │   ├── core/
│   │   │   ├── profile_matcher.ex
│   │   │   ├── alert_manager.ex
│   │   │   └── chain_monitor.ex
│   │   ├── services/
│   │   │   ├── notification_service.ex
│   │   │   └── wanderer_integration.ex
│   │   └── api.ex
│   │
│   ├── fleet/                   # Fleet operations & doctrine
│   │   ├── core/
│   │   │   ├── doctrine_manager.ex
│   │   │   ├── composition_analyzer.ex
│   │   │   └── readiness_calculator.ex
│   │   └── api.ex
│   │
│   ├── corporation/             # Corporation management
│   │   ├── core/
│   │   │   ├── member_analyzer.ex
│   │   │   ├── activity_tracker.ex
│   │   │   └── risk_assessor.ex
│   │   └── api.ex
│   │
│   └── wormhole/               # Wormhole-specific operations
│       ├── core/
│       │   ├── mass_calculator.ex
│       │   ├── chain_mapper.ex
│       │   └── home_defender.ex
│       └── api.ex
│
├── infrastructure/              # External integrations & technical concerns
│   ├── eve_api/                # EVE API clients
│   │   ├── esi_client.ex
│   │   ├── circuit_breaker.ex
│   │   └── name_resolver.ex
│   ├── killmail_pipeline/      # Broadway pipeline
│   │   ├── producer.ex
│   │   ├── processor.ex
│   │   └── pipeline.ex
│   ├── persistence/            # Database layer
│   │   ├── repositories/
│   │   ├── queries/
│   │   └── migrations/
│   ├── cache/                  # Unified caching
│   │   ├── cache_manager.ex
│   │   └── strategies/
│   └── monitoring/             # Telemetry & monitoring
│       ├── telemetry.ex
│       └── health_checks.ex
│
├── web_interface/              # Phoenix web layer adapters
│   ├── character_view_adapter.ex
│   ├── battle_view_adapter.ex
│   └── surveillance_view_adapter.ex
│
├── shared/                     # Shared kernel
│   ├── value_objects/          # Domain value objects
│   ├── domain_events.ex        # Event definitions
│   └── calculations/           # Shared calculations
│
├── application.ex              # OTP application
├── repo.ex                     # Ecto repo
└── config.ex                   # Runtime configuration
```

### Phase 2: Consolidation Steps

#### Step 1: Remove Redundancy (Week 1)
1. Delete all backup files (`.ex.backup`, `.ex.bak`)
2. Merge overlapping contexts:
   - `battle_analysis` + `combat_analysis` + `combat_intelligence` → `combat`
   - `character_intelligence` + `player_profile` → `intelligence`
   - `threat_assessment` + `threat_surveillance` → `surveillance`
   - `corporation_analysis` + `corporation_intelligence` → `corporation`
3. Consolidate duplicate analyzers into context-specific core modules

#### Step 2: Flatten Structure (Week 2)
1. Remove unnecessary nesting (max 4 levels deep)
2. Move all `domain/` contents up one level
3. Standardize on `core/` for domain logic, `services/` for application services
4. Extract all infrastructure code to top-level `infrastructure/`

#### Step 3: Establish Clear Boundaries (Week 3)
1. Create explicit context APIs (`api.ex` files)
2. Remove cross-context direct dependencies
3. Use domain events for inter-context communication
4. Move shared logic to `shared/` directory

#### Step 4: Infrastructure Separation (Week 4)
1. Extract all external integrations to `infrastructure/`
2. Consolidate caching strategies
3. Unify repository patterns
4. Centralize event handling

## Migration Strategy

### 1. Create Migration Scripts
```bash
# Script to track all imports and exports
mix eve.analyze_dependencies

# Script to safely move files with git history
./scripts/reorganize_files.sh

# Script to update all import statements
mix eve.update_imports
```

### 2. Incremental Migration
- Migrate one context at a time
- Run full test suite after each migration
- Update documentation as you go
- Use feature flags for gradual rollout

### 3. Validation Checklist
- [ ] All tests pass
- [ ] No circular dependencies
- [ ] Max 4 levels of nesting
- [ ] Each context has clear API boundary
- [ ] No duplicate functionality
- [ ] Consistent naming patterns

## Naming Conventions

### Contexts
- Use business domain names (not technical names)
- Singular form: `combat`, not `combats`
- Clear, non-overlapping boundaries

### Modules
- `*Service` - Application services
- `*Repository` - Data access
- `*Client` - External API clients
- No `*Manager`, `*Helper`, `*Utils` suffixes (too vague)

### Files
- One module per file
- File name matches module name (snake_case)
- Group related modules in subdirectories

## Benefits

1. **Clearer Architecture** - Obvious where code belongs
2. **Better Maintainability** - Less duplication, clearer dependencies
3. **Improved Testing** - Isolated contexts are easier to test
4. **Faster Development** - Developers can find code quickly
5. **Easier Onboarding** - New developers understand structure immediately

## Metrics for Success

- Reduce directory depth from 7+ to max 4 levels
- Reduce analyzer directories from 12 to 6 (one per context)
- Eliminate all backup files
- Achieve 100% context API coverage
- Zero circular dependencies between contexts

## Timeline

- **Week 1**: Remove redundancy and backup files
- **Week 2**: Flatten directory structure
- **Week 3**: Establish context boundaries
- **Week 4**: Separate infrastructure concerns
- **Week 5**: Update documentation and create developer guide
- **Week 6**: Team training and knowledge transfer

## Risk Mitigation

1. **Git History**: Use `git mv` to preserve file history
2. **Import Updates**: Automated scripts to update all imports
3. **Testing**: Run full test suite after each change
4. **Rollback Plan**: Tag releases before each major change
5. **Team Communication**: Daily updates during migration

## Next Steps

1. Review and approve this plan
2. Create detailed migration scripts
3. Set up feature flags for gradual migration
4. Begin with the smallest context as proof of concept
5. Document lessons learned for future refactoring
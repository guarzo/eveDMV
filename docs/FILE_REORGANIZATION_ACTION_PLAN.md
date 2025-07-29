# File Reorganization Action Plan

## Phase 1: Immediate Cleanup (Day 1)

### Remove Backup Files
```bash
rm lib/eve_dmv/static_data/ship_types.ex.backup
rm lib/eve_dmv/contexts/combat_intelligence/domain/extractors/participant_extractor.ex.backup
rm lib/eve_dmv/contexts/intelligence_infrastructure/domain/cross_system_analyzer/activity_correlator.ex.backup
rm lib/eve_dmv/contexts/intelligence_infrastructure/domain/cross_system_analyzer/monitoring_engine.ex.backup
rm lib/eve_dmv/contexts/intelligence_infrastructure/domain/cross_system_analyzer/monitoring_engine.ex.bak
```

### Remove Empty/Archived Directories
```bash
rm -rf lib/eve_dmv/contexts/_archived_infrastructure/
```

## Phase 2: Context Consolidation (Week 1)

### Merge Combat Contexts

**From:** 3 separate contexts
```
contexts/battle_analysis/
contexts/combat_analysis/
contexts/combat_intelligence/
```

**To:** Single unified context
```
contexts/combat/
├── core/
│   ├── battle_detection.ex (from battle_analysis + combat_analysis)
│   ├── battle_analysis.ex (from combat_intelligence)
│   ├── battle_timeline.ex (from battle_analysis)
│   ├── participant_analysis.ex (consolidated from 3 sources)
│   ├── fleet_composition.ex (from combat_intelligence)
│   ├── tactical_patterns.ex (from multiple analyzers)
│   └── ship_performance.ex (from battle_analysis)
├── services/
│   ├── battle_service.ex (new unified service)
│   ├── zkillboard_import.ex (from battle_analysis)
│   ├── combat_log_parser.ex (from battle_analysis)
│   └── battle_sharing.ex (from combat_analysis)
├── resources/
│   ├── battle.ex
│   ├── battle_killmail.ex
│   ├── combat_log.ex
│   └── ship_fitting.ex
└── api.ex
```

### Merge Character/Player Contexts

**From:** 2 separate contexts
```
contexts/character_intelligence/
contexts/player_profile/
```

**To:** Single unified context
```
contexts/intelligence/
├── core/
│   ├── character_analysis.ex
│   ├── threat_scoring.ex
│   ├── combat_patterns.ex
│   ├── ship_preferences.ex
│   └── activity_metrics.ex
├── services/
│   ├── character_service.ex
│   ├── comparison_service.ex
│   └── threat_assessment.ex
└── api.ex
```

### Merge Corporation Contexts

**From:** 2 separate contexts
```
contexts/corporation_analysis/
contexts/corporation_intelligence/
```

**To:** Single unified context
```
contexts/corporation/
├── core/
│   ├── member_activity.ex
│   ├── participation_tracking.ex
│   ├── risk_assessment.ex
│   └── doctrine_analysis.ex
├── services/
│   ├── corporation_service.ex
│   └── activity_intelligence.ex
└── api.ex
```

## Phase 3: Infrastructure Extraction (Week 2)

### Move External Integrations

**From:**
```
external/eve/
external/killmails/
external/market/
external/wanderer/
```

**To:**
```
infrastructure/
├── eve_api/
│   ├── esi/
│   │   ├── client.ex
│   │   ├── character_client.ex
│   │   ├── corporation_client.ex
│   │   └── market_client.ex
│   ├── circuit_breaker.ex
│   ├── name_resolver.ex
│   └── static_data_loader.ex
├── killmail_pipeline/
│   ├── broadway_pipeline.ex
│   ├── sse_producer.ex
│   ├── processor.ex
│   └── enrichment.ex
├── market_data/
│   ├── janice_client.ex
│   ├── price_service.ex
│   └── valuation.ex
└── wanderer_integration/
    ├── sse_client.ex
    └── chain_sync.ex
```

### Consolidate Cache Layer

**From:** Multiple cache implementations
**To:**
```
infrastructure/cache/
├── cache_manager.ex (main interface)
├── strategies/
│   ├── ets_cache.ex
│   ├── redis_cache.ex
│   └── memory_cache.ex
├── adapters/
│   ├── analysis_cache.ex
│   ├── static_data_cache.ex
│   └── query_cache.ex
└── cache_warmer.ex
```

### Unify Database Layer

**From:** Scattered database modules
**To:**
```
infrastructure/persistence/
├── repositories/
│   ├── base_repository.ex (shared behavior)
│   ├── killmail_repository.ex
│   ├── character_repository.ex
│   ├── corporation_repository.ex
│   └── surveillance_repository.ex
├── queries/
│   ├── killmail_queries.ex
│   ├── character_queries.ex
│   └── performance_queries.ex
├── optimization/
│   ├── partition_manager.ex
│   ├── materialized_views.ex
│   └── query_analyzer.ex
└── migrations/
```

## Phase 4: Shared Kernel Creation (Week 3)

### Extract Common Domain Concepts
```
shared/
├── domain/
│   ├── value_objects/
│   │   ├── character_id.ex
│   │   ├── corporation_id.ex
│   │   ├── solar_system.ex
│   │   └── isk_amount.ex
│   ├── calculations/
│   │   ├── efficiency_calculator.ex
│   │   ├── mass_calculator.ex
│   │   └── threat_calculator.ex
│   └── events/
│       ├── killmail_received.ex
│       ├── battle_detected.ex
│       └── alert_triggered.ex
├── ship_classification.ex
├── time_utils.ex
└── math_utils.ex
```

## Phase 5: Flatten Deep Nesting (Week 4)

### Before:
```
contexts/character_intelligence/domain/threat_scoring/threat_scoring_coordinator/generators/comparison_engine.ex
```

### After:
```
contexts/intelligence/core/threat_comparison.ex
```

### General Rules:
- Max 4 levels from `lib/eve_dmv/`
- Combine related modules into single files where appropriate
- Use module namespacing instead of directory nesting

## Migration Scripts

### 1. Dependency Analysis Script
```elixir
# lib/mix/tasks/eve.analyze_dependencies.ex
defmodule Mix.Tasks.Eve.AnalyzeDependencies do
  use Mix.Task
  
  def run(_) do
    # Analyze all module dependencies
    # Generate dependency graph
    # Identify circular dependencies
    # Output report
  end
end
```

### 2. Safe Move Script
```bash
#!/bin/bash
# scripts/safe_move.sh
# Safely moves files preserving git history and updating imports

OLD_PATH=$1
NEW_PATH=$2

# Create new directory if needed
mkdir -p $(dirname $NEW_PATH)

# Move with git
git mv $OLD_PATH $NEW_PATH

# Update imports in all Elixir files
find lib test -name "*.ex" -o -name "*.exs" | xargs sed -i "s|${OLD_PATH}|${NEW_PATH}|g"
```

### 3. Import Update Script
```elixir
# lib/mix/tasks/eve.update_imports.ex
defmodule Mix.Tasks.Eve.UpdateImports do
  use Mix.Task
  
  @import_mappings %{
    "EveDmv.Analytics" => "EveDmv.Contexts.Combat",
    "EveDmv.Intelligence" => "EveDmv.Contexts.Intelligence",
    # ... more mappings
  }
  
  def run(_) do
    # Update all alias statements
    # Update all module references
    # Verify no broken imports
  end
end
```

## Validation Steps

After each phase:
1. Run full test suite: `mix test`
2. Check for compilation warnings: `mix compile --warnings-as-errors`
3. Verify no circular dependencies: `mix eve.analyze_dependencies`
4. Run dialyzer: `mix dialyzer`
5. Check credo: `mix credo --strict`

## Rollback Plan

1. Tag before each phase: `git tag pre-phase-X`
2. Create feature branch for each phase
3. Merge only after all tests pass
4. Keep mapping of old → new paths for quick reference

## Success Metrics

- [ ] 0 backup files
- [ ] Max 4 directory levels
- [ ] 6 or fewer top-level contexts
- [ ] Single cache implementation
- [ ] All tests passing
- [ ] No increase in compilation warnings
- [ ] Improved module cohesion scores
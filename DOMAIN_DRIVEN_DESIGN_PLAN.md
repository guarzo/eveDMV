# Domain-Driven Design Implementation Plan

## Overview

This plan outlines the implementation of Domain-Driven Design (DDD) boundaries to create clear bounded contexts in the EVE DMV codebase. The goal is to improve modularity, reduce coupling, and establish clear domain boundaries.

## Identified Bounded Contexts

### 1. **Killmail Processing Context**
**Purpose**: Real-time ingestion and enrichment of EVE Online killmail data
**Core Aggregates**: 
- KillmailRaw
- KillmailEnriched
- Participant

**Domain Services**:
- KillmailPipeline
- EnrichmentService
- DataTransformer

### 2. **Combat Intelligence Context**
**Purpose**: Tactical analysis and intelligence generation
**Core Aggregates**:
- CharacterIntelligence
- CorporationAnalytics
- ThreatAssessment

**Domain Services**:
- CharacterAnalyzer
- CorporationAnalyzer
- ThreatAnalyzer

### 3. **Fleet Operations Context**
**Purpose**: Fleet composition analysis and effectiveness metrics
**Core Aggregates**:
- FleetComposition
- DoctrineCompliance
- FleetEffectiveness

**Domain Services**:
- FleetAnalyzer
- DoctrineValidator
- EffectivenessCalculator

### 4. **Wormhole Operations Context**
**Purpose**: Wormhole-specific tactics and chain management
**Core Aggregates**:
- ChainTopology
- WHVetting
- MassCalculation

**Domain Services**:
- ChainMonitor
- VettingAnalyzer
- WormholeCompatibilityChecker

### 5. **Surveillance Context**
**Purpose**: Real-time threat monitoring and alerting
**Core Aggregates**:
- SurveillanceProfile
- MatchResult
- Notification

**Domain Services**:
- MatchingEngine
- NotificationService
- FilterProcessor

### 6. **Market Intelligence Context**
**Purpose**: Item valuation and market analysis
**Core Aggregates**:
- ItemPrice
- MarketSnapshot

**Domain Services**:
- PriceService
- ValuationEngine

## Implementation Strategy

### Phase 1: Context Mapping and Integration Patterns

#### 1.1 Create Context Map
```elixir
defmodule EveDmv.Contexts do
  @moduledoc """
  Defines the bounded contexts and their relationships
  """
  
  @contexts %{
    killmail_processing: %{
      name: "Killmail Processing",
      type: :core,
      publishes: [:killmail_received, :killmail_enriched],
      subscribes: []
    },
    combat_intelligence: %{
      name: "Combat Intelligence", 
      type: :core,
      publishes: [:character_analyzed, :threat_detected],
      subscribes: [:killmail_enriched]
    },
    fleet_operations: %{
      name: "Fleet Operations",
      type: :core,
      publishes: [:fleet_analyzed],
      subscribes: [:killmail_enriched]
    },
    wormhole_operations: %{
      name: "Wormhole Operations",
      type: :core,
      publishes: [:chain_updated, :vetting_completed],
      subscribes: [:killmail_enriched, :character_analyzed]
    },
    surveillance: %{
      name: "Surveillance",
      type: :core,
      publishes: [:match_found, :alert_triggered],
      subscribes: [:killmail_received]
    },
    market_intelligence: %{
      name: "Market Intelligence",
      type: :supporting,
      publishes: [:price_updated],
      subscribes: []
    }
  }
end
```

#### 1.2 Define Integration Events
```elixir
defmodule EveDmv.DomainEvents do
  @moduledoc """
  Domain events for inter-context communication
  """
  
  defmodule KillmailReceived do
    @enforce_keys [:killmail_id, :timestamp, :participants]
    defstruct [:killmail_id, :timestamp, :participants, :value]
  end
  
  defmodule KillmailEnriched do
    @enforce_keys [:killmail_id, :enriched_data]
    defstruct [:killmail_id, :enriched_data, :timestamp]
  end
  
  defmodule CharacterAnalyzed do
    @enforce_keys [:character_id, :analysis_results]
    defstruct [:character_id, :analysis_results, :timestamp]
  end
  
  defmodule ThreatDetected do
    @enforce_keys [:threat_type, :character_id, :severity]
    defstruct [:threat_type, :character_id, :severity, :details]
  end
end
```

### Phase 2: Context Isolation

#### 2.1 Create Context Boundaries
Each context will have:
- **API Module**: Public interface for the context
- **Domain Module**: Internal domain logic
- **Infrastructure Module**: External dependencies

```elixir
defmodule EveDmv.CombatIntelligence do
  @moduledoc """
  Public API for Combat Intelligence bounded context
  """
  
  alias EveDmv.CombatIntelligence.Domain
  
  # Public API functions
  def analyze_character(character_id, opts \\ []) do
    Domain.CharacterAnalyzer.analyze(character_id, opts)
  end
  
  def get_threat_assessment(character_id) do
    Domain.ThreatAssessor.assess(character_id)
  end
  
  # Anti-corruption layer for external data
  def import_killmail_data(enriched_killmail) do
    Domain.KillmailImporter.import(enriched_killmail)
  end
end
```

#### 2.2 Implement Anti-Corruption Layers
```elixir
defmodule EveDmv.CombatIntelligence.AntiCorruption do
  @moduledoc """
  Translates external models to internal domain models
  """
  
  def translate_killmail(external_killmail) do
    %Domain.CombatEvent{
      id: external_killmail.killmail_id,
      timestamp: external_killmail.occurred_at,
      participants: translate_participants(external_killmail.participants),
      location: translate_location(external_killmail)
    }
  end
  
  defp translate_participants(participants) do
    Enum.map(participants, &translate_participant/1)
  end
end
```

### Phase 3: Directory Structure Reorganization

```
lib/eve_dmv/
├── contexts/
│   ├── killmail_processing/
│   │   ├── api.ex                    # Public interface
│   │   ├── domain/
│   │   │   ├── aggregates/
│   │   │   ├── services/
│   │   │   └── events/
│   │   └── infrastructure/
│   │       ├── repositories/
│   │       └── adapters/
│   ├── combat_intelligence/
│   │   ├── api.ex
│   │   ├── domain/
│   │   └── infrastructure/
│   ├── fleet_operations/
│   ├── wormhole_operations/
│   ├── surveillance/
│   └── market_intelligence/
├── shared_kernel/                     # Shared concepts
│   ├── types/
│   ├── value_objects/
│   └── specifications/
└── infrastructure/                    # Cross-cutting concerns
    ├── event_bus/
    ├── cache/
    └── telemetry/
```

### Phase 4: Implementation Steps

#### Step 1: Create Context APIs (Week 1)
- [ ] Define public API for each bounded context
- [ ] Document context responsibilities
- [ ] Create integration tests for context boundaries

#### Step 2: Implement Domain Events (Week 1-2)
- [ ] Create event definitions
- [ ] Implement event bus infrastructure
- [ ] Add event publishing to existing code

#### Step 3: Refactor Intelligence Module (Week 2-3)
- [ ] Split into separate contexts
- [ ] Move character analysis to Combat Intelligence
- [ ] Move fleet analysis to Fleet Operations
- [ ] Move WH-specific code to Wormhole Operations

#### Step 4: Establish Anti-Corruption Layers (Week 3-4)
- [ ] Create translators for cross-context data
- [ ] Remove direct cross-context dependencies
- [ ] Implement context-specific repositories

#### Step 5: Migrate to New Structure (Week 4-5)
- [ ] Move files to new directory structure
- [ ] Update module references
- [ ] Update tests

### Phase 5: Validation and Testing

#### Context Independence Tests
```elixir
defmodule EveDmv.Contexts.IndependenceTest do
  use ExUnit.Case
  
  test "combat intelligence context has no direct dependencies on killmail internals" do
    deps = Mix.Dep.loaded([])
    combat_intel_deps = filter_context_deps(deps, "combat_intelligence")
    
    refute has_dependency?(combat_intel_deps, "killmail_processing/domain")
  end
end
```

## Benefits

1. **Clear Boundaries**: Each context has explicit responsibilities
2. **Reduced Coupling**: Contexts communicate only through events and APIs
3. **Better Testing**: Each context can be tested in isolation
4. **Parallel Development**: Teams can work on different contexts independently
5. **Easier Maintenance**: Changes in one context don't ripple through others

## Migration Strategy

1. **Incremental Migration**: Move one context at a time
2. **Backward Compatibility**: Maintain existing APIs during migration
3. **Feature Flags**: Use flags to switch between old and new implementations
4. **Gradual Rollout**: Test each context in production before full migration

## Success Metrics

- Reduced coupling score (measured by module dependencies)
- Faster test execution (contexts tested in isolation)
- Decreased time to implement new features
- Reduced bug count from cross-context issues
- Improved code navigation and discoverability

## Next Steps

1. Review and approve the context boundaries
2. Set up the base infrastructure for events
3. Begin with the smallest context (Market Intelligence) as a pilot
4. Iterate based on learnings from the pilot
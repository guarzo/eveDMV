# Stream Isolation Strategy - Technical Details

## File-Level Isolation Matrix

### Conflict Analysis
| File | Stream 1 | Stream 2 | Stream 3 | Stream 4 | Stream 5 |
|------|----------|----------|----------|----------|----------|
| `ship_types.ex` | ✅ | - | - | - | - |
| `single_system_analyzer.ex` | ✅ | - | - | - | - |
| `participant_extractor.ex` | - | ✅ | - | - | - |
| `tactical_extractor.ex` | - | - | ✅ | - | - |
| `battle_analysis_service.ex` | - | - | - | ✅ | - |
| `surveillance_alerts_live.ex` | - | - | - | - | ✅ |

**Result: ZERO file conflicts between streams** ✅

## Interface Dependency Management

### Stream 1 → Stream 2/3 Dependencies
```elixir
# Stream 1 provides static data functions that Streams 2&3 will use
# Interface contract:

defmodule EveDmv.StaticData.ShipTypes do
  @spec get_ship_range(ship_type_id :: integer()) :: {:ok, range :: float()} | {:error, :not_found}
  def get_ship_range(ship_type_id) do
    # Implementation in Stream 1
  end
  
  @spec get_ship_role(ship_type_id :: integer()) :: {:ok, role :: atom()} | {:error, :not_found}  
  def get_ship_role(ship_type_id) do
    # Implementation in Stream 1
  end
end
```

### Stream 2/3 → Stream 4 Dependencies
```elixir
# Streams 2&3 provide extractor functions that Stream 4 will use
# Interface contracts:

defmodule EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysis.Extractors.ParticipantExtractor do
  @spec extract_participants(killmail :: map()) :: {:ok, [participant()]} | {:error, term()}
  def extract_participants(killmail) do
    # Implementation in Stream 2
  end
end

defmodule EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysis.Extractors.TacticalExtractor do
  @spec extract_tactical_patterns(battle :: map()) :: {:ok, patterns :: map()} | {:error, term()}
  def extract_tactical_patterns(battle) do  
    # Implementation in Stream 3
  end
end
```

## Development Sequence to Avoid Conflicts

### Week 1: Foundation (Stream 1) + Independent UI (Stream 5)
```bash
# Stream 1 Developer
git checkout -b stream-1-static-data
# Modify: ship_types.ex, single_system_analyzer.ex
# No conflicts possible - different files

# Stream 5 Developer  
git checkout -b stream-5-surveillance-ui
# Modify: surveillance_alerts_live.ex
# No conflicts possible - different files
```

### Week 2: Parallel Development (Streams 2 & 3)
```bash
# Stream 2 Developer
git checkout -b stream-2-participant-extractor
git merge origin/stream-1-static-data  # Get static data APIs
# Modify: participant_extractor.ex only

# Stream 3 Developer
git checkout -b stream-3-tactical-extractor  
git merge origin/stream-1-static-data  # Get static data APIs
# Modify: tactical_extractor.ex only
```

### Week 5: Service Integration (Stream 4)
```bash
# Stream 4 Developer
git checkout -b stream-4-service-integration
git merge origin/stream-2-participant-extractor
git merge origin/stream-3-tactical-extractor  
# Modify: battle_analysis_service.ex only
```

## Function-Level Implementation Strategy

### Stream 2: Participant Extractor (38 TODOs)
**Implementation Order to Minimize Risk:**

#### Phase 2A: Core Functions (Week 2)
```elixir
# Low-risk implementations first
def extract_basic_participant_data(killmail) do
  # TODO Line 18: Basic participant extraction - PRIORITY 1
end

def analyze_basic_affiliations(participants) do  
  # TODO Line 42: Basic affiliation analysis - PRIORITY 1
end

def classify_ship_roles(participants) do
  # TODO Line 60: Role analysis using static data - PRIORITY 1  
end
```

#### Phase 2B: Enhanced Functions (Week 3)  
```elixir
# Medium-risk implementations
def classify_engagement_sides(participants) do
  # TODO Line 178: Side classification - PRIORITY 2
end

def identify_coalitions(participants) do
  # TODO Line 232: Coalition identification - PRIORITY 2
end
```

#### Phase 2C: Advanced Analytics (Week 4)
```elixir
# Complex implementations last
def calculate_experience_metrics(participants) do
  # TODO Line 303: Experience distribution - PRIORITY 3
end

def analyze_tactical_contributions(participants) do
  # TODO Line 384: Contribution scoring - PRIORITY 3
end
```

### Stream 3: Tactical Extractor (32 TODOs)  
**Parallel Implementation Strategy:**

#### Phase 3A: Pattern Recognition (Week 2)
```elixir
# Independent pattern analysis
def extract_positioning_patterns(battle_data) do
  # TODO Line 39: Positioning patterns - ISOLATED
end

def extract_targeting_patterns(battle_data) do  
  # TODO Line 57: Target selection patterns - ISOLATED
end
```

#### Phase 3B: Behavioral Analysis (Week 3)
```elixir
# Advanced pattern detection
def analyze_command_patterns(battle_data) do
  # TODO Line 111: Command patterns - ISOLATED
end

def analyze_formation_patterns(battle_data) do
  # TODO Line 125: Formation patterns - ISOLATED  
end
```

## Database Migration Coordination

### Migration Naming Convention
```bash
# Stream-specific prefixes prevent conflicts
priv/repo/migrations/20240125_001_s1_update_ship_types.exs       # Stream 1
priv/repo/migrations/20240125_002_s2_participant_indexes.exs     # Stream 2
priv/repo/migrations/20240125_003_s3_tactical_tables.exs         # Stream 3
priv/repo/migrations/20240125_004_s5_surveillance_views.exs      # Stream 5
priv/repo/migrations/20240201_005_s4_service_integration.exs     # Stream 4
```

### Migration Dependencies
```elixir
# Stream 2 migration can reference Stream 1 tables
defmodule EveDmv.Repo.Migrations.S2ParticipantIndexes do
  def change do
    # Safe to reference ship_types table updated in Stream 1
    create index(:participants, [:ship_type_id])
  end
end
```

## Testing Isolation Strategy

### Independent Test Suites
```bash
# Each stream has isolated tests
test/contexts/static_data/ship_types_test.exs                    # Stream 1
test/contexts/combat_intelligence/participant_extractor_test.exs  # Stream 2
test/contexts/combat_intelligence/tactical_extractor_test.exs     # Stream 3
test/contexts/combat_intelligence/battle_analysis_service_test.exs # Stream 4
test/eve_dmv_web/live/surveillance_alerts_live_test.exs          # Stream 5
```

### Mock Strategy for Dependencies
```elixir
# Stream 2 tests can mock Stream 1 functions during development
defmodule ParticipantExtractorTest do
  setup do
    # Mock static data until Stream 1 is complete
    :meck.new(EveDmv.StaticData.ShipTypes)
    :meck.expect(EveDmv.StaticData.ShipTypes, :get_ship_role, fn(_) -> {:ok, :dps} end)
  end
end
```

## Continuous Integration Strategy

### Branch Protection Rules
```yaml
# .github/branch-protection.yml
protected_branches:
  stream-1-static-data:
    required_status_checks: ["test-stream-1"]
  stream-2-participant-extractor:  
    required_status_checks: ["test-stream-2"]
  stream-3-tactical-extractor:
    required_status_checks: ["test-stream-3"]
```

### Parallel CI Jobs
```yaml
# .github/workflows/stream-testing.yml
jobs:
  test-stream-1:
    runs-on: ubuntu-latest
    steps:
      - run: mix test test/contexts/static_data/
      
  test-stream-2:
    runs-on: ubuntu-latest  
    steps:
      - run: mix test test/contexts/combat_intelligence/participant_*
      
  test-stream-3:
    runs-on: ubuntu-latest
    steps:
      - run: mix test test/contexts/combat_intelligence/tactical_*
```

## Integration Points & Handoffs

### Stream 1 → Stream 2/3 Handoff
```elixir
# Stream 1 completion criteria for handoff:
defmodule StaticDataReadinessCheck do
  def ready_for_streams_2_and_3? do
    # Verify all static data functions are implemented
    functions = [
      {EveDmv.StaticData.ShipTypes, :get_ship_range, 1},
      {EveDmv.StaticData.ShipTypes, :get_ship_role, 1},
      {EveDmv.StaticData.Systems, :get_system_effects, 1}
    ]
    
    Enum.all?(functions, fn {mod, fun, arity} ->
      function_exported?(mod, fun, arity)
    end)
  end
end
```

### Stream 2/3 → Stream 4 Handoff  
```elixir
# Stream 2&3 completion criteria:
defmodule ExtractorReadinessCheck do
  def ready_for_stream_4? do
    participant_ready = function_exported?(ParticipantExtractor, :extract_participants, 1)
    tactical_ready = function_exported?(TacticalExtractor, :extract_tactical_patterns, 1)
    
    participant_ready and tactical_ready
  end
end
```

## Risk Mitigation Checkpoints

### Daily Standup Coordination
- **Day 1**: Stream alignment on interface contracts
- **Day 3**: Cross-stream dependency validation  
- **Day 5**: Integration readiness assessment
- **Day 7**: Merge conflict prevention review

### Weekly Integration Tests
```bash
# Week 1: Foundation validation
mix test --only integration_stream_1

# Week 2: Cross-stream interface validation  
mix test --only integration_stream_1_2_3

# Week 5: Full system integration
mix test --only integration_all_streams
```

## Emergency Conflict Resolution

### If Conflicts Occur
1. **Immediate isolation**: Revert to last known good state
2. **Root cause analysis**: Identify interface contract violation
3. **Coordinated fix**: Both teams agree on resolution approach
4. **Prevention update**: Update this strategy to prevent recurrence

### Conflict Prevention Tools
```bash
# Pre-commit hooks to detect potential conflicts
#!/bin/bash
# Check for cross-stream file modifications
if git diff --cached --name-only | grep -E "(participant_extractor|tactical_extractor)" | wc -l > 1; then
  echo "ERROR: Multiple extractor files modified in single commit"
  exit 1
fi
```

This strategy ensures **zero merge conflicts** through careful file isolation, interface contracts, and coordinated development sequencing.
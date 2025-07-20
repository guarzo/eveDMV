# EVE DMV Implementation Strategy

*Created: 2025-01-20*

This document provides a comprehensive strategy for completing EVE DMV implementation, focusing on removing placeholder code and adding missing features from `REVISED_REQUIREMENTS.md`.

## Strategic Overview

**Timeline**: 2-3 weeks  
**Approach**: 4-phase execution prioritizing user impact and technical debt removal  
**Goal**: 100% compliance with "Definition of Done" from `CLEAN_CODEBASE_VISION.md`

## Phase 1: Critical Fixes (2-3 days)

### Priority 1: Fix Kill Feed Real-time Updates (30 minutes)

**Issue**: Topic name mismatch prevents real-time updates  
**Impact**: Users must refresh page to see new kills

**Solution**:
```elixir
# Option 1: Update broadcaster (recommended)
# File: lib/eve_dmv/killmails/killmail_broadcaster.ex
Phoenix.PubSub.broadcast(EveDmv.PubSub, "kill_feed", {:new_killmail, enriched_killmail})

# Option 2: Update LiveView
# File: lib/eve_dmv_web/live/kill_feed_live.ex
Phoenix.PubSub.subscribe(EveDmv.PubSub, "killmail_feed")
```

### Priority 2: Fleet DPS Calculation Cleanup

**Issue**: Hardcoded DPS values (frigate=200, cruiser=600)  
**Files**: `fleet_analyzer.ex`, `ship_instance_extractor.ex`

**Solution - Create static data service**:
```elixir
defmodule EveDmv.StaticData.ShipStats do
  @moduledoc "Ship statistics from static data with sensible defaults"
  
  # Conservative DPS estimates per ship class
  @base_dps %{
    frigate: 150,
    destroyer: 300,
    cruiser: 450,
    battlecruiser: 750,
    battleship: 1200,
    carrier: 3000,
    dreadnought: 8000,
    supercarrier: 12000,
    titan: 15000
  }
  
  def get_estimated_dps(ship_type_id) do
    with {:ok, ship_type} <- EveDmv.StaticData.get_item_type(ship_type_id),
         {:ok, ship_class} <- EveDmv.StaticData.get_ship_class(ship_type_id) do
      
      # Check for actual DPS in dogma attributes
      case get_dogma_attribute(ship_type, "dps_base") do
        {:ok, dps} -> {:ok, dps}
        _ -> {:ok, Map.get(@base_dps, ship_class, 100)}
      end
    else
      _ -> {:error, :ship_not_found}
    end
  end
end
```

### Priority 3: Ship Mass Calculations

**Issue**: Hardcoded fallbacks (10,000,000)  
**Goal**: Use static data with confidence reporting

**Solution**:
```elixir
defp get_ship_mass(ship_type_id) do
  case EveDmv.StaticData.get_ship_mass(ship_type_id) do
    {:ok, mass} when mass > 0 -> 
      {:ok, mass}
    _ ->
      Logger.warning("Missing mass data for ship type #{ship_type_id}")
      {:error, :mass_not_found}
  end
end

defp calculate_fleet_mass(participants) do
  results = Enum.map(participants, &get_ship_mass(&1.ship_type_id))
  
  {known_masses, unknown_count} = 
    Enum.reduce(results, {[], 0}, fn
      {:ok, mass}, {masses, unknown} -> {[mass | masses], unknown}
      {:error, _}, {masses, unknown} -> {masses, unknown + 1}
    end)
  
  %{
    total_known_mass: Enum.sum(known_masses),
    ships_with_known_mass: length(known_masses),
    ships_with_unknown_mass: unknown_count,
    confidence: calculate_confidence(length(known_masses), unknown_count)
  }
end
```

## Phase 2: Fleet Operations Complete Cleanup (3-4 days)

### Ship Role Detection Upgrade

**Current**: Simple class-based roles  
**Goal**: Use ship traits and bonuses from static data

**Implementation**:
```elixir
defmodule EveDmv.StaticData.ShipRoles do
  def get_ship_role(ship_type_id) do
    with {:ok, ship_type} <- EveDmv.StaticData.get_item_type(ship_type_id) do
      ship_type
      |> get_ship_traits()
      |> determine_primary_role()
    else
      _ -> :unknown
    end
  end
  
  defp determine_primary_role(traits) do
    cond do
      has_logistics_bonus?(traits) -> :logistics
      has_ewar_bonus?(traits) -> :ewar  
      has_tackle_bonus?(traits) -> :tackle
      has_command_bonus?(traits) -> :command
      has_mining_bonus?(traits) -> :industrial
      true -> :dps  # Default for combat ships
    end
  end
  
  defp has_logistics_bonus?(traits) do
    # Check for remote repair amount/range bonuses
    Enum.any?(traits, fn trait ->
      String.contains?(trait.bonus_text || "", ["remote", "repair", "logistics"])
    end)
  end
  
  # Similar implementations for other role detection...
end
```

### Ship Value Estimation Service

**Current**: Hardcoded ISK values in LiveView  
**Goal**: Multiple data sources with fallbacks

**Implementation**:
```elixir
defmodule EveDmv.Market.ShipValues do
  @moduledoc "Multi-source ship value estimation"
  
  def get_ship_value(ship_type_id) do
    # Try data sources in order of reliability
    with {:error, _} <- get_killmail_average(ship_type_id),
         {:error, _} <- get_market_estimate(ship_type_id) do
      get_class_based_estimate(ship_type_id)
    end
  end
  
  defp get_killmail_average(ship_type_id) do
    query = """
    SELECT 
      AVG(ship_value) as avg_value, 
      COUNT(*) as sample_size,
      STDDEV(ship_value) as std_dev
    FROM killmails_enriched 
    WHERE ship_type_id = $1 
      AND killmail_time > NOW() - INTERVAL '30 days'
      AND ship_value > 0
    """
    
    case EveDmv.Repo.query(query, [ship_type_id]) do
      {:ok, %{rows: [[avg, count, stddev]]}} when count >= 10 ->
        {:ok, %{
          value: avg,
          source: :killmail_average,
          confidence: calculate_confidence(count, stddev),
          sample_size: count
        }}
      _ ->
        {:error, :insufficient_data}
    end
  end
end
```

### Wormhole Compatibility System

**Current**: Stub returning same values  
**Goal**: Accurate mass and ship restrictions

**Implementation**:
```elixir
defmodule EveDmv.Wormhole.Compatibility do
  # Actual EVE Online wormhole specifications
  @wormhole_limits %{
    c1: %{total_mass: 500_000_000, jump_mass: 5_000_000, regen: 200_000_000},
    c2: %{total_mass: 1_000_000_000, jump_mass: 20_000_000, regen: 500_000_000},
    c3: %{total_mass: 2_000_000_000, jump_mass: 50_000_000, regen: 500_000_000},
    c4: %{total_mass: 2_000_000_000, jump_mass: 100_000_000, regen: 500_000_000},
    c5: %{total_mass: 3_000_000_000, jump_mass: 200_000_000, regen: 500_000_000},
    c6: %{total_mass: 3_000_000_000, jump_mass: 300_000_000, regen: 500_000_000}
  }
  
  def analyze_fleet_compatibility(fleet_composition, wormhole_class) do
    limits = Map.get(@wormhole_limits, wormhole_class)
    fleet_mass = calculate_fleet_mass(fleet_composition)
    
    %{
      can_all_jump: fleet_mass.max_ship_mass <= limits.jump_mass,
      fleet_jumps_possible: calculate_fleet_jumps(fleet_mass, limits),
      ships_too_heavy: find_oversized_ships(fleet_composition, limits.jump_mass),
      total_mass_usage: fleet_mass.total_known_mass / limits.total_mass * 100,
      recommendations: generate_recommendations(fleet_composition, limits)
    }
  end
end
```

## Phase 3: Wormhole Operations Cleanup (4-5 days)

### Remove ALL Random Data Generation

**Files to audit**:
```bash
# Find all random usage
rg "Enum\.random|:rand\.uniform" lib/eve_dmv/contexts/wormhole_operations/
```

**Replacement strategy**:
```elixir
# BEFORE: Random threat levels
threat_level: Enum.random([:low, :medium, :high])

# AFTER: Calculate from activity data
defp calculate_threat_level(system_activity) do
  case system_activity do
    %{recent_kills: kills, avg_ship_value: value} ->
      cond do
        kills > 10 and value > 100_000_000 -> :high
        kills > 3 or value > 50_000_000 -> :medium
        true -> :low
      end
    _ -> :unknown
  end
end
```

### Strategic Value Calculations

**Current**: Hardcoded values (0.2, 0.1, 0.5)  
**Goal**: Real metrics from system activity

**Implementation**:
```elixir
defmodule EveDmv.Wormhole.StrategicAnalysis do
  def calculate_strategic_importance(system_id) do
    with {:ok, metrics} <- gather_system_metrics(system_id) do
      %{
        kill_density: normalize_kills(metrics.kills_per_day),
        pilot_diversity: normalize_pilots(metrics.unique_pilots),
        asset_value: normalize_isk(metrics.isk_destroyed_daily),
        strategic_score: calculate_weighted_score(metrics)
      }
    else
      _ -> %{strategic_score: 0.0, confidence: :no_data}
    end
  end
  
  defp gather_system_metrics(system_id) do
    query = """
    SELECT 
      COUNT(*) / 30.0 as kills_per_day,
      COUNT(DISTINCT victim_character_id) as unique_pilots,
      SUM(total_value) / 30.0 as isk_destroyed_daily,
      AVG(participant_count) as avg_fleet_size
    FROM killmails k
    JOIN killmail_participants p ON k.killmail_id = p.killmail_id
    WHERE k.solar_system_id = $1
      AND k.killmail_time > NOW() - INTERVAL '30 days'
    """
    
    case EveDmv.Repo.query(query, [system_id]) do
      {:ok, %{rows: [[kills, pilots, isk, fleet_size]]}} ->
        {:ok, %{
          kills_per_day: kills || 0,
          unique_pilots: pilots || 0,
          isk_destroyed_daily: isk || 0,
          avg_fleet_size: fleet_size || 0
        }}
      _ ->
        {:error, :no_data}
    end
  end
end
```

### Replace Mock Data Generation

**Current**: Fake corp history and killboard stats  
**Goal**: ESI API and database queries

**Implementation**:
```elixir
defmodule EveDmv.Intelligence.CharacterAnalysis do
  def get_corporation_history(character_id) do
    case EveDmv.ESI.get_character_corporation_history(character_id) do
      {:ok, history} ->
        Enum.map(history, &enrich_corporation_record/1)
      {:error, reason} ->
        Logger.error("ESI corp history failed: #{inspect(reason)}")
        []
    end
  end
  
  def get_killboard_statistics(character_id) do
    query = """
    SELECT 
      COUNT(CASE WHEN final_blow THEN 1 END) as solo_kills,
      COUNT(CASE WHEN NOT final_blow THEN 1 END) as assists,
      COUNT(CASE WHEN victim_character_id = $1 THEN 1 END) as deaths,
      SUM(CASE WHEN final_blow THEN total_value ELSE 0 END) as isk_killed,
      SUM(CASE WHEN victim_character_id = $1 THEN total_value ELSE 0 END) as isk_lost,
      AVG(participant_count) as avg_gang_size
    FROM killmail_participants kp
    JOIN killmails k ON kp.killmail_id = k.killmail_id
    WHERE kp.character_id = $1
      AND k.killmail_time > NOW() - INTERVAL '90 days'
    """
    
    case EveDmv.Repo.query(query, [character_id]) do
      {:ok, %{rows: [[kills, assists, deaths, isk_k, isk_l, gang]]}} ->
        %{
          solo_kills: kills || 0,
          assists: assists || 0,
          deaths: deaths || 0,
          isk_killed: isk_k || 0.0,
          isk_lost: isk_l || 0.0,
          avg_gang_size: gang || 0.0,
          efficiency: calculate_efficiency(isk_k, isk_l)
        }
      _ ->
        %{} # Return empty map for no data
    end
  end
end
```

## Phase 4: Enhancements (2-3 days)

### Multi-Character Support

**Database changes**:
```sql
CREATE TABLE user_characters (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT REFERENCES users(id) ON DELETE CASCADE,
  character_id BIGINT NOT NULL,
  character_name VARCHAR NOT NULL,
  is_primary BOOLEAN DEFAULT FALSE,
  added_at TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE UNIQUE INDEX idx_user_characters_unique ON user_characters(user_id, character_id);
```

### Advanced Kill Feed Filtering

**Add filter types**:
- Alliance/Corporation
- Ship type/group  
- ISK value ranges
- Participant count
- Time windows

### Infinite Scroll Implementation

**LiveView streaming**:
```elixir
def handle_event("load_more", %{"last_killmail_id" => last_id}, socket) do
  additional_kills = 
    socket.assigns.current_filters
    |> apply_filters()
    |> load_kills_after(last_id, 50)
  
  {:noreply,
   socket
   |> stream_insert(:kills, additional_kills)
   |> assign(:has_more, length(additional_kills) == 50)}
end
```

## Testing Strategy

### Validation Approach
1. **Unit tests** for each replaced function
2. **Integration tests** for full pipelines  
3. **Performance tests** for database queries
4. **Acceptance tests** for user workflows

### Quality Gates
- [ ] No `Enum.random` or `:rand.uniform` in production code
- [ ] No hardcoded calculation values
- [ ] All ship data queries use static data tables
- [ ] Mass calculations report confidence levels
- [ ] Strategic values calculated from real metrics

## Success Criteria

### Phase 1 Complete
- [ ] Kill feed updates in real-time
- [ ] Fleet DPS uses static data or estimates
- [ ] Ship mass calculations report confidence

### Phase 2 Complete  
- [ ] Ship roles detected from bonuses
- [ ] Ship values from multiple sources
- [ ] Wormhole compatibility accurate

### Phase 3 Complete
- [ ] Zero random data generation
- [ ] Strategic values from real activity
- [ ] No mock/fake data in any module

### Phase 4 Complete
- [ ] Multi-character support functional
- [ ] Advanced filtering available
- [ ] Infinite scroll implemented
- [ ] Documentation updated

## Implementation Timeline

**Week 1**:
- Days 1-3: Phase 1 (Critical fixes)
- Days 4-5: Begin Phase 2 (Fleet operations)

**Week 2**:
- Days 1-2: Complete Phase 2  
- Days 3-5: Phase 3 (Wormhole operations)

**Week 3**:
- Days 1-2: Complete Phase 3
- Days 3-5: Phase 4 (Enhancements)

This strategy ensures systematic removal of all placeholder code while maintaining application functionality throughout the process.
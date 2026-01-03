# SQL to Ash Migration Implementation Plan

## Executive Summary

This plan outlines the migration of ~40+ handwritten SQL queries to Ash-native approaches. The migration is organized into 6 phases over multiple implementation cycles, prioritizing by complexity and impact.

---

## Current State Analysis

### Query Locations
| File | Query Count | Complexity |
|------|-------------|------------|
| `lib/eve_dmv/platform/database/character_queries.ex` | 4 functions | Medium |
| `lib/eve_dmv/platform/database/corporation_queries.ex` | 8 functions | High |
| `lib/eve_dmv/platform/database/query_optimizations.ex` | 6 functions | High |
| `lib/eve_dmv/utilities/query_helpers/killmail_queries.ex` | 5+ builders | Medium |
| `lib/eve_dmv/contexts/character_intelligence/analyzers/` | 10+ queries | High |
| `lib/eve_dmv/contexts/battle_analysis/domain/services/` | 5+ queries | Very High |

### Integration Points
- **LiveViews**: `CharacterAnalysisLive`, `CorporationLive`, `SystemLive`
- **Data Loaders**: `CharacterDataLoader`, `CorporationLive.DataLoader`
- **Repositories**: `PlayerRepository`, `CorporationRepository`
- **Caching**: `QueryCache` with 1-24 hour TTLs

---

## Migration Decision Matrix

### MIGRATE TO ASH (Priority)
| Query Type | Ash Approach | Effort |
|------------|--------------|--------|
| Simple COUNT/SUM | `aggregates` block | Low |
| Filtered counts | Aggregate with `filter` | Low |
| Computed fields | `calculations` block | Low |
| Time-filtered reads | Custom `read` actions | Medium |
| Entity lookups | Relationships + loads | Medium |

### HYBRID APPROACH (Use Ash + Fragments)
| Query Type | Ash Approach | Effort |
|------------|--------------|--------|
| JSONB extraction | `fragment()` in calculations | Medium |
| Timezone conversions | `fragment()` expressions | Medium |
| Complex conditionals | `expr()` with `cond` | Medium |

### KEEP AS RAW SQL
| Query Type | Reason |
|------------|--------|
| Window functions (ROW_NUMBER, FIRST_VALUE) | Not supported in Ash expressions |
| Complex CTEs with multiple stages | Ash can't express multi-CTE patterns |
| Materialized view definitions | Infrastructure, not domain |
| pg_catalog/system queries | Operational diagnostics |
| Batch operations with UNION ALL | Performance-critical patterns |

---

## Phase 1: Foundation Setup (Prerequisites)

### 1.1 Create Shared Calculation Modules

**File**: `lib/eve_dmv/calculations/base.ex`
```elixir
defmodule EveDmv.Calculations.Base do
  @moduledoc "Base module for shared calculation patterns"

  defmacro __using__(_opts) do
    quote do
      use Ash.Resource.Calculation
      import EveDmv.Calculations.Helpers
    end
  end
end
```

**File**: `lib/eve_dmv/calculations/helpers.ex`
```elixir
defmodule EveDmv.Calculations.Helpers do
  @moduledoc "Helper functions for Ash calculations"

  def safe_divide(numerator, denominator, default \\ 0.0) do
    if denominator > 0, do: numerator / denominator, else: default
  end

  def percentage(part, whole), do: safe_divide(part * 100, whole)
end
```

### 1.2 Create Fragment Library

**File**: `lib/eve_dmv/ash/fragments.ex`
```elixir
defmodule EveDmv.Ash.Fragments do
  @moduledoc "Reusable SQL fragments for Ash expressions"

  import Ash.Expr

  # JSONB extraction helpers
  def jsonb_text(field, path) when is_list(path) do
    path_str = Enum.join(path, "->")
    fragment("(?->>#{})", field, ^path_str)
  end

  def jsonb_int(field, path) do
    fragment("(#{jsonb_text(field, path)})::integer")
  end

  def jsonb_array_length(field, path) do
    fragment("jsonb_array_length(?->?)", field, ^Enum.join(path, "->"))
  end

  # Time helpers
  def extract_hour_utc(timestamp_field) do
    fragment("EXTRACT(HOUR FROM ? AT TIME ZONE 'UTC')", timestamp_field)
  end

  def days_ago(days) do
    fragment("NOW() - INTERVAL '? days'", ^days)
  end
end
```

### 1.3 Update Base Resource Configuration

**File**: `lib/eve_dmv/resource.ex` (new)
```elixir
defmodule EveDmv.Resource do
  @moduledoc "Base resource configuration with shared patterns"

  defmacro __using__(opts) do
    quote do
      use Ash.Resource, unquote(opts)
      import EveDmv.Ash.Fragments
    end
  end
end
```

---

## Phase 2: KillmailRaw Resource Enhancement

### 2.1 Add Aggregates to KillmailRaw

**File**: `lib/eve_dmv/external/killmails/killmail_raw.ex`

Add to existing resource:
```elixir
aggregates do
  # Existing
  count :participant_count, :participants

  # NEW aggregates
  count :attacker_count, :participants do
    filter expr(is_victim == false)
  end

  sum :total_attacker_damage, :participants, :damage_done do
    filter expr(is_victim == false)
  end

  count :solo_kill_indicator, :participants do
    filter expr(is_victim == false)
  end
end

calculations do
  # Existing
  calculate :is_recent, :boolean, expr(killmail_time > ago(24, :hour))

  # NEW calculations
  calculate :is_solo_kill, :boolean, expr(solo_kill_indicator == 1)

  calculate :victim_ship_type_id, :integer, expr(
    fragment("(raw_data->'victim'->>'ship_type_id')::integer")
  )

  calculate :victim_character_id, :integer, expr(
    fragment("(raw_data->'victim'->>'character_id')::integer")
  )

  calculate :victim_corporation_id, :integer, expr(
    fragment("(raw_data->'victim'->>'corporation_id')::integer")
  )

  calculate :attacker_count_from_json, :integer, expr(
    fragment("jsonb_array_length(raw_data->'attackers')")
  )
end
```

### 2.2 Add Custom Read Actions

```elixir
actions do
  # Existing actions...

  read :by_character_involvement do
    description "Find killmails where character was involved (victim or attacker)"
    argument :character_id, :integer, allow_nil?: false
    argument :since_date, :utc_datetime, allow_nil?: true
    argument :limit, :integer, default: 100

    prepare fn query, context ->
      char_id = context.arguments.character_id

      query
      |> Ash.Query.filter(
        victim_character_id == ^char_id or
        fragment("EXISTS (SELECT 1 FROM jsonb_array_elements(raw_data->'attackers') a WHERE (a->>'character_id')::integer = ?)", ^char_id)
      )
      |> maybe_filter_since(context.arguments.since_date)
      |> Ash.Query.sort(killmail_time: :desc)
      |> Ash.Query.limit(context.arguments.limit)
    end
  end

  read :by_corporation do
    description "Find killmails involving a corporation"
    argument :corporation_id, :integer, allow_nil?: false
    argument :since_date, :utc_datetime, allow_nil?: true
    argument :involvement, :atom, constraints: [one_of: [:all, :kills, :losses]], default: :all

    prepare fn query, context ->
      corp_id = context.arguments.corporation_id

      query
      |> apply_corporation_filter(corp_id, context.arguments.involvement)
      |> maybe_filter_since(context.arguments.since_date)
      |> Ash.Query.sort(killmail_time: :desc)
    end
  end
end
```

---

## Phase 3: Character Statistics Migration

### 3.1 Create CharacterStats Resource

**File**: `lib/eve_dmv/contexts/character_intelligence/resources/character_stats.ex`

```elixir
defmodule EveDmv.Contexts.CharacterIntelligence.Resources.CharacterStats do
  @moduledoc """
  Virtual resource for character statistics.
  Replaces CharacterQueries.get_character_stats/2
  """
  use Ash.Resource,
    domain: EveDmv.Contexts.CharacterIntelligence.Api,
    data_layer: :embedded  # Virtual resource, computed on demand

  attributes do
    attribute :character_id, :integer, primary_key?: true, allow_nil?: false
    attribute :kills, :integer, default: 0
    attribute :deaths, :integer, default: 0
    attribute :isk_destroyed, :decimal, default: Decimal.new("0")
    attribute :isk_lost, :decimal, default: Decimal.new("0")
    attribute :period_days, :integer, default: 90
  end

  calculations do
    calculate :kd_ratio, :float, expr(
      if deaths > 0 do
        kills / deaths
      else
        kills * 1.0  # Return kills as float if no deaths
      end
    )

    calculate :isk_efficiency, :float, expr(
      if isk_destroyed + isk_lost > 0 do
        isk_destroyed / (isk_destroyed + isk_lost) * 100
      else
        0.0
      end
    )
  end

  code_interface do
    domain EveDmv.Contexts.CharacterIntelligence.Api
    define :calculate_for_character, action: :calculate, args: [:character_id, :since_date]
  end

  actions do
    action :calculate, :struct do
      argument :character_id, :integer, allow_nil?: false
      argument :since_date, :utc_datetime, allow_nil?: true

      run fn input, _context ->
        character_id = input.arguments.character_id
        since_date = input.arguments.since_date || default_since_date()

        # Use Ash query to get kill/death counts
        stats = calculate_stats(character_id, since_date)
        {:ok, struct(__MODULE__, stats)}
      end
    end
  end

  defp calculate_stats(character_id, since_date) do
    # Query kills (as attacker)
    kills_query =
      EveDmv.External.Killmails.KillmailRaw
      |> Ash.Query.filter(
        killmail_time >= ^since_date and
        fragment("EXISTS (SELECT 1 FROM jsonb_array_elements(raw_data->'attackers') a WHERE (a->>'character_id')::integer = ?)", ^character_id)
      )
      |> Ash.Query.aggregate(:count, :id)

    # Query deaths (as victim)
    deaths_query =
      EveDmv.External.Killmails.KillmailRaw
      |> Ash.Query.filter(
        killmail_time >= ^since_date and
        victim_character_id == ^character_id
      )
      |> Ash.Query.aggregate(:count, :id)

    # Execute in parallel
    kills_task = Task.async(fn -> Ash.count!(kills_query) end)
    deaths_task = Task.async(fn -> Ash.count!(deaths_query) end)

    %{
      character_id: character_id,
      kills: Task.await(kills_task),
      deaths: Task.await(deaths_task),
      period_days: Date.diff(Date.utc_today(), since_date)
    }
  end

  defp default_since_date do
    Date.utc_today() |> Date.add(-90) |> DateTime.new!(~T[00:00:00], "Etc/UTC")
  end
end
```

### 3.2 Create Character Activity Read Action

Add to `Participant` resource:

```elixir
# In lib/eve_dmv/external/killmails/participant.ex

read :character_activity do
  description "Get recent activity for a character with involvement type"
  argument :character_id, :integer, allow_nil?: false
  argument :limit, :integer, default: 50
  argument :page, :integer, default: 1

  pagination do
    offset? true
    default_limit 50
    max_page_size 100
  end

  prepare fn query, context ->
    query
    |> Ash.Query.filter(character_id == ^context.arguments.character_id)
    |> Ash.Query.load([:killmail, :ship_type])
    |> Ash.Query.sort(inserted_at: :desc)
  end
end
```

### 3.3 Migration: CharacterQueries Functions

| Old Function | New Approach | Status |
|--------------|--------------|--------|
| `get_character_stats/2` | `CharacterStats.calculate_for_character/2` | Phase 3 |
| `get_recent_activity/2` | `Participant.character_activity` action | Phase 3 |
| `get_character_name_from_killmails/1` | Calculation on Participant | Phase 3 |
| `get_character_affiliations/1` | Relationship + latest read | Phase 3 |

---

## Phase 4: Corporation Statistics Migration

### 4.1 Enhance Corporation Resource

**File**: `lib/eve_dmv/contexts/corporation/resources/corporation.ex`

Add aggregates and calculations:

```elixir
aggregates do
  count :total_members, :members

  count :active_members_30d, :members do
    filter expr(last_activity_at > ago(30, :day))
  end

  sum :total_kills, :activity_metrics, :kills do
    filter expr(metric_date > ago(90, :day))
  end

  sum :total_losses, :activity_metrics, :losses do
    filter expr(metric_date > ago(90, :day))
  end

  sum :total_isk_destroyed, :activity_metrics, :isk_destroyed do
    filter expr(metric_date > ago(90, :day))
  end

  sum :total_isk_lost, :activity_metrics, :isk_lost do
    filter expr(metric_date > ago(90, :day))
  end
end

calculations do
  calculate :kill_death_ratio, :float, expr(
    if total_losses > 0 do
      total_kills / total_losses
    else
      total_kills * 1.0
    end
  )

  calculate :isk_efficiency, :float, expr(
    if total_isk_destroyed + total_isk_lost > 0 do
      total_isk_destroyed / (total_isk_destroyed + total_isk_lost) * 100
    else
      0.0
    end
  )
end
```

### 4.2 Create Corporation Stats Loader

**File**: `lib/eve_dmv/contexts/corporation/services/stats_loader.ex`

```elixir
defmodule EveDmv.Contexts.Corporation.Services.StatsLoader do
  @moduledoc """
  Loads corporation statistics using Ash queries.
  Replaces CorporationQueries.get_corporation_stats/2
  """

  alias EveDmv.Contexts.Corporation.Resources.Corporation

  def load_stats(corporation_id, opts \\ []) do
    days = Keyword.get(opts, :days, 90)
    since_date = Date.utc_today() |> Date.add(-days)

    Corporation
    |> Ash.Query.filter(corporation_id == ^corporation_id)
    |> Ash.Query.load([
      :total_kills,
      :total_losses,
      :total_isk_destroyed,
      :total_isk_lost,
      :kill_death_ratio,
      :isk_efficiency,
      :active_members_30d
    ])
    |> Ash.read_one()
    |> case do
      {:ok, nil} -> {:error, :not_found}
      {:ok, corp} -> {:ok, format_stats(corp)}
      error -> error
    end
  end

  defp format_stats(corp) do
    %{
      kills: corp.total_kills || 0,
      losses: corp.total_losses || 0,
      isk_destroyed: corp.total_isk_destroyed || Decimal.new("0"),
      isk_lost: corp.total_isk_lost || Decimal.new("0"),
      efficiency: corp.kill_death_ratio || 0.0,
      isk_efficiency: corp.isk_efficiency || 0.0,
      active_members: corp.active_members_30d || 0
    }
  end
end
```

### 4.3 Migration: CorporationQueries Functions

| Old Function | New Approach | Status |
|--------------|--------------|--------|
| `get_corporation_stats/2` | `StatsLoader.load_stats/2` | Phase 4 |
| `get_top_active_members/3` | Aggregate on CorporationMember | Phase 4 |
| `get_recent_activity/2` | Custom read action on Participant | Phase 4 |
| `get_corporation_info_from_killmails/1` | Keep as fallback only | Keep SQL |
| `get_timezone_activity/2` | Keep (EXTRACT not expressible) | Keep SQL |
| `get_ship_usage_stats/3` | Keep (complex UNION) | Keep SQL |

---

## Phase 5: Query Optimizations Migration

### 5.1 Batch Loading with Ash

**File**: `lib/eve_dmv/contexts/character_intelligence/services/batch_loader.ex`

```elixir
defmodule EveDmv.Contexts.CharacterIntelligence.Services.BatchLoader do
  @moduledoc """
  Batch loads character data using Ash queries.
  Replaces QueryOptimizations.bulk_analyze_characters/1
  """

  alias EveDmv.External.Killmails.Participant

  def bulk_load_character_stats(character_ids) when is_list(character_ids) do
    # Use Ash aggregate query with grouping
    Participant
    |> Ash.Query.filter(character_id in ^character_ids)
    |> Ash.Query.filter(inserted_at > ago(90, :day))
    |> Ash.Query.aggregate(:kill_count, :count, filter: expr(not is_victim))
    |> Ash.Query.aggregate(:death_count, :count, filter: expr(is_victim))
    |> Ash.Query.aggregate(:total_isk_destroyed, :sum, :isk_value, filter: expr(not is_victim))
    |> Ash.Query.aggregate(:total_isk_lost, :sum, :isk_value, filter: expr(is_victim))
    |> Ash.Query.group_by(:character_id)
    |> Ash.read!()
    |> Map.new(fn record -> {record.character_id, format_stats(record)} end)
  end

  def bulk_load_recent_activity(character_ids, limit \\ 10) do
    # For window functions, we still need raw SQL or post-processing
    # This is a case where we keep the optimized SQL
    EveDmv.Platform.Database.QueryOptimizations.batch_load_recent_activity(character_ids, limit)
  end

  defp format_stats(record) do
    %{
      kills: record.kill_count || 0,
      deaths: record.death_count || 0,
      isk_destroyed: record.total_isk_destroyed || Decimal.new("0"),
      isk_lost: record.total_isk_lost || Decimal.new("0")
    }
  end
end
```

### 5.2 Keep Window Function Queries

These functions should remain as raw SQL due to window function requirements:
- `batch_load_recent_activity/2` - Uses ROW_NUMBER() OVER PARTITION BY
- `batch_load_affiliations/1` - Uses FIRST_VALUE() OVER
- `batch_load_ship_preferences/2` - Uses ROW_NUMBER() for ranking

---

## Phase 6: Integration & Cleanup

### 6.1 Update Data Loaders

**File**: `lib/eve_dmv_web/live/character_analysis/helpers/character_data_loader.ex`

```elixir
# Replace:
CharacterQueries.get_character_stats(character_id, since_date)

# With:
EveDmv.Contexts.CharacterIntelligence.Resources.CharacterStats
|> Ash.ActionInput.new()
|> Ash.ActionInput.set_argument(:character_id, character_id)
|> Ash.ActionInput.set_argument(:since_date, since_date)
|> Ash.run_action(:calculate)
```

### 6.2 Update Corporation Data Loader

**File**: `lib/eve_dmv_web/live/corporation_live/data_loader.ex`

```elixir
# Replace:
CorporationQueries.get_corporation_stats(corporation_id, since_date)

# With:
EveDmv.Contexts.Corporation.Services.StatsLoader.load_stats(corporation_id, days: 90)
```

### 6.3 Deprecation Strategy

1. Add `@deprecated` attributes to old query functions
2. Log warnings when deprecated functions are called
3. Run both old and new implementations in parallel for validation
4. Remove old implementations after 2-week validation period

```elixir
# In CharacterQueries
@deprecated "Use CharacterStats.calculate_for_character/2 instead"
def get_character_stats(character_id, since_date) do
  Logger.warning("Deprecated: CharacterQueries.get_character_stats/2 called")
  # ... existing implementation
end
```

---

## Files to Modify

### New Files to Create
| File | Purpose |
|------|---------|
| `lib/eve_dmv/calculations/base.ex` | Base calculation module |
| `lib/eve_dmv/calculations/helpers.ex` | Shared calculation helpers |
| `lib/eve_dmv/ash/fragments.ex` | Reusable SQL fragments |
| `lib/eve_dmv/resource.ex` | Base resource configuration |
| `lib/eve_dmv/contexts/character_intelligence/resources/character_stats.ex` | Character stats resource |
| `lib/eve_dmv/contexts/corporation/services/stats_loader.ex` | Corporation stats loader |
| `lib/eve_dmv/contexts/character_intelligence/services/batch_loader.ex` | Batch loading service |

### Existing Files to Modify
| File | Changes |
|------|---------|
| `lib/eve_dmv/external/killmails/killmail_raw.ex` | Add aggregates, calculations, read actions |
| `lib/eve_dmv/external/killmails/participant.ex` | Add character_activity read action |
| `lib/eve_dmv/contexts/corporation/resources/corporation.ex` | Add aggregates, calculations |
| `lib/eve_dmv_web/live/character_analysis/helpers/character_data_loader.ex` | Use new Ash queries |
| `lib/eve_dmv_web/live/corporation_live/data_loader.ex` | Use new Ash queries |
| `lib/eve_dmv/contexts/character_intelligence/api.ex` | Register new resources |

### Files to Eventually Remove (After Validation)
| File | Replacement |
|------|-------------|
| `lib/eve_dmv/platform/database/character_queries.ex` | Ash resources + batch_loader |
| `lib/eve_dmv/platform/database/corporation_queries.ex` | Ash resources + stats_loader |

### Files to Keep (Complex SQL)
| File | Reason |
|------|--------|
| `lib/eve_dmv/platform/database/query_optimizations.ex` | Window functions, batch operations |
| `lib/eve_dmv/utilities/query_helpers/killmail_queries.ex` | Complex JSONB builders |
| `lib/eve_dmv/contexts/battle_analysis/domain/services/detection_service.ex` | Temporal clustering |

---

## Testing Strategy

### Unit Tests
```elixir
# test/eve_dmv/contexts/character_intelligence/resources/character_stats_test.exs
defmodule EveDmv.Contexts.CharacterIntelligence.Resources.CharacterStatsTest do
  use EveDmv.DataCase

  describe "calculate_for_character/2" do
    test "returns correct kill/death counts" do
      # Setup killmail fixtures
      character_id = 12345
      insert_killmail(victim_character_id: character_id)
      insert_killmail(attacker_character_id: character_id)
      insert_killmail(attacker_character_id: character_id)

      {:ok, stats} = CharacterStats.calculate_for_character(character_id, days_ago(90))

      assert stats.kills == 2
      assert stats.deaths == 1
      assert stats.kd_ratio == 2.0
    end
  end
end
```

### Integration Tests
```elixir
# Compare old vs new implementations
test "new implementation matches old implementation" do
  character_id = 12345
  since_date = days_ago(90)

  old_stats = CharacterQueries.get_character_stats(character_id, since_date)
  {:ok, new_stats} = CharacterStats.calculate_for_character(character_id, since_date)

  assert old_stats.kills == new_stats.kills
  assert old_stats.deaths == new_stats.deaths
  assert_in_delta old_stats.kd_ratio, new_stats.kd_ratio, 0.01
end
```

---

## Rollback Plan

Each phase can be rolled back independently:

1. **Feature flags**: Use config to toggle between old/new implementations
2. **Dual-write period**: Run both implementations and compare results
3. **Gradual rollout**: Enable new implementation for subset of users first

```elixir
# config/config.exs
config :eve_dmv, :query_migration,
  use_ash_character_stats: true,
  use_ash_corporation_stats: false,
  log_comparison_mismatches: true
```

---

## Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Query response time | <= current | Application telemetry |
| Test coverage | >= 70% | ExCoveralls |
| Code reduction | 30% fewer raw SQL lines | Line count diff |
| Type safety | 100% typed returns | Dialyzer clean |

---

## Summary

### What Gets Migrated (60%)
- Simple aggregations -> Ash `aggregates`
- Computed fields -> Ash `calculations`
- Filtered reads -> Ash custom `read` actions
- Entity lookups -> Ash relationships

### What Stays as Raw SQL (40%)
- Window functions (ROW_NUMBER, FIRST_VALUE)
- Complex multi-stage CTEs
- Materialized view definitions
- Batch operations with UNION ALL
- System diagnostics (pg_catalog)

### Key Benefits
1. **Type Safety**: Ash resources provide compile-time checks
2. **Consistency**: Centralized business logic in resources
3. **Maintainability**: Declarative > imperative for common patterns
4. **Testability**: Easier to unit test Ash actions
5. **Documentation**: Self-documenting resource definitions

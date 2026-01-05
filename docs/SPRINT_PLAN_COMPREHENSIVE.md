# Comprehensive Sprint Plan: EVE DMV Quality & Feature Sprint

**Created:** 2026-01-05
**Scope:** Ash Migration, Test Coverage Improvement, Historical Fetch Feature
**Target Duration:** Organized by phases with parallel workstreams

---

## Executive Summary

This sprint plan consolidates three major initiatives:
1. **Ash Migration** - Migrate ~40+ SQL queries to Ash-native approaches (6 phases)
2. **Test Coverage** - Increase from 7.6% to 50%+ (5 phases, ~670 tests)
3. **Historical Fetch** - 2-year killmail fetch feature with UI indicators (4 phases)

The work is organized into **10 sequential phases**, with parallel workstreams within each phase where dependencies allow.

---

## Quality Gates (Apply After Each Phase)

Every phase MUST pass these quality gates before proceeding:

```bash
# Run all quality checks
./scripts/quality_check.sh

# Or individually:
mix compile --warnings-as-errors
mix format --check-formatted
mix credo --strict
mix dialyzer
mix test
```

**Minimum Requirements:**
- Zero compilation warnings
- Zero credo issues
- Zero dialyzer errors
- All existing tests pass
- New tests pass

---

## Phase 1: Foundation & Infrastructure

**Objective:** Establish shared infrastructure for all three initiatives.

### Workstream 1A: Ash Migration Foundation
**Files to Create:**

| File | Purpose |
|------|---------|
| `lib/eve_dmv/calculations/base.ex` | Base module for shared calculation patterns |
| `lib/eve_dmv/calculations/helpers.ex` | Helper functions for Ash calculations |
| `lib/eve_dmv/ash/fragments.ex` | Reusable SQL fragments for Ash expressions |

**Implementation Details:**

```elixir
# lib/eve_dmv/calculations/base.ex
defmodule EveDmv.Calculations.Base do
  @moduledoc """
  Base module for shared calculation patterns.
  Use this as a starting point for Ash calculations.
  """

  defmacro __using__(_opts) do
    quote do
      use Ash.Resource.Calculation
      import EveDmv.Calculations.Helpers
    end
  end
end
```

```elixir
# lib/eve_dmv/calculations/helpers.ex
defmodule EveDmv.Calculations.Helpers do
  @moduledoc """
  Helper functions for Ash calculations.
  Pure functions for common mathematical operations.
  """

  @doc "Safely divide, returning default if denominator is zero."
  @spec safe_divide(number(), number(), any()) :: float() | any()
  def safe_divide(numerator, denominator, default \\ 0.0) do
    if denominator > 0, do: numerator / denominator, else: default
  end

  @doc "Calculate percentage of part to whole."
  @spec percentage(number(), number()) :: float()
  def percentage(part, whole), do: safe_divide(part * 100, whole)

  @doc "Calculate K/D ratio with proper zero-death handling."
  @spec kd_ratio(integer(), integer()) :: float()
  def kd_ratio(kills, deaths) when deaths > 0, do: Float.round(kills / deaths, 2)
  def kd_ratio(kills, _deaths), do: kills * 1.0
end
```

```elixir
# lib/eve_dmv/ash/fragments.ex
defmodule EveDmv.Ash.Fragments do
  @moduledoc """
  Reusable SQL fragments for Ash expressions.
  Wraps PostgreSQL-specific functions not natively supported in Ash.
  """

  import Ash.Expr

  @doc "Extract text value from JSONB field."
  defmacro jsonb_text(field, path) when is_list(path) do
    path_navigation = build_jsonb_path(path)
    quote do
      fragment(unquote("(?#{path_navigation})"), unquote(field))
    end
  end

  @doc "Extract integer value from JSONB field."
  defmacro jsonb_int(field, path) when is_list(path) do
    path_navigation = build_jsonb_path(path)
    quote do
      fragment(unquote("(?#{path_navigation})::integer"), unquote(field))
    end
  end

  @doc "Extract hour from timestamp in UTC."
  defmacro extract_hour_utc(timestamp_field) do
    quote do
      fragment("EXTRACT(HOUR FROM ? AT TIME ZONE 'UTC')", unquote(timestamp_field))
    end
  end

  defp build_jsonb_path(path) do
    {leading, [last]} = Enum.split(path, -1)
    leading_path = Enum.map_join(leading, "", fn key -> "->'#{key}'" end)
    "#{leading_path}->>'#{last}'"
  end
end
```

**Verification:**
```bash
mix compile --warnings-as-errors
# In iex:
import EveDmv.Calculations.Helpers
safe_divide(10, 2)  # => 5.0
safe_divide(10, 0)  # => 0.0
kd_ratio(10, 5)     # => 2.0
```

---

### Workstream 1B: Historical Fetch Database Schema
**Files to Create:**

| File | Purpose |
|------|---------|
| `priv/repo/migrations/TIMESTAMP_create_historical_fetch_status.exs` | Migration for status tracking table |
| `lib/eve_dmv/contexts/killmail_processing/resources/historical_fetch_status.ex` | Ash resource definition |

**Migration SQL:**
```sql
CREATE TABLE historical_fetch_status (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entity_type VARCHAR(20) NOT NULL,
  entity_id BIGINT NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'pending',
  phase1_completed_at TIMESTAMP WITH TIME ZONE,
  phase2_started_at TIMESTAMP WITH TIME ZONE,
  phase2_completed_at TIMESTAMP WITH TIME ZONE,
  oldest_killmail_date DATE,
  target_date DATE,
  killmails_fetched INTEGER DEFAULT 0,
  current_page INTEGER DEFAULT 1,
  last_error TEXT,
  retry_count INTEGER DEFAULT 0,
  last_retry_at TIMESTAMP WITH TIME ZONE,
  inserted_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  CONSTRAINT unique_entity UNIQUE (entity_type, entity_id),
  CONSTRAINT valid_entity_type CHECK (entity_type IN ('character', 'corporation', 'system', 'alliance')),
  CONSTRAINT valid_status CHECK (status IN ('pending', 'phase1_complete', 'in_progress', 'completed', 'failed'))
);

CREATE INDEX idx_historical_fetch_status_entity ON historical_fetch_status(entity_type, entity_id);
CREATE INDEX idx_historical_fetch_status_status ON historical_fetch_status(status);
CREATE INDEX idx_historical_fetch_status_pending ON historical_fetch_status(status)
  WHERE status IN ('pending', 'phase1_complete', 'in_progress');
```

**Ash Resource:** See `HISTORICAL_FETCH_2YEAR_IMPLEMENTATION.md` lines 119-271 for complete implementation.

**Register in API domain:**
```elixir
# lib/eve_dmv/api.ex - add to resources block:
resource EveDmv.Contexts.KillmailProcessing.Resources.HistoricalFetchStatus
```

---

### Workstream 1C: Test Infrastructure Setup
**Files to Create:**

| File | Purpose |
|------|---------|
| `test/support/test_factories.ex` | Shared test data factories |
| `test/support/api_test_helpers.ex` | API testing helpers |

**Test Factories:**
```elixir
# test/support/test_factories.ex
defmodule EveDmv.TestFactories do
  @moduledoc "Shared test data factories for consistent test setup."

  alias EveDmv.Killmails.{KillmailRaw, Participant}

  def build_killmail_raw(attrs \\ %{}) do
    defaults = %{
      killmail_id: System.unique_integer([:positive]),
      killmail_hash: Base.encode16(:crypto.strong_rand_bytes(20)),
      killmail_time: DateTime.utc_now(),
      solar_system_id: 30_000_142,
      victim_character_id: Enum.random(90_000_000..99_999_999),
      victim_corporation_id: Enum.random(98_000_000..98_999_999),
      victim_ship_type_id: 587,
      attacker_count: Enum.random(1..10),
      total_value: Decimal.new("#{Enum.random(1_000_000..1_000_000_000)}"),
      raw_data: %{},
      source: "test"
    }
    Map.merge(defaults, attrs)
  end

  def build_participant(attrs \\ %{}) do
    defaults = %{
      killmail_id: System.unique_integer([:positive]),
      killmail_time: DateTime.utc_now(),
      character_id: Enum.random(90_000_000..99_999_999),
      corporation_id: Enum.random(98_000_000..98_999_999),
      ship_type_id: 587,
      solar_system_id: 30_000_142,
      damage_done: Enum.random(100..10000),
      is_victim: false,
      final_blow: false,
      is_npc: false
    }
    Map.merge(defaults, attrs)
  end

  def insert_killmail_raw!(attrs \\ %{}) do
    attrs
    |> build_killmail_raw()
    |> then(&Ash.create!(KillmailRaw, &1, domain: EveDmv.Api))
  end

  def insert_participant!(attrs \\ %{}) do
    attrs
    |> build_participant()
    |> then(&Ash.create!(Participant, &1, domain: EveDmv.Api))
  end
end
```

---

### Phase 1 Parallel Execution Plan

```
┌─────────────────────────────────────────────────────────────────┐
│                        PHASE 1                                   │
├─────────────────┬─────────────────┬─────────────────────────────┤
│  Workstream 1A  │  Workstream 1B  │  Workstream 1C              │
│  Ash Foundation │  Historical DB  │  Test Infrastructure        │
│                 │                 │                             │
│  - base.ex      │  - migration    │  - test_factories.ex        │
│  - helpers.ex   │  - resource.ex  │  - api_test_helpers.ex      │
│  - fragments.ex │  - api.ex reg   │                             │
└─────────────────┴─────────────────┴─────────────────────────────┘
                              │
                              ▼
                    Quality Gate Check
```

**Dependencies:** None - all three workstreams can run in parallel.

---

## Phase 2: Core Resource Enhancements

**Objective:** Enhance existing Ash resources with aggregates and calculations.

### Workstream 2A: KillmailRaw Enhancements
**File to Modify:** `lib/eve_dmv/external/killmails/killmail_raw.ex`

**Add Aggregates (after line ~248):**
```elixir
aggregates do
  count :participant_count, :participants do
    description("Number of participants in this killmail")
  end

  count :attacker_count, :participants do
    description("Number of attackers in this killmail")
    filter expr(is_victim == false)
  end

  sum :total_attacker_damage, :participants, :damage_done do
    description("Total damage dealt by all attackers")
    filter expr(is_victim == false)
  end

  count :non_victim_count, :participants do
    filter expr(is_victim == false)
  end
end
```

**Add Calculations (extend existing block ~line 262):**
```elixir
calculations do
  # ... existing calculations ...

  calculate(:is_solo_kill, :boolean,
    description: "True if only one attacker was involved",
    calculation: expr(non_victim_count == 1)
  )

  calculate(:is_high_value, :boolean,
    description: "True if kill value exceeds 1 billion ISK",
    calculation: expr(total_value > 1_000_000_000)
  )

  calculate(:age_in_days, :integer,
    description: "Age of the killmail in days",
    calculation: fn records, _context ->
      now = DateTime.utc_now()
      Enum.map(records, fn record ->
        DateTime.diff(now, record.killmail_time, :day)
      end)
    end
  )
end
```

**Add Custom Read Actions (after line ~214):**
```elixir
read :by_character_involvement do
  description("Find killmails where character was involved")

  argument :character_id, :integer, allow_nil?: false
  argument :since_days, :integer, default: 90
  argument :limit, :integer, default: 100

  filter expr(
    victim_character_id == ^arg(:character_id) or
    fragment(
      "EXISTS (SELECT 1 FROM jsonb_array_elements(raw_data->'attackers') a
       WHERE (a->>'character_id')::integer = ?)",
      ^arg(:character_id)
    )
  )

  prepare build(sort: [killmail_time: :desc], limit: arg(:limit))
end

read :by_corporation_involvement do
  description("Find killmails involving a corporation")

  argument :corporation_id, :integer, allow_nil?: false
  argument :involvement_type, :atom do
    constraints one_of: [:all, :kills, :losses]
    default :all
  end
  argument :since_days, :integer, default: 90

  prepare fn query, context ->
    corp_id = context.arguments.corporation_id
    involvement = context.arguments.involvement_type
    days = context.arguments.since_days
    since_date = DateTime.add(DateTime.utc_now(), -days, :day)

    query
    |> Ash.Query.filter(killmail_time >= ^since_date)
    |> apply_corporation_filter(corp_id, involvement)
    |> Ash.Query.sort(killmail_time: :desc)
    |> Ash.Query.limit(100)
  end
end
```

---

### Workstream 2B: Participant Resource Enhancements
**File to Modify:** `lib/eve_dmv/external/killmails/participant.ex`

**Add Action (after line ~352):**
```elixir
read :character_activity_summary do
  description("Get activity summary for a character with kill/loss breakdown")

  argument :character_id, :integer, allow_nil?: false
  argument :since_days, :integer, default: 90
  argument :limit, :integer, default: 50

  pagination do
    offset? true
    default_limit 50
    max_page_size 100
  end

  prepare fn query, context ->
    char_id = context.arguments.character_id
    days = context.arguments.since_days
    since_date = DateTime.add(DateTime.utc_now(), -days, :day)

    query
    |> Ash.Query.filter(character_id == ^char_id)
    |> Ash.Query.filter(killmail_time >= ^since_date)
    |> Ash.Query.load([:ship_type, :participation_type])
    |> Ash.Query.sort(killmail_time: :desc)
  end
end
```

---

### Workstream 2C: API Module Tests - Batch 1 (Highest Priority)
**Files to Create:**

| File | Lines of API | Priority |
|------|--------------|----------|
| `test/eve_dmv/contexts/combat_intelligence/api_test.exs` | 393 | Critical |
| `test/eve_dmv/contexts/surveillance/api_test.exs` | 340 | Critical |
| `test/eve_dmv/contexts/killmail_processing/api_test.exs` | 356 | Critical |

**Template for API Tests:**
```elixir
defmodule EveDmv.Contexts.CombatIntelligence.ApiTest do
  use EveDmv.DataCase, async: true

  alias EveDmv.Contexts.CombatIntelligence.Api
  import EveDmv.TestFactories

  describe "public API functions" do
    # List all public functions from the API module and test each
  end

  describe "error handling" do
    test "returns error for invalid input" do
      # Test error paths
    end
  end

  describe "edge cases" do
    test "handles empty data gracefully" do
      # Test with no data
    end
  end
end
```

**Instructions for AI Assistant:**
1. Read the API module at `lib/eve_dmv/contexts/combat_intelligence/api.ex`
2. Identify all public functions (those with `@doc` or no `defp`)
3. Create a test case for each function's happy path
4. Create test cases for error paths
5. Create test cases for edge cases (nil inputs, empty lists, etc.)

---

### Phase 2 Parallel Execution Plan

```
┌─────────────────────────────────────────────────────────────────┐
│                        PHASE 2                                   │
├─────────────────┬─────────────────┬─────────────────────────────┤
│  Workstream 2A  │  Workstream 2B  │  Workstream 2C              │
│  KillmailRaw    │  Participant    │  API Tests Batch 1          │
│                 │                 │                             │
│  - aggregates   │  - activity     │  - combat_intelligence      │
│  - calculations │    summary      │  - surveillance             │
│  - read actions │    action       │  - killmail_processing      │
└─────────────────┴─────────────────┴─────────────────────────────┘
                              │
                              ▼
                    Quality Gate Check
```

**Dependencies:**
- 2A and 2B depend on Phase 1A (Ash foundation)
- 2C depends on Phase 1C (test infrastructure)
- 2A, 2B, and 2C can run in parallel with each other

---

## Phase 3: Character & Corporation Statistics

**Objective:** Create virtual resources for statistics and add corporation aggregates.

### Workstream 3A: CharacterStats Resource
**File to Create:** `lib/eve_dmv/contexts/character_intelligence/resources/character_stats.ex`

**Complete Implementation:**
```elixir
defmodule EveDmv.Contexts.CharacterIntelligence.Resources.CharacterStats do
  @moduledoc """
  Virtual resource for character statistics.
  Replaces CharacterQueries.get_character_stats/2 with Ash-native approach.
  """

  use Ash.Resource,
    domain: EveDmv.Api,
    data_layer: :embedded

  alias EveDmv.Killmails.Participant

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
        kills * 1.0
      end
    ) do
      description("Kill/Death ratio")
    end

    calculate :isk_efficiency, :float, expr(
      if isk_destroyed + isk_lost > 0 do
        isk_destroyed / (isk_destroyed + isk_lost) * 100
      else
        0.0
      end
    ) do
      description("ISK efficiency as percentage")
    end

    calculate :net_isk, :decimal, expr(isk_destroyed - isk_lost) do
      description("Net ISK (destroyed minus lost)")
    end
  end

  code_interface do
    domain EveDmv.Api
    define :calculate_for_character, action: :calculate, args: [:character_id, :since_date]
  end

  actions do
    action :calculate, :struct do
      description("Calculate statistics for a character within a time period")

      argument :character_id, :integer, allow_nil?: false
      argument :since_date, :utc_datetime, allow_nil?: true

      run fn input, _context ->
        character_id = input.arguments.character_id
        since_date = input.arguments.since_date || default_since_date()
        stats = calculate_from_participants(character_id, since_date)
        {:ok, struct(__MODULE__, Map.put(stats, :character_id, character_id))}
      end
    end
  end

  defp calculate_from_participants(character_id, since_date) do
    kills_query =
      Participant
      |> Ash.Query.filter(
        character_id == ^character_id and
        killmail_time >= ^since_date and
        is_victim == false
      )

    deaths_query =
      Participant
      |> Ash.Query.filter(
        character_id == ^character_id and
        killmail_time >= ^since_date and
        is_victim == true
      )

    kills_task = Task.async(fn -> Ash.count!(kills_query) end)
    deaths_task = Task.async(fn -> Ash.count!(deaths_query) end)

    kills = Task.await(kills_task)
    deaths = Task.await(deaths_task)

    period_days = Date.diff(Date.utc_today(), DateTime.to_date(since_date))

    %{
      kills: kills,
      deaths: deaths,
      period_days: period_days,
      isk_destroyed: Decimal.new("0"),
      isk_lost: Decimal.new("0")
    }
  end

  defp default_since_date do
    DateTime.utc_now()
    |> DateTime.add(-90, :day)
    |> DateTime.truncate(:second)
  end
end
```

**Register in API:**
```elixir
# lib/eve_dmv/api.ex
resource EveDmv.Contexts.CharacterIntelligence.Resources.CharacterStats
```

---

### Workstream 3B: Corporation Stats Loader
**File to Create:** `lib/eve_dmv/contexts/corporation/services/stats_loader.ex`

See `ASH_MIGRATION_PLAN.md` lines 730-866 for complete implementation.

**Key Functions:**
- `load_stats/2` - Main entry point with caching
- `compute_stats/2` - Uses materialized view with fallback
- `compute_stats_direct/2` - Direct query fallback

---

### Workstream 3C: API Module Tests - Batch 2
**Files to Create:**

| File | Lines of API | Priority |
|------|--------------|----------|
| `test/eve_dmv/contexts/corporation_intelligence/api_test.exs` | 471 | High |
| `test/eve_dmv/contexts/fleet_operations/api_test.exs` | 422 | High |
| `test/eve_dmv/contexts/system_analysis/api_test.exs` | 420 | High |

---

### Workstream 3D: Threat Surveillance Tests (Critical - 0% Coverage)
**Files to Create:**

| File | Target Module Lines | Priority |
|------|---------------------|----------|
| `test/eve_dmv/contexts/threat_surveillance/threat_detector_test.exs` | 757 | Critical |
| `test/eve_dmv/contexts/threat_surveillance/intelligence_correlator_test.exs` | 551 | Critical |
| `test/eve_dmv/contexts/threat_surveillance/alert_manager_test.exs` | 466 | Critical |

**Test Strategy for Large Modules:**
1. Read the source file to identify public functions
2. Group tests by describe blocks matching function groupings
3. Test happy paths first
4. Add error handling tests
5. Add edge case tests
6. Aim for 70%+ coverage of public interface

---

### Phase 3 Parallel Execution Plan

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              PHASE 3                                         │
├─────────────────┬─────────────────┬─────────────────┬───────────────────────┤
│  Workstream 3A  │  Workstream 3B  │  Workstream 3C  │  Workstream 3D        │
│  CharacterStats │  Corp Stats     │  API Tests B2   │  Threat Tests         │
│                 │  Loader         │                 │                       │
│  - resource     │  - service      │  - corp_intel   │  - threat_detector    │
│  - api.ex reg   │  - caching      │  - fleet_ops    │  - intel_correlator   │
│                 │  - fallbacks    │  - system_anal  │  - alert_manager      │
└─────────────────┴─────────────────┴─────────────────┴───────────────────────┘
                                    │
                                    ▼
                          Quality Gate Check
```

**Dependencies:**
- 3A depends on Phase 2B (Participant enhancements)
- 3B depends on Phase 1A (Ash foundation)
- 3C and 3D depend on Phase 1C (test infrastructure)
- All workstreams can run in parallel

---

## Phase 4: Historical Fetch Backend Services

**Objective:** Implement the backend services for 2-year killmail fetching.

### Workstream 4A: ExtendedHistoricalFetcher Service
**File to Create:** `lib/eve_dmv/contexts/killmail_processing/domain/extended_historical_fetcher.ex`

See `HISTORICAL_FETCH_2YEAR_IMPLEMENTATION.md` lines 279-606 for complete implementation.

**Key Components:**
- `fetch_extended_history/3` - Main entry point
- `fetch_pages/7` - Recursive page fetching with rate limiting
- `fetch_page/3` - Single page fetch from zkillboard
- `process_kills/3` - Filter and transform kills
- `store_kills/1` - Persist to database
- `store_participants/3` - Extract and store participants

**Configuration Constants:**
```elixir
@zkillboard_base_url "https://zkillboard.com/api"
@rate_limit_delay 1_000  # 1 second between requests
@kills_per_page 200      # zkillboard max per page
@max_pages 100           # Safety limit
@two_years_days 730
```

---

### Workstream 4B: HistoricalFetchWorker GenServer
**File to Create:** `lib/eve_dmv/contexts/killmail_processing/domain/historical_fetch_worker.ex`

See `HISTORICAL_FETCH_2YEAR_IMPLEMENTATION.md` lines 614-836 for complete implementation.

**Key Components:**
- GenServer implementation
- Queue management (`queue_fetch/2`)
- Status tracking (`get_status/2`)
- PubSub integration (`subscribe/2`, `unsubscribe/2`)
- Background task processing

**Application Supervisor Update:**
```elixir
# lib/eve_dmv/application.ex - add to children list:
{EveDmv.Contexts.KillmailProcessing.Domain.HistoricalFetchWorker, []}
```

---

### Workstream 4C: KillmailProcessing API Updates
**File to Modify:** `lib/eve_dmv/contexts/killmail_processing/api.ex`

**Add Functions:**
```elixir
@doc "Queue entity for 2-year historical fetch (Phase 2)."
@spec queue_extended_historical_fetch(atom(), integer()) :: Result.t(map())
def queue_extended_historical_fetch(entity_type, entity_id)
    when entity_type in [:character, :corporation, :system, :alliance] do
  Domain.HistoricalFetchWorker.queue_fetch(entity_type, entity_id)
end

@doc "Get the historical fetch status for an entity."
@spec get_historical_fetch_status(atom(), integer()) :: Result.t(map()) | {:error, :not_found}
def get_historical_fetch_status(entity_type, entity_id) do
  Domain.HistoricalFetchWorker.get_status(entity_type, entity_id)
end

@doc "Subscribe to historical fetch status updates."
@spec subscribe_to_historical_fetch(atom(), integer()) :: :ok
def subscribe_to_historical_fetch(entity_type, entity_id) do
  Domain.HistoricalFetchWorker.subscribe(entity_type, entity_id)
end

@doc "Mark Phase 1 complete and queue Phase 2."
@spec complete_phase1_and_queue_phase2(atom(), integer()) :: Result.t(map())
def complete_phase1_and_queue_phase2(entity_type, entity_id) do
  # Implementation - see HISTORICAL_FETCH_2YEAR_IMPLEMENTATION.md lines 890-908
end
```

---

### Workstream 4D: Threat Assessment Tests (Critical - 0% Coverage)
**Files to Create:**

| File | Target Module Lines | Priority |
|------|---------------------|----------|
| `test/eve_dmv/contexts/threat_assessment/vulnerability_scanner_test.exs` | 1,096 | Critical |
| `test/eve_dmv/contexts/threat_assessment/assessment_engine_test.exs` | 903 | Critical |
| `test/eve_dmv/contexts/threat_assessment/threat_calculator_test.exs` | 705 | Critical |

---

### Phase 4 Parallel Execution Plan

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              PHASE 4                                         │
├─────────────────┬─────────────────┬─────────────────┬───────────────────────┤
│  Workstream 4A  │  Workstream 4B  │  Workstream 4C  │  Workstream 4D        │
│  ExtendedFetch  │  FetchWorker    │  API Updates    │  Threat Assess Tests  │
│                 │                 │                 │                       │
│  - fetcher svc  │  - genserver    │  - api funcs    │  - vuln_scanner       │
│  - zkb api      │  - queue mgmt   │  - delegates    │  - assess_engine      │
│  - rate limit   │  - pubsub       │                 │  - threat_calc        │
└─────────────────┴─────────────────┴─────────────────┴───────────────────────┘
                                    │
                                    ▼
                          Quality Gate Check
```

**Dependencies:**
- 4A depends on Phase 1B (HistoricalFetchStatus resource)
- 4B depends on 4A (ExtendedHistoricalFetcher)
- 4C depends on 4B (HistoricalFetchWorker)
- 4D is independent (test infrastructure only)
- 4A, 4B, 4C must be sequential; 4D can run in parallel

---

## Phase 5: Query Optimizations & Batch Loading

**Objective:** Create hybrid batch loading and finalize Ash migration patterns.

### Workstream 5A: Batch Loader Service
**File to Create:** `lib/eve_dmv/contexts/character_intelligence/services/batch_loader.ex`

See `ASH_MIGRATION_PLAN.md` lines 896-976 for complete implementation.

**Key Design Decision:** Some queries MUST stay as raw SQL:
- Window functions (ROW_NUMBER, FIRST_VALUE)
- Complex CTEs with multiple stages
- Materialized view queries
- Batch operations with UNION ALL

The BatchLoader delegates to `QueryOptimizations` for these cases.

---

### Workstream 5B: Feature Flags for Migration
**File to Create:** `lib/eve_dmv/config/query_migration.ex`

```elixir
defmodule EveDmv.Config.QueryMigration do
  @moduledoc "Feature flags for gradual migration from raw SQL to Ash queries."

  def use_ash_character_stats? do
    Application.get_env(:eve_dmv, :query_migration)[:use_ash_character_stats] || false
  end

  def use_ash_corporation_stats? do
    Application.get_env(:eve_dmv, :query_migration)[:use_ash_corporation_stats] || false
  end

  def log_comparison_mismatches? do
    Application.get_env(:eve_dmv, :query_migration)[:log_comparison_mismatches] || false
  end
end
```

**Config Update:**
```elixir
# config/config.exs
config :eve_dmv, :query_migration,
  use_ash_character_stats: true,
  use_ash_corporation_stats: false,
  log_comparison_mismatches: true
```

---

### Workstream 5C: Battle Analysis Tests (Gaps)
**Files to Create:**

| File | Target Module Lines | Current Coverage |
|------|---------------------|------------------|
| `test/eve_dmv/contexts/battle_analysis/ship_performance_analyzer_test.exs` | 2,064 | 0% |
| `test/eve_dmv/contexts/battle_analysis/recommendation_engine_test.exs` | 1,254 | 0% |
| `test/eve_dmv/contexts/battle_analysis/detection_service_test.exs` | 1,018 | 0% |

---

### Workstream 5D: API Module Tests - Batch 3
**Files to Create:**

| File | Lines of API |
|------|--------------|
| `test/eve_dmv/contexts/market_intelligence/api_test.exs` | 232 |
| `test/eve_dmv/contexts/threat_surveillance/api_test.exs` | 134 |
| `test/eve_dmv/contexts/corporation/api_test.exs` | 113 |
| `test/eve_dmv/contexts/intelligence/api_test.exs` | 102 |

---

### Phase 5 Parallel Execution Plan

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              PHASE 5                                         │
├─────────────────┬─────────────────┬─────────────────┬───────────────────────┤
│  Workstream 5A  │  Workstream 5B  │  Workstream 5C  │  Workstream 5D        │
│  BatchLoader    │  Feature Flags  │  Battle Tests   │  API Tests B3         │
│                 │                 │                 │                       │
│  - hybrid svc   │  - config mod   │  - ship_perf    │  - market_intel       │
│  - sql delegate │  - flags        │  - recommend    │  - threat_surv        │
│                 │                 │  - detection    │  - corporation        │
└─────────────────┴─────────────────┴─────────────────┴───────────────────────┘
                                    │
                                    ▼
                          Quality Gate Check
```

**Dependencies:** All workstreams can run in parallel.

---

## Phase 6: Historical Fetch UI Components

**Objective:** Create frontend components for historical fetch status display.

### Workstream 6A: HistoricalFetchIndicator Component
**File to Create:** `lib/eve_dmv_web/components/historical_fetch_indicator.ex`

See `HISTORICAL_FETCH_2YEAR_IMPLEMENTATION.md` lines 1017-1159 for complete implementation.

**Component States:**
1. `nil` / `:pending` - Loading indicator
2. `:phase1_complete` - Queued indicator
3. `:in_progress` - Progress bar with kill count
4. `:completed` - Checkmark with total count
5. `:failed` - Error with retry button

---

### Workstream 6B: PlayerProfileLive Updates
**File to Modify:** `lib/eve_dmv_web/live/player_profile_live.ex`

**Changes Required:**
1. Import the indicator component
2. Subscribe to historical fetch updates in `mount/3`
3. Add `historical_fetch_status` assign
4. Handle `:historical_fetch_update` messages
5. Handle `retry_historical_fetch` event

See `HISTORICAL_FETCH_2YEAR_IMPLEMENTATION.md` lines 1167-1268 for implementation details.

**Template Update:**
```heex
<!-- Add near top of profile, after character info -->
<div class="mb-4">
  <.historical_fetch_indicator
    status={@historical_fetch_status}
    entity_type={:character}
    entity_id={@character_id}
  />
</div>
```

---

### Workstream 6C: Other LiveView Updates
**Files to Modify:**

| File | Entity Type |
|------|-------------|
| `lib/eve_dmv_web/live/corporation_live.ex` | `:corporation` |
| `lib/eve_dmv_web/live/system_live.ex` | `:system` |
| `lib/eve_dmv_web/live/alliance_live.ex` | `:alliance` |

Same pattern as PlayerProfileLive.

---

### Workstream 6D: Character Intelligence Tests
**Files to Create:**

| File | Priority |
|------|----------|
| `test/eve_dmv/contexts/character_intelligence/resources/character_stats_test.exs` | High |
| `test/eve_dmv/contexts/character_intelligence/services/batch_loader_test.exs` | Medium |

**CharacterStats Test Template:**
```elixir
defmodule EveDmv.Contexts.CharacterIntelligence.Resources.CharacterStatsTest do
  use EveDmv.DataCase, async: true

  alias EveDmv.Contexts.CharacterIntelligence.Resources.CharacterStats
  import EveDmv.TestFactories

  describe "calculate_for_character/2" do
    test "returns zero counts for character with no activity" do
      {:ok, stats} = CharacterStats.calculate_for_character(999999, nil)

      assert stats.kills == 0
      assert stats.deaths == 0
      assert stats.kd_ratio == 0.0
    end

    test "correctly counts kills and deaths" do
      character_id = 12345
      now = DateTime.utc_now()
      killmail = insert_killmail_raw!()

      # Create 3 kills
      for _ <- 1..3 do
        insert_participant!(
          character_id: character_id,
          killmail_id: killmail.killmail_id,
          is_victim: false,
          killmail_time: now
        )
      end

      # Create 1 death
      insert_participant!(
        character_id: character_id,
        killmail_id: killmail.killmail_id,
        is_victim: true,
        killmail_time: now
      )

      {:ok, stats} = CharacterStats.calculate_for_character(character_id, nil)

      assert stats.kills == 3
      assert stats.deaths == 1
      assert stats.kd_ratio == 3.0
    end
  end
end
```

---

### Phase 6 Parallel Execution Plan

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              PHASE 6                                         │
├─────────────────┬─────────────────┬─────────────────┬───────────────────────┤
│  Workstream 6A  │  Workstream 6B  │  Workstream 6C  │  Workstream 6D        │
│  UI Component   │  PlayerProfile  │  Other LiveViews│  CharIntel Tests      │
│                 │                 │                 │                       │
│  - indicator    │  - subscribe    │  - corp_live    │  - char_stats         │
│  - states       │  - handlers     │  - system_live  │  - batch_loader       │
│  - styling      │  - template     │  - alliance     │                       │
└─────────────────┴─────────────────┴─────────────────┴───────────────────────┘
                                    │
                                    ▼
                          Quality Gate Check
```

**Dependencies:**
- 6A is independent
- 6B depends on 6A
- 6C depends on 6A
- 6D depends on Phase 3A (CharacterStats resource)

---

## Phase 7: Data Loader Integration

**Objective:** Integrate new Ash queries into existing data loaders.

### Workstream 7A: Character Data Loader Updates
**File to Modify:** `lib/eve_dmv_web/live/character_analysis/helpers/character_data_loader.ex`

**Replace Old Calls:**
```elixir
# Before:
CharacterQueries.get_character_stats(character_id, since_date)

# After:
alias EveDmv.Contexts.CharacterIntelligence.Resources.CharacterStats

case CharacterStats.calculate_for_character(character_id, since_date) do
  {:ok, stats} ->
    %{
      kills: stats.kills,
      deaths: stats.deaths,
      kd_ratio: stats.kd_ratio
    }
  {:error, _} ->
    %{kills: 0, deaths: 0, kd_ratio: 0.0}
end
```

---

### Workstream 7B: Corporation Data Loader Updates
Similar pattern using `StatsLoader.load_stats/2`.

---

### Workstream 7C: PlayerProfile DataLoader Historical Integration
**File to Modify:** `lib/eve_dmv/player_profile/data_loader.ex`

See `HISTORICAL_FETCH_2YEAR_IMPLEMENTATION.md` lines 915-1006 for implementation.

**Key Change:** After Phase 1 completes, queue Phase 2:
```elixir
# In load_character_data/2, after historical fetch:
queue_phase2_fetch(:character, character_id)
```

---

### Workstream 7D: Corporation Intelligence Tests
**Files to Create:**

| File | Target Module Lines |
|------|---------------------|
| `test/eve_dmv/contexts/corporation_intelligence/combat_doctrine_analyzer_test.exs` | 2,644 |

---

### Phase 7 Parallel Execution Plan

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              PHASE 7                                         │
├─────────────────┬─────────────────┬─────────────────┬───────────────────────┤
│  Workstream 7A  │  Workstream 7B  │  Workstream 7C  │  Workstream 7D        │
│  Char Loader    │  Corp Loader    │  Profile Loader │  CorpIntel Tests      │
│                 │                 │                 │                       │
│  - ash queries  │  - stats_loader │  - phase2 queue │  - doctrine_analyzer  │
│  - deprecation  │  - caching      │  - integration  │                       │
└─────────────────┴─────────────────┴─────────────────┴───────────────────────┘
                                    │
                                    ▼
                          Quality Gate Check
```

---

## Phase 8: Integration Tests & E2E

**Objective:** Add comprehensive integration tests for critical flows.

### Workstream 8A: Historical Fetch Integration Tests
**Files to Create:**

| File | Purpose |
|------|---------|
| `test/eve_dmv/contexts/killmail_processing/domain/extended_historical_fetcher_test.exs` | Fetcher unit tests |
| `test/eve_dmv/contexts/killmail_processing/domain/historical_fetch_worker_test.exs` | Worker unit tests |
| `test/integration/historical_fetch_flow_test.exs` | Full flow integration |

---

### Workstream 8B: Battle Flow Integration Tests
**File to Create:** `test/integration/battle_analysis_flow_test.exs`

Test the complete flow:
1. Killmail ingestion
2. Battle detection
3. Timeline reconstruction
4. Intelligence generation

---

### Workstream 8C: Surveillance Flow Integration Tests
**File to Create:** `test/integration/surveillance_flow_test.exs`

Test:
1. Profile creation
2. Entity matching
3. Alert generation
4. Real-time updates

---

### Workstream 8D: Character Analysis Flow Integration Tests
**File to Create:** `test/integration/character_analysis_flow_test.exs`

Test:
1. ESI data fetch
2. Killmail aggregation
3. Threat scoring
4. Intelligence display

---

### Workstream 8E: Remaining API Tests - Batch 4
**Files to Create:**

| File | Lines |
|------|-------|
| `test/eve_dmv/contexts/combat_analysis/api_test.exs` | 73 |
| `test/eve_dmv/contexts/combat/api_test.exs` | 64 |
| `test/eve_dmv/contexts/battle_analysis/api_test.exs` | 62 |
| `test/eve_dmv/contexts/intelligence_infrastructure/api_test.exs` | 41 |
| `test/eve_dmv/contexts/player_profile/api_test.exs` | 34 |
| `test/eve_dmv/contexts/corporation_analysis/api_test.exs` | 28 |
| `test/eve_dmv/contexts/threat_assessment/api_test.exs` | 26 |

---

### Phase 8 Parallel Execution Plan

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                                    PHASE 8                                               │
├─────────────────┬─────────────────┬─────────────────┬─────────────────┬─────────────────┤
│  Workstream 8A  │  Workstream 8B  │  Workstream 8C  │  Workstream 8D  │  Workstream 8E  │
│  HistFetch Int  │  Battle Int     │  Surv Int       │  CharAnal Int   │  API Tests B4   │
│                 │                 │                 │                 │                 │
│  - fetcher      │  - full flow    │  - profiles     │  - esi fetch    │  - remaining    │
│  - worker       │  - detection    │  - matching     │  - aggregation  │    7 APIs       │
│  - flow         │  - timeline     │  - alerts       │  - scoring      │                 │
└─────────────────┴─────────────────┴─────────────────┴─────────────────┴─────────────────┘
                                           │
                                           ▼
                                 Quality Gate Check
```

**Dependencies:** All workstreams can run in parallel.

---

## Phase 9: LiveView Tests & Controller Tests

**Objective:** Add comprehensive frontend testing.

### Workstream 9A: LiveView Tests - Priority
**Files to Create:**

| File | Target Module Lines |
|------|---------------------|
| `test/eve_dmv_web/live/surveillance_profiles_live_test.exs` | 1,393 |
| `test/eve_dmv_web/live/fleet_operations_live_test.exs` | 1,289 |
| `test/eve_dmv_web/live/battle_analysis_live_test.exs` | 1,257 |
| `test/eve_dmv_web/live/player_profile_live_test.exs` | - |

---

### Workstream 9B: Controller Tests
**Files to Create:**

| File | Purpose |
|------|---------|
| `test/eve_dmv_web/controllers/api/battle_controller_test.exs` | Battle API |
| `test/eve_dmv_web/controllers/api/character_controller_test.exs` | Character API |
| `test/eve_dmv_web/controllers/api/corporation_controller_test.exs` | Corporation API |
| `test/eve_dmv_web/controllers/api/api_key_controller_test.exs` | API Key management |

---

### Workstream 9C: Historical Fetch Component Tests
**File to Create:** `test/eve_dmv_web/components/historical_fetch_indicator_test.exs`

Test all component states and interactions.

---

### Workstream 9D: Migration Comparison Tests
**File to Create:** `test/eve_dmv/migration_comparison_test.exs`

```elixir
defmodule EveDmv.MigrationComparisonTest do
  @moduledoc "Tests that new Ash implementations match old SQL implementations."
  use EveDmv.DataCase, async: false

  alias EveDmv.Platform.Database.CharacterQueries
  alias EveDmv.Contexts.CharacterIntelligence.Resources.CharacterStats

  @tag :migration_comparison
  test "new implementation matches old for character stats" do
    character_id = 12345
    since_date = Date.utc_today() |> Date.add(-90)

    old_stats = CharacterQueries.get_character_stats(character_id, since_date)
    {:ok, new_stats} = CharacterStats.calculate_for_character(
      character_id,
      DateTime.new!(since_date, ~T[00:00:00])
    )

    assert old_stats.kills == new_stats.kills
    assert old_stats.deaths == new_stats.deaths
    assert_in_delta old_stats.kd_ratio, new_stats.kd_ratio, 0.01
  end
end
```

---

### Phase 9 Parallel Execution Plan

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              PHASE 9                                         │
├─────────────────┬─────────────────┬─────────────────┬───────────────────────┤
│  Workstream 9A  │  Workstream 9B  │  Workstream 9C  │  Workstream 9D        │
│  LiveView Tests │  Controller     │  Component Test │  Migration Compare    │
│                 │                 │                 │                       │
│  - surv_prof    │  - battle       │  - indicator    │  - char_stats         │
│  - fleet_ops    │  - character    │    states       │  - corp_stats         │
│  - battle       │  - corporation  │                 │                       │
│  - profile      │  - api_key      │                 │                       │
└─────────────────┴─────────────────┴─────────────────┴───────────────────────┘
                                    │
                                    ▼
                          Quality Gate Check
```

---

## Phase 10: Cleanup, Documentation & Final Validation

**Objective:** Finalize migration, add deprecations, and validate coverage targets.

### Workstream 10A: Add Deprecation Notices
**Files to Modify:**

| File | Functions to Deprecate |
|------|------------------------|
| `lib/eve_dmv/platform/database/character_queries.ex` | `get_character_stats/2` |
| `lib/eve_dmv/platform/database/corporation_queries.ex` | `get_corporation_stats/2` |

**Pattern:**
```elixir
@deprecated "Use CharacterStats.calculate_for_character/2 instead"
def get_character_stats(character_id, since_date) do
  Logger.warning(
    "Deprecated: CharacterQueries.get_character_stats/2 called. " <>
    "Use CharacterStats.calculate_for_character/2 instead."
  )
  # ... existing implementation
end
```

---

### Workstream 10B: Runtime Configuration
**File to Modify:** `config/runtime.exs`

Add historical fetch configuration:
```elixir
config :eve_dmv, EveDmv.Contexts.KillmailProcessing.Domain.ExtendedHistoricalFetcher,
  rate_limit_delay: System.get_env("HISTORICAL_FETCH_RATE_LIMIT", "1000") |> String.to_integer(),
  max_pages: System.get_env("HISTORICAL_FETCH_MAX_PAGES", "100") |> String.to_integer(),
  lookback_days: System.get_env("HISTORICAL_FETCH_LOOKBACK_DAYS", "730") |> String.to_integer()

config :eve_dmv, EveDmv.Contexts.KillmailProcessing.Domain.HistoricalFetchWorker,
  check_interval: System.get_env("HISTORICAL_FETCH_CHECK_INTERVAL", "30000") |> String.to_integer(),
  enabled: System.get_env("HISTORICAL_FETCH_ENABLED", "true") == "true"
```

---

### Workstream 10C: Coverage Validation
Run comprehensive coverage report:

```bash
MIX_ENV=test mix test --cover
```

**Targets:**
| Metric | Target |
|--------|--------|
| Overall Coverage | 50%+ |
| API Coverage | 80%+ |
| Critical Path Coverage | 80%+ |

---

### Workstream 10D: Documentation Updates
**Files to Update:**

| File | Updates |
|------|---------|
| `CLAUDE.md` | Add historical fetch feature docs |
| `docs/ARCHITECTURE.md` | Add Ash migration patterns |

---

### Phase 10 Parallel Execution Plan

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              PHASE 10                                        │
├─────────────────┬─────────────────┬─────────────────┬───────────────────────┤
│  Workstream 10A │  Workstream 10B │  Workstream 10C │  Workstream 10D       │
│  Deprecations   │  Config         │  Coverage Valid │  Documentation        │
│                 │                 │                 │                       │
│  - char_queries │  - runtime.exs  │  - run coverage │  - CLAUDE.md          │
│  - corp_queries │  - env vars     │  - validate 50% │  - ARCHITECTURE.md    │
│  - warnings     │                 │  - report gaps  │                       │
└─────────────────┴─────────────────┴─────────────────┴───────────────────────┘
                                    │
                                    ▼
                          Final Quality Gate
```

---

## Summary: Files to Create

### New Files (Ash Migration)
| File | Phase |
|------|-------|
| `lib/eve_dmv/calculations/base.ex` | 1 |
| `lib/eve_dmv/calculations/helpers.ex` | 1 |
| `lib/eve_dmv/ash/fragments.ex` | 1 |
| `lib/eve_dmv/contexts/character_intelligence/resources/character_stats.ex` | 3 |
| `lib/eve_dmv/contexts/corporation/services/stats_loader.ex` | 3 |
| `lib/eve_dmv/contexts/character_intelligence/services/batch_loader.ex` | 5 |
| `lib/eve_dmv/config/query_migration.ex` | 5 |

### New Files (Historical Fetch)
| File | Phase |
|------|-------|
| `priv/repo/migrations/TIMESTAMP_create_historical_fetch_status.exs` | 1 |
| `lib/eve_dmv/contexts/killmail_processing/resources/historical_fetch_status.ex` | 1 |
| `lib/eve_dmv/contexts/killmail_processing/domain/extended_historical_fetcher.ex` | 4 |
| `lib/eve_dmv/contexts/killmail_processing/domain/historical_fetch_worker.ex` | 4 |
| `lib/eve_dmv_web/components/historical_fetch_indicator.ex` | 6 |

### New Test Files (Priority Order)
| File | Phase | Priority |
|------|-------|----------|
| `test/support/test_factories.ex` | 1 | Setup |
| `test/eve_dmv/contexts/combat_intelligence/api_test.exs` | 2 | Critical |
| `test/eve_dmv/contexts/surveillance/api_test.exs` | 2 | Critical |
| `test/eve_dmv/contexts/killmail_processing/api_test.exs` | 2 | Critical |
| `test/eve_dmv/contexts/threat_surveillance/threat_detector_test.exs` | 3 | Critical |
| `test/eve_dmv/contexts/threat_surveillance/alert_manager_test.exs` | 3 | Critical |
| `test/eve_dmv/contexts/threat_assessment/vulnerability_scanner_test.exs` | 4 | Critical |
| `test/eve_dmv/contexts/threat_assessment/assessment_engine_test.exs` | 4 | Critical |
| `test/eve_dmv/contexts/battle_analysis/ship_performance_analyzer_test.exs` | 5 | High |
| `test/eve_dmv/contexts/character_intelligence/resources/character_stats_test.exs` | 6 | High |
| `test/integration/historical_fetch_flow_test.exs` | 8 | Medium |
| `test/integration/battle_analysis_flow_test.exs` | 8 | Medium |
| `test/integration/surveillance_flow_test.exs` | 8 | Medium |
| `test/eve_dmv_web/live/surveillance_profiles_live_test.exs` | 9 | Medium |
| `test/eve_dmv_web/live/battle_analysis_live_test.exs` | 9 | Medium |

### Files to Modify
| File | Phase | Changes |
|------|-------|---------|
| `lib/eve_dmv/api.ex` | 1, 3 | Register new resources |
| `lib/eve_dmv/external/killmails/killmail_raw.ex` | 2 | Aggregates, calculations, actions |
| `lib/eve_dmv/external/killmails/participant.ex` | 2 | New action |
| `lib/eve_dmv/contexts/killmail_processing/api.ex` | 4 | Historical fetch functions |
| `lib/eve_dmv/application.ex` | 4 | Add worker to supervision |
| `lib/eve_dmv_web/live/player_profile_live.ex` | 6 | Historical fetch UI |
| `lib/eve_dmv_web/live/corporation_live.ex` | 6 | Historical fetch UI |
| `lib/eve_dmv_web/live/system_live.ex` | 6 | Historical fetch UI |
| `lib/eve_dmv_web/live/character_analysis/helpers/character_data_loader.ex` | 7 | Use Ash queries |
| `config/config.exs` | 5 | Query migration flags |
| `config/runtime.exs` | 10 | Historical fetch config |

---

## Progress Tracking

### Phase Completion Checklist

- [ ] **Phase 1:** Foundation & Infrastructure
  - [ ] 1A: Ash Migration Foundation
  - [ ] 1B: Historical Fetch Database Schema
  - [ ] 1C: Test Infrastructure Setup
  - [ ] Quality Gate: PASS

- [ ] **Phase 2:** Core Resource Enhancements
  - [ ] 2A: KillmailRaw Enhancements
  - [ ] 2B: Participant Resource Enhancements
  - [ ] 2C: API Module Tests - Batch 1
  - [ ] Quality Gate: PASS

- [ ] **Phase 3:** Character & Corporation Statistics
  - [ ] 3A: CharacterStats Resource
  - [ ] 3B: Corporation Stats Loader
  - [ ] 3C: API Module Tests - Batch 2
  - [ ] 3D: Threat Surveillance Tests
  - [ ] Quality Gate: PASS

- [ ] **Phase 4:** Historical Fetch Backend Services
  - [ ] 4A: ExtendedHistoricalFetcher Service
  - [ ] 4B: HistoricalFetchWorker GenServer
  - [ ] 4C: KillmailProcessing API Updates
  - [ ] 4D: Threat Assessment Tests
  - [ ] Quality Gate: PASS

- [ ] **Phase 5:** Query Optimizations & Batch Loading
  - [ ] 5A: Batch Loader Service
  - [ ] 5B: Feature Flags for Migration
  - [ ] 5C: Battle Analysis Tests
  - [ ] 5D: API Module Tests - Batch 3
  - [ ] Quality Gate: PASS

- [ ] **Phase 6:** Historical Fetch UI Components
  - [ ] 6A: HistoricalFetchIndicator Component
  - [ ] 6B: PlayerProfileLive Updates
  - [ ] 6C: Other LiveView Updates
  - [ ] 6D: Character Intelligence Tests
  - [ ] Quality Gate: PASS

- [ ] **Phase 7:** Data Loader Integration
  - [ ] 7A: Character Data Loader Updates
  - [ ] 7B: Corporation Data Loader Updates
  - [ ] 7C: PlayerProfile DataLoader Historical Integration
  - [ ] 7D: Corporation Intelligence Tests
  - [ ] Quality Gate: PASS

- [ ] **Phase 8:** Integration Tests & E2E
  - [ ] 8A: Historical Fetch Integration Tests
  - [ ] 8B: Battle Flow Integration Tests
  - [ ] 8C: Surveillance Flow Integration Tests
  - [ ] 8D: Character Analysis Flow Integration Tests
  - [ ] 8E: Remaining API Tests - Batch 4
  - [ ] Quality Gate: PASS

- [ ] **Phase 9:** LiveView Tests & Controller Tests
  - [ ] 9A: LiveView Tests - Priority
  - [ ] 9B: Controller Tests
  - [ ] 9C: Historical Fetch Component Tests
  - [ ] 9D: Migration Comparison Tests
  - [ ] Quality Gate: PASS

- [ ] **Phase 10:** Cleanup, Documentation & Final Validation
  - [ ] 10A: Add Deprecation Notices
  - [ ] 10B: Runtime Configuration
  - [ ] 10C: Coverage Validation (50%+)
  - [ ] 10D: Documentation Updates
  - [ ] Final Quality Gate: PASS

---

## Success Metrics

| Metric | Current | Target | Measured By |
|--------|---------|--------|-------------|
| Test Coverage | 7.6% | 50%+ | `mix test --cover` |
| API Coverage | 0% | 80%+ | API test coverage |
| Test Files | 57 | 120+ | File count |
| Test Cases | 890 | 1,500+ | Test count |
| Dialyzer Errors | 0 | 0 | `mix dialyzer` |
| Credo Issues | 0 | 0 | `mix credo --strict` |
| Ash Migration | 0% | 60% | Migrated query count |
| Historical Fetch | Not implemented | Complete | Feature functional |

---

*Generated: 2026-01-05*

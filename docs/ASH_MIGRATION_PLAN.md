# SQL to Ash Migration Implementation Plan

## Executive Summary

This plan outlines the migration of ~40+ handwritten SQL queries to Ash-native approaches. The migration is organized into 6 phases, prioritizing by complexity and impact.

**Current Status**: No phases have been completed. The codebase still uses raw SQL queries in the locations documented below.

---

## Current State Analysis (Updated 2025-01)

### Query Locations - Detailed Inventory

| File | Functions | Line Count | Complexity | Status |
|------|-----------|------------|------------|--------|
| `lib/eve_dmv/platform/database/character_queries.ex` | 4 functions | ~230 lines | Medium | **Not migrated** |
| `lib/eve_dmv/platform/database/corporation_queries.ex` | 8 functions | ~500 lines | High | **Not migrated** |
| `lib/eve_dmv/platform/database/query_optimizations.ex` | 6 functions | ~380 lines | High | **Partially keep** |
| `lib/eve_dmv/utilities/query_helpers/killmail_queries.ex` | 5+ builders | ~150 lines | Medium | **Not migrated** |
| `lib/eve_dmv/contexts/character_intelligence/analyzers/character_intelligence_analyzer.ex` | 15+ queries | ~1900 lines | Very High | **Not migrated** |

### Existing Ash Resources (Reference)

These resources exist and can be extended:

| Resource | Location | Current State |
|----------|----------|---------------|
| `KillmailRaw` | `lib/eve_dmv/external/killmails/killmail_raw.ex` | Has basic aggregates (`participant_count`), basic calculations (`age_in_hours`, `is_recent`) |
| `Participant` | `lib/eve_dmv/external/killmails/participant.ex` | Has read actions (`by_character`, `by_corporation`), basic calculations (`damage_percentage`, `is_solo_kill`, `participation_type`) |
| `Corporation` | `lib/eve_dmv/contexts/corporation/resources/corporation.ex` | Has basic calculations (`member_activity_score`, `is_recruiting`), relationships to `members`, `activity_metrics` |

### What Does NOT Exist Yet

The following modules from the original plan have **NOT been created**:
- `lib/eve_dmv/calculations/base.ex`
- `lib/eve_dmv/calculations/helpers.ex`
- `lib/eve_dmv/ash/fragments.ex`
- `lib/eve_dmv/resource.ex`
- `lib/eve_dmv/contexts/character_intelligence/resources/character_stats.ex`
- `lib/eve_dmv/contexts/corporation/services/stats_loader.ex`
- `lib/eve_dmv/contexts/character_intelligence/services/batch_loader.ex`

### Integration Points

- **LiveViews**: `CharacterAnalysisLive`, `CorporationLive`, `SystemLive`
- **Data Loaders**: `lib/eve_dmv_web/live/character_analysis/helpers/character_data_loader.ex`
- **Repositories**: Direct SQL queries in `Platform.Database.*` modules
- **Caching**: `QueryCache` with 1-24 hour TTLs (keep using this pattern)

---

## Migration Decision Matrix

### MIGRATE TO ASH (Priority)
| Query Type | Ash Approach | Effort | Examples in Codebase |
|------------|--------------|--------|---------------------|
| Simple COUNT/SUM | `aggregates` block | Low | `get_character_stats` kill_count |
| Filtered counts | Aggregate with `filter` | Low | `get_character_stats` death_count |
| Computed fields | `calculations` block | Low | ISK efficiency calculations |
| Time-filtered reads | Custom `read` actions | Medium | `get_recent_activity` |
| Entity lookups | Relationships + loads | Medium | `get_character_affiliations` |

### HYBRID APPROACH (Use Ash + Fragments)
| Query Type | Ash Approach | Effort | Notes |
|------------|--------------|--------|-------|
| JSONB extraction | `fragment()` in calculations | Medium | Needed for `raw_data` field queries |
| Timezone conversions | `fragment()` expressions | Medium | `EXTRACT(HOUR FROM x AT TIME ZONE 'UTC')` |
| Complex conditionals | `expr()` with `cond` | Medium | Security class detection |

### KEEP AS RAW SQL (Window Functions & CTEs)
| Query Type | Reason | Example Functions |
|------------|--------|-------------------|
| Window functions (ROW_NUMBER, FIRST_VALUE) | Not supported in Ash expressions | `batch_load_recent_activity`, `batch_load_affiliations` |
| Complex CTEs with multiple stages | Ash can't express multi-CTE patterns | `analyze_gang_patterns`, `analyze_bait_indicators` |
| Materialized view definitions | Infrastructure, not domain | N/A |
| pg_catalog/system queries | Operational diagnostics | N/A |
| Batch operations with UNION ALL | Performance-critical patterns | `batch_load_character_stats` |

---

## Phase 1: Foundation Setup (Prerequisites)

### 1.1 Create Shared Calculation Modules

**Create File**: `lib/eve_dmv/calculations/base.ex`

```elixir
defmodule EveDmv.Calculations.Base do
  @moduledoc """
  Base module for shared calculation patterns.

  Use this as a starting point for Ash calculations that need
  common helper functions.
  """

  defmacro __using__(_opts) do
    quote do
      use Ash.Resource.Calculation
      import EveDmv.Calculations.Helpers
    end
  end
end
```

**Create File**: `lib/eve_dmv/calculations/helpers.ex`

```elixir
defmodule EveDmv.Calculations.Helpers do
  @moduledoc """
  Helper functions for Ash calculations.

  These are pure functions that can be used in calculation modules
  to perform common mathematical operations safely.
  """

  @doc """
  Safely divide two numbers, returning a default if denominator is zero.

  ## Examples

      iex> safe_divide(10, 2)
      5.0
      iex> safe_divide(10, 0)
      0.0
      iex> safe_divide(10, 0, nil)
      nil
  """
  @spec safe_divide(number(), number(), any()) :: float() | any()
  def safe_divide(numerator, denominator, default \\ 0.0) do
    if denominator > 0, do: numerator / denominator, else: default
  end

  @doc """
  Calculate percentage of part to whole.
  """
  @spec percentage(number(), number()) :: float()
  def percentage(part, whole), do: safe_divide(part * 100, whole)

  @doc """
  Calculate K/D ratio with proper handling of zero deaths.
  """
  @spec kd_ratio(integer(), integer()) :: float()
  def kd_ratio(kills, deaths) when deaths > 0, do: Float.round(kills / deaths, 2)
  def kd_ratio(kills, _deaths), do: kills * 1.0
end
```

### 1.2 Create Fragment Library

**Create File**: `lib/eve_dmv/ash/fragments.ex`

```elixir
defmodule EveDmv.Ash.Fragments do
  @moduledoc """
  Reusable SQL fragments for Ash expressions.

  These fragments wrap PostgreSQL-specific functions that aren't
  natively supported in Ash expressions. Use sparingly and prefer
  native Ash expressions when possible.

  ## Usage

  Import in your resource:

      import EveDmv.Ash.Fragments

  Then use in calculations:

      calculate :victim_ship_id, :integer, expr(
        jsonb_int(:raw_data, ["victim", "ship_type_id"])
      )
  """

  import Ash.Expr

  # JSONB extraction helpers for raw_data field queries

  @doc """
  Extract a text value from a JSONB field.

  ## Examples

      jsonb_text(:raw_data, ["victim", "character_name"])
      # Generates: raw_data->'victim'->>'character_name'
  """
  defmacro jsonb_text(field, path) when is_list(path) do
    path_navigation = build_jsonb_path(path)
    quote do
      fragment(unquote("(?#{path_navigation})"), unquote(field))
    end
  end

  @doc """
  Extract an integer value from a JSONB field.
  """
  defmacro jsonb_int(field, path) when is_list(path) do
    path_navigation = build_jsonb_path(path)
    quote do
      fragment(unquote("(?#{path_navigation})::integer"), unquote(field))
    end
  end

  @doc """
  Get the length of a JSONB array.
  """
  defmacro jsonb_array_length(field, path) when is_list(path) do
    # Build path without the last ->> (use -> for all elements)
    arrow_path = Enum.map_join(path, "", fn key -> "->'#{key}'" end)
    quote do
      fragment(unquote("jsonb_array_length(?#{arrow_path})"), unquote(field))
    end
  end

  # Time helpers

  @doc """
  Extract hour from a timestamp in UTC.
  """
  defmacro extract_hour_utc(timestamp_field) do
    quote do
      fragment("EXTRACT(HOUR FROM ? AT TIME ZONE 'UTC')", unquote(timestamp_field))
    end
  end

  @doc """
  Check if timestamp is within N days ago.
  """
  defmacro within_days(timestamp_field, days) do
    quote do
      fragment("? >= NOW() - INTERVAL '? days'", unquote(timestamp_field), unquote(days))
    end
  end

  # Private helpers

  defp build_jsonb_path(path) do
    # All but last use ->, last uses ->> for text extraction
    {leading, [last]} = Enum.split(path, -1)
    leading_path = Enum.map_join(leading, "", fn key -> "->'#{key}'" end)
    "#{leading_path}->>'#{last}'"
  end
end
```

### 1.3 Verification Steps for Phase 1

After creating these files, verify:

1. **Compile check**:
   ```bash
   mix compile --warnings-as-errors
   ```

2. **Test the helpers work**:
   ```bash
   # In iex -S mix
   import EveDmv.Calculations.Helpers
   safe_divide(10, 2)  # Should return 5.0
   safe_divide(10, 0)  # Should return 0.0
   kd_ratio(10, 5)     # Should return 2.0
   ```

---

## Phase 2: KillmailRaw Resource Enhancement

### 2.1 Add Aggregates to KillmailRaw

**Modify File**: `lib/eve_dmv/external/killmails/killmail_raw.ex`

Find the existing `aggregates` block (around line 248) and extend it:

```elixir
# Current state (around line 248):
aggregates do
  count :participant_count, :participants do
    description("Number of participants in this killmail")
  end
end

# Replace with:
aggregates do
  count :participant_count, :participants do
    description("Number of participants in this killmail")
  end

  # NEW: Attacker-specific aggregates
  count :attacker_count, :participants do
    description("Number of attackers in this killmail")
    filter expr(is_victim == false)
  end

  sum :total_attacker_damage, :participants, :damage_done do
    description("Total damage dealt by all attackers")
    filter expr(is_victim == false)
  end

  # For solo kill detection
  count :non_victim_count, :participants do
    filter expr(is_victim == false)
  end
end
```

### 2.2 Add Enhanced Calculations to KillmailRaw

Find the existing `calculations` block (around line 262) and extend it:

```elixir
# Current state (around line 262):
calculations do
  calculate :age_in_hours, :integer do
    # ... existing implementation
  end

  calculate(:is_recent, :boolean,
    description: "True if killmail is less than 24 hours old",
    calculation: expr(killmail_time > ago(24, :hour))
  )
end

# Add to the calculations block:
calculations do
  # ... keep existing calculations above ...

  # NEW: Solo kill detection
  calculate(:is_solo_kill, :boolean,
    description: "True if only one attacker was involved",
    calculation: expr(non_victim_count == 1)
  )

  # NEW: High-value kill detection
  calculate(:is_high_value, :boolean,
    description: "True if kill value exceeds 1 billion ISK",
    calculation: expr(total_value > 1_000_000_000)
  )

  # NEW: Kill age in days for filtering
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

### 2.3 Add Custom Read Actions for Common Queries

Add these actions to the existing `actions` block in KillmailRaw (after line 214):

```elixir
# Add after the existing read actions in killmail_raw.ex

read :by_character_involvement do
  description("Find killmails where character was involved as victim or attacker")

  argument :character_id, :integer do
    allow_nil?(false)
    description("Character ID to search for")
  end

  argument :since_days, :integer do
    default(90)
    description("Number of days to look back")
  end

  argument :limit, :integer do
    default(100)
    description("Maximum number of results")
  end

  # Filter: victim matches OR character in attackers array
  # Note: For the attackers array check, we need a fragment
  filter expr(
    victim_character_id == ^arg(:character_id) or
    fragment(
      "EXISTS (SELECT 1 FROM jsonb_array_elements(raw_data->'attackers') a WHERE (a->>'character_id')::integer = ?)",
      ^arg(:character_id)
    )
  )

  prepare build(
    sort: [killmail_time: :desc],
    limit: arg(:limit)
  )
end

read :by_corporation_involvement do
  description("Find killmails involving a corporation")

  argument :corporation_id, :integer do
    allow_nil?(false)
    description("Corporation ID to search for")
  end

  argument :involvement_type, :atom do
    constraints(one_of: [:all, :kills, :losses])
    default(:all)
    description("Filter by involvement type")
  end

  argument :since_days, :integer do
    default(90)
    description("Number of days to look back")
  end

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

Also add this private helper function at the end of the module (before the final `end`):

```elixir
# Private helpers for query building

defp apply_corporation_filter(query, corp_id, :all) do
  Ash.Query.filter(query,
    victim_corporation_id == ^corp_id or
    fragment(
      "EXISTS (SELECT 1 FROM jsonb_array_elements(raw_data->'attackers') a WHERE (a->>'corporation_id')::integer = ?)",
      ^corp_id
    )
  )
end

defp apply_corporation_filter(query, corp_id, :losses) do
  Ash.Query.filter(query, victim_corporation_id == ^corp_id)
end

defp apply_corporation_filter(query, corp_id, :kills) do
  Ash.Query.filter(query,
    victim_corporation_id != ^corp_id and
    fragment(
      "EXISTS (SELECT 1 FROM jsonb_array_elements(raw_data->'attackers') a WHERE (a->>'corporation_id')::integer = ?)",
      ^corp_id
    )
  )
end
```

### 2.4 Verification Steps for Phase 2

```bash
# 1. Compile and check for errors
mix compile --warnings-as-errors

# 2. Test in iex
iex -S mix

# Test the new aggregates work
alias EveDmv.Killmails.KillmailRaw
alias EveDmv.Api

# Get a recent killmail with aggregates loaded
{:ok, kills} = Api.read(KillmailRaw, load: [:attacker_count, :is_solo_kill])
kills |> Enum.take(5) |> Enum.map(&{&1.killmail_id, &1.attacker_count, &1.is_solo_kill})

# Test the new read action
{:ok, results} = Api.read(KillmailRaw, action: :by_character_involvement, character_id: 12345)
```

---

## Phase 3: Character Statistics Migration

### 3.1 Create CharacterStats Resource

**Create File**: `lib/eve_dmv/contexts/character_intelligence/resources/character_stats.ex`

```elixir
defmodule EveDmv.Contexts.CharacterIntelligence.Resources.CharacterStats do
  @moduledoc """
  Virtual resource for character statistics.

  This replaces `CharacterQueries.get_character_stats/2` with an Ash-native
  approach. The resource is embedded (computed on demand) rather than
  persisted.

  ## Usage

      {:ok, stats} = CharacterStats.calculate_for_character(character_id, since_date)

      stats.kills        # => 42
      stats.deaths       # => 10
      stats.kd_ratio     # => 4.2
  """

  use Ash.Resource,
    domain: EveDmv.Api,
    data_layer: :embedded  # Virtual resource, computed on demand

  alias EveDmv.Killmails.Participant
  alias EveDmv.Calculations.Helpers

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

        # Query using the Participant resource which has indexed lookups
        stats = calculate_from_participants(character_id, since_date)

        {:ok, struct(__MODULE__, Map.put(stats, :character_id, character_id))}
      end
    end
  end

  # Private implementation functions

  defp calculate_from_participants(character_id, since_date) do
    # Use Ash queries against the Participant resource
    # This leverages the idx_participants_character_activity index

    # Get kills (as attacker, not victim)
    kills_query =
      Participant
      |> Ash.Query.filter(
        character_id == ^character_id and
        killmail_time >= ^since_date and
        is_victim == false
      )

    # Get deaths (as victim)
    deaths_query =
      Participant
      |> Ash.Query.filter(
        character_id == ^character_id and
        killmail_time >= ^since_date and
        is_victim == true
      )

    # Execute counts in parallel for performance
    kills_task = Task.async(fn -> Ash.count!(kills_query) end)
    deaths_task = Task.async(fn -> Ash.count!(deaths_query) end)

    kills = Task.await(kills_task)
    deaths = Task.await(deaths_task)

    period_days = Date.diff(Date.utc_today(), DateTime.to_date(since_date))

    %{
      kills: kills,
      deaths: deaths,
      period_days: period_days,
      # ISK values would need additional queries - keeping simple for now
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

### 3.2 Register the Resource

**Modify File**: `lib/eve_dmv/api.ex`

Find the `resources` block and add the new resource:

```elixir
resources do
  # ... existing resources ...

  # Add this line in the resources block
  resource EveDmv.Contexts.CharacterIntelligence.Resources.CharacterStats
end
```

### 3.3 Add Character Activity Read Action to Participant

**Modify File**: `lib/eve_dmv/external/killmails/participant.ex`

Add this action after the existing read actions (around line 352):

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

### 3.4 Verification Steps for Phase 3

```bash
# 1. Compile
mix compile --warnings-as-errors

# 2. Test in iex
iex -S mix

alias EveDmv.Contexts.CharacterIntelligence.Resources.CharacterStats

# Test the new resource
{:ok, stats} = CharacterStats.calculate_for_character(12345, nil)
IO.inspect(stats, label: "Character Stats")
IO.puts("K/D Ratio: #{stats.kd_ratio}")
```

### 3.5 Migration Mapping: CharacterQueries Functions

| Old Function | File Location | New Approach | Phase |
|--------------|---------------|--------------|-------|
| `get_character_stats/2` | `character_queries.ex:18` | `CharacterStats.calculate_for_character/2` | 3 |
| `get_recent_activity/2` | `character_queries.ex:53` | `Participant.character_activity_summary` action | 3 |
| `get_character_name_from_killmails/1` | `character_queries.ex:133` | Keep as fallback (rarely used) | Keep |
| `get_character_affiliations/1` | `character_queries.ex:169` | Relationship + latest read | 3 |

---

## Phase 4: Corporation Statistics Migration

### 4.1 Enhance Corporation Resource with Aggregates

**Modify File**: `lib/eve_dmv/contexts/corporation/resources/corporation.ex`

Add aggregates block after the relationships block (around line 75):

```elixir
# Add this new block after the relationships block

aggregates do
  count :total_members, :members do
    description("Total number of corporation members")
  end

  count :active_members_30d, :members do
    description("Members active in the last 30 days")
    # Note: This requires the CorporationMember resource to have a last_activity_at field
    # If not available, this aggregate won't work
    filter expr(last_activity_at > ago(30, :day))
  end
end
```

**Important Note**: The aggregates depend on relationships being properly configured. Check that `lib/eve_dmv/contexts/corporation/resources/corporation_member.ex` has a `last_activity_at` attribute.

### 4.2 Create Corporation Stats Loader Service

**Create File**: `lib/eve_dmv/contexts/corporation/services/stats_loader.ex`

```elixir
defmodule EveDmv.Contexts.Corporation.Services.StatsLoader do
  @moduledoc """
  Loads corporation statistics using a hybrid approach.

  This module replaces `CorporationQueries.get_corporation_stats/2` with a
  more maintainable implementation that uses Ash queries where possible
  and falls back to optimized SQL for complex aggregations.

  ## Usage

      {:ok, stats} = StatsLoader.load_stats(corporation_id, days: 90)
  """

  alias EveDmv.Platform.Cache.QueryCache
  alias EveDmv.Repo
  require Logger

  @default_days 90
  @cache_ttl :timer.hours(1)

  @doc """
  Load corporation statistics for the given time period.

  ## Options

    * `:days` - Number of days to look back (default: 90)
    * `:skip_cache` - Skip the cache and compute fresh (default: false)

  ## Returns

      {:ok, %{
        kills: 150,
        losses: 50,
        isk_destroyed: 1_000_000_000.0,
        isk_lost: 250_000_000.0,
        efficiency: 75.0,
        isk_efficiency: 80.0,
        active_members: 25
      }}
  """
  @spec load_stats(integer(), keyword()) :: {:ok, map()} | {:error, term()}
  def load_stats(corporation_id, opts \\ []) do
    days = Keyword.get(opts, :days, @default_days)
    skip_cache = Keyword.get(opts, :skip_cache, false)

    since_date = DateTime.add(DateTime.utc_now(), -days, :day)
    cache_key = "corp_stats_v2:#{corporation_id}:#{Date.to_iso8601(DateTime.to_date(since_date))}"

    if skip_cache do
      compute_stats(corporation_id, since_date)
    else
      QueryCache.get_or_compute(
        cache_key,
        fn -> compute_stats(corporation_id, since_date) end,
        ttl: @cache_ttl
      )
    end
  end

  defp compute_stats(corporation_id, since_date) do
    # Use the materialized view for fast lookups
    # Falls back to direct query if view isn't available
    stats_query = """
    SELECT
      SUM(kills) as kill_count,
      SUM(losses) as loss_count,
      SUM(isk_destroyed) as isk_destroyed,
      SUM(isk_lost) as isk_lost,
      COUNT(DISTINCT character_id) as active_members
    FROM corporation_member_summary
    WHERE corporation_id = $1
      AND last_seen >= $2
    """

    case Repo.query(stats_query, [corporation_id, since_date]) do
      {:ok, %{rows: [[kills, losses, isk_destroyed, isk_lost, active_members]]}} ->
        format_stats(kills, losses, isk_destroyed, isk_lost, active_members)

      {:error, %Postgrex.Error{postgres: %{code: :undefined_table}}} ->
        # Materialized view doesn't exist, fall back to direct query
        Logger.warning("corporation_member_summary view not available, using fallback")
        compute_stats_direct(corporation_id, since_date)

      {:error, error} ->
        Logger.error("Failed to load corporation stats: #{inspect(error)}")
        {:error, :query_failed}
    end
  end

  defp compute_stats_direct(corporation_id, since_date) do
    # Direct query against participants table
    query = """
    SELECT
      COUNT(CASE WHEN p.is_victim = false THEN 1 END) as kills,
      COUNT(CASE WHEN p.is_victim = true THEN 1 END) as losses,
      COUNT(DISTINCT p.character_id) as active_members
    FROM participants p
    WHERE p.corporation_id = $1
      AND p.killmail_time >= $2
    """

    case Repo.query(query, [corporation_id, since_date]) do
      {:ok, %{rows: [[kills, losses, active_members]]}} ->
        format_stats(kills, losses, nil, nil, active_members)

      {:error, error} ->
        Logger.error("Fallback query failed: #{inspect(error)}")
        {:error, :query_failed}
    end
  end

  defp format_stats(kills, losses, isk_destroyed, isk_lost, active_members) do
    k = kills || 0
    l = losses || 0
    isk_d = safe_to_float(isk_destroyed)
    isk_l = safe_to_float(isk_lost)

    efficiency = if k + l > 0, do: Float.round(k / (k + l) * 100, 2), else: 100.0
    isk_efficiency = if isk_d + isk_l > 0, do: Float.round(isk_d / (isk_d + isk_l) * 100, 2), else: 50.0

    {:ok, %{
      kills: k,
      losses: l,
      isk_destroyed: isk_d,
      isk_lost: isk_l,
      efficiency: efficiency,
      isk_efficiency: isk_efficiency,
      active_members: active_members || 0
    }}
  end

  defp safe_to_float(nil), do: 0.0
  defp safe_to_float(%Decimal{} = d), do: Decimal.to_float(d)
  defp safe_to_float(n) when is_number(n), do: n * 1.0
  defp safe_to_float(_), do: 0.0
end
```

### 4.3 Migration Mapping: CorporationQueries Functions

| Old Function | New Approach | Status |
|--------------|--------------|--------|
| `get_corporation_stats/2` | `StatsLoader.load_stats/2` | Phase 4 |
| `get_top_active_members/3` | Keep SQL (uses materialized view) | Keep |
| `get_recent_activity/2` | Custom read action on Participant | Phase 4 |
| `get_corporation_info_from_killmails/1` | Keep as fallback | Keep |
| `get_timezone_activity/2` | Keep SQL (uses EXTRACT) | Keep |
| `get_ship_usage_stats/3` | Keep SQL (complex UNION) | Keep |

---

## Phase 5: Query Optimizations Migration

### 5.1 Batch Loading Considerations

The `QueryOptimizations` module contains several functions that use window functions (ROW_NUMBER, FIRST_VALUE) which cannot be expressed in Ash. These should **remain as raw SQL**:

- `batch_load_recent_activity/2` - Uses `ROW_NUMBER() OVER PARTITION BY`
- `batch_load_affiliations/1` - Uses `FIRST_VALUE() OVER`
- `batch_load_ship_preferences/2` - Uses `ROW_NUMBER()` for ranking

### 5.2 Create Hybrid Batch Loader

**Create File**: `lib/eve_dmv/contexts/character_intelligence/services/batch_loader.ex`

```elixir
defmodule EveDmv.Contexts.CharacterIntelligence.Services.BatchLoader do
  @moduledoc """
  Batch loads character data using a hybrid approach.

  Uses Ash queries for simple aggregations and delegates to
  QueryOptimizations for complex window function queries.
  """

  alias EveDmv.Killmails.Participant
  alias EveDmv.Platform.Database.QueryOptimizations
  require Logger

  @doc """
  Batch load basic stats for multiple characters.

  Uses Ash Query for the simple COUNT aggregations.
  """
  def bulk_load_basic_stats(character_ids) when is_list(character_ids) do
    # This can use Ash since it's just counts grouped by character
    # However, Ash doesn't support GROUP BY in the same way SQL does
    # So we use a manual approach with parallel queries

    character_ids
    |> Task.async_stream(fn char_id ->
      stats = load_single_character_stats(char_id)
      {char_id, stats}
    end, max_concurrency: 10, timeout: 5000)
    |> Enum.reduce(%{}, fn
      {:ok, {char_id, stats}}, acc -> Map.put(acc, char_id, stats)
      {:exit, _reason}, acc -> acc
    end)
  end

  defp load_single_character_stats(character_id) do
    since_date = DateTime.add(DateTime.utc_now(), -90, :day)

    kills =
      Participant
      |> Ash.Query.filter(character_id == ^character_id and killmail_time >= ^since_date and is_victim == false)
      |> Ash.count!()

    deaths =
      Participant
      |> Ash.Query.filter(character_id == ^character_id and killmail_time >= ^since_date and is_victim == true)
      |> Ash.count!()

    %{kills: kills, deaths: deaths}
  rescue
    e ->
      Logger.warning("Failed to load stats for character #{character_id}: #{inspect(e)}")
      %{kills: 0, deaths: 0}
  end

  @doc """
  Batch load recent activity with ranking.

  Delegates to QueryOptimizations since this requires window functions.
  """
  def bulk_load_recent_activity(character_ids, limit \\ 10) do
    QueryOptimizations.batch_load_recent_activity(character_ids, limit)
  end

  @doc """
  Batch load affiliations for multiple characters.

  Delegates to QueryOptimizations since this requires FIRST_VALUE window function.
  """
  def bulk_load_affiliations(character_ids) do
    QueryOptimizations.batch_load_affiliations(character_ids)
  end

  @doc """
  Batch load ship preferences with ranking.

  Delegates to QueryOptimizations since this requires ROW_NUMBER window function.
  """
  def bulk_load_ship_preferences(character_ids, limit \\ 5) do
    QueryOptimizations.batch_load_ship_preferences(character_ids, limit)
  end
end
```

---

## Phase 6: Integration & Cleanup

### 6.1 Update Data Loaders

**Modify File**: `lib/eve_dmv_web/live/character_analysis/helpers/character_data_loader.ex`

Find usages of `CharacterQueries.get_character_stats` and replace:

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

### 6.2 Update Corporation Data Loader

Find usages of `CorporationQueries.get_corporation_stats` and replace:

```elixir
# Before:
CorporationQueries.get_corporation_stats(corporation_id, since_date)

# After:
alias EveDmv.Contexts.Corporation.Services.StatsLoader

case StatsLoader.load_stats(corporation_id, days: days) do
  {:ok, stats} -> stats
  {:error, _} -> %{kills: 0, losses: 0, efficiency: 0.0}
end
```

### 6.3 Deprecation Strategy

Add deprecation notices to old functions before removal:

```elixir
# In CharacterQueries module
@deprecated "Use CharacterStats.calculate_for_character/2 instead"
def get_character_stats(character_id, since_date) do
  Logger.warning(
    "Deprecated: CharacterQueries.get_character_stats/2 called. " <>
    "Use CharacterStats.calculate_for_character/2 instead."
  )
  # ... existing implementation
end
```

### 6.4 Feature Flag for Gradual Rollout

**Create File**: `lib/eve_dmv/config/query_migration.ex`

```elixir
defmodule EveDmv.Config.QueryMigration do
  @moduledoc """
  Feature flags for gradual migration from raw SQL to Ash queries.
  """

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

**Add to config/config.exs**:

```elixir
config :eve_dmv, :query_migration,
  use_ash_character_stats: true,
  use_ash_corporation_stats: false,
  log_comparison_mismatches: true
```

---

## Files Summary

### Files to Create

| File | Purpose | Phase |
|------|---------|-------|
| `lib/eve_dmv/calculations/base.ex` | Base calculation module | 1 |
| `lib/eve_dmv/calculations/helpers.ex` | Shared calculation helpers | 1 |
| `lib/eve_dmv/ash/fragments.ex` | Reusable SQL fragments | 1 |
| `lib/eve_dmv/contexts/character_intelligence/resources/character_stats.ex` | Character stats resource | 3 |
| `lib/eve_dmv/contexts/corporation/services/stats_loader.ex` | Corporation stats loader | 4 |
| `lib/eve_dmv/contexts/character_intelligence/services/batch_loader.ex` | Batch loading service | 5 |
| `lib/eve_dmv/config/query_migration.ex` | Feature flags | 6 |

### Files to Modify

| File | Changes | Phase |
|------|---------|-------|
| `lib/eve_dmv/external/killmails/killmail_raw.ex` | Add aggregates, calculations, read actions | 2 |
| `lib/eve_dmv/external/killmails/participant.ex` | Add character_activity_summary action | 3 |
| `lib/eve_dmv/contexts/corporation/resources/corporation.ex` | Add aggregates | 4 |
| `lib/eve_dmv/api.ex` | Register new resources | 3 |
| `lib/eve_dmv_web/live/character_analysis/helpers/character_data_loader.ex` | Use new Ash queries | 6 |
| `config/config.exs` | Add query_migration config | 6 |

### Files to Keep (Complex SQL)

| File | Reason |
|------|--------|
| `lib/eve_dmv/platform/database/query_optimizations.ex` | Window functions, batch operations |
| `lib/eve_dmv/utilities/query_helpers/killmail_queries.ex` | Complex JSONB builders |
| `lib/eve_dmv/contexts/character_intelligence/analyzers/character_intelligence_analyzer.ex` | Complex CTEs, temporal analysis |

---

## Testing Strategy

### Unit Tests

Create test file: `test/eve_dmv/contexts/character_intelligence/resources/character_stats_test.exs`

```elixir
defmodule EveDmv.Contexts.CharacterIntelligence.Resources.CharacterStatsTest do
  use EveDmv.DataCase, async: true

  alias EveDmv.Contexts.CharacterIntelligence.Resources.CharacterStats
  alias EveDmv.Killmails.Participant

  describe "calculate_for_character/2" do
    test "returns zero counts for character with no activity" do
      {:ok, stats} = CharacterStats.calculate_for_character(999999, nil)

      assert stats.kills == 0
      assert stats.deaths == 0
      assert stats.kd_ratio == 0.0
    end

    test "correctly counts kills and deaths" do
      # Setup: Create participant records
      character_id = 12345
      now = DateTime.utc_now()

      # Create 3 kills (is_victim: false)
      for _ <- 1..3 do
        insert_participant(character_id: character_id, is_victim: false, killmail_time: now)
      end

      # Create 1 death (is_victim: true)
      insert_participant(character_id: character_id, is_victim: true, killmail_time: now)

      {:ok, stats} = CharacterStats.calculate_for_character(character_id, nil)

      assert stats.kills == 3
      assert stats.deaths == 1
      assert stats.kd_ratio == 3.0
    end
  end

  # Helper to insert participant records for testing
  defp insert_participant(attrs) do
    defaults = %{
      killmail_id: System.unique_integer([:positive]),
      killmail_time: DateTime.utc_now(),
      ship_type_id: 587,  # Rifter
      solar_system_id: 30000142,  # Jita
      damage_done: 1000,
      is_victim: false,
      final_blow: false,
      is_npc: false
    }

    attrs = Enum.into(attrs, defaults)

    Ash.create!(Participant, attrs)
  end
end
```

### Integration Tests - Compare Old vs New

```elixir
defmodule EveDmv.MigrationComparisonTest do
  @moduledoc """
  Tests that new Ash implementations match old SQL implementations.
  Run these during the migration period to verify correctness.
  """
  use EveDmv.DataCase, async: false

  alias EveDmv.Platform.Database.CharacterQueries
  alias EveDmv.Contexts.CharacterIntelligence.Resources.CharacterStats

  @tag :migration_comparison
  test "new implementation matches old for character stats" do
    character_id = 12345  # Use a real character ID with data
    since_date = Date.utc_today() |> Date.add(-90)

    # Get old implementation result
    old_stats = CharacterQueries.get_character_stats(character_id, since_date)

    # Get new implementation result
    {:ok, new_stats} = CharacterStats.calculate_for_character(
      character_id,
      DateTime.new!(since_date, ~T[00:00:00])
    )

    assert old_stats.kills == new_stats.kills,
      "Kill count mismatch: old=#{old_stats.kills}, new=#{new_stats.kills}"
    assert old_stats.deaths == new_stats.deaths,
      "Death count mismatch: old=#{old_stats.deaths}, new=#{new_stats.deaths}"
    assert_in_delta old_stats.kd_ratio, new_stats.kd_ratio, 0.01,
      "K/D ratio mismatch"
  end
end
```

---

## Common Pitfalls & Solutions

### Pitfall 1: Fragment Syntax Errors

**Problem**: SQL fragments with incorrect syntax cause cryptic errors.

**Solution**: Test fragments in isolation first:
```elixir
# In iex
import Ash.Expr
query = Ash.Query.filter(MyResource, fragment("?::integer", 123) > 0)
Ash.read!(query)
```

### Pitfall 2: Missing Domain Registration

**Problem**: `** (ArgumentError) Could not find resource ...`

**Solution**: Ensure resource is registered in `lib/eve_dmv/api.ex`:
```elixir
resources do
  resource EveDmv.Contexts.CharacterIntelligence.Resources.CharacterStats
end
```

### Pitfall 3: Aggregate on Unloaded Relationship

**Problem**: Aggregates return nil when relationship isn't preloaded.

**Solution**: Always load aggregates explicitly:
```elixir
# Wrong
Api.read!(KillmailRaw) |> Enum.map(& &1.attacker_count)  # All nil

# Right
Api.read!(KillmailRaw, load: [:attacker_count]) |> Enum.map(& &1.attacker_count)
```

### Pitfall 4: Calculation Type Mismatch

**Problem**: Calculation returns wrong type.

**Solution**: Ensure `expr()` evaluates to declared type:
```elixir
# Wrong - expr returns integer but declared as float
calculate :ratio, :float, expr(kills / deaths)  # Integer division!

# Right - ensure float division
calculate :ratio, :float, expr(kills * 1.0 / deaths)
```

### Pitfall 5: JSONB Fragment Parameter Order

**Problem**: Fragment parameters don't match placeholders.

**Solution**: Check parameter order carefully:
```elixir
# Wrong - parameters reversed
fragment("?->>'name' = ?", "value", :field)

# Right
fragment("?->>'name' = ?", :field, "value")
```

---

## Success Metrics

| Metric | Target | How to Measure |
|--------|--------|----------------|
| Query response time | <= current SQL | Application telemetry, compare P95 latencies |
| Test coverage | >= 70% | `mix test --cover` |
| Code reduction | 30% fewer raw SQL lines | `git diff --stat` on query files |
| Type safety | 100% typed returns | `mix dialyzer` clean |
| Zero regressions | All existing tests pass | CI pipeline |

---

## Migration Checklist

### Phase 1
- [ ] Create `lib/eve_dmv/calculations/base.ex`
- [ ] Create `lib/eve_dmv/calculations/helpers.ex`
- [ ] Create `lib/eve_dmv/ash/fragments.ex`
- [ ] Run `mix compile --warnings-as-errors`
- [ ] Test helper functions in iex

### Phase 2
- [ ] Add aggregates to `killmail_raw.ex`
- [ ] Add calculations to `killmail_raw.ex`
- [ ] Add read actions to `killmail_raw.ex`
- [ ] Test new aggregates/calculations
- [ ] Verify query performance

### Phase 3
- [ ] Create `character_stats.ex` resource
- [ ] Register in `api.ex`
- [ ] Add `character_activity_summary` action to Participant
- [ ] Write unit tests
- [ ] Compare with old implementation

### Phase 4
- [ ] Add aggregates to `corporation.ex`
- [ ] Create `stats_loader.ex`
- [ ] Write unit tests
- [ ] Compare with old implementation

### Phase 5
- [ ] Create `batch_loader.ex`
- [ ] Identify which functions must stay as SQL
- [ ] Test batch loading performance

### Phase 6
- [ ] Update data loaders
- [ ] Add deprecation notices
- [ ] Add feature flags
- [ ] Run comparison tests
- [ ] Monitor in production
- [ ] Remove deprecated code after validation period

---

## Summary

### What Gets Migrated (~60%)
- Simple aggregations -> Ash `aggregates`
- Computed fields -> Ash `calculations`
- Filtered reads -> Ash custom `read` actions
- Entity lookups -> Ash relationships

### What Stays as Raw SQL (~40%)
- Window functions (ROW_NUMBER, FIRST_VALUE)
- Complex multi-stage CTEs
- Materialized view queries
- Batch operations with UNION ALL
- Timezone extraction (EXTRACT ... AT TIME ZONE)

### Key Benefits
1. **Type Safety**: Ash resources provide compile-time checks
2. **Consistency**: Centralized business logic in resources
3. **Maintainability**: Declarative > imperative for common patterns
4. **Testability**: Easier to unit test Ash actions
5. **Documentation**: Self-documenting resource definitions

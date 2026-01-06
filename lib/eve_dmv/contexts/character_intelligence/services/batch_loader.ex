defmodule EveDmv.Contexts.CharacterIntelligence.Services.BatchLoader do
  @moduledoc """
  Batch loads character data using a hybrid approach.

  Uses Ash queries for simple aggregations and delegates to
  QueryOptimizations for complex window function queries.

  ## Design Decision

  Some queries MUST stay as raw SQL because they use PostgreSQL-specific
  features not supported in Ash:
  - Window functions (ROW_NUMBER, FIRST_VALUE)
  - Complex CTEs with multiple stages
  - Materialized view queries
  - Batch operations with UNION ALL

  This module provides a clean interface that delegates to the appropriate
  implementation based on query complexity.
  """

  alias EveDmv.Killmails.Participant
  alias EveDmv.Platform.Database.QueryOptimizations
  require Ash.Query
  require Logger

  @doc """
  Batch load basic stats for multiple characters.

  Uses Ash Query for the simple COUNT aggregations.
  Returns a map of character_id => %{kills: n, deaths: n}.

  ## Examples

      iex> BatchLoader.bulk_load_basic_stats([12345, 67890])
      %{12345 => %{kills: 10, deaths: 2}, 67890 => %{kills: 5, deaths: 1}}
  """
  @spec bulk_load_basic_stats([integer()]) :: %{integer() => map()}
  def bulk_load_basic_stats(character_ids) when is_list(character_ids) do
    # Ash doesn't support GROUP BY in the same way SQL does
    # So we use a manual approach with parallel queries
    character_ids
    |> Task.async_stream(
      fn char_id ->
        stats = load_single_character_stats(char_id)
        {char_id, stats}
      end,
      max_concurrency: 10,
      timeout: 5000
    )
    |> Enum.reduce(%{}, fn
      {:ok, {char_id, stats}}, acc -> Map.put(acc, char_id, stats)
      {:exit, _reason}, acc -> acc
    end)
  end

  @doc """
  Load basic stats for a single character.

  Returns %{kills: n, deaths: n} for the last 90 days.
  """
  @spec load_single_character_stats(integer() | nil) :: map()
  def load_single_character_stats(nil), do: %{kills: 0, deaths: 0}

  def load_single_character_stats(char_id) when is_integer(char_id) do
    since_date = DateTime.add(DateTime.utc_now(), -90, :day)

    kills =
      Participant
      |> Ash.Query.new()
      |> Ash.Query.filter(
        character_id == ^char_id and killmail_time >= ^since_date and is_victim == false
      )
      |> Ash.count!(domain: EveDmv.Api)

    deaths =
      Participant
      |> Ash.Query.new()
      |> Ash.Query.filter(
        character_id == ^char_id and killmail_time >= ^since_date and is_victim == true
      )
      |> Ash.count!(domain: EveDmv.Api)

    %{kills: kills, deaths: deaths}
  rescue
    e ->
      Logger.warning("Failed to load stats for character #{char_id}: #{inspect(e)}")
      %{kills: 0, deaths: 0}
  end

  @doc """
  Batch load recent activity with ranking.

  Delegates to QueryOptimizations since this requires window functions
  (ROW_NUMBER() OVER PARTITION BY).

  ## Parameters
  - `character_ids` - List of character IDs to load activity for
  - `limit` - Maximum number of recent activities per character (default: 10)

  ## Returns
  Map of character_id => list of activity maps
  """
  @spec bulk_load_recent_activity([integer()], integer()) :: %{integer() => [map()]}
  def bulk_load_recent_activity(character_ids, limit \\ 10) do
    QueryOptimizations.batch_load_recent_activity(character_ids, limit)
  end

  @doc """
  Batch load affiliations for multiple characters.

  Delegates to QueryOptimizations since this requires FIRST_VALUE window function
  to get the most recent corporation/alliance for each character.

  ## Parameters
  - `character_ids` - List of character IDs to load affiliations for

  ## Returns
  Map of character_id => list of affiliation maps containing:
  - corporation_id, corporation_name
  - alliance_id, alliance_name
  - last_seen timestamp
  """
  @spec bulk_load_affiliations([integer()]) :: %{integer() => [map()]}
  def bulk_load_affiliations(character_ids) do
    QueryOptimizations.batch_load_affiliations(character_ids)
  end

  @doc """
  Batch load ship preferences with ranking.

  Delegates to QueryOptimizations since this requires ROW_NUMBER window function
  for ranking ships by usage count.

  ## Parameters
  - `character_ids` - List of character IDs to load ship preferences for
  - `limit` - Maximum number of top ships per character (default: 5)

  ## Returns
  Map of character_id => list of ship preference maps containing:
  - ship_type_id, ship_name
  - usage_count, kill_count, loss_count
  """
  @spec bulk_load_ship_preferences([integer()], integer()) :: %{integer() => [map()]}
  def bulk_load_ship_preferences(character_ids, limit \\ 5) do
    QueryOptimizations.batch_load_ship_preferences(character_ids, limit)
  end

  @doc """
  Load comprehensive character data in batch.

  Combines all batch loading operations for efficiency.
  Uses parallel execution to minimize total load time.

  ## Parameters
  - `character_ids` - List of character IDs to analyze

  ## Returns
  Map of character_id => comprehensive character data map
  """
  @spec bulk_load_character_data([integer()]) :: %{integer() => map()}
  def bulk_load_character_data(character_ids) when is_list(character_ids) do
    # Run all batch loads in parallel
    tasks = [
      Task.async(fn -> bulk_load_basic_stats(character_ids) end),
      Task.async(fn -> bulk_load_recent_activity(character_ids) end),
      Task.async(fn -> bulk_load_affiliations(character_ids) end),
      Task.async(fn -> bulk_load_ship_preferences(character_ids) end)
    ]

    # Wait for all tasks with 10 second timeout
    [stats_map, activity_map, affiliations_map, ships_map] = Task.await_many(tasks, 10_000)

    # Combine results for each character
    character_ids
    |> Enum.map(fn char_id ->
      {
        char_id,
        %{
          stats: Map.get(stats_map, char_id, %{kills: 0, deaths: 0}),
          recent_activity: Map.get(activity_map, char_id, []),
          affiliations: Map.get(affiliations_map, char_id, []),
          ship_preferences: Map.get(ships_map, char_id, [])
        }
      }
    end)
    |> Map.new()
  end
end

defmodule EveDmv.Intelligence.Core.QueryHelper do
  @moduledoc """
  Common query patterns and utilities for intelligence analyzers.

  Provides standardized query patterns, result aggregation, and data
  transformation utilities used across multiple intelligence analyzers.
  """

  require Logger
  require Ash.Query
  alias EveDmv.Api

  @type query_result :: {:ok, term()} | {:error, term()}
  @type entity_id :: integer()
  @type query_options :: map()

  @doc """
  Execute Ash query with standardized error handling and logging.

  Provides consistent query execution patterns with proper telemetry.
  """
  @spec execute_ash_query(Ash.Query.t(), atom()) :: query_result()
  def execute_ash_query(query, operation_type \\ :generic) do
    start_time = System.monotonic_time()

    try do
      case Ash.read(query, domain: Api) do
        {:ok, results} ->
          duration_ms = calculate_duration(start_time)

          :telemetry.execute(
            [:eve_dmv, :intelligence, :query_execution],
            %{duration_ms: duration_ms, result_count: length(results)},
            %{operation_type: operation_type, status: :success}
          )

          {:ok, results}

        {:error, reason} = error ->
          duration_ms = calculate_duration(start_time)

          Logger.warning("Ash query failed for #{operation_type}: #{inspect(reason)}")

          :telemetry.execute(
            [:eve_dmv, :intelligence, :query_execution],
            %{duration_ms: duration_ms, result_count: 0},
            %{operation_type: operation_type, status: :error, error: inspect(reason)}
          )

          error
      end
    rescue
      exception ->
        duration_ms = calculate_duration(start_time)

        Logger.error("Ash query exception for #{operation_type}: #{inspect(exception)}")

        :telemetry.execute(
          [:eve_dmv, :intelligence, :query_execution],
          %{duration_ms: duration_ms, result_count: 0},
          %{operation_type: operation_type, status: :exception, error: inspect(exception)}
        )

        {:error, {:exception, exception}}
    end
  end

  @doc """
  Get character killmails with standardized filters and pagination.

  Common pattern used across multiple analyzers for character analysis.
  """
  @spec get_character_killmails(entity_id(), query_options()) :: query_result()
  def get_character_killmails(character_id, opts \\ %{}) do
    limit = Map.get(opts, :limit, 1000)
    days_back = Map.get(opts, :days_back, 90)
    cutoff_date = DateTime.add(DateTime.utc_now(), -days_back, :day)

    query =
      EveDmv.Killmails.KillmailEnriched
      |> Ash.Query.new()
      |> Ash.Query.filter(
        victim_character_id == ^character_id or
          attackers[character_id: ^character_id]
      )
      |> Ash.Query.filter(killmail_time >= ^cutoff_date)
      |> Ash.Query.sort(desc: :killmail_time)
      |> Ash.Query.limit(limit)

    execute_ash_query(query, :character_killmails)
  end

  @doc """
  Get corporation killmails with standardized filters.

  Common pattern for corporation-level analysis.
  """
  @spec get_corporation_killmails(entity_id(), query_options()) :: query_result()
  def get_corporation_killmails(corporation_id, opts \\ %{}) do
    limit = Map.get(opts, :limit, 1000)
    days_back = Map.get(opts, :days_back, 30)
    cutoff_date = DateTime.add(DateTime.utc_now(), -days_back, :day)

    query =
      EveDmv.Killmails.KillmailEnriched
      |> Ash.Query.new()
      |> Ash.Query.filter(
        victim_corporation_id == ^corporation_id or
          attackers[corporation_id: ^corporation_id]
      )
      |> Ash.Query.filter(killmail_time >= ^cutoff_date)
      |> Ash.Query.sort(desc: :killmail_time)
      |> Ash.Query.limit(limit)

    execute_ash_query(query, :corporation_killmails)
  end

  @doc """
  Aggregate killmail statistics with common calculations.

  Standard aggregation pattern used across multiple analyzers.
  """
  @spec aggregate_killmail_stats([map()], entity_id()) :: map()
  def aggregate_killmail_stats(killmails, entity_id) do
    {kills, losses} = partition_kills_losses(killmails, entity_id)

    %{
      total_killmails: length(killmails),
      total_kills: length(kills),
      total_losses: length(losses),
      kill_loss_ratio: calculate_ratio(length(kills), length(losses)),
      isk_destroyed: sum_isk_values(kills, :total_value),
      isk_lost: sum_isk_values(losses, :total_value),
      avg_kill_value: avg_isk_value(kills, :total_value),
      avg_loss_value: avg_isk_value(losses, :total_value),
      first_activity: get_first_activity_date(killmails),
      last_activity: get_last_activity_date(killmails),
      unique_systems: count_unique_systems(killmails),
      unique_regions: count_unique_regions(killmails),
      ship_types_used: count_ship_types(killmails, entity_id)
    }
  end

  @doc """
  Get common character statistics used across analyzers.
  """
  @spec get_character_stats(entity_id()) :: query_result()
  def get_character_stats(character_id) do
    case Ash.get(EveDmv.Intelligence.CharacterStats, character_id, domain: Api) do
      {:ok, stats} -> {:ok, stats}
      {:error, %Ash.Error.Query.NotFound{}} -> {:ok, nil}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Batch load character information for multiple characters.

  Common pattern for loading character names and corporations.
  """
  @spec batch_load_characters([entity_id()]) :: query_result()
  def batch_load_characters(character_ids) do
    query =
      EveDmv.Universe.Character
      |> Ash.Query.new()
      |> Ash.Query.filter(character_id in ^character_ids)
      |> Ash.Query.load([:corporation, :alliance])

    execute_ash_query(query, :batch_characters)
  end

  # Private helper functions

  defp partition_kills_losses(killmails, entity_id) do
    Enum.split_with(killmails, fn km ->
      km.victim_character_id != entity_id and km.victim_corporation_id != entity_id
    end)
  end

  defp calculate_ratio(kills, losses) when losses > 0, do: kills / losses
  defp calculate_ratio(kills, _losses), do: kills

  defp sum_isk_values(killmails, field) do
    killmails
    |> Enum.map(&Map.get(&1, field, 0))
    |> Enum.sum()
  end

  defp avg_isk_value([], _field), do: 0

  defp avg_isk_value(killmails, field) do
    sum_isk_values(killmails, field) / length(killmails)
  end

  defp get_first_activity_date([]), do: nil

  defp get_first_activity_date(killmails) do
    killmails
    |> Enum.map(& &1.killmail_time)
    |> Enum.min(DateTime)
  end

  defp get_last_activity_date([]), do: nil

  defp get_last_activity_date(killmails) do
    killmails
    |> Enum.map(& &1.killmail_time)
    |> Enum.max(DateTime)
  end

  defp count_unique_systems(killmails) do
    killmails
    |> Enum.map(& &1.solar_system_id)
    |> Enum.uniq()
    |> length()
  end

  defp count_unique_regions(killmails) do
    killmails
    |> Enum.map(& &1.region_id)
    |> Enum.uniq()
    |> length()
  end

  defp count_ship_types(killmails, entity_id) do
    killmails
    |> Enum.filter(fn km ->
      km.victim_character_id == entity_id or
        Enum.any?(km.attackers || [], &(&1.character_id == entity_id))
    end)
    |> Enum.map(fn km ->
      if km.victim_character_id == entity_id do
        km.victim_ship_type_id
      else
        attacker = Enum.find(km.attackers || [], &(&1.character_id == entity_id))
        attacker && attacker.ship_type_id
      end
    end)
    |> Enum.filter(& &1)
    |> Enum.uniq()
    |> length()
  end

  defp calculate_duration(start_time) do
    duration = System.monotonic_time() - start_time
    System.convert_time_unit(duration, :native, :millisecond)
  end
end

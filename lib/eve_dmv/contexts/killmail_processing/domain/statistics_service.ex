defmodule EveDmv.Contexts.KillmailProcessing.Domain.StatisticsService do
  @moduledoc """
  Service for calculating various statistics from killmail data.

  Provides aggregated statistics for systems, characters, corporations,
  and other entities based on killmail activity.
  """

  alias EveDmv.Api
  alias EveDmv.Core.Utils.DateTimeUtils
  alias EveDmv.Killmails.KillmailEnriched
  alias EveDmv.SharedKernel.ValueObjects.SolarSystemId
  alias EveDmv.SharedKernel.ValueObjects.TimeRange

  require Logger
  require Ash.Query

  @doc """
  Validate and calculate system statistics.

  Public entry point that validates the system ID before calculating.
  """
  @spec calculate_system_statistics_validated(integer(), TimeRange.t()) ::
          {:ok, map()} | {:error, term()}
  def calculate_system_statistics_validated(system_id, time_range) do
    case SolarSystemId.new(system_id) do
      {:ok, system_id_vo} ->
        calculate_system_statistics(system_id_vo.value, time_range)

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Calculate comprehensive statistics for a solar system over a time period.

  Returns kill counts, ISK destroyed, top ships, and other relevant metrics.
  """
  @spec calculate_system_statistics(integer(), TimeRange.t()) :: {:ok, map()} | {:error, term()}
  def calculate_system_statistics(system_id, time_range) do
    Logger.debug("Calculating statistics for system #{system_id}")

    try do
      # Query killmails for the system within the time range
      killmails_query =
        KillmailEnriched
        |> Ash.Query.filter(solar_system_id: system_id)
        |> Ash.Query.filter(killmail_time >= ^time_range.since)
        |> Ash.Query.filter(killmail_time <= ^time_range.until)
        # Prevent runaway queries
        |> Ash.Query.limit(10_000)

      case Ash.read(killmails_query, domain: Api) do
        {:ok, killmails} ->
          statistics = compile_system_statistics(killmails, system_id, time_range)
          {:ok, statistics}

        {:error, reason} ->
          Logger.error("Failed to query killmails for system #{system_id}: #{inspect(reason)}")
          {:error, :query_failed}
      end
    rescue
      error ->
        Logger.error("Error calculating system statistics: #{inspect(error)}")
        {:error, :calculation_failed}
    end
  end

  @doc """
  Calculate statistics for a character over a time period.
  """
  @spec calculate_character_statistics(integer(), TimeRange.t()) ::
          {:ok, map()} | {:error, term()}
  def calculate_character_statistics(character_id, time_range) do
    Logger.debug("Calculating statistics for character #{character_id}")

    try do
      # Get killmails where character was involved
      participant_query =
        EveDmv.Killmails.Participant
        |> Ash.Query.filter(character_id: character_id)
        |> Ash.Query.load(:killmail_enriched)
        |> Ash.Query.limit(5_000)

      case Ash.read(participant_query, domain: Api) do
        {:ok, participants} ->
          # Filter by time range
          filtered_participants =
            Enum.filter(participants, fn participant ->
              km_time = participant.killmail_enriched.killmail_time

              DateTimeUtils.compare(km_time, time_range.since) != :lt and
                DateTimeUtils.compare(km_time, time_range.until) != :gt
            end)

          statistics =
            compile_character_statistics(filtered_participants, character_id, time_range)

          {:ok, statistics}

        {:error, reason} ->
          Logger.error(
            "Failed to query participants for character #{character_id}: #{inspect(reason)}"
          )

          {:error, :query_failed}
      end
    rescue
      error ->
        Logger.error("Error calculating character statistics: #{inspect(error)}")
        {:error, :calculation_failed}
    end
  end

  # Private functions

  defp compile_system_statistics(killmails, system_id, time_range) do
    kill_count = length(killmails)
    total_value = Enum.sum(Enum.map(killmails, &Map.get(&1, :total_value, 0)))

    # Analyze ship types
    ship_types =
      killmails
      |> Enum.map(&Map.get(&1, :victim_ship_type_id))
      |> Enum.frequencies()
      |> Enum.sort_by(&elem(&1, 1), :desc)
      |> Enum.take(10)

    # Analyze time distribution
    hourly_distribution = analyze_hourly_distribution(killmails)

    # Calculate average values
    avg_killmail_value = if kill_count > 0, do: total_value / kill_count, else: 0

    # Compile top participants
    top_killers = analyze_top_killers(killmails)
    top_victims = analyze_top_victims(killmails)

    %{
      system_id: system_id,
      time_range: time_range,
      kill_count: kill_count,
      total_value: total_value,
      average_killmail_value: Float.round(avg_killmail_value, 2),
      top_ships: format_ship_frequencies(ship_types),
      hourly_distribution: hourly_distribution,
      top_killers: top_killers,
      top_victims: top_victims,
      analysis_timestamp: DateTime.utc_now()
    }
  end

  defp compile_character_statistics(participants, character_id, time_range) do
    # Calculate basic metrics
    total_participations = length(participants)

    kills =
      Enum.count(participants, fn p ->
        Map.get(p, :final_blow, false) or Map.get(p, :damage_done, 0) > 0
      end)

    deaths =
      Enum.count(participants, fn p ->
        p.killmail_enriched.victim_character_id == character_id
      end)

    # Calculate ISK metrics
    isk_destroyed =
      participants
      |> Enum.filter(fn p -> p.killmail_enriched.victim_character_id != character_id end)
      |> Enum.map(fn p -> Map.get(p.killmail_enriched, :total_value, 0) end)
      |> Enum.sum()

    isk_lost =
      participants
      |> Enum.filter(fn p -> p.killmail_enriched.victim_character_id == character_id end)
      |> Enum.map(fn p -> Map.get(p.killmail_enriched, :total_value, 0) end)
      |> Enum.sum()

    # Analyze ship preferences
    ship_preferences = analyze_character_ships(participants, character_id)

    # Calculate efficiency
    efficiency =
      if isk_destroyed + isk_lost > 0 do
        isk_destroyed / (isk_destroyed + isk_lost) * 100
      else
        0
      end

    %{
      character_id: character_id,
      time_range: time_range,
      total_participations: total_participations,
      kills: kills,
      deaths: deaths,
      kill_death_ratio: if(deaths > 0, do: Float.round(kills / deaths, 2), else: kills),
      isk_destroyed: isk_destroyed,
      isk_lost: isk_lost,
      efficiency: Float.round(efficiency, 2),
      ship_preferences: ship_preferences,
      analysis_timestamp: DateTime.utc_now()
    }
  end

  defp analyze_hourly_distribution(killmails) do
    killmails
    |> Enum.group_by(fn km ->
      km.killmail_time
      |> DateTime.to_time()
      |> Time.to_erl()
      # Extract hour
      |> elem(0)
    end)
    |> Enum.map(fn {hour, hour_kms} -> {hour, length(hour_kms)} end)
    |> Enum.into(%{})
  end

  defp analyze_top_killers(killmails) do
    killmails
    |> Enum.flat_map(fn km -> Map.get(km, :participants, []) end)
    |> Enum.filter(fn p -> Map.get(p, :damage_done, 0) > 0 end)
    |> Enum.group_by(& &1.character_id)
    |> Enum.map(fn {char_id, participations} ->
      total_damage = Enum.sum(Enum.map(participations, &Map.get(&1, :damage_done, 0)))

      %{
        character_id: char_id,
        kill_count: length(participations),
        total_damage: total_damage
      }
    end)
    |> Enum.sort_by(& &1.kill_count, :desc)
    |> Enum.take(10)
  end

  defp analyze_top_victims(killmails) do
    killmails
    |> Enum.group_by(& &1.victim_character_id)
    |> Enum.map(fn {char_id, char_deaths} ->
      total_value_lost = Enum.sum(Enum.map(char_deaths, &Map.get(&1, :total_value, 0)))

      %{
        character_id: char_id,
        death_count: length(char_deaths),
        total_value_lost: total_value_lost
      }
    end)
    |> Enum.sort_by(& &1.death_count, :desc)
    |> Enum.take(10)
  end

  defp analyze_character_ships(participants, character_id) do
    participants
    |> Enum.map(fn p ->
      if p.killmail_enriched.victim_character_id == character_id do
        p.killmail_enriched.victim_ship_type_id
      else
        Map.get(p, :ship_type_id)
      end
    end)
    |> Enum.filter(& &1)
    |> Enum.frequencies()
    |> Enum.sort_by(&elem(&1, 1), :desc)
    |> Enum.take(5)
    |> format_ship_frequencies()
  end

  defp format_ship_frequencies(ship_frequencies) do
    Enum.map(ship_frequencies, fn {ship_type_id, count} ->
      %{
        ship_type_id: ship_type_id,
        count: count,
        # Would calculate from total if needed
        percentage: 0.0
      }
    end)
  end
end

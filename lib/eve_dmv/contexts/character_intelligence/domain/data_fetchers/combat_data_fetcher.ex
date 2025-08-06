defmodule EveDmv.Contexts.CharacterIntelligence.Domain.ThreatScoring.DataFetchers.CombatDataFetcher do
  @moduledoc """
  Handles fetching and processing of combat data for threat scoring analysis.

  This module is responsible for:
  - Fetching killmails where character was victim
  - Fetching killmails where character was attacker
  - Processing and structuring combat data
  - Validating data quality for analysis
  """

  alias EveDmv.Api
  alias EveDmv.Core.Utils.DateTimeUtils
  alias EveDmv.Killmails.KillmailRaw

  require Ash.Query
  require Logger

  @analysis_window_days 90
  @minimum_killmails_for_scoring 5

  @doc """
  Fetch comprehensive combat data for a character.

  ## Parameters
  - character_id: Character to analyze
  - options: Fetch options (analysis_window_days, etc.)

  ## Returns
  - {:ok, combat_data} - Structured combat data
  - {:error, reason} - Error details
  """
  def fetch_character_combat_data(character_id, options \\ []) do
    analysis_window_days = Keyword.get(options, :analysis_window_days, @analysis_window_days)

    cutoff_date =
      DateTimeUtils.add(DateTime.utc_now(), -analysis_window_days * 24 * 60 * 60, :second)

    Logger.debug(
      "Fetching combat data for character #{character_id}, window: #{analysis_window_days} days"
    )

    # Execute parallel queries for optimal performance
    with {:ok, victim_killmails, attacker_killmails} <-
           fetch_parallel_killmails(character_id, cutoff_date),
         {:ok, combat_data} <-
           structure_combat_data(
             character_id,
             victim_killmails,
             attacker_killmails,
             analysis_window_days,
             cutoff_date
           ) do
      Logger.info(
        "Fetched combat data for character #{character_id}: #{length(combat_data.killmails)} total killmails"
      )

      {:ok, combat_data}
    else
      {:error, reason} ->
        Logger.warning(
          "Failed to fetch combat data for character #{character_id}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  # Private helper functions

  defp fetch_parallel_killmails(character_id, cutoff_date) do
    # Execute both queries in parallel for better performance
    tasks = [
      Task.async(fn -> fetch_victim_killmails(character_id, cutoff_date) end),
      Task.async(fn -> fetch_attacker_killmails(character_id, cutoff_date) end)
    ]

    case Task.await_many(tasks, 10_000) do
      [{:ok, victim_killmails}, {:ok, attacker_killmails}] ->
        {:ok, victim_killmails, attacker_killmails}

      [victim_result, attacker_result] ->
        handle_partial_fetch_results(victim_result, attacker_result)

      error ->
        Logger.error("Parallel fetch failed: #{inspect(error)}")
        {:error, :database_error}
    end
  rescue
    error ->
      Logger.error("Exception during parallel fetch: #{inspect(error)}")
      {:error, :database_error}
  end

  defp fetch_victim_killmails(character_id, cutoff_date) do
    query =
      KillmailRaw
      |> Ash.Query.new()
      |> Ash.Query.filter(victim_character_id: character_id)
      |> Ash.Query.filter(killmail_time: [gte: cutoff_date])
      |> Ash.Query.sort(killmail_time: :desc)
      |> Ash.Query.limit(500)

    case Ash.read(query, domain: Api) do
      {:ok, killmails} ->
        Logger.debug("Fetched #{length(killmails)} victim killmails")
        {:ok, killmails}

      error ->
        Logger.error("Failed to fetch victim killmails: #{inspect(error)}")
        error
    end
  end

  defp fetch_attacker_killmails(character_id, cutoff_date) do
    # Fetch recent killmails and filter for character as attacker
    query =
      KillmailRaw
      |> Ash.Query.new()
      |> Ash.Query.filter(killmail_time: [gte: cutoff_date])
      |> Ash.Query.sort(killmail_time: :desc)
      # Larger sample for attacker search
      |> Ash.Query.limit(2000)

    case Ash.read(query, domain: Api) do
      {:ok, potential_killmails} ->
        attacker_killmails = filter_character_as_attacker(potential_killmails, character_id)

        Logger.debug(
          "Filtered #{length(attacker_killmails)} attacker killmails from #{length(potential_killmails)} candidates"
        )

        {:ok, attacker_killmails}

      error ->
        Logger.error("Failed to fetch attacker killmails: #{inspect(error)}")
        error
    end
  end

  defp filter_character_as_attacker(killmails, character_id) do
    Enum.filter(killmails, fn km ->
      case km.raw_data do
        %{"attackers" => attackers} when is_list(attackers) ->
          Enum.any?(attackers, &(&1["character_id"] == character_id))

        _ ->
          false
      end
    end)
  end

  defp handle_partial_fetch_results(victim_result, attacker_result) do
    case {victim_result, attacker_result} do
      {{:ok, victim_killmails}, {:ok, attacker_killmails}} ->
        {:ok, victim_killmails, attacker_killmails}

      {{:ok, victim_killmails}, _} ->
        Logger.warning("Only victim data available")
        {:ok, victim_killmails, []}

      {_, {:ok, attacker_killmails}} ->
        Logger.warning("Only attacker data available")
        {:ok, [], attacker_killmails}

      _ ->
        {:error, :database_error}
    end
  end

  defp structure_combat_data(
         character_id,
         victim_killmails,
         attacker_killmails,
         analysis_window_days,
         cutoff_date
       ) do
    all_killmails = Enum.uniq_by(victim_killmails ++ attacker_killmails, & &1.killmail_id)

    if length(all_killmails) < @minimum_killmails_for_scoring do
      {:error, :insufficient_data}
    else
      combat_data = %{
        character_id: character_id,
        killmails: all_killmails,
        victim_killmails: victim_killmails,
        attacker_killmails: attacker_killmails,
        analysis_period_days: analysis_window_days,
        data_cutoff: cutoff_date,
        total_killmails: length(all_killmails),
        fetched_at: DateTime.utc_now()
      }

      {:ok, combat_data}
    end
  end
end

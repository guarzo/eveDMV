defmodule EveDmv.Intelligence.CharacterAnalysis.CharacterAnalyzerSimplified do
  @moduledoc """
  Core character analysis coordination - simplified version.

  This module coordinates the character analysis process, delegating
  specific calculations to CharacterMetrics and formatting to CharacterFormatters.
  """

  require Logger
  alias EveDmv.Api
  # alias EveDmv.Eve.{EsiClient, NameResolver}
  alias EveDmv.Intelligence.CharacterStats
  alias EveDmv.Intelligence.CharacterAnalysis.CharacterMetrics
  alias EveDmv.Killmails.{KillmailEnriched, Participant}
  require Ash.Query

  @analysis_period_days 90
  @min_activity_threshold 10

  @doc """
  Analyze a character and create/update their intelligence profile.
  """
  @spec analyze_character(integer()) :: {:ok, CharacterStats.t()} | {:error, term()}
  def analyze_character(character_id) do
    with {:ok, basic_info} <- get_character_info(character_id),
         {:ok, killmail_data} <- get_recent_killmails(character_id),
         {:ok, metrics} <- calculate_all_metrics(character_id, killmail_data),
         {:ok, character_stats} <- save_character_stats(basic_info, metrics) do
      {:ok, character_stats}
    else
      {:error, reason} = error ->
        Logger.error("Failed to analyze character #{character_id}: #{inspect(reason)}")
        error
    end
  end

  @doc """
  Analyze multiple characters in parallel.
  """
  def analyze_characters(character_ids) when is_list(character_ids) do
    tasks =
      character_ids
      |> Enum.map(fn character_id ->
        Task.async(fn -> analyze_character_with_timeout(character_id) end)
      end)

    results =
      tasks
      |> Task.await_many(60_000)
      |> Enum.zip(character_ids)
      |> Enum.map(fn {result, character_id} ->
        case result do
          {:ok, _} = success -> success
          {:error, _} = error -> error
          {:exit, reason} -> {:error, {:timeout, character_id, reason}}
        end
      end)

    successful = Enum.filter(results, &match?({:ok, _}, &1))
    failed = Enum.filter(results, &match?({:error, _}, &1))

    {:ok, %{successful: successful, failed: failed}}
  end

  @doc """
  Process raw killmail data for analysis.
  """
  def process_killmail_data(raw_killmail_data) do
    case raw_killmail_data do
      data when is_list(data) ->
        {:ok, data}

      data when is_map(data) ->
        {:ok, [data]}

      _ ->
        {:error, :invalid_killmail_format}
    end
  end

  # Private functions

  defp analyze_character_with_timeout(character_id) do
    task = Task.async(fn -> analyze_character(character_id) end)

    case Task.yield(task, 30_000) || Task.shutdown(task) do
      {:ok, result} -> result
      nil -> {:error, :timeout}
    end
  end

  defp get_character_info(character_id) do
    # Try participant data first for cached info
    participants_query =
      Participant
      |> Ash.Query.new()
      |> Ash.Query.filter(character_id: character_id)
      |> Ash.Query.limit(1)
      |> Ash.Query.sort(updated_at: :desc)

    case Ash.read(participants_query, domain: Api) do
      {:ok, [participant | _]} ->
        basic_info = extract_basic_info(participant, character_id)
        {:ok, basic_info}

      {:ok, []} ->
        Logger.warning("No participant data found for character #{character_id}")
        {:error, :no_data}

      {:error, reason} ->
        Logger.error("Failed to query participant data: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp extract_basic_info(participant, character_id) do
    %{
      character_id: character_id,
      character_name: participant.character_name || "Unknown",
      corporation_id: participant.corporation_id,
      corporation_name: participant.corporation_name || "Unknown Corp",
      alliance_id: participant.alliance_id,
      alliance_name: participant.alliance_name,
      security_status: 0.0,
      portrait_url: nil
    }
  end

  defp get_recent_killmails(character_id) do
    cutoff_date = DateTime.add(DateTime.utc_now(), -@analysis_period_days, :day)

    # Get killmails where character is a participant
    participants_query =
      Participant
      |> Ash.Query.new()
      |> Ash.Query.filter(character_id: character_id)

    case Ash.read(participants_query, domain: Api) do
      {:ok, participants} ->
        # Get enriched killmails for these participants
        killmail_ids = participants |> Stream.map(& &1.killmail_id) |> Enum.uniq()
        fetch_killmails_for_participants(killmail_ids, cutoff_date)

      {:error, reason} ->
        Logger.error("Failed to query participants: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp fetch_killmails_for_participants(killmail_ids, cutoff_date) do
    killmails_query =
      KillmailEnriched
      |> Ash.Query.new()
      |> Ash.Query.filter(killmail_id in ^killmail_ids)
      |> Ash.Query.filter(killmail_time >= ^cutoff_date)
      |> Ash.Query.load(:participants)

    case Ash.read(killmails_query, domain: Api) do
      {:ok, killmails} -> {:ok, killmails}
      {:error, reason} -> {:error, reason}
    end
  end

  defp calculate_all_metrics(character_id, killmail_data) do
    if length(killmail_data) < @min_activity_threshold do
      Logger.info(
        "Character #{character_id} has insufficient activity for analysis (#{length(killmail_data)} killmails)"
      )

      {:error, :insufficient_data}
    else
      # Use the comprehensive CharacterMetrics module
      metrics = CharacterMetrics.calculate_all_metrics(character_id, killmail_data)
      {:ok, metrics}
    end
  end

  defp save_character_stats(basic_info, metrics) do
    attrs = build_character_stats_attrs(basic_info, metrics)

    case Ash.create(CharacterStats, attrs,
           domain: Api,
           upsert?: true,
           upsert_identity: :character_id
         ) do
      {:ok, character_stats} ->
        Logger.info("Successfully saved character stats for #{basic_info.character_name}")
        {:ok, character_stats}

      {:error, changeset} ->
        Logger.error("Failed to save character stats: #{inspect(changeset)}")
        {:error, changeset}
    end
  end

  # Helper functions

  defp calculate_efficiency(combat_metrics) do
    kills = combat_metrics.total_kills || 0
    losses = combat_metrics.total_losses || 0

    if kills + losses == 0 do
      50.0
    else
      Float.round(kills / (kills + losses) * 100, 1)
    end
  end

  defp build_character_stats_attrs(basic_info, metrics) do
    combat_metrics = Map.get(metrics, :combat_metrics, %{})
    ship_usage = Map.get(metrics, :ship_usage, %{})
    geographic = Map.get(metrics, :geographic_patterns, %{})
    temporal = Map.get(metrics, :temporal_patterns, %{})
    danger = Map.get(metrics, :dangerous_rating, %{})
    associates = Map.get(metrics, :associate_analysis, %{})

    %{
      character_id: basic_info.character_id,
      character_name: basic_info.character_name,
      corporation_id: basic_info.corporation_id,
      corporation_name: basic_info.corporation_name,
      alliance_id: basic_info.alliance_id,
      alliance_name: basic_info.alliance_name,
      total_kills: combat_metrics.total_kills || 0,
      total_losses: combat_metrics.total_losses || 0,
      kd_ratio: combat_metrics.kd_ratio || 0.0,
      solo_kills: combat_metrics.solo_kills || 0,
      solo_losses: combat_metrics.solo_losses || 0,
      dangerous_rating: danger.score || 0.0,
      solo_ratio: combat_metrics.solo_kills / max(1, combat_metrics.total_kills),
      avg_gang_size: associates.typical_gang_size || 0.0,
      efficiency: calculate_efficiency(combat_metrics),
      recent_activity_score: calculate_recent_activity_score(metrics),
      primary_timezone: temporal.prime_timezone || "Unknown",
      most_active_regions: geographic.most_active_regions || [],
      most_active_systems: geographic.most_active_systems || [],
      ship_usage: format_ship_usage(ship_usage),
      ship_diversity_score: ship_usage.ship_diversity_score || 0.0,
      analysis_data: Jason.encode!(metrics),
      analysis_timestamp: DateTime.utc_now(),
      completeness_score: calculate_completeness_score(metrics),
      last_seen: DateTime.utc_now()
    }
  end

  defp calculate_recent_activity_score(metrics) do
    combat = Map.get(metrics, :combat_metrics, %{})
    total_activity = (combat.total_kills || 0) + (combat.total_losses || 0)

    # Simple activity score based on total engagements
    min(100, total_activity)
  end

  defp format_ship_usage(ship_usage) do
    ship_usage
    |> Map.get(:ship_frequencies, %{})
    |> Jason.encode!()
  end

  defp calculate_completeness_score(metrics) do
    # Calculate how complete the analysis is based on available data
    scores = [
      if(Map.get(metrics, :combat_metrics), do: 20, else: 0),
      if(Map.get(metrics, :ship_usage), do: 20, else: 0),
      if(Map.get(metrics, :geographic_patterns), do: 20, else: 0),
      if(Map.get(metrics, :temporal_patterns), do: 20, else: 0),
      if(Map.get(metrics, :associate_analysis), do: 20, else: 0)
    ]

    Enum.sum(scores)
  end

  # defp victim_is_character?(killmail, character_id) do
  #   Enum.any?(killmail.participants || [], fn p ->
  #     p.is_victim && p.character_id == character_id
  #   end)
  # end
end

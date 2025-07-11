defmodule EveDmv.Contexts.BattleAnalysis do
  @moduledoc """
  Context module for battle analysis functionality.

  This module provides the public API for battle detection, analysis, and reconstruction.
  """

  require Logger
  
  alias EveDmv.Contexts.BattleAnalysis.Domain.BattleDetectionService
  alias EveDmv.Contexts.BattleAnalysis.Domain.BattleTimelineService
  alias EveDmv.Contexts.BattleAnalysis.Domain.ZkillboardImportService
  alias EveDmv.Contexts.BattleAnalysis.Domain.MultiSystemBattleCorrelator
  alias EveDmv.Contexts.BattleAnalysis.Domain.TacticalPhaseDetector
  alias EveDmv.Contexts.BattleAnalysis.Domain.ShipPerformanceAnalyzer

  @doc """
  Detects battles from killmail data within a time range.

  ## Examples

      iex> start_time = ~N[2025-01-09 00:00:00]
      iex> end_time = ~N[2025-01-09 23:59:59]
      iex> EveDmv.Contexts.BattleAnalysis.detect_battles(start_time, end_time)
      {:ok, [%{battle_id: "battle_30003089_20250109050000", killmails: [...], metadata: %{...}}]}
  """
  def detect_battles(start_time, end_time, options \\ []) do
    BattleDetectionService.detect_battles(start_time, end_time, options)
  end

  @doc """
  Detects battles in a specific solar system within a time range.
  """
  def detect_battles_in_system(system_id, start_time, end_time, options \\ []) do
    BattleDetectionService.detect_battles_in_system(system_id, start_time, end_time, options)
  end

  @doc """
  Analyzes a potential battle from a list of killmail IDs.
  Useful for analyzing battles from external sources like zkillboard.
  """
  def analyze_battle_from_killmail_ids(killmail_ids) when is_list(killmail_ids) do
    BattleDetectionService.analyze_battle_from_killmail_ids(killmail_ids)
  end

  @doc """
  Detects recent battles from the last N hours.
  """
  def detect_recent_battles(hours_back \\ 24, options \\ []) do
    end_time = NaiveDateTime.utc_now()
    start_time = NaiveDateTime.add(end_time, -hours_back * 3600, :second)

    detect_battles(start_time, end_time, options)
  end

  @doc """
  Gets battle summary statistics for a time period.
  """
  def get_battle_statistics(start_time, end_time) do
    case detect_battles(start_time, end_time) do
      {:ok, battles} ->
        stats = %{
          total_battles: length(battles),
          total_kills: Enum.sum(Enum.map(battles, &length(&1.killmails))),
          battle_types: analyze_battle_types(battles),
          most_active_systems: analyze_most_active_systems(battles),
          average_battle_duration: calculate_average_duration(battles)
        }

        {:ok, stats}

      error ->
        error
    end
  end

  @doc """
  Reconstructs a detailed timeline from battle data.

  Provides chronological event analysis, battle phases, fleet composition changes,
  and identifies key moments in the battle.
  """
  def reconstruct_battle_timeline(battle) do
    BattleTimelineService.reconstruct_timeline(battle)
  end

  @doc """
  Analyzes a sequence of battles to identify patterns and connections.

  Useful for tracking roaming gangs, escalating conflicts, or multi-system engagements.
  """
  def analyze_battle_sequence(battles) when is_list(battles) do
    BattleTimelineService.analyze_battle_sequence(battles)
  end

  @doc """
  Gets a detailed battle analysis including timeline for a specific battle ID.
  """
  def get_battle_with_timeline(battle_id) do
    # Parse battle_id to extract system and time
    case parse_battle_id(battle_id) do
      {:ok, {system_id, start_time}} ->
        # Detect battles in a narrow time window around this battle
        end_time = NaiveDateTime.add(start_time, 3600, :second) # 1 hour window
        
        case detect_battles_in_system(system_id, start_time, end_time) do
          {:ok, battles} ->
            Logger.debug("Found #{length(battles)} battles in system #{system_id}")
            Logger.debug("Looking for battle_id: #{battle_id}")
            Logger.debug("Available battle IDs: #{inspect(Enum.map(battles, & &1.battle_id))}")
            
            case Enum.find(battles, fn b -> b.battle_id == battle_id end) do
              nil ->
                # Try to find a battle in the same system with similar timestamp
                similar_battle = find_similar_battle(battles, battle_id, system_id)
                case similar_battle do
                  nil -> {:error, :battle_not_found}
                  battle -> 
                    timeline = reconstruct_battle_timeline(battle)
                    {:ok, Map.put(battle, :timeline, timeline)}
                end

              battle ->
                timeline = reconstruct_battle_timeline(battle)
                {:ok, Map.put(battle, :timeline, timeline)}
            end
            
          error ->
            error
        end
        
      _ ->
        # Fallback to old method if parsing fails
        get_battle_with_timeline_legacy(battle_id)
    end
  end
  
  defp parse_battle_id(battle_id) do
    # Battle ID format: "battle_SYSTEMID_YYYYMMDDHHMMSS"
    case String.split(battle_id, "_") do
      ["battle", system_id_str, timestamp_str] ->
        with {system_id, ""} <- Integer.parse(system_id_str),
             {:ok, timestamp} <- parse_battle_timestamp(timestamp_str) do
          # Go back 30 minutes to ensure we catch the battle start
          start_time = NaiveDateTime.add(timestamp, -1800, :second)
          {:ok, {system_id, start_time}}
        else
          _ -> :error
        end
      _ ->
        :error
    end
  end
  
  defp find_similar_battle(battles, requested_battle_id, system_id) do
    # Extract timestamp from the requested battle ID
    case parse_battle_id(requested_battle_id) do
      {:ok, {_system_id, requested_time}} ->
        # Find battles in the same system within a 10-minute window
        time_window_seconds = 600  # 10 minutes
        
        battles
        |> Enum.filter(fn battle ->
          # Parse each battle's timestamp
          case parse_battle_id(battle.battle_id) do
            {:ok, {^system_id, battle_time}} ->
              time_diff = abs(NaiveDateTime.diff(requested_time, battle_time, :second))
              time_diff <= time_window_seconds
            _ ->
              false
          end
        end)
        |> Enum.min_by(fn battle ->
          # Find the battle with the closest timestamp
          case parse_battle_id(battle.battle_id) do
            {:ok, {^system_id, battle_time}} ->
              abs(NaiveDateTime.diff(requested_time, battle_time, :second))
            _ ->
              :infinity
          end
        end, fn -> nil end)
        
      _ ->
        nil
    end
  end
  
  defp parse_battle_timestamp(timestamp_str) do
    # Parse YYYYMMDDHHMMSS format
    with <<year::binary-4, month::binary-2, day::binary-2, 
           hour::binary-2, minute::binary-2, second::binary-2>> <- timestamp_str,
         {y, ""} <- Integer.parse(year),
         {mo, ""} <- Integer.parse(month),
         {d, ""} <- Integer.parse(day),
         {h, ""} <- Integer.parse(hour),
         {mi, ""} <- Integer.parse(minute),
         {s, ""} <- Integer.parse(second) do
      NaiveDateTime.new(y, mo, d, h, mi, s)
    else
      _ -> :error
    end
  end
  
  
  defp get_battle_with_timeline_legacy(battle_id) do
    # Fallback: search recent battles
    case detect_recent_battles(48) do
      {:ok, battles} ->
        case Enum.find(battles, fn b -> b.battle_id == battle_id end) do
          nil ->
            {:error, :battle_not_found}

          battle ->
            timeline = reconstruct_battle_timeline(battle)
            {:ok, Map.put(battle, :timeline, timeline)}
        end

      error ->
        error
    end
  end

  @doc """
  Imports killmail data from a zkillboard URL.

  Automatically detects the type of zkillboard link and imports relevant killmails.
  After import, analyzes the killmails for battle patterns.

  ## Examples

      # Import a single kill
      {:ok, battle} = import_from_zkillboard("https://zkillboard.com/kill/128431979/")
      
      # Import related kills from a battle
      {:ok, battle} = import_from_zkillboard("https://zkillboard.com/related/31001629/202507090500/")
      
      # Import recent kills for a character
      {:ok, battles} = import_from_zkillboard("https://zkillboard.com/character/1234567890/")
  """
  def import_from_zkillboard(url) when is_binary(url) do
    case ZkillboardImportService.import_from_url(url) do
      {:ok, killmail_ids} ->
        # Analyze the imported killmails for battles
        analyze_imported_killmails(killmail_ids)

      error ->
        error
    end
  end

  @doc """
  Imports a specific killmail from zkillboard by ID.
  """
  def import_killmail_from_zkillboard(killmail_id) when is_integer(killmail_id) do
    case ZkillboardImportService.import_killmail(killmail_id) do
      {:ok, killmail_ids} ->
        analyze_imported_killmails(killmail_ids)

      error ->
        error
    end
  end

  @doc """
  Imports related kills from zkillboard for a specific system and time.
  """
  def import_related_kills_from_zkillboard(system_id, timestamp) do
    case ZkillboardImportService.import_related_kills(system_id, timestamp) do
      {:ok, killmail_ids} ->
        analyze_imported_killmails(killmail_ids)

      error ->
        error
    end
  end

  @doc """
  Performs comprehensive intelligence analysis on a battle.

  Includes tactical phase detection, ship performance analysis, and multi-system correlation.

  ## Examples

      iex> battle = get_battle!(battle_id)
      iex> EveDmv.Contexts.BattleAnalysis.analyze_battle_with_intelligence(battle)
      {:ok, %{
        tactical_phases: [...],
        ship_performance: %{...},
        multi_system_context: %{...},
        battle_flow: :pursuit_engagement
      }}
  """
  def analyze_battle_with_intelligence(battle) do
    with {:ok, phases} <- TacticalPhaseDetector.detect_tactical_phases(battle),
         {:ok, performance} <- ShipPerformanceAnalyzer.analyze_battle_performance(battle),
         {:ok, correlated} <-
           MultiSystemBattleCorrelator.correlate_multi_system_battles([battle]),
         # Ensure correlated is a list before passing to analyze_combat_flow_patterns
         true <- is_list(correlated) || {:error, "Correlated battles must be a list"},
         {:ok, flow_analysis} <-
           MultiSystemBattleCorrelator.analyze_combat_flow_patterns(correlated) do
      # For single-battle analysis, extract the current battle from correlated results
      current_battle = List.first(correlated)
      other_battles = Enum.drop(correlated, 1)

      {:ok,
       %{
         tactical_phases: phases,
         ship_performance: performance,
         multi_system_context: %{
           current_battle: current_battle,
           correlated_battles: other_battles,
           is_multi_system: length(correlated) > 1
         },
         battle_flow: flow_analysis
       }}
    else
      false -> {:error, "Unexpected data structure in battle analysis"}
      error -> error
    end
  end

  @doc """
  Gets correlated battles across multiple systems.

  Identifies connected engagements that may be part of a larger conflict.
  """
  def get_multi_system_battle_chain(battle_id) do
    with {:ok, battle} <- get_battle_by_id(battle_id),
         {:ok, chain} <- MultiSystemBattleCorrelator.correlate_multi_system_battles([battle]) do
      {:ok, chain}
    end
  end

  @doc """
  Gets detailed tactical analysis for a battle.

  Returns phase detection, key moments, and tactical patterns.
  """
  def get_tactical_analysis(battle_id) do
    with {:ok, battle} <- get_battle_by_id(battle_id),
         {:ok, phases} <- TacticalPhaseDetector.detect_tactical_phases(battle),
         transitions <- TacticalPhaseDetector.analyze_phase_transitions(phases) do
      {:ok,
       %{
         phases: phases,
         phase_transitions: transitions,
         key_moments: extract_key_moments_from_phases(phases),
         tactical_summary: generate_tactical_summary(phases, transitions)
       }}
    end
  end

  @doc """
  Gets comprehensive ship performance report for a battle.

  Analyzes DPS efficiency, survivability, and tactical contribution.
  """
  def get_ship_performance_report(battle_id) do
    with {:ok, battle} <- get_battle_by_id(battle_id),
         {:ok, performance} <- ShipPerformanceAnalyzer.analyze_battle_performance(battle) do
      {:ok, performance}
    end
  end

  @doc """
  Gets a comprehensive intelligence summary for a battle.

  Combines all available intelligence analysis into a single report.
  """
  def get_battle_intelligence_summary(battle_id) do
    with {:ok, battle} <- get_battle_by_id(battle_id),
         {:ok, intelligence} <- analyze_battle_with_intelligence(battle),
         timeline <- reconstruct_battle_timeline(battle) do
      {:ok,
       %{
         battle: battle,
         intelligence: intelligence,
         timeline: timeline,
         summary: generate_intelligence_summary(battle, intelligence, timeline)
       }}
    end
  end

  # Private helper functions

  defp analyze_imported_killmails(killmail_ids) do
    case analyze_battle_from_killmail_ids(killmail_ids) do
      {:ok, result} ->
        # If it's a single battle, return it with timeline
        case result do
          %{battle_id: _} = battle ->
            timeline = reconstruct_battle_timeline(battle)
            {:ok, Map.put(battle, :timeline, timeline)}

          %{battles: battles} ->
            # Multiple battles found
            battles_with_timelines =
              Enum.map(battles, fn battle ->
                timeline = reconstruct_battle_timeline(battle)
                Map.put(battle, :timeline, timeline)
              end)

            {:ok, %{battles: battles_with_timelines, type: :multiple_battles}}
        end

      error ->
        error
    end
  end

  defp analyze_battle_types(battles) do
    battles
    |> Enum.group_by(& &1.metadata.battle_type)
    |> Enum.map(fn {type, battles_of_type} ->
      {type, length(battles_of_type)}
    end)
    |> Enum.into(%{})
  end

  defp analyze_most_active_systems(battles) do
    battles
    |> Enum.group_by(& &1.metadata.primary_system)
    |> Enum.map(fn {system_id, battles_in_system} ->
      {system_id, length(battles_in_system)}
    end)
    |> Enum.sort_by(fn {_system_id, count} -> count end, :desc)
    |> Enum.take(10)
  end

  defp calculate_average_duration(battles) do
    case battles do
      [] ->
        0.0

      _ ->
        total_duration = Enum.sum(Enum.map(battles, & &1.metadata.duration_minutes))
        total_duration / length(battles)
    end
  end

  defp get_battle_by_id(battle_id) do
    # First try recent battles
    case detect_recent_battles(72) do
      {:ok, battles} ->
        case Enum.find(battles, fn b -> b.battle_id == battle_id end) do
          nil ->
            {:error, :battle_not_found}

          battle ->
            {:ok, battle}
        end

      error ->
        error
    end
  end

  defp generate_intelligence_summary(battle, intelligence, timeline) do
    %{
      overview: "Battle #{battle.battle_id} in system #{battle.metadata.primary_system}",
      duration: "#{battle.metadata.duration_minutes} minutes",
      participants: "#{battle.metadata.total_participants} pilots",
      tactical_summary: summarize_tactical_phases(intelligence.tactical_phases),
      performance_highlights: summarize_ship_performance(intelligence.ship_performance),
      multi_system_impact: summarize_multi_system_context(intelligence.multi_system_context),
      battle_flow_type: intelligence.battle_flow,
      key_timeline_events: extract_key_timeline_events(timeline)
    }
  end

  defp summarize_tactical_phases(phases) do
    phase_names = Enum.map(phases, & &1.phase_type)
    "Battle progressed through #{length(phases)} phases: #{Enum.join(phase_names, " → ")}"
  end

  defp summarize_ship_performance(performance) do
    top_performers =
      performance
      |> Map.get(:individual_performance, [])
      |> Enum.sort_by(& &1.overall_score, :desc)
      |> Enum.take(3)
      |> Enum.map(& &1.character_name)

    "Top performers: #{Enum.join(top_performers, ", ")}"
  end

  defp summarize_multi_system_context(context) do
    related_count = length(Map.get(context, :related_battles, []))

    if related_count > 0 do
      "Part of larger engagement spanning #{related_count + 1} systems"
    else
      "Isolated engagement"
    end
  end

  defp extract_key_timeline_events(timeline) do
    timeline
    |> Map.get(:events, [])
    |> Enum.filter(&(&1.significance == :high))
    |> Enum.take(5)
    |> Enum.map(& &1.description)
  end

  defp extract_key_moments_from_phases(phases) do
    phases
    |> Enum.flat_map(fn phase ->
      phase
      |> Map.get(:key_events, [])
      |> Enum.map(fn event ->
        %{
          time: event.timestamp,
          phase: phase.phase_type,
          description: event.description,
          significance: event.significance
        }
      end)
    end)
    |> Enum.sort_by(& &1.time)
  end

  defp generate_tactical_summary(phases, transitions) do
    phase_summary =
      phases
      |> Enum.map(fn phase ->
        "#{phase.phase_type} (#{phase.duration_seconds}s): #{phase.characteristics}"
      end)
      |> Enum.join(" → ")

    transition_summary =
      transitions
      |> Map.get(:significant_transitions, [])
      |> Enum.map(& &1.description)
      |> Enum.join(", ")

    %{
      phase_progression: phase_summary,
      key_transitions: transition_summary,
      combat_style: detect_combat_style(phases),
      engagement_type: classify_engagement_type(phases)
    }
  end

  defp detect_combat_style(phases) do
    # Analyze phases to determine combat style
    cond do
      Enum.any?(phases, &(&1.phase_type == :kiting)) -> :kiting_engagement
      Enum.any?(phases, &(&1.phase_type == :brawl)) -> :close_range_brawl
      Enum.any?(phases, &(&1.phase_type == :siege)) -> :siege_warfare
      true -> :mixed_tactics
    end
  end

  defp classify_engagement_type(phases) do
    # Classify the type of engagement based on phases
    phase_types = Enum.map(phases, & &1.phase_type)

    cond do
      :ambush in phase_types -> :ambush
      :chase in phase_types -> :pursuit
      length(phases) > 5 -> :prolonged_engagement
      true -> :standard_fleet_fight
    end
  end
end

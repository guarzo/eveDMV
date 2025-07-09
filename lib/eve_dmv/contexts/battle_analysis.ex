defmodule EveDmv.Contexts.BattleAnalysis do
  @moduledoc """
  Context module for battle analysis functionality.
  
  This module provides the public API for battle detection, analysis, and reconstruction.
  """
  
  alias EveDmv.Contexts.BattleAnalysis.Domain.BattleDetectionService
  alias EveDmv.Contexts.BattleAnalysis.Domain.BattleTimelineService
  alias EveDmv.Contexts.BattleAnalysis.Domain.ZkillboardImportService
  
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
          total_kills: Enum.sum(Enum.map(battles, & length(&1.killmails))),
          battle_types: analyze_battle_types(battles),
          most_active_systems: analyze_most_active_systems(battles),
          average_battle_duration: calculate_average_duration(battles)
        }
        {:ok, stats}
      
      error -> error
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
    # First, we need to find the battle - for now we'll search recent battles
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
      [] -> 0.0
      _ ->
        total_duration = Enum.sum(Enum.map(battles, & &1.metadata.duration_minutes))
        total_duration / length(battles)
    end
  end
end
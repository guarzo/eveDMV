defmodule EveDmv.Contexts.Combat.Core.BattleDetector do
  @moduledoc """
  Unified battle detection service that combines the best features from:
  - Time-based clustering with spatial correlation (from battle_analysis)
  - Real-time GenServer processing (from combat_analysis)  
  - Advanced analytics and metrics (from combat_intelligence)
  
  This module provides comprehensive battle detection from killmail streams.
  """
  
  use GenServer
  require Logger
  
  alias EveDmv.Killmails.KillmailRaw
  alias EveDmv.Repo
  import Ecto.Query
  
  # Configuration
  @time_window_minutes 10
  @spatial_threshold_au 100
  @min_participants_for_battle 4
  @cluster_merge_threshold 0.7
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc """
  Detect battles from a list of killmails using clustering algorithms.
  
  Options:
    - time_window: Minutes to consider for clustering (default: 10)
    - spatial_threshold: AU distance for spatial correlation (default: 100)
    - min_participants: Minimum participants for battle (default: 4)
    - real_time: Whether to process in real-time mode (default: false)
  """
  def detect_battles(killmails, opts \\ []) do
    GenServer.call(__MODULE__, {:detect_battles, killmails, opts}, :infinity)
  end
  
  @doc """
  Detect battles within a specific timeframe from the database.
  """
  def detect_battles_in_timeframe(start_time, end_time, opts \\ []) do
    GenServer.call(__MODULE__, {:detect_timeframe, start_time, end_time, opts}, :infinity)
  end
  
  @doc """
  Process a single killmail for real-time battle detection.
  """
  def process_killmail(killmail) do
    GenServer.cast(__MODULE__, {:process_killmail, killmail})
  end
  
  @doc """
  Get current active battles being tracked.
  """
  def get_active_battles do
    GenServer.call(__MODULE__, :get_active_battles)
  end
  
  # Server Callbacks
  
  @impl true
  def init(_opts) do
    state = %{
      active_battles: %{},
      killmail_buffer: [],
      last_cleanup: DateTime.utc_now()
    }
    
    # Schedule periodic cleanup
    Process.send_after(self(), :cleanup_stale_battles, :timer.minutes(5))
    
    {:ok, state}
  end
  
  @impl true
  def handle_call({:detect_battles, killmails, opts}, _from, state) do
    time_window = Keyword.get(opts, :time_window, @time_window_minutes)
    spatial_threshold = Keyword.get(opts, :spatial_threshold, @spatial_threshold_au)
    min_participants = Keyword.get(opts, :min_participants, @min_participants_for_battle)
    
    battles = killmails
    |> group_by_system()
    |> Enum.flat_map(fn {system_id, system_killmails} ->
      detect_battles_in_system(system_killmails, system_id, time_window, spatial_threshold, min_participants)
    end)
    |> merge_cross_system_battles(spatial_threshold)
    
    {:reply, {:ok, battles}, state}
  end
  
  @impl true
  def handle_call({:detect_timeframe, start_time, end_time, opts}, _from, state) do
    killmails = fetch_killmails_in_timeframe(start_time, end_time)
    
    case detect_battles(killmails, opts) do
      {:ok, battles} -> {:reply, {:ok, battles}, state}
      error -> {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call(:get_active_battles, _from, state) do
    {:reply, {:ok, state.active_battles}, state}
  end
  
  @impl true
  def handle_cast({:process_killmail, killmail}, state) do
    # Real-time processing: add to buffer and check for battle updates
    updated_state = state
    |> add_killmail_to_buffer(killmail)
    |> update_active_battles(killmail)
    |> check_battle_completion()
    
    {:noreply, updated_state}
  end
  
  @impl true
  def handle_info(:cleanup_stale_battles, state) do
    now = DateTime.utc_now()
    
    active_battles = state.active_battles
    |> Enum.reject(fn {_battle_id, battle} ->
      DateTime.diff(now, battle.last_activity, :minute) > @time_window_minutes * 2
    end)
    |> Map.new()
    
    Process.send_after(self(), :cleanup_stale_battles, :timer.minutes(5))
    
    {:noreply, %{state | active_battles: active_battles, last_cleanup: now}}
  end
  
  # Private Functions
  
  defp group_by_system(killmails) do
    Enum.group_by(killmails, & &1.solar_system_id)
  end
  
  defp detect_battles_in_system(killmails, system_id, time_window, spatial_threshold, min_participants) do
    killmails
    |> Enum.sort_by(& &1.killmail_time)
    |> cluster_by_time(time_window)
    |> Enum.map(fn cluster ->
      %{
        id: generate_battle_id(),
        system_id: system_id,
        killmail_ids: Enum.map(cluster, & &1.killmail_id),
        start_time: List.first(cluster).killmail_time,
        end_time: List.last(cluster).killmail_time,
        participant_count: count_unique_participants(cluster),
        ship_classes: analyze_ship_classes(cluster),
        total_value: calculate_total_value(cluster),
        intensity_score: calculate_intensity_score(cluster)
      }
    end)
    |> Enum.filter(& &1.participant_count >= min_participants)
  end
  
  defp cluster_by_time(killmails, time_window) do
    Enum.reduce(killmails, [], fn killmail, clusters ->
      case find_matching_cluster(killmail, clusters, time_window) do
        nil -> [[killmail] | clusters]
        index ->
          List.update_at(clusters, index, &(&1 ++ [killmail]))
      end
    end)
  end
  
  defp find_matching_cluster(killmail, clusters, time_window) do
    Enum.find_index(clusters, fn cluster ->
      Enum.any?(cluster, fn km ->
        DateTime.diff(killmail.killmail_time, km.killmail_time, :minute) <= time_window
      end)
    end)
  end
  
  defp merge_cross_system_battles(battles, spatial_threshold) do
    # Group battles that might be part of a larger multi-system engagement
    battles
    |> Enum.reduce([], fn battle, merged ->
      case find_mergeable_battle(battle, merged, spatial_threshold) do
        nil -> [battle | merged]
        index ->
          List.update_at(merged, index, &merge_battles(&1, battle))
      end
    end)
  end
  
  defp find_mergeable_battle(battle, battles, spatial_threshold) do
    Enum.find_index(battles, fn existing ->
      time_overlap?(battle, existing) &&
      systems_nearby?(battle.system_id, existing.system_id, spatial_threshold) &&
      similar_participants?(battle, existing)
    end)
  end
  
  defp count_unique_participants(killmails) do
    killmails
    |> Enum.flat_map(fn km ->
      attackers = (km.attackers || []) |> Enum.map(& &1["character_id"])
      [km.victim["character_id"] | attackers]
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> length()
  end
  
  defp analyze_ship_classes(killmails) do
    killmails
    |> Enum.map(& &1.victim["ship_type_id"])
    |> Enum.frequencies()
    |> Map.keys()
    # TODO: Map to actual ship classes once we have ship type data
  end
  
  defp calculate_total_value(killmails) do
    Enum.reduce(killmails, 0.0, fn km, sum ->
      sum + (km.zkb["totalValue"] || 0.0)
    end)
  end
  
  defp calculate_intensity_score(killmails) do
    # Score based on kills per minute, ship values, and participant count
    duration = case killmails do
      [] -> 1
      [_] -> 1
      kms ->
        first = List.first(kms).killmail_time
        last = List.last(kms).killmail_time
        max(DateTime.diff(last, first, :minute), 1)
    end
    
    kills_per_minute = length(killmails) / duration
    avg_value = calculate_total_value(killmails) / max(length(killmails), 1)
    participants = count_unique_participants(killmails)
    
    # Weighted score
    kills_per_minute * 0.4 + (avg_value / 1_000_000_000) * 0.3 + participants * 0.3
  end
  
  defp fetch_killmails_in_timeframe(start_time, end_time) do
    KillmailRaw
    |> where([k], k.killmail_time >= ^start_time and k.killmail_time <= ^end_time)
    |> order_by([k], asc: k.killmail_time)
    |> Repo.all()
  end
  
  defp generate_battle_id do
    "battle_#{:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)}"
  end
  
  defp add_killmail_to_buffer(state, killmail) do
    %{state | killmail_buffer: [killmail | state.killmail_buffer]}
  end
  
  defp update_active_battles(state, killmail) do
    # Find or create active battle for this killmail
    battle_id = find_or_create_active_battle(state.active_battles, killmail)
    
    updated_battles = Map.update(state.active_battles, battle_id, 
      create_new_battle(killmail),
      &update_battle_with_killmail(&1, killmail)
    )
    
    %{state | active_battles: updated_battles}
  end
  
  defp find_or_create_active_battle(active_battles, killmail) do
    Enum.find_value(active_battles, generate_battle_id(), fn {id, battle} ->
      if killmail_belongs_to_battle?(killmail, battle), do: id
    end)
  end
  
  defp killmail_belongs_to_battle?(killmail, battle) do
    time_diff = DateTime.diff(killmail.killmail_time, battle.last_activity, :minute)
    time_diff <= @time_window_minutes && killmail.solar_system_id == battle.system_id
  end
  
  defp create_new_battle(killmail) do
    %{
      id: generate_battle_id(),
      system_id: killmail.solar_system_id,
      killmail_ids: [killmail.killmail_id],
      start_time: killmail.killmail_time,
      last_activity: killmail.killmail_time,
      participants: extract_participants(killmail),
      status: :active
    }
  end
  
  defp update_battle_with_killmail(battle, killmail) do
    battle
    |> Map.update!(:killmail_ids, &[killmail.killmail_id | &1])
    |> Map.put(:last_activity, killmail.killmail_time)
    |> Map.update!(:participants, &merge_participants(&1, extract_participants(killmail)))
  end
  
  defp extract_participants(killmail) do
    attackers = (killmail.attackers || [])
    |> Enum.map(& &1["character_id"])
    |> Enum.reject(&is_nil/1)
    
    victim = killmail.victim["character_id"]
    
    MapSet.new([victim | attackers] |> Enum.reject(&is_nil/1))
  end
  
  defp merge_participants(existing, new) do
    MapSet.union(MapSet.new(existing), new)
  end
  
  defp check_battle_completion(state) do
    # Mark battles as completed if no activity for 2x time window
    state
  end
  
  defp time_overlap?(battle1, battle2) do
    # Check if battles have overlapping time windows
    DateTime.diff(battle1.end_time, battle2.start_time, :minute) >= 0 &&
    DateTime.diff(battle2.end_time, battle1.start_time, :minute) >= 0
  end
  
  defp systems_nearby?(_system1_id, _system2_id, _threshold) do
    # TODO: Implement actual distance calculation once we have system data
    # For now, assume all systems in same region are "nearby"
    true
  end
  
  defp similar_participants?(_battle1, _battle2) do
    # TODO: Check participant overlap once we track participants properly
    true
  end
  
  defp merge_battles(battle1, battle2) do
    %{
      id: battle1.id,
      system_id: [battle1.system_id, battle2.system_id] |> List.flatten() |> Enum.uniq(),
      killmail_ids: battle1.killmail_ids ++ battle2.killmail_ids,
      start_time: Enum.min([battle1.start_time, battle2.start_time], DateTime),
      end_time: Enum.max([battle1.end_time, battle2.end_time], DateTime),
      participant_count: battle1.participant_count + battle2.participant_count,
      total_value: battle1.total_value + battle2.total_value,
      intensity_score: (battle1.intensity_score + battle2.intensity_score) / 2
    }
  end
end
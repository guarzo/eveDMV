defmodule EveDmv.Contexts.BattleAnalysis.Core.BattleDetector do
  @moduledoc """
  Unified battle detection service that combines the best features from:
  - Time-based clustering with spatial correlation (from battle_analysis)
  - Real-time GenServer processing (from combat_analysis)
  - Advanced analytics and metrics (from combat_intelligence)

  This module provides comprehensive battle detection from killmail streams.
  """

  use GenServer

  import Ecto.Query

  alias EveDmv.Core.Utils.DateTimeUtils
  alias EveDmv.Killmails.KillmailRaw
  alias EveDmv.Repo

  require Logger

  # Configuration
  @time_window_minutes 10
  @spatial_threshold_au 100
  @min_participants_for_battle 4

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

  @impl GenServer
  def init(_opts) do
    state = %{
      active_battles: %{},
      killmail_buffer: [],
      last_cleanup: DateTimeUtils.utc_now()
    }

    # Schedule periodic cleanup
    Process.send_after(self(), :cleanup_stale_battles, :timer.minutes(5))

    {:ok, state}
  end

  @impl GenServer
  def handle_call({:detect_battles, killmails, opts}, _from, state) do
    time_window = Keyword.get(opts, :time_window, @time_window_minutes)
    spatial_threshold = Keyword.get(opts, :spatial_threshold, @spatial_threshold_au)
    min_participants = Keyword.get(opts, :min_participants, @min_participants_for_battle)

    battles =
      killmails
      |> group_by_system()
      |> Enum.flat_map(fn {system_id, system_killmails} ->
        detect_battles_in_system(
          system_killmails,
          system_id,
          time_window,
          spatial_threshold,
          min_participants
        )
      end)
      |> merge_cross_system_battles(spatial_threshold)

    {:reply, {:ok, battles}, state}
  end

  @impl GenServer
  def handle_call({:detect_timeframe, start_time, end_time, opts}, _from, state) do
    killmails = fetch_killmails_in_timeframe(start_time, end_time)

    case detect_battles(killmails, opts) do
      {:ok, battles} -> {:reply, {:ok, battles}, state}
      error -> {:reply, error, state}
    end
  end

  @impl GenServer
  def handle_call(:get_active_battles, _from, state) do
    {:reply, {:ok, state.active_battles}, state}
  end

  @impl GenServer
  def handle_cast({:process_killmail, killmail}, state) do
    # Real-time processing: add to buffer and check for battle updates
    updated_state =
      state
      |> add_killmail_to_buffer(killmail)
      |> update_active_battles(killmail)
      |> check_battle_completion()

    {:noreply, updated_state}
  end

  @impl GenServer
  def handle_info(:cleanup_stale_battles, state) do
    now = DateTimeUtils.utc_now()

    active_battles =
      state.active_battles
      |> Enum.reject(fn {_battle_id, battle} ->
        DateTimeUtils.diff(now, battle.last_activity, :minute) > @time_window_minutes * 2
      end)
      |> Map.new()

    Process.send_after(self(), :cleanup_stale_battles, :timer.minutes(5))

    {:noreply, %{state | active_battles: active_battles, last_cleanup: now}}
  end

  # Private Functions

  defp group_by_system(killmails) do
    Enum.group_by(killmails, & &1.solar_system_id)
  end

  defp detect_battles_in_system(
         killmails,
         system_id,
         time_window,
         _spatial_threshold,
         min_participants
       ) do
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
    |> Enum.filter(&(&1.participant_count >= min_participants))
  end

  defp cluster_by_time(killmails, time_window) do
    Enum.reduce(killmails, [], fn killmail, clusters ->
      case find_matching_cluster(killmail, clusters, time_window) do
        nil ->
          [[killmail] | clusters]

        index ->
          List.update_at(clusters, index, &(&1 ++ [killmail]))
      end
    end)
  end

  defp find_matching_cluster(killmail, clusters, time_window) do
    Enum.find_index(clusters, fn cluster ->
      Enum.any?(cluster, fn km ->
        DateTimeUtils.diff(killmail.killmail_time, km.killmail_time, :minute) <= time_window
      end)
    end)
  end

  defp merge_cross_system_battles(battles, spatial_threshold) do
    # Group battles that might be part of a larger multi-system engagement
    battles
    |> Enum.reduce([], fn battle, merged ->
      case find_mergeable_battle(battle, merged, spatial_threshold) do
        nil ->
          [battle | merged]

        index ->
          List.update_at(merged, index, &merge_battles(&1, battle))
      end
    end)
  end

  defp find_mergeable_battle(battle, battles, _spatial_threshold) do
    Enum.find_index(battles, fn existing ->
      time_overlap?(battle, existing) &&
        battle.system_id == existing.system_id &&
        similar_participants?(battle, existing)
    end)
  end

  defp count_unique_participants(killmails) do
    killmails
    |> Enum.reduce(MapSet.new(), fn km, acc ->
      victim_id = km.victim["character_id"]

      attacker_ids =
        (km.attackers || [])
        |> Enum.reduce(acc, fn attacker, inner_acc ->
          case attacker["character_id"] do
            nil -> inner_acc
            id -> MapSet.put(inner_acc, id)
          end
        end)

      if victim_id, do: MapSet.put(attacker_ids, victim_id), else: attacker_ids
    end)
    |> MapSet.size()
  end

  defp analyze_ship_classes(killmails) do
    killmails
    |> Enum.map(& &1.victim["ship_type_id"])
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&{&1, EveDmv.StaticData.ShipTypes.classify_ship_type(&1)})
    |> Enum.group_by(fn {_type_id, class} -> class end)
    |> Enum.map(fn {class, ships} -> {class, length(ships)} end)
    |> Map.new()
  end

  defp calculate_total_value(killmails) do
    Enum.reduce(killmails, 0.0, fn km, sum ->
      sum + (km.zkb["totalValue"] || 0.0)
    end)
  end

  defp calculate_intensity_score(killmails) do
    # Score based on kills per minute, ship values, and participant count
    duration =
      case killmails do
        [] ->
          1

        [_] ->
          1

        kms ->
          first = List.first(kms).killmail_time
          last = List.last(kms).killmail_time
          max(DateTimeUtils.diff(last, first, :minute), 1)
      end

    kills_per_minute = length(killmails) / duration
    avg_value = calculate_total_value(killmails) / max(length(killmails), 1)
    participants = count_unique_participants(killmails)

    # Weighted score
    kills_per_minute * 0.4 + avg_value / 1_000_000_000 * 0.3 + participants * 0.3
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

    updated_battles =
      Map.update(
        state.active_battles,
        battle_id,
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
    time_diff = DateTimeUtils.diff(killmail.killmail_time, battle.last_activity, :minute)
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
    victim_id = killmail.victim["character_id"]

    base_set = if victim_id, do: MapSet.new([victim_id]), else: MapSet.new()

    (killmail.attackers || [])
    |> Enum.reduce(base_set, fn attacker, acc ->
      case attacker["character_id"] do
        nil -> acc
        id -> MapSet.put(acc, id)
      end
    end)
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
    DateTimeUtils.diff(battle1.end_time, battle2.start_time, :minute) >= 0 &&
      DateTimeUtils.diff(battle2.end_time, battle1.start_time, :minute) >= 0
  end

  defp similar_participants?(battle1, battle2) do
    # Calculate participant overlap between two battles
    participants1 = get_battle_participants(battle1)
    participants2 = get_battle_participants(battle2)

    if MapSet.size(participants1) == 0 || MapSet.size(participants2) == 0 do
      false
    else
      # Calculate Jaccard similarity for participant overlap
      intersection = MapSet.intersection(participants1, participants2)
      union = MapSet.union(participants1, participants2)
      overlap_ratio = MapSet.size(intersection) / MapSet.size(union)
      # Consider battles similar if they share >30% of participants
      overlap_ratio > 0.3
    end
  end

  defp get_battle_participants(battle) do
    # Extract participants from battle data
    case battle do
      %{participants: participants} when is_struct(participants, MapSet) ->
        participants

      %{participants: participants} when is_list(participants) ->
        MapSet.new(participants)

      %{participants: participants} when is_map(participants) ->
        MapSet.new(Map.keys(participants))

      # If no participants field, try to extract from killmail_ids
      %{killmail_ids: killmail_ids} ->
        extract_participants_from_killmail_ids(killmail_ids)

      _ ->
        MapSet.new()
    end
  end

  defp extract_participants_from_killmail_ids(killmail_ids) do
    # Query database to get participants for these killmails
    killmails =
      KillmailRaw
      |> where([k], k.killmail_id in ^killmail_ids)
      |> Repo.all()

    killmails
    |> Enum.reduce(MapSet.new(), fn killmail, acc ->
      participants = extract_participants(killmail)
      MapSet.union(acc, participants)
    end)
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

  @doc """
  Detect battles involving a specific character.
  """
  def detect_character_battles(character_id, limit \\ 10) do
    since = DateTimeUtils.add(DateTimeUtils.utc_now(), -30 * 24 * 3600, :second)

    # Get killmails involving this character
    killmails =
      KillmailRaw
      |> where([k], k.killmail_time > ^since)
      |> where([k], fragment("? @> ?", k.participants, ^[%{character_id: character_id}]))
      |> order_by([k], desc: k.killmail_time)
      # Get more killmails to find battles
      |> limit(^(limit * 3))
      |> Repo.all()

    case detect_battles(killmails) do
      {:ok, battles} -> battles |> Enum.take(limit)
      {:error, _} -> []
    end
  rescue
    error in [Ecto.QueryError, Postgrex.Error] ->
      Logger.error("Database error in detect_character_battles: #{inspect(error)}")
      []
  end

  @doc """
  Get battle statistics for a character.
  """
  def get_character_battle_stats(character_id) do
    battles = detect_character_battles(character_id, 100)

    %{
      total_battles: length(battles),
      total_kills: count_character_kills_in_battles(character_id, battles),
      total_losses: count_character_losses_in_battles(character_id, battles),
      isk_destroyed: calculate_character_isk_destroyed(character_id, battles),
      isk_lost: calculate_character_isk_lost(character_id, battles),
      most_active_system: find_most_active_system(battles),
      last_battle: List.first(battles)
    }
  end

  @doc """
  Detect battles in a specific system.
  """
  def detect_system_battles(system_id, limit \\ 10) do
    since = DateTimeUtils.add(DateTimeUtils.utc_now(), -7 * 24 * 3600, :second)

    killmails =
      KillmailRaw
      |> where([k], k.solar_system_id == ^system_id)
      |> where([k], k.killmail_time > ^since)
      |> order_by([k], desc: k.killmail_time)
      |> limit(^(limit * 5))
      |> Repo.all()

    case detect_battles(killmails) do
      {:ok, battles} -> battles |> Enum.take(limit)
      {:error, _} -> []
    end
  rescue
    error in [Ecto.QueryError, Postgrex.Error] ->
      Logger.error("Database error in detect_system_battles: #{inspect(error)}")
      []
  end

  @doc """
  Get battle statistics for a system.
  """
  def get_system_battle_stats(system_id) do
    battles = detect_system_battles(system_id, 100)

    %{
      total_battles: length(battles),
      total_kills: count_total_kills_in_battles(battles),
      total_isk_destroyed: calculate_total_isk_destroyed(battles),
      average_battle_size: calculate_average_battle_size(battles),
      most_recent_battle: List.first(battles),
      battle_frequency: calculate_battle_frequency(battles)
    }
  end

  @doc """
  Detect battles involving a specific corporation.
  """
  def detect_corporation_battles(corporation_id, limit \\ 10) do
    since = DateTimeUtils.add(DateTimeUtils.utc_now(), -30 * 24 * 3600, :second)

    killmails =
      KillmailRaw
      |> where([k], k.killmail_time > ^since)
      |> where([k], fragment("? @> ?", k.participants, ^[%{corporation_id: corporation_id}]))
      |> order_by([k], desc: k.killmail_time)
      |> limit(^(limit * 3))
      |> Repo.all()

    case detect_battles(killmails) do
      {:ok, battles} -> battles |> Enum.take(limit)
      {:error, _} -> []
    end
  rescue
    error in [Ecto.QueryError, Postgrex.Error] ->
      Logger.error("Database error in detect_corporation_battles: #{inspect(error)}")
      []
  end

  @doc """
  Get battle statistics for a corporation.
  """
  def get_corporation_battle_stats(corporation_id) do
    battles = detect_corporation_battles(corporation_id, 100)

    %{
      total_battles: length(battles),
      total_kills: count_corporation_kills_in_battles(corporation_id, battles),
      total_losses: count_corporation_losses_in_battles(corporation_id, battles),
      isk_destroyed: calculate_corporation_isk_destroyed(corporation_id, battles),
      isk_lost: calculate_corporation_isk_lost(corporation_id, battles),
      most_active_system: find_most_active_system(battles),
      efficiency: calculate_corporation_efficiency(corporation_id, battles)
    }
  end

  @doc """
  Detect battle from a single killmail.
  """
  def detect_battle_from_killmail(killmail) do
    # Find other killmails in the same timeframe and system
    time_window = @time_window_minutes
    start_time = DateTimeUtils.add(killmail.killmail_time, -time_window * 60, :second)
    end_time = DateTimeUtils.add(killmail.killmail_time, time_window * 60, :second)

    related_killmails =
      KillmailRaw
      |> where([k], k.solar_system_id == ^killmail.solar_system_id)
      |> where([k], k.killmail_time >= ^start_time and k.killmail_time <= ^end_time)
      |> Repo.all()

    case detect_battles([killmail | related_killmails]) do
      {:ok, [battle | _]} -> {:ok, battle}
      {:ok, []} -> {:error, :no_battle_detected}
      {:error, reason} -> {:error, reason}
    end
  rescue
    error -> {:error, error}
  end

  # Helper functions for statistics calculations

  defp count_character_kills_in_battles(character_id, battles) do
    battles
    |> Enum.map(fn battle ->
      count_character_kills_in_battle(character_id, battle.killmail_ids)
    end)
    |> Enum.sum()
  end

  defp count_character_losses_in_battles(character_id, battles) do
    battles
    |> Enum.map(fn battle ->
      count_character_losses_in_battle(character_id, battle.killmail_ids)
    end)
    |> Enum.sum()
  end

  defp count_character_kills_in_battle(character_id, killmail_ids) do
    KillmailRaw
    |> where([k], k.killmail_id in ^killmail_ids)
    |> where([k], fragment("? @> ?", k.participants, ^[%{character_id: character_id}]))
    |> where(
      [k],
      fragment("?->'victim'->>'character_id' != ?", k.participants, ^to_string(character_id))
    )
    |> Repo.aggregate(:count)
  rescue
    error in [Ecto.QueryError, Postgrex.Error] ->
      Logger.error("Database error in count query: #{inspect(error)}")
      0
  end

  defp count_character_losses_in_battle(character_id, killmail_ids) do
    KillmailRaw
    |> where([k], k.killmail_id in ^killmail_ids)
    |> where(
      [k],
      fragment("?->'victim'->>'character_id' = ?", k.participants, ^to_string(character_id))
    )
    |> Repo.aggregate(:count)
  rescue
    error in [Ecto.QueryError, Postgrex.Error] ->
      Logger.error("Database error in count query: #{inspect(error)}")
      0
  end

  defp calculate_character_isk_destroyed(character_id, battles) do
    battles
    |> Enum.map(fn battle ->
      calculate_character_isk_destroyed_in_battle(character_id, battle.killmail_ids)
    end)
    |> Enum.sum()
  end

  defp calculate_character_isk_lost(character_id, battles) do
    battles
    |> Enum.map(fn battle ->
      calculate_character_isk_lost_in_battle(character_id, battle.killmail_ids)
    end)
    |> Enum.sum()
  end

  defp calculate_character_isk_destroyed_in_battle(character_id, killmail_ids) do
    KillmailRaw
    |> where([k], k.killmail_id in ^killmail_ids)
    |> where([k], fragment("? @> ?", k.participants, ^[%{character_id: character_id}]))
    |> where(
      [k],
      fragment("?->'victim'->>'character_id' != ?", k.participants, ^to_string(character_id))
    )
    |> select([k], k.total_value)
    |> Repo.all()
    |> Enum.sum()
  rescue
    error in [Ecto.QueryError, Postgrex.Error] ->
      Logger.error("Database error in sum query: #{inspect(error)}")
      0.0
  end

  defp calculate_character_isk_lost_in_battle(character_id, killmail_ids) do
    KillmailRaw
    |> where([k], k.killmail_id in ^killmail_ids)
    |> where(
      [k],
      fragment("?->'victim'->>'character_id' = ?", k.participants, ^to_string(character_id))
    )
    |> select([k], k.total_value)
    |> Repo.all()
    |> Enum.sum()
  rescue
    error in [Ecto.QueryError, Postgrex.Error] ->
      Logger.error("Database error in sum query: #{inspect(error)}")
      0.0
  end

  defp find_most_active_system(battles) do
    battles
    |> Enum.flat_map(fn battle ->
      case battle.system_id do
        list when is_list(list) -> list
        single -> [single]
      end
    end)
    |> Enum.frequencies()
    |> Enum.max_by(fn {_system, count} -> count end, fn -> {nil, 0} end)
    |> elem(0)
  end

  defp count_total_kills_in_battles(battles) do
    battles
    |> Enum.map(fn battle -> length(battle.killmail_ids) end)
    |> Enum.sum()
  end

  defp calculate_total_isk_destroyed(battles) do
    battles
    |> Enum.map(fn battle -> battle.total_value || 0.0 end)
    |> Enum.sum()
  end

  defp calculate_average_battle_size(battles) do
    if length(battles) > 0 do
      total_participants = battles |> Enum.map(& &1.participant_count) |> Enum.sum()
      Float.round(total_participants / length(battles), 1)
    else
      0.0
    end
  end

  defp calculate_battle_frequency(battles) do
    if length(battles) < 2 do
      0.0
    else
      first_battle = List.last(battles)
      last_battle = List.first(battles)

      time_diff_hours = DateTimeUtils.diff(last_battle.start_time, first_battle.start_time, :hour)

      if time_diff_hours > 0 do
        Float.round(length(battles) / time_diff_hours, 2)
      else
        0.0
      end
    end
  end

  defp count_corporation_kills_in_battles(corporation_id, battles) do
    battles
    |> Enum.map(fn battle ->
      count_corporation_kills_in_battle(corporation_id, battle.killmail_ids)
    end)
    |> Enum.sum()
  end

  defp count_corporation_losses_in_battles(corporation_id, battles) do
    battles
    |> Enum.map(fn battle ->
      count_corporation_losses_in_battle(corporation_id, battle.killmail_ids)
    end)
    |> Enum.sum()
  end

  defp count_corporation_kills_in_battle(corporation_id, killmail_ids) do
    KillmailRaw
    |> where([k], k.killmail_id in ^killmail_ids)
    |> where([k], fragment("? @> ?", k.participants, ^[%{corporation_id: corporation_id}]))
    |> where(
      [k],
      fragment("?->'victim'->>'corporation_id' != ?", k.participants, ^to_string(corporation_id))
    )
    |> Repo.aggregate(:count)
  rescue
    error in [Ecto.QueryError, Postgrex.Error] ->
      Logger.error("Database error in count query: #{inspect(error)}")
      0
  end

  defp count_corporation_losses_in_battle(corporation_id, killmail_ids) do
    KillmailRaw
    |> where([k], k.killmail_id in ^killmail_ids)
    |> where(
      [k],
      fragment("?->'victim'->>'corporation_id' = ?", k.participants, ^to_string(corporation_id))
    )
    |> Repo.aggregate(:count)
  rescue
    error in [Ecto.QueryError, Postgrex.Error] ->
      Logger.error("Database error in count query: #{inspect(error)}")
      0
  end

  defp calculate_corporation_isk_destroyed(corporation_id, battles) do
    battles
    |> Enum.map(fn battle ->
      calculate_corporation_isk_destroyed_in_battle(corporation_id, battle.killmail_ids)
    end)
    |> Enum.sum()
  end

  defp calculate_corporation_isk_lost(corporation_id, battles) do
    battles
    |> Enum.map(fn battle ->
      calculate_corporation_isk_lost_in_battle(corporation_id, battle.killmail_ids)
    end)
    |> Enum.sum()
  end

  defp calculate_corporation_isk_destroyed_in_battle(corporation_id, killmail_ids) do
    KillmailRaw
    |> where([k], k.killmail_id in ^killmail_ids)
    |> where([k], fragment("? @> ?", k.participants, ^[%{corporation_id: corporation_id}]))
    |> where(
      [k],
      fragment("?->'victim'->>'corporation_id' != ?", k.participants, ^to_string(corporation_id))
    )
    |> select([k], k.total_value)
    |> Repo.all()
    |> Enum.sum()
  rescue
    error in [Ecto.QueryError, Postgrex.Error] ->
      Logger.error("Database error in sum query: #{inspect(error)}")
      0.0
  end

  defp calculate_corporation_isk_lost_in_battle(corporation_id, killmail_ids) do
    KillmailRaw
    |> where([k], k.killmail_id in ^killmail_ids)
    |> where(
      [k],
      fragment("?->'victim'->>'corporation_id' = ?", k.participants, ^to_string(corporation_id))
    )
    |> select([k], k.total_value)
    |> Repo.all()
    |> Enum.sum()
  rescue
    error in [Ecto.QueryError, Postgrex.Error] ->
      Logger.error("Database error in sum query: #{inspect(error)}")
      0.0
  end

  defp calculate_corporation_efficiency(corporation_id, battles) do
    destroyed = calculate_corporation_isk_destroyed(corporation_id, battles)
    lost = calculate_corporation_isk_lost(corporation_id, battles)

    if destroyed + lost > 0 do
      Float.round(destroyed / (destroyed + lost) * 100, 1)
    else
      0.0
    end
  end
end

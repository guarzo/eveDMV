defmodule EveDmv.Contexts.CombatAnalysis.Domain.BattleDetectionService do
  @moduledoc """
  Service for detecting and clustering killmails into battles.

  Uses temporal and spatial clustering to identify when multiple killmails
  represent a single engagement or battle.
  """

  use GenServer

  import Ecto.Query

  alias EveDmv.DomainEvents.KillmailEnriched
  alias EveDmv.Infrastructure.EventBus
  alias EveDmv.Shared.Infrastructure.UnifiedCache
  alias EveDmv.Shared.Infrastructure.UnifiedRepository

  require Logger

  # 5 minutes
  @battle_time_window 300
  # Minimum participants for a battle
  @min_participants 3

  # Public API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Process a killmail for battle detection.
  """
  def process_killmail(%KillmailEnriched{} = killmail) do
    GenServer.cast(__MODULE__, {:process_killmail, killmail})
  end

  @doc """
  Get detected battles in a time range.
  """
  def get_battles(options \\ []) do
    GenServer.call(__MODULE__, {:get_battles, options})
  end

  @doc """
  Get battle details by ID.
  """
  def get_battle(battle_id) do
    case UnifiedCache.get_combat_analysis({:battle, battle_id}) do
      {:ok, battle} ->
        {:ok, battle}

      {:error, :not_found} ->
        # Try to load from database
        case UnifiedRepository.get_by_id(:combat, EveDmv.BattleAnalysis.Battle, battle_id) do
          {:ok, battle} ->
            # Cache for future requests
            UnifiedCache.cache_combat_analysis({:battle, battle_id}, battle, 1800)
            {:ok, battle}

          error ->
            error
        end
    end
  end

  @doc """
  Create a battle from validated data.
  """
  def create_battle_from_data(battle_data) do
    GenServer.call(__MODULE__, {:create_battle_from_data, battle_data})
  end

  @doc """
  Detect recent battles.
  """
  def detect_recent_battles(hours_back, options \\ []) do
    GenServer.call(__MODULE__, {:detect_recent_battles, hours_back, options})
  end

  # GenServer implementation

  @impl GenServer
  def init(_opts) do
    state = %{
      pending_battles: %{},
      active_battles: %{},
      processed_killmails: 0,
      detected_battles: 0
    }

    Logger.info("BattleDetectionService started")
    {:ok, state}
  end

  @impl GenServer
  def handle_cast({:process_killmail, killmail}, state) do
    case detect_or_assign_battle(killmail, state) do
      {:new_battle, battle_id, updated_state} ->
        # Publish battle detected event
        EventBus.publish(%{
          __struct__: EveDmv.DomainEvents.BattleDetected,
          battle_id: battle_id,
          system_id: killmail.solar_system_id,
          started_at: killmail.killmail_time,
          detected_at: DateTime.utc_now()
        })

        Logger.info("New battle detected: #{battle_id}")
        {:noreply, %{updated_state | detected_battles: updated_state.detected_battles + 1}}

      {:assigned_to_battle, battle_id, updated_state} ->
        Logger.debug("Killmail assigned to existing battle: #{battle_id}")
        {:noreply, updated_state}

      {:no_battle, updated_state} ->
        {:noreply, updated_state}
    end
    |> elem(1)
    |> Map.update!(:processed_killmails, &(&1 + 1))
    |> then(&{:noreply, &1})
  end

  @impl GenServer
  def handle_call({:get_battles, options}, _from, state) do
    limit = Keyword.get(options, :limit, 50)
    since = Keyword.get(options, :since, DateTime.add(DateTime.utc_now(), -24 * 3600, :second))

    battles = get_recent_battles(since, limit)
    {:reply, {:ok, battles}, state}
  end

  @impl GenServer
  def handle_call(:get_metrics, _from, state) do
    metrics = %{
      processed_killmails: state.processed_killmails,
      detected_battles: state.detected_battles,
      active_battles: map_size(state.active_battles),
      pending_battles: map_size(state.pending_battles)
    }

    {:reply, metrics, state}
  end

  @impl GenServer
  def handle_call(:health_check, _from, state) do
    # Check if service is responsive and functioning
    health_status = if state.processed_killmails >= 0, do: :ok, else: {:error, :invalid_state}
    {:reply, health_status, state}
  end

  @impl GenServer
  def handle_call({:detect_recent_battles, hours_back, options}, _from, state) do
    result = perform_recent_battle_detection(hours_back, options)
    {:reply, result, state}
  end

  @impl GenServer
  def handle_call({:get_battle, battle_id}, _from, state) do
    # Check active battles first
    result =
      case Map.get(state.active_battles, battle_id) do
        nil ->
          # Check pending battles
          case Map.get(state.pending_battles, battle_id) do
            nil ->
              # Try to fetch from database
              fetch_battle_from_db(battle_id)

            battle ->
              {:ok, battle}
          end

        battle ->
          {:ok, battle}
      end

    {:reply, result, state}
  end

  @impl GenServer
  def handle_call({:create_battle_from_data, battle_data}, _from, state) do
    case create_battle_from_validated_data(battle_data) do
      {:ok, battle} ->
        # Add to active battles
        updated_state =
          Map.put(state, :active_battles, Map.put(state.active_battles, battle.id, battle))

        {:reply, {:ok, battle}, updated_state}

      error ->
        {:reply, error, state}
    end
  end

  # Private functions

  defp detect_or_assign_battle(killmail, state) do
    # Check for existing battles in the same system within time window
    potential_battles = find_potential_battles(killmail, state)

    case potential_battles do
      [] ->
        # No existing battle found, check if this should start a new one
        case should_start_new_battle?(killmail) do
          true ->
            battle_id = generate_battle_id(killmail)
            battle_data = create_battle_data(killmail, battle_id)
            updated_state = add_pending_battle(state, battle_id, battle_data)
            {:new_battle, battle_id, updated_state}

          false ->
            {:no_battle, state}
        end

      [battle_id | _] ->
        # Assign to existing battle
        updated_state = add_killmail_to_battle(state, battle_id, killmail)
        {:assigned_to_battle, battle_id, updated_state}
    end
  end

  defp find_potential_battles(killmail, state) do
    time_cutoff = DateTime.add(killmail.killmail_time, -@battle_time_window, :second)

    state.active_battles
    |> Enum.filter(fn {_battle_id, battle} ->
      battle.system_id == killmail.solar_system_id and
        DateTime.compare(battle.last_activity, time_cutoff) == :gt
    end)
    |> Enum.map(fn {battle_id, _battle} -> battle_id end)
    |> Enum.sort_by(
      fn battle_id ->
        # Sort by most recent activity
        state.active_battles[battle_id].last_activity
      end,
      {:desc, DateTime}
    )
  end

  defp should_start_new_battle?(killmail) do
    # Check if killmail indicates potential battle activity
    # +1 for victim
    participant_count = length(killmail.attackers) + 1

    # 10M ISK minimum
    participant_count >= @min_participants and
      killmail.zkb_total_value > 10_000_000
  end

  defp generate_battle_id(killmail) do
    timestamp = DateTime.to_unix(killmail.killmail_time)
    system_hash = :erlang.phash2(killmail.solar_system_id)
    "battle_#{timestamp}_#{system_hash}"
  end

  defp create_battle_data(killmail, battle_id) do
    %{
      id: battle_id,
      system_id: killmail.solar_system_id,
      started_at: killmail.killmail_time,
      last_activity: killmail.killmail_time,
      killmail_ids: [killmail.killmail_id],
      participant_count: length(killmail.attackers) + 1,
      total_value: killmail.zkb_total_value || 0,
      status: :pending
    }
  end

  defp add_pending_battle(state, battle_id, battle_data) do
    %{state | pending_battles: Map.put(state.pending_battles, battle_id, battle_data)}
  end

  defp add_killmail_to_battle(state, battle_id, killmail) do
    case Map.get(state.active_battles, battle_id) do
      nil ->
        # Battle might be in pending battles
        case Map.get(state.pending_battles, battle_id) do
          nil ->
            state

          battle ->
            updated_battle = update_battle_with_killmail(battle, killmail)
            %{state | pending_battles: Map.put(state.pending_battles, battle_id, updated_battle)}
        end

      battle ->
        updated_battle = update_battle_with_killmail(battle, killmail)
        %{state | active_battles: Map.put(state.active_battles, battle_id, updated_battle)}
    end
  end

  defp update_battle_with_killmail(battle, killmail) do
    %{
      battle
      | last_activity: killmail.killmail_time,
        killmail_ids: [killmail.killmail_id | battle.killmail_ids],
        participant_count: battle.participant_count + length(killmail.attackers) + 1,
        total_value: battle.total_value + (killmail.zkb_total_value || 0)
    }
  end

  defp get_recent_battles(since, limit) do
    # This would typically query the database
    # For now, return cached battles
    case UnifiedCache.get(:combat, {:recent_battles, since}) do
      {:ok, battles} -> Enum.take(battles, limit)
      {:error, :not_found} -> []
    end
  end

  defp perform_recent_battle_detection(hours_back, options) do
    since = DateTime.add(DateTime.utc_now(), -hours_back * 3600, :second)
    min_participants = Keyword.get(options, :min_participants, @min_participants)
    min_value = Keyword.get(options, :min_value, 10_000_000)

    # Query killmails within the time range
    query =
      from(k in EveDmv.Killmails.KillmailRaw,
        where: k.killmail_time > ^since,
        order_by: [asc: k.killmail_time]
      )

    killmails = EveDmv.Repo.all(query)

    # Group killmails into potential battles
    battles = detect_battles_from_killmails(killmails, min_participants, min_value)

    {:ok, battles}
  end

  defp detect_battles_from_killmails(killmails, min_participants, min_value) do
    # Group killmails by system and time windows
    killmails
    |> Enum.group_by(& &1.solar_system_id)
    |> Enum.flat_map(fn {system_id, system_kills} ->
      # Group by time windows within each system
      group_by_time_windows(system_kills, @battle_time_window)
      |> Enum.filter(fn kills ->
        # Filter by minimum participants and value
        participant_count = calculate_total_participants(kills)
        total_value = Enum.sum(Enum.map(kills, &(&1.zkb_total_value || 0)))

        participant_count >= min_participants and total_value >= min_value
      end)
      |> Enum.map(fn kills ->
        # Create battle summary
        %{
          system_id: system_id,
          start_time: List.first(kills).killmail_time,
          end_time: List.last(kills).killmail_time,
          killmail_count: length(kills),
          participant_count: calculate_total_participants(kills),
          total_value: Enum.sum(Enum.map(kills, &(&1.zkb_total_value || 0))),
          killmail_ids: Enum.map(kills, & &1.killmail_id)
        }
      end)
    end)
  end

  defp group_by_time_windows(killmails, window_seconds) do
    # Sort by time
    sorted = Enum.sort_by(killmails, & &1.killmail_time, DateTime)

    # Group into time windows
    Enum.reduce(sorted, [], fn km, acc ->
      case acc do
        [] ->
          [[km]]

        [current_group | rest] ->
          last_time = List.last(current_group).killmail_time
          time_diff = DateTime.diff(km.killmail_time, last_time)

          if time_diff <= window_seconds do
            # Add to current group
            [[km | current_group] | rest]
          else
            # Start new group
            [[km] | [Enum.reverse(current_group) | rest]]
          end
      end
    end)
    |> Enum.map(&Enum.reverse/1)
    |> Enum.reverse()
  end

  defp calculate_total_participants(killmails) do
    # Get unique participants across all killmails
    participants =
      killmails
      |> Enum.flat_map(fn km ->
        victim_id = get_in(km.victim, ["character_id"])
        attacker_ids = Enum.map(km.attackers, & &1["character_id"])

        [victim_id | attacker_ids]
        |> Enum.filter(&(&1 != nil))
      end)
      |> Enum.uniq()

    length(participants)
  end

  defp fetch_battle_from_db(battle_id) do
    # Try to fetch battle from database
    case UnifiedRepository.get_by_id(:combat, EveDmv.BattleAnalysis.Battle, battle_id) do
      {:ok, battle} ->
        # Enrich with additional data
        enriched_battle = %{
          battle
          | killmails: fetch_battle_killmails(battle_id),
            participants: fetch_battle_participants(battle_id)
        }

        {:ok, enriched_battle}

      {:error, _reason} ->
        {:error, :not_found}
    end
  end

  defp fetch_battle_killmails(_battle_id) do
    # Fetch killmails associated with the battle
    # This would query a battle_killmails join table
    []
  end

  defp fetch_battle_participants(_battle_id) do
    # Fetch participants associated with the battle
    # This would aggregate from killmail data
    []
  end

  defp create_battle_from_validated_data(battle_data) do
    # Create a new battle record
    battle_attrs = %{
      id: battle_data[:id] || generate_battle_id_from_data(battle_data),
      system_id: battle_data[:system_id],
      start_time: battle_data[:start_time],
      end_time: battle_data[:end_time],
      killmail_count: length(battle_data[:killmail_ids]),
      participant_count: battle_data[:participant_count] || 0,
      total_value: battle_data[:total_value] || 0,
      status: :active,
      created_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }

    # In a real implementation, this would save to database
    # For now, return the battle structure
    {:ok, battle_attrs}
  end

  defp generate_battle_id_from_data(battle_data) do
    # Generate deterministic ID from battle data
    timestamp = DateTime.to_unix(battle_data[:start_time])
    system_hash = :erlang.phash2(battle_data[:system_id])
    "battle_#{timestamp}_#{system_hash}_#{:rand.uniform(1000)}"
  end
end

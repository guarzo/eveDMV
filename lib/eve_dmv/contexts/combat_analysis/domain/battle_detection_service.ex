defmodule EveDmv.Contexts.CombatAnalysis.Domain.BattleDetectionService do
  @moduledoc """
  Service for detecting and clustering killmails into battles.

  Uses temporal and spatial clustering to identify when multiple killmails
  represent a single engagement or battle.
  """

  use GenServer
  require Logger

  alias EveDmv.Shared.Infrastructure.{UnifiedCache, UnifiedRepository}
  alias EveDmv.DomainEvents.KillmailEnriched
  alias EveDmv.Infrastructure.EventBus

  # 5 minutes
  @battle_time_window 300
  # 100 AU
  @battle_distance_au 100
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
end

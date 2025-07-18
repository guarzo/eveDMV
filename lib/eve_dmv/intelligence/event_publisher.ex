defmodule EveDmv.Intelligence.EventPublisher do
  @moduledoc """
  Publisher for intelligence-related domain events.

  This module provides a centralized way to publish intelligence events
  to the EventBus for real-time updates across the application.

  Events are published asynchronously to avoid blocking intelligence
  analysis operations.
  """

  use GenServer
  require Logger

  alias EveDmv.Infrastructure.EventBus
  alias EveDmv.Intelligence.Events

  # Publishing configuration
  # Publish batched events every 1 second
  @batch_publish_interval 1000
  # Maximum events per batch
  @max_batch_size 50

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Publish a threat level update event.

  This is called when character threat scoring detects a significant change.
  """
  def publish_threat_update(character_id, new_level, previous_level, opts \\ []) do
    event = %Events.ThreatLevelUpdated{
      character_id: character_id,
      new_threat_level: new_level,
      previous_threat_level: previous_level,
      updated_at: DateTime.utc_now(),
      analysis_factors: opts[:analysis_factors] || [],
      system_id: opts[:system_id],
      confidence_score: opts[:confidence_score] || 0.5
    }

    publish_async(event)
  end

  @doc """
  Publish a battle detection event.

  Called when the battle detection system identifies a new engagement.
  """
  def publish_battle_detected(battle_id, system_id, participant_count, opts \\ []) do
    event = %Events.BattleDetected{
      battle_id: battle_id,
      system_id: system_id,
      detected_at: DateTime.utc_now(),
      participant_count: participant_count,
      estimated_scale: classify_battle_scale(participant_count),
      involved_alliances: opts[:involved_alliances] || [],
      isk_destroyed: opts[:isk_destroyed] || 0,
      battle_status: opts[:battle_status] || :developing
    }

    publish_async(event)
  end

  @doc """
  Publish an intelligence alert for high-priority situations.
  """
  def publish_intelligence_alert(alert_type, priority, title, description, opts \\ []) do
    alert_id = generate_alert_id()

    event = %Events.IntelligenceAlert{
      alert_id: alert_id,
      alert_type: alert_type,
      priority: priority,
      created_at: DateTime.utc_now(),
      expires_at: opts[:expires_at],
      title: title,
      description: description,
      related_character_ids: opts[:related_character_ids] || [],
      related_system_ids: opts[:related_system_ids] || [],
      action_required: opts[:action_required],
      data: opts[:data] || %{}
    }

    # High priority alerts are published immediately
    if priority in [:high, :critical] do
      publish_immediately(event)
    else
      publish_async(event)
    end
  end

  @doc """
  Publish character analysis update event.
  """
  def publish_character_analysis_update(character_id, analysis_type, new_data, opts \\ []) do
    event = %Events.CharacterAnalysisUpdated{
      character_id: character_id,
      updated_at: DateTime.utc_now(),
      analysis_type: analysis_type,
      previous_data: opts[:previous_data],
      new_data: new_data,
      significant_changes: opts[:significant_changes] || [],
      confidence_level: opts[:confidence_level] || 0.7
    }

    publish_async(event)
  end

  @doc """
  Publish system activity spike detection.
  """
  def publish_activity_spike(system_id, activity_level, baseline_level, activity_type, opts \\ []) do
    spike_magnitude = if baseline_level > 0, do: activity_level / baseline_level, else: 10.0

    event = %Events.SystemActivitySpikeDetected{
      system_id: system_id,
      detected_at: DateTime.utc_now(),
      activity_level: activity_level,
      baseline_level: baseline_level,
      spike_magnitude: spike_magnitude,
      activity_type: activity_type,
      duration_minutes: opts[:duration_minutes] || 0,
      related_events: opts[:related_events] || []
    }

    # Significant spikes are published immediately
    if spike_magnitude >= 5.0 do
      publish_immediately(event)
    else
      publish_async(event)
    end
  end

  @doc """
  Publish chain intelligence update for wormhole space.
  """
  def publish_chain_update(chain_id, update_type, opts \\ []) do
    event = %Events.ChainIntelligenceUpdate{
      chain_id: chain_id,
      updated_at: DateTime.utc_now(),
      update_type: update_type,
      system_changes: opts[:system_changes] || [],
      threat_changes: opts[:threat_changes] || [],
      new_signatures: opts[:new_signatures] || [],
      pilot_movements: opts[:pilot_movements] || []
    }

    publish_async(event)
  end

  @doc """
  Publish vetting result update.
  """
  def publish_vetting_update(character_id, vetting_result, opts \\ []) do
    event = %Events.VettingResultUpdated{
      character_id: character_id,
      vetting_result: vetting_result,
      updated_at: DateTime.utc_now(),
      previous_result: opts[:previous_result],
      vetting_factors: opts[:vetting_factors] || [],
      reviewer_notes: opts[:reviewer_notes],
      confidence_score: opts[:confidence_score] || 0.8,
      expires_at: opts[:expires_at]
    }

    publish_async(event)
  end

  @doc """
  Publish fleet composition analysis results.
  """
  def publish_fleet_analysis(fleet_id, system_id, composition_type, opts \\ []) do
    event = %Events.FleetCompositionAnalyzed{
      fleet_id: fleet_id,
      system_id: system_id,
      analyzed_at: DateTime.utc_now(),
      composition_type: composition_type,
      doctrine_match: opts[:doctrine_match],
      effectiveness_rating: opts[:effectiveness_rating],
      threat_assessment: opts[:threat_assessment],
      recommendations: opts[:recommendations] || [],
      participant_count: opts[:participant_count] || 0,
      estimated_capabilities: opts[:estimated_capabilities] || %{}
    }

    publish_async(event)
  end

  @doc """
  Get publishing statistics for monitoring.
  """
  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  # Private API

  defp publish_async(event) do
    GenServer.cast(__MODULE__, {:publish_async, event})
  end

  defp publish_immediately(event) do
    Task.Supervisor.start_child(EveDmv.TaskSupervisor, fn ->
      EventBus.publish(event)
    end)
  end

  defp classify_battle_scale(participant_count) do
    cond do
      participant_count <= 10 -> :small_gang
      participant_count <= 50 -> :medium_fleet
      participant_count <= 150 -> :large_fleet
      true -> :capital_engagement
    end
  end

  defp generate_alert_id do
    "alert_#{:erlang.unique_integer([:positive])}_#{DateTime.utc_now() |> DateTime.to_unix()}"
  end

  # GenServer implementation

  @impl GenServer
  def init(_opts) do
    # Schedule periodic batch publishing
    schedule_batch_publish()

    state = %{
      pending_events: [],
      stats: %{
        events_published: 0,
        events_batched: 0,
        batch_publishes: 0,
        immediate_publishes: 0,
        publish_failures: 0
      }
    }

    Logger.info("Intelligence EventPublisher started")
    {:ok, state}
  end

  @impl GenServer
  def handle_cast({:publish_async, event}, state) do
    new_pending = [event | state.pending_events]

    # If batch is full, publish immediately
    if length(new_pending) >= @max_batch_size do
      publish_batch(new_pending)

      new_stats = %{
        state.stats
        | events_batched: state.stats.events_batched + length(new_pending),
          batch_publishes: state.stats.batch_publishes + 1
      }

      {:noreply, %{state | pending_events: [], stats: new_stats}}
    else
      new_stats = %{state.stats | events_batched: state.stats.events_batched + 1}
      {:noreply, %{state | pending_events: new_pending, stats: new_stats}}
    end
  end

  @impl GenServer
  def handle_call(:get_stats, _from, state) do
    {:reply, state.stats, state}
  end

  @impl GenServer
  def handle_info(:publish_batch, state) do
    if not Enum.empty?(state.pending_events) do
      publish_batch(state.pending_events)

      new_stats = %{
        state.stats
        | events_published: state.stats.events_published + length(state.pending_events),
          batch_publishes: state.stats.batch_publishes + 1
      }

      schedule_batch_publish()
      {:noreply, %{state | pending_events: [], stats: new_stats}}
    else
      schedule_batch_publish()
      {:noreply, state}
    end
  end

  @impl GenServer
  def handle_info(msg, state) do
    Logger.debug("Intelligence EventPublisher received unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  # Private functions

  defp schedule_batch_publish do
    Process.send_after(self(), :publish_batch, @batch_publish_interval)
  end

  defp publish_batch(events) do
    Task.Supervisor.start_child(EveDmv.TaskSupervisor, fn ->
      Enum.each(events, fn event ->
        case EventBus.publish(event) do
          :ok ->
            :ok

          {:error, reason} ->
            Logger.error("Failed to publish intelligence event", %{
              event_type: event.__struct__,
              error: inspect(reason)
            })
        end
      end)
    end)
  end
end

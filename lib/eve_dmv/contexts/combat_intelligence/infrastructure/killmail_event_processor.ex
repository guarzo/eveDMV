defmodule EveDmv.Contexts.CombatIntelligence.Infrastructure.KillmailEventProcessor do
  @moduledoc """
  Processes enriched killmail events for combat intelligence analysis.

  This module handles the processing of killmail events that have been enriched
  with additional data, preparing them for various combat intelligence operations
  including battle detection, participant analysis, and strategic assessment.
  """
  """

  use GenServer

  alias EveDmv.Contexts.BattleAnalysis.Core.BattleDetector
  alias EveDmv.Infrastructure.EventBus

  require Logger

  # Processing configuration
  @batch_size 10
  # 1 second
  @processing_interval 1000

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Process a killmail event for combat intelligence analysis.

  This is the main entry point for processing enriched killmail events.
  """
  def process_killmail_event(killmail_event) do
    GenServer.cast(__MODULE__, {:process_killmail_event, killmail_event})
  end

  @doc """
  Process multiple killmail events in a batch for efficiency.
  """
  def process_killmail_batch(killmail_events) when is_list(killmail_events) do
    GenServer.cast(__MODULE__, {:process_killmail_batch, killmail_events})
  end

  @doc """
  Get processing statistics and metrics.
  """
  def get_processing_stats do
    GenServer.call(__MODULE__, :get_processing_stats)
  end

  @doc """
  Flush any pending events in the processing queue.
  """
  def flush_processing_queue do
    GenServer.call(__MODULE__, :flush_processing_queue)
  end

  # GenServer callbacks

  @impl GenServer
  def init(_opts) do
    state = %{
      processing_queue: [],
      processed_count: 0,
      error_count: 0,
      last_processed: nil,
      batch_metrics: %{
        total_batches: 0,
        avg_batch_size: 0,
        last_batch_time: nil
      }
    }

    # Schedule periodic batch processing
    schedule_batch_processing()

    Logger.info("KillmailEventProcessor started")
    {:ok, state}
  end

  @impl GenServer
  def handle_cast({:process_killmail_event, killmail_event}, state) do
    # Add to processing queue
    new_queue = [killmail_event | state.processing_queue]

    # If queue is full, process immediately
    if length(new_queue) >= @batch_size do
      {processed_state, _results} = process_queue_batch(new_queue, state)
      new_state = %{processed_state | processing_queue: []}
      {:noreply, new_state}
    else
      new_state = %{state | processing_queue: new_queue}
      {:noreply, new_state}
    end
  end

  @impl GenServer
  def handle_cast({:process_killmail_batch, killmail_events}, state) do
    # Process batch immediately
    {new_state, _results} = process_queue_batch(killmail_events, state)
    {:noreply, new_state}
  end

  @impl GenServer
  def handle_call(:get_processing_stats, _from, state) do
    stats = %{
      queue_size: length(state.processing_queue),
      processed_count: state.processed_count,
      error_count: state.error_count,
      last_processed: state.last_processed,
      batch_metrics: state.batch_metrics,
      uptime_seconds: get_uptime_seconds()
    }

    {:reply, stats, state}
  end

  @impl GenServer
  def handle_call(:flush_processing_queue, _from, state) do
    if length(state.processing_queue) > 0 do
      {new_state, results} = process_queue_batch(state.processing_queue, state)
      final_state = %{new_state | processing_queue: []}
      {:reply, {:ok, length(results)}, final_state}
    else
      {:reply, {:ok, 0}, state}
    end
  end

  @impl GenServer
  def handle_info(:process_batch, state) do
    # Process any queued events
    if length(state.processing_queue) > 0 do
      {new_state, _results} = process_queue_batch(state.processing_queue, state)
      final_state = %{new_state | processing_queue: []}
      schedule_batch_processing()
      {:noreply, final_state}
    else
      schedule_batch_processing()
      {:noreply, state}
    end
  end

  # Private functions

  defp process_queue_batch(killmail_events, state) do
    start_time = System.monotonic_time(:millisecond)

    # Process each killmail event
    results =
      Enum.map(killmail_events, fn event ->
        try do
          result = process_single_killmail(event)
          {:ok, result}
        rescue
          error ->
            Logger.error("Error processing killmail event",
              error: inspect(error),
              killmail_id: extract_killmail_id(event)
            )

            {:error, error}
        end
      end)

    # Separate successful and failed results
    {successes, errors} =
      Enum.split_with(results, fn
        {:ok, _} -> true
        {:error, _} -> false
      end)

    # Update processing metrics
    processing_time = System.monotonic_time(:millisecond) - start_time

    new_batch_metrics =
      update_batch_metrics(
        state.batch_metrics,
        length(killmail_events),
        processing_time
      )

    new_state = %{
      state
      | processed_count: state.processed_count + length(successes),
        error_count: state.error_count + length(errors),
        last_processed: DateTime.utc_now(),
        batch_metrics: new_batch_metrics
    }

    {new_state, results}
  end

  defp process_single_killmail(killmail_event) do
    # Extract killmail data
    killmail_data = extract_killmail_data(killmail_event)

    # Perform combat intelligence analysis
    analysis_result = perform_combat_analysis(killmail_data)

    # Publish analysis results as domain events
    publish_analysis_events(analysis_result, killmail_data)

    analysis_result
  end

  defp extract_killmail_data(killmail_event) do
    %{
      killmail_id: extract_killmail_id(killmail_event),
      solar_system_id: killmail_event[:solar_system_id] || killmail_event["solar_system_id"],
      killmail_time: killmail_event[:killmail_time] || killmail_event["killmail_time"],
      victim: extract_victim_data(killmail_event),
      attackers: extract_attackers_data(killmail_event),
      total_value: killmail_event[:zkb_total_value] || killmail_event["zkb_total_value"] || 0,
      raw_data: killmail_event
    }
  end

  defp extract_killmail_id(killmail_event) do
    killmail_event[:killmail_id] ||
      killmail_event["killmail_id"] ||
      killmail_event[:id] ||
      killmail_event["id"] ||
      "unknown"
  end

  defp extract_victim_data(killmail_event) do
    victim = killmail_event[:victim] || killmail_event["victim"] || %{}

    %{
      character_id: victim[:character_id] || victim["character_id"],
      corporation_id: victim[:corporation_id] || victim["corporation_id"],
      alliance_id: victim[:alliance_id] || victim["alliance_id"],
      ship_type_id: victim[:ship_type_id] || victim["ship_type_id"]
    }
  end

  defp extract_attackers_data(killmail_event) do
    attackers = killmail_event[:attackers] || killmail_event["attackers"] || []

    Enum.map(attackers, fn attacker ->
      %{
        character_id: attacker[:character_id] || attacker["character_id"],
        corporation_id: attacker[:corporation_id] || attacker["corporation_id"],
        alliance_id: attacker[:alliance_id] || attacker["alliance_id"],
        ship_type_id: attacker[:ship_type_id] || attacker["ship_type_id"],
        damage_done: attacker[:damage_done] || attacker["damage_done"] || 0,
        final_blow: attacker[:final_blow] || attacker["final_blow"] || false
      }
    end)
  end

  defp perform_combat_analysis(killmail_data) do
    # Initialize analysis result
    analysis = %{
      killmail_id: killmail_data.killmail_id,
      timestamp: DateTime.utc_now(),
      analysis_type: :combat_intelligence,
      components: %{}
    }

    # Battle detection analysis
    battle_analysis = analyze_battle_context(killmail_data)

    # Participant analysis
    participant_analysis = analyze_participants(killmail_data)

    # Fleet composition analysis (simplified)
    fleet_analysis = analyze_fleet_composition(killmail_data)

    # Tactical pattern analysis
    tactical_analysis = analyze_tactical_patterns(killmail_data)

    %{
      analysis
      | components: %{
          battle_detection: battle_analysis,
          participant_analysis: participant_analysis,
          fleet_composition: fleet_analysis,
          tactical_patterns: tactical_analysis
        }
    }
  end

  defp analyze_battle_context(killmail_data) do
    # Use battle detector if available
    case BattleDetector.detect_battle_from_killmail(killmail_data) do
      {:ok, battle_info} ->
        %{
          status: :battle_detected,
          battle_id: battle_info.battle_id,
          participants: battle_info.participant_count,
          estimated_duration: battle_info.duration_estimate
        }

      {:error, :no_battle} ->
        %{
          status: :isolated_kill,
          participants: length(killmail_data.attackers) + 1
        }

      {:error, reason} ->
        Logger.warning("Battle detection failed", reason: reason)
        %{status: :analysis_failed, reason: reason}
    end
  rescue
    _error ->
      %{status: :analysis_error, participants: length(killmail_data.attackers) + 1}
  end

  defp analyze_participants(killmail_data) do
    # Use participant analyzer if available
    all_participants = [killmail_data.victim | killmail_data.attackers]

    %{
      total_participants: length(all_participants),
      unique_corporations: count_unique_entities(all_participants, :corporation_id),
      unique_alliances: count_unique_entities(all_participants, :alliance_id),
      ship_types: count_ship_types(all_participants),
      final_blow_pilot: find_final_blow_pilot(killmail_data.attackers)
    }
  end

  defp analyze_fleet_composition(killmail_data) do
    attackers = killmail_data.attackers

    %{
      fleet_size: length(attackers),
      ship_diversity: count_unique_entities(attackers, :ship_type_id),
      composition_type: classify_fleet_composition(attackers),
      estimated_fleet_value: estimate_fleet_value(attackers)
    }
  end

  defp analyze_tactical_patterns(killmail_data) do
    %{
      engagement_type: classify_engagement_type(killmail_data),
      system_type: classify_system_type(killmail_data.solar_system_id),
      kill_value_category: classify_kill_value(killmail_data.total_value),
      time_of_day: classify_time_of_day(killmail_data.killmail_time)
    }
  end

  defp count_unique_entities(participants, field) do
    participants
    |> Enum.map(&Map.get(&1, field))
    |> Enum.filter(&(&1 != nil))
    |> Enum.uniq()
    |> length()
  end

  defp count_ship_types(participants) do
    participants
    |> Enum.map(&Map.get(&1, :ship_type_id))
    |> Enum.filter(&(&1 != nil))
    |> Enum.frequencies()
  end

  defp find_final_blow_pilot(attackers) do
    case Enum.find(attackers, &(&1.final_blow == true)) do
      nil -> nil
      pilot -> pilot.character_id
    end
  end

  defp classify_fleet_composition(attackers) when length(attackers) <= 3, do: :small_gang
  defp classify_fleet_composition(attackers) when length(attackers) <= 10, do: :medium_gang
  defp classify_fleet_composition(attackers) when length(attackers) <= 30, do: :large_gang
  defp classify_fleet_composition(_attackers), do: :fleet_engagement

  defp estimate_fleet_value(attackers) do
    # Simplified fleet value estimation
    # Rough 50M ISK per ship estimate
    length(attackers) * 50_000_000
  end

  defp classify_engagement_type(killmail_data) do
    attacker_count = length(killmail_data.attackers)

    cond do
      attacker_count == 1 -> :solo_kill
      attacker_count <= 5 -> :small_gang
      attacker_count <= 20 -> :medium_fleet
      true -> :large_fleet
    end
  end

  defp classify_system_type(system_id) when is_integer(system_id) do
    cond do
      system_id >= 31_000_000 -> :wormhole
      system_id >= 30_000_000 -> :null_sec
      true -> :known_space
    end
  end

  defp classify_system_type(_), do: :unknown

  defp classify_kill_value(value) when is_number(value) do
    cond do
      # 10B+
      value >= 10_000_000_000 -> :super_capital
      # 1B+
      value >= 1_000_000_000 -> :capital
      # 100M+
      value >= 100_000_000 -> :high_value
      # 10M+
      value >= 10_000_000 -> :medium_value
      true -> :low_value
    end
  end

  defp classify_kill_value(_), do: :unknown_value

  defp classify_time_of_day(killmail_time) when is_binary(killmail_time) do
    case DateTime.from_iso8601(killmail_time) do
      {:ok, dt, _} -> classify_time_of_day(dt)
      _ -> :unknown_time
    end
  end

  defp classify_time_of_day(%DateTime{} = dt) do
    hour = dt.hour

    cond do
      hour >= 6 and hour < 12 -> :morning
      hour >= 12 and hour < 18 -> :afternoon
      hour >= 18 and hour < 22 -> :evening
      true -> :night
    end
  end

  defp classify_time_of_day(_), do: :unknown_time

  defp publish_analysis_events(analysis_result, killmail_data) do
    # Publish combat intelligence analysis event
    event = %{
      event_type: :combat_intelligence_analysis_completed,
      killmail_id: killmail_data.killmail_id,
      analysis: analysis_result,
      timestamp: DateTime.utc_now()
    }

    EventBus.publish(:combat_intelligence, event)

    # Publish specific events based on analysis results
    if analysis_result.components.battle_detection.status == :battle_detected do
      battle_event = %{
        event_type: :battle_detected,
        killmail_id: killmail_data.killmail_id,
        battle_info: analysis_result.components.battle_detection,
        timestamp: DateTime.utc_now()
      }

      EventBus.publish(:battle_analysis, battle_event)
    end
  end

  defp update_batch_metrics(current_metrics, batch_size, processing_time) do
    total_batches = current_metrics.total_batches + 1
    current_avg = current_metrics.avg_batch_size

    # Calculate new running average
    new_avg = (current_avg * (total_batches - 1) + batch_size) / total_batches

    %{
      total_batches: total_batches,
      avg_batch_size: Float.round(new_avg, 2),
      last_batch_time: processing_time,
      last_processed: DateTime.utc_now()
    }
  end

  defp schedule_batch_processing do
    Process.send_after(self(), :process_batch, @processing_interval)
  end

  defp get_uptime_seconds do
    # Simple uptime calculation - in real implementation would track start time
    :erlang.system_time(:second) - :erlang.system_info(:start_time)
  end
end

defmodule EveDmv.Contexts.Surveillance.Infrastructure.KillmailEventProcessor do
  @moduledoc """
  Event processor for handling killmail events in the surveillance context.

  Receives killmail events and coordinates the surveillance matching process,
  ensuring proper transformation and validation before processing.
  """

  use GenServer
  use EveDmv.ErrorHandler
  alias EveDmv.Contexts.Surveillance.Domain.MatchingEngine
  alias EveDmv.DomainEvents.KillmailEnriched
  alias EveDmv.DomainEvents.KillmailReceived
  alias EveDmv.Infrastructure.EventBus

  require Logger

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # Public API

  @doc """
  Process a killmail for surveillance matching.

  This is called by the Surveillance context when a killmail event is received.
  """
  def process_killmail_for_surveillance(killmail_event) do
    GenServer.cast(__MODULE__, {:process_killmail, killmail_event})
  end

  @doc """
  Get processing metrics and statistics.
  """
  def get_processing_metrics do
    GenServer.call(__MODULE__, :get_processing_metrics)
  end

  @doc """
  Get current processing status.
  """
  def get_processing_status do
    GenServer.call(__MODULE__, :get_processing_status)
  end

  # GenServer implementation

  @impl GenServer
  def init(_opts) do
    # Subscribe to killmail events from the event bus
    EventBus.subscribe_process(:killmail_received, self())
    EventBus.subscribe_process(:killmail_enriched, self())

    state = %{
      processing_metrics: %{
        total_processed: 0,
        successful_matches: 0,
        failed_processing: 0,
        average_processing_time_ms: 0,
        last_processed_at: nil
      },
      processing_queue: [],
      processing_status: :ready,
      # Keep last 100 processing times for averaging
      recent_processing_times: []
    }

    Logger.info("KillmailEventProcessor started and subscribed to killmail events")
    {:ok, state}
  end

  @impl GenServer
  def handle_cast({:process_killmail, killmail_event}, state) do
    start_time = System.monotonic_time(:millisecond)

    # Transform event to surveillance-compatible format
    case transform_killmail_event(killmail_event) do
      {:ok, surveillance_killmail} ->
        # Send to matching engine
        MatchingEngine.process_killmail(surveillance_killmail)

        # Update metrics for successful processing
        end_time = System.monotonic_time(:millisecond)
        processing_time = end_time - start_time

        new_metrics = update_success_metrics(state.processing_metrics, processing_time)
        new_processing_times = [processing_time | Enum.take(state.recent_processing_times, 99)]

        new_state = %{
          state
          | processing_metrics: new_metrics,
            recent_processing_times: new_processing_times
        }

        {:noreply, new_state}

      {:error, reason} ->
        Logger.warning("Failed to transform killmail event for surveillance: #{inspect(reason)}")

        # Update metrics for failed processing
        new_metrics = %{
          state.processing_metrics
          | failed_processing: state.processing_metrics.failed_processing + 1,
            total_processed: state.processing_metrics.total_processed + 1,
            last_processed_at: DateTime.utc_now()
        }

        new_state = %{state | processing_metrics: new_metrics}

        {:noreply, new_state}
    end
  end

  @impl GenServer
  def handle_call(:get_processing_metrics, _from, state) do
    # Calculate current average processing time
    current_avg =
      case state.recent_processing_times do
        [] -> 0
        times -> Enum.sum(times) / length(times)
      end

    metrics = %{
      state.processing_metrics
      | average_processing_time_ms: Float.round(current_avg, 2)
    }

    {:reply, {:ok, metrics}, state}
  end

  @impl GenServer
  def handle_call(:get_processing_status, _from, state) do
    status_info = %{
      status: state.processing_status,
      queue_size: length(state.processing_queue),
      recent_activity: state.processing_metrics.last_processed_at != nil,
      uptime_seconds: get_uptime_seconds()
    }

    {:reply, {:ok, status_info}, state}
  end

  @impl GenServer
  def handle_info({:event, %KillmailReceived{} = event}, state) do
    # Process killmail received event
    handle_cast({:process_killmail, event}, state)
  end

  @impl GenServer
  def handle_info({:event, %KillmailEnriched{} = event}, state) do
    # We can also process enriched killmails for more detailed matching
    # Convert enriched event to received format for consistency
    received_event = %KillmailReceived{
      killmail_id: event.killmail_id,
      # Not available in enriched event
      hash: "",
      occurred_at: event.timestamp || DateTime.utc_now(),
      received_at: DateTime.utc_now()
    }

    handle_cast({:process_killmail, received_event}, state)
  end

  @impl GenServer
  def handle_info(_message, state) do
    # Ignore other messages
    {:noreply, state}
  end

  # Private transformation functions

  defp transform_killmail_event(%KillmailReceived{} = event) do
    # Transform KillmailReceived event to surveillance-compatible format
    case parse_killmail_data(event.raw_data) do
      {:ok, parsed_data} ->
        surveillance_killmail = %{
          killmail_id: event.killmail_id,
          killmail_time: event.killmail_time,
          solar_system_id: event.solar_system_id,
          zkb_total_value: event.zkb_total_value,
          victim: extract_victim_data(parsed_data, event),
          attackers: extract_attackers_data(parsed_data),
          timestamp: event.timestamp,
          raw_data: event.raw_data
        }

        {:ok, surveillance_killmail}

      {:error, reason} ->
        {:error, {:parse_failed, reason}}
    end
  end

  defp transform_killmail_event(event) do
    Logger.warning("Received unknown killmail event type: #{inspect(event.__struct__)}")
    {:error, :unknown_event_type}
  end

  defp parse_killmail_data(raw_data) when is_map(raw_data) do
    # Raw data is already parsed JSON
    {:ok, raw_data}
  end

  defp parse_killmail_data(raw_data) when is_binary(raw_data) do
    # Raw data is JSON string
    case Jason.decode(raw_data) do
      {:ok, parsed} -> {:ok, parsed}
      {:error, reason} -> {:error, {:json_decode_failed, reason}}
    end
  end

  defp parse_killmail_data(_raw_data) do
    {:error, :invalid_raw_data_format}
  end

  defp extract_victim_data(parsed_data, event) do
    victim_data = parsed_data["victim"] || %{}

    %{
      character_id: get_safe_integer(victim_data["character_id"]) || event.character_id,
      corporation_id: get_safe_integer(victim_data["corporation_id"]) || event.corporation_id,
      alliance_id: get_safe_integer(victim_data["alliance_id"]) || event.alliance_id,
      ship_type_id: get_safe_integer(victim_data["ship_type_id"]) || event.ship_type_id,
      damage_taken: get_safe_integer(victim_data["damage_taken"]),
      position: extract_position_data(victim_data["position"])
    }
  end

  defp extract_attackers_data(parsed_data) do
    attackers_data = parsed_data["attackers"] || []

    attackers_data
    |> Enum.map(fn attacker ->
      %{
        character_id: get_safe_integer(attacker["character_id"]),
        corporation_id: get_safe_integer(attacker["corporation_id"]),
        alliance_id: get_safe_integer(attacker["alliance_id"]),
        ship_type_id: get_safe_integer(attacker["ship_type_id"]),
        weapon_type_id: get_safe_integer(attacker["weapon_type_id"]),
        damage_done: get_safe_integer(attacker["damage_done"]),
        final_blow: get_safe_boolean(attacker["final_blow"]),
        security_status: get_safe_float(attacker["security_status"])
      }
    end)
    |> Enum.filter(fn attacker ->
      # Filter out attackers without character_id (like structures)
      is_map(attacker) and Map.has_key?(attacker, :character_id) and attacker.character_id != nil
    end)
  end

  defp extract_position_data(position_data) when is_map(position_data) do
    %{
      x: get_safe_float(position_data["x"]),
      y: get_safe_float(position_data["y"]),
      z: get_safe_float(position_data["z"])
    }
  end

  defp extract_position_data(_), do: nil

  # Safe data extraction helpers

  defp get_safe_integer(value) when is_integer(value), do: value

  defp get_safe_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {int_val, ""} -> int_val
      _ -> nil
    end
  end

  defp get_safe_integer(_), do: nil

  defp get_safe_float(value) when is_float(value), do: value
  defp get_safe_float(value) when is_integer(value), do: value * 1.0

  defp get_safe_float(value) when is_binary(value) do
    case Float.parse(value) do
      {float_val, ""} -> float_val
      _ -> nil
    end
  end

  defp get_safe_float(_), do: nil

  defp get_safe_boolean(value) when is_boolean(value), do: value
  defp get_safe_boolean(1), do: true
  defp get_safe_boolean(0), do: false
  defp get_safe_boolean("true"), do: true
  defp get_safe_boolean("false"), do: false
  defp get_safe_boolean(_), do: false

  # Metrics helpers

  defp update_success_metrics(current_metrics, _processing_time) do
    %{
      current_metrics
      | total_processed: current_metrics.total_processed + 1,
        successful_matches: current_metrics.successful_matches + 1,
        last_processed_at: DateTime.utc_now()
    }
  end

  defp get_uptime_seconds do
    # Calculate uptime since process start
    # This is a simplified implementation
    {uptime_ms, _} = :erlang.statistics(:wall_clock)
    div(uptime_ms, 1000)
  end
end

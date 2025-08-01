defmodule EveDmv.Contexts.Surveillance.Infrastructure.KillmailEventProcessor do
  @moduledoc """
  Killmail event processor for surveillance context.

  Processes incoming killmail events for surveillance profile matching,
  alert generation, and real-time notification dispatch.

  This module was created to resolve undefined function warnings during
  Phase 3 cleanup, specifically for surveillance killmail processing.

  ## Responsibilities

  - Process killmail events for surveillance matching
  - Trigger profile matching engine
  - Generate surveillance alerts
  - Dispatch notifications for matches
  - Maintain match history and statistics
  """

  use GenServer

  alias EveDmv.Contexts.Surveillance.Domain.AlertService
  alias EveDmv.Contexts.Surveillance.Domain.MatchingEngine
  alias EveDmv.Contexts.Surveillance.Domain.NotificationService
  alias EveDmv.Contexts.Surveillance.Infrastructure.MatchCache
  alias EveDmv.Contexts.Surveillance.Infrastructure.ProfileRepository
  alias EveDmv.DomainEvents.KillmailReceived

  require Logger

  @doc """
  Start the killmail event processor.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Process a killmail for surveillance matching.

  Takes a killmail event and processes it through the surveillance
  matching engine to identify profile matches and generate alerts.

  ## Parameters

  - `killmail_event` - The KillmailReceived event to process

  ## Returns

  `:ok` on successful processing, `{:error, reason}` on failure
  """
  @spec process_killmail_for_surveillance(KillmailReceived.t()) :: :ok | {:error, term()}
  def process_killmail_for_surveillance(%KillmailReceived{} = killmail_event) do
    GenServer.cast(__MODULE__, {:process_killmail, killmail_event})
    :ok
  end

  @doc """
  Process a killmail synchronously for surveillance matching.

  Synchronous version that waits for processing to complete before returning.

  ## Parameters

  - `killmail_event` - The KillmailReceived event to process
  - `timeout` - Timeout in milliseconds (default: 5000)

  ## Returns

  `{:ok, match_results}` on successful processing with match details
  """
  @spec process_killmail_sync(KillmailReceived.t(), integer()) :: {:ok, map()} | {:error, term()}
  def process_killmail_sync(%KillmailReceived{} = killmail_event, timeout \\ 5000) do
    GenServer.call(__MODULE__, {:process_killmail_sync, killmail_event}, timeout)
  end

  @doc """
  Get processing statistics.

  Returns statistics about killmail processing performance
  and surveillance matching results.

  ## Returns

  `{:ok, statistics}` containing processing metrics
  """
  @spec get_processing_statistics() :: {:ok, map()} | {:error, term()}
  def get_processing_statistics do
    GenServer.call(__MODULE__, :get_statistics)
  end

  @doc """
  Get current processing status.

  Returns information about the current state of the event processor.

  ## Returns

  `{:ok, status}` containing processor status information
  """
  @spec get_processor_status() :: {:ok, map()} | {:error, term()}
  def get_processor_status do
    GenServer.call(__MODULE__, :get_status)
  end

  # GenServer implementation

  @impl GenServer
  def init(opts) do
    Logger.info("Starting surveillance killmail event processor")

    initial_state = %{
      processing_count: 0,
      match_count: 0,
      alert_count: 0,
      error_count: 0,
      start_time: DateTime.utc_now(),
      last_processed: nil,
      options: opts
    }

    {:ok, initial_state}
  end

  @impl GenServer
  def handle_cast({:process_killmail, killmail_event}, state) do
    Logger.debug("Processing killmail for surveillance",
      killmail_id: killmail_event.killmail_id
    )

    start_time = System.monotonic_time(:millisecond)

    result = perform_surveillance_processing(killmail_event)

    processing_time = System.monotonic_time(:millisecond) - start_time

    updated_state = update_processing_statistics(state, result, processing_time)

    {:noreply, updated_state}
  end

  @impl GenServer
  def handle_call({:process_killmail_sync, killmail_event}, _from, state) do
    Logger.debug("Processing killmail synchronously for surveillance",
      killmail_id: killmail_event.killmail_id
    )

    start_time = System.monotonic_time(:millisecond)

    result = perform_surveillance_processing(killmail_event)

    processing_time = System.monotonic_time(:millisecond) - start_time

    updated_state = update_processing_statistics(state, result, processing_time)

    case result do
      {:ok, match_results} ->
        {:reply, {:ok, match_results}, updated_state}

      {:error, _reason} = error ->
        {:reply, error, updated_state}
    end
  end

  @impl GenServer
  def handle_call(:get_statistics, _from, state) do
    uptime_seconds = DateTime.diff(DateTime.utc_now(), state.start_time)

    statistics = %{
      uptime_seconds: uptime_seconds,
      total_processed: state.processing_count,
      total_matches: state.match_count,
      total_alerts: state.alert_count,
      total_errors: state.error_count,
      processing_rate: calculate_processing_rate(state.processing_count, uptime_seconds),
      match_rate: calculate_match_rate(state.match_count, state.processing_count),
      error_rate: calculate_error_rate(state.error_count, state.processing_count),
      last_processed: state.last_processed,
      status: :running
    }

    {:reply, {:ok, statistics}, state}
  end

  @impl GenServer
  def handle_call(:get_status, _from, state) do
    status = %{
      processor_name: __MODULE__,
      status: :running,
      start_time: state.start_time,
      current_time: DateTime.utc_now(),
      processing_count: state.processing_count,
      last_activity: state.last_processed,
      memory_usage: get_memory_usage(),
      message_queue_length: Process.info(self(), :message_queue_len) |> elem(1)
    }

    {:reply, {:ok, status}, state}
  end

  @impl GenServer
  def handle_info(_msg, state) do
    Logger.warning("Received unexpected message")
    {:noreply, state}
  end

  # Private helper functions for surveillance processing

  defp perform_surveillance_processing(%KillmailReceived{} = killmail_event) do
    with {:ok, active_profiles} <- get_active_surveillance_profiles(),
         {:ok, match_results} <- run_profile_matching(killmail_event, active_profiles),
         {:ok, alert_results} <- process_matches_for_alerts(match_results),
         {:ok, notification_results} <- dispatch_notifications(alert_results) do
      # Cache the results for performance metrics
      cache_processing_results(killmail_event, match_results)

      processing_summary = %{
        killmail_id: killmail_event.killmail_id,
        profiles_checked: length(active_profiles),
        matches_found: count_matches(match_results),
        alerts_generated: count_alerts(alert_results),
        notifications_sent: count_notifications(notification_results),
        processing_status: :success
      }

      {:ok, processing_summary}
    else
      {:error, :no_active_profiles} ->
        Logger.debug("No active surveillance profiles",
          killmail_id: killmail_event.killmail_id
        )

        {:ok, %{killmail_id: killmail_event.killmail_id, matches_found: 0, reason: :no_profiles}}

      {:error, reason} = error ->
        Logger.error("Surveillance processing failed",
          killmail_id: killmail_event.killmail_id,
          reason: reason
        )

        error
    end
  rescue
    error ->
      Logger.error("Exception during surveillance processing",
        killmail_id: killmail_event.killmail_id,
        error: inspect(error)
      )

      {:error, :processing_exception}
  end

  defp get_active_surveillance_profiles do
    case ProfileRepository.list_active_profiles() do
      {:ok, [_ | _] = profiles} ->
        {:ok, profiles}

      {:ok, []} ->
        {:error, :no_active_profiles}

      {:error, reason} = error ->
        Logger.error("Failed to retrieve active surveillance profiles", reason: reason)
        error
    end
  end

  defp run_profile_matching(killmail_event, profiles) do
    Logger.debug("Running profile matching")

    match_results =
      Enum.map(profiles, fn profile ->
        case MatchingEngine.match_killmail_against_profile(killmail_event, profile) do
          {:ok, match_result} ->
            match_result

          {:error, reason} ->
            Logger.warning("Profile matching failed", profile_id: profile.id, reason: reason)
            %{profile_id: profile.id, matched: false, error: reason}
        end
      end)

    {:ok, match_results}
  end

  defp process_matches_for_alerts(match_results) do
    Logger.debug("Processing matches for alert generation")

    alert_results =
      match_results
      |> Enum.filter(& &1.matched)
      |> Enum.map(fn match ->
        case AlertService.generate_alert_for_match(match) do
          {:ok, alert} ->
            %{match_id: match.id, alert: alert, status: :success}

          {:error, reason} ->
            Logger.warning("Alert generation failed")
            %{match_id: match.id, status: :error, reason: reason}
        end
      end)

    {:ok, alert_results}
  end

  defp dispatch_notifications(alert_results) do
    Logger.debug("Dispatching notifications")

    notification_results =
      alert_results
      |> Enum.filter(&(&1.status == :success))
      |> Enum.map(fn alert_result ->
        case NotificationService.dispatch_alert_notification(alert_result.alert) do
          {:ok, notification} ->
            %{alert_id: alert_result.alert.id, notification: notification, status: :sent}

          {:error, reason} ->
            Logger.warning("Notification dispatch failed")

            %{alert_id: alert_result.alert.id, status: :failed, reason: reason}
        end
      end)

    {:ok, notification_results}
  end

  defp cache_processing_results(killmail_event, match_results) do
    cache_key = "surveillance:processing:#{killmail_event.killmail_id}"

    cache_data = %{
      killmail_id: killmail_event.killmail_id,
      processed_at: DateTime.utc_now(),
      match_count: count_matches(match_results),
      match_results: match_results
    }

    case MatchCache.put(cache_key, cache_data, ttl: :timer.hours(1)) do
      :ok ->
        Logger.debug("Cached processing results", killmail_id: killmail_event.killmail_id)

      {:error, reason} ->
        Logger.warning("Failed to cache processing results",
          killmail_id: killmail_event.killmail_id,
          reason: reason
        )
    end
  end

  defp update_processing_statistics(state, processing_result, _processing_time_ms) do
    new_processing_count = state.processing_count + 1

    {new_match_count, new_alert_count, new_error_count} =
      case processing_result do
        {:ok, summary} ->
          matches = Map.get(summary, :matches_found, 0)
          alerts = Map.get(summary, :alerts_generated, 0)
          {state.match_count + matches, state.alert_count + alerts, state.error_count}

        {:error, _} ->
          {state.match_count, state.alert_count, state.error_count + 1}
      end

    %{
      state
      | processing_count: new_processing_count,
        match_count: new_match_count,
        alert_count: new_alert_count,
        error_count: new_error_count,
        last_processed: DateTime.utc_now()
    }
  end

  # Utility functions for counting and metrics

  defp count_matches(match_results) do
    Enum.count(match_results, & &1.matched)
  end

  defp count_alerts(alert_results) do
    Enum.count(alert_results, &(&1.status == :success))
  end

  defp count_notifications(notification_results) do
    Enum.count(notification_results, &(&1.status == :sent))
  end

  defp calculate_processing_rate(total_processed, uptime_seconds) when uptime_seconds > 0 do
    Float.round(total_processed / uptime_seconds, 2)
  end

  defp calculate_processing_rate(_, _), do: 0.0

  defp calculate_match_rate(total_matches, total_processed) when total_processed > 0 do
    Float.round(total_matches / total_processed, 3)
  end

  defp calculate_match_rate(_, _), do: 0.0

  defp calculate_error_rate(total_errors, total_processed) when total_processed > 0 do
    Float.round(total_errors / total_processed, 3)
  end

  defp calculate_error_rate(_, _), do: 0.0

  defp get_memory_usage do
    case Process.info(self(), :memory) do
      {:memory, memory_bytes} -> memory_bytes
      _ -> 0
    end
  end
end

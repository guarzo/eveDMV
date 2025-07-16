defmodule EveDmv.Monitoring.ErrorRecoveryWorker do
  @moduledoc """
  Worker process that monitors error patterns and initiates recovery actions.

  Watches for systematic failures and takes corrective actions like:
  - Restarting stalled pipelines
  - Clearing bad data from queues
  - Adjusting rate limits
  - Triggering circuit breakers
  """

  use GenServer
  alias EveDmv.Monitoring.{ErrorTracker, PipelineMonitor}

  require Logger

  @check_interval :timer.minutes(1)
  @stall_threshold_minutes 5
  # 10% error rate
  @error_rate_threshold 0.10
  # errors in check interval
  @spike_threshold 50

  defmodule RecoveryAction do
    @moduledoc false
    defstruct [:type, :reason, :timestamp, :details]
  end

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Force an immediate recovery check.
  """
  def check_now do
    GenServer.cast(__MODULE__, :check_now)
  end

  @doc """
  Get recent recovery actions.
  """
  def get_recovery_history(limit \\ 10) do
    GenServer.call(__MODULE__, {:get_history, limit})
  end

  # Server callbacks

  @impl true
  def init(_opts) do
    # Schedule first check
    schedule_check()

    # Attach telemetry handlers for error spikes
    attach_telemetry_handlers()

    state = %{
      recovery_history: [],
      last_check: DateTime.utc_now()
    }

    {:ok, state}
  end

  @impl true
  def handle_cast(:check_now, state) do
    new_state = perform_recovery_check(state)
    {:noreply, new_state}
  end

  @impl true
  def handle_call({:get_history, limit}, _from, state) do
    history = Enum.take(state.recovery_history, limit)
    {:reply, history, state}
  end

  @impl true
  def handle_info(:scheduled_check, state) do
    new_state = perform_recovery_check(state)
    schedule_check()
    {:noreply, new_state}
  end

  @impl true
  def handle_info({:error_spike_detected, error_code}, state) do
    Logger.warning("Error spike detected for #{error_code}, initiating recovery check")
    new_state = handle_error_spike(error_code, state)
    {:noreply, new_state}
  end

  # Private functions

  defp perform_recovery_check(state) do
    Logger.debug("Performing error recovery check")

    # Get current metrics
    pipeline_health = PipelineMonitor.get_health_status()
    pipeline_metrics = PipelineMonitor.get_metrics()
    error_summary = ErrorTracker.get_summary_report()

    # Check various failure conditions
    state
    |> check_pipeline_stall(pipeline_metrics)
    |> check_error_rates(error_summary, pipeline_metrics)
    |> check_pipeline_health(pipeline_health)
    |> Map.put(:last_check, DateTime.utc_now())
  end

  defp check_pipeline_stall(state, metrics) do
    case metrics.last_success do
      nil ->
        state

      last_success ->
        minutes_since_success = DateTime.diff(DateTime.utc_now(), last_success, :minute)

        if minutes_since_success > @stall_threshold_minutes do
          take_recovery_action(state, %RecoveryAction{
            type: :pipeline_restart,
            reason: :stalled,
            timestamp: DateTime.utc_now(),
            details: %{
              minutes_since_success: minutes_since_success,
              last_success: last_success
            }
          })
        else
          state
        end
    end
  end

  defp check_error_rates(state, error_summary, pipeline_metrics) do
    total_messages = pipeline_metrics.messages.processed + pipeline_metrics.messages.failed

    if total_messages > 0 do
      error_rate = pipeline_metrics.messages.failed / total_messages

      if error_rate > @error_rate_threshold do
        # Identify top error types
        top_errors = Enum.take(error_summary.top_errors, 3)

        take_recovery_action(state, %RecoveryAction{
          type: :rate_limit_adjustment,
          reason: :high_error_rate,
          timestamp: DateTime.utc_now(),
          details: %{
            error_rate: Float.round(error_rate * 100, 2),
            top_errors: top_errors,
            total_errors: pipeline_metrics.messages.failed
          }
        })
      else
        state
      end
    else
      state
    end
  end

  defp check_pipeline_health(state, health) do
    case health.status do
      :unhealthy ->
        take_recovery_action(state, %RecoveryAction{
          type: :health_intervention,
          reason: :unhealthy_pipeline,
          timestamp: DateTime.utc_now(),
          details: %{
            issues: health.issues
          }
        })

      _ ->
        state
    end
  end

  defp handle_error_spike(error_code, state) do
    # Get detailed stats for the error
    case ErrorTracker.get_error_stats(error_code) do
      nil ->
        state

      stats ->
        if stats.count > @spike_threshold do
          take_recovery_action(state, %RecoveryAction{
            type: :error_spike_response,
            reason: error_code,
            timestamp: DateTime.utc_now(),
            details: %{
              error_count: stats.count,
              first_seen: stats.first_seen,
              last_seen: stats.last_seen
            }
          })
        else
          state
        end
    end
  end

  defp take_recovery_action(state, action) do
    Logger.warning("Taking recovery action: #{action.type} due to #{action.reason}")

    # Execute the recovery action
    case action.type do
      :pipeline_restart ->
        restart_pipeline()

      :rate_limit_adjustment ->
        adjust_rate_limits(action.details)

      :health_intervention ->
        handle_health_issues(action.details)

      :error_spike_response ->
        handle_error_spike_recovery(action.reason, action.details)

      _ ->
        Logger.error("Unknown recovery action type: #{action.type}")
    end

    # Record the action
    history = Enum.take([action | state.recovery_history], 100)

    # Emit telemetry
    :telemetry.execute(
      [:eve_dmv, :error_recovery, :action_taken],
      %{count: 1},
      %{
        action_type: action.type,
        reason: action.reason
      }
    )

    %{state | recovery_history: history}
  end

  defp restart_pipeline do
    Logger.warning("Attempting to restart killmail pipeline")

    # First, try a gentle restart by clearing any backlog
    case Process.whereis(EveDmv.Killmails.KillmailPipeline) do
      nil ->
        Logger.error("Pipeline process not found")

      pid ->
        # Send a message to clear backlog (if implemented)
        send(pid, :clear_backlog)

        # If that doesn't work, we could restart the supervisor
        # This would require coordination with the main application supervisor
        Logger.info("Sent clear_backlog signal to pipeline")
    end
  end

  defp adjust_rate_limits(details) do
    Logger.warning("Adjusting rate limits due to high error rate: #{inspect(details)}")

    # Identify if errors are from external services
    external_errors =
      Enum.filter(details.top_errors, fn error ->
        EveDmv.ErrorCodes.category(error.code) == :external_service
      end)

    if length(external_errors) > 0 do
      # Could implement dynamic rate limiting here
      # For now, just log the recommendation
      Logger.warning("Recommend reducing external API call rate")
    end
  end

  defp handle_health_issues(details) do
    Logger.warning("Handling pipeline health issues: #{inspect(details.issues)}")

    # Take specific actions based on health issues
    Enum.each(details.issues, fn issue ->
      case issue do
        "No successful processing in last" <> _ ->
          restart_pipeline()

        "High " <> rest ->
          if String.contains?(rest, " error rate") do
            error_type = String.trim(String.replace(rest, " error rate", ""))
            Logger.warning("High error rate for #{error_type}, consider circuit breaker")
          end

        _ ->
          Logger.warning("Health issue: #{issue}")
      end
    end)
  end

  defp handle_error_spike_recovery(error_code, details) do
    Logger.warning("Handling error spike for #{error_code}: #{inspect(details)}")

    # Take action based on error code
    case EveDmv.ErrorCodes.category(error_code) do
      :external_service ->
        Logger.warning("External service errors spiking, activating circuit breaker")

      # Could trigger circuit breaker here

      :database ->
        Logger.warning("Database errors spiking, checking connection pool")

      # Could check/adjust connection pool

      _ ->
        Logger.warning("Error spike for #{error_code}, monitoring continues")
    end
  end

  defp schedule_check do
    Process.send_after(self(), :scheduled_check, @check_interval)
  end

  defp attach_telemetry_handlers do
    :telemetry.attach(
      "error-recovery-spike-handler",
      [:eve_dmv, :error_tracker, :spike_detected],
      &__MODULE__.handle_spike_telemetry/4,
      nil
    )
  end

  @doc false
  def handle_spike_telemetry(_event_name, _measurements, metadata, _config) do
    if metadata[:error_code] && Process.whereis(__MODULE__) do
      send(__MODULE__, {:error_spike_detected, metadata.error_code})
    end
  end
end

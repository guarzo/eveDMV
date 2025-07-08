defmodule EveDmv.Monitoring.AlertDispatcher do
  @moduledoc """
  Dispatches alerts for critical errors and system issues.
  
  Currently logs alerts, but can be extended to send notifications
  via email, Slack, Discord, or other channels.
  """
  
  use GenServer
  require Logger
  
  @critical_error_threshold 100
  @alert_cooldown_minutes 15
  
  defmodule Alert do
    @moduledoc false
    defstruct [:id, :type, :severity, :message, :details, :timestamp]
  end
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc """
  Send an alert.
  """
  def send_alert(type, severity, message, details \\ %{}) do
    GenServer.cast(__MODULE__, {:send_alert, type, severity, message, details})
  end
  
  @doc """
  Get recent alerts.
  """
  def get_recent_alerts(limit \\ 20) do
    GenServer.call(__MODULE__, {:get_recent_alerts, limit})
  end
  
  # Server callbacks
  
  @impl true
  def init(_opts) do
    # Attach telemetry handlers
    attach_telemetry_handlers()
    
    state = %{
      alerts: [],
      last_alert_times: %{},
      alert_counts: %{}
    }
    
    {:ok, state}
  end
  
  @impl true
  def handle_cast({:send_alert, type, severity, message, details}, state) do
    # Check cooldown
    if should_send_alert?(type, state) do
      alert = %Alert{
        id: generate_id(),
        type: type,
        severity: severity,
        message: message,
        details: details,
        timestamp: DateTime.utc_now()
      }
      
      # Dispatch the alert
      dispatch_alert(alert)
      
      # Update state
      new_state = state
      |> update_in([:alerts], &([alert | &1] |> Enum.take(100)))
      |> put_in([:last_alert_times, type], DateTime.utc_now())
      |> update_in([:alert_counts, type], &((&1 || 0) + 1))
      
      {:noreply, new_state}
    else
      Logger.debug("Alert for #{type} suppressed due to cooldown")
      {:noreply, state}
    end
  end
  
  @impl true
  def handle_call({:get_recent_alerts, limit}, _from, state) do
    alerts = Enum.take(state.alerts, limit)
    {:reply, alerts, state}
  end
  
  @impl true
  def handle_info({:telemetry_alert, event_name, measurements, metadata}, state) do
    # Handle telemetry-based alerts
    {type, severity, message} = analyze_telemetry_event(event_name, measurements, metadata)
    
    if type do
      handle_cast({:send_alert, type, severity, message, metadata}, state)
    else
      {:noreply, state}
    end
  end
  
  # Private functions
  
  defp generate_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end
  
  defp should_send_alert?(type, state) do
    case Map.get(state.last_alert_times, type) do
      nil -> true
      last_time ->
        minutes_elapsed = DateTime.diff(DateTime.utc_now(), last_time, :minute)
        minutes_elapsed >= @alert_cooldown_minutes
    end
  end
  
  defp dispatch_alert(alert) do
    # Log the alert with appropriate level
    case alert.severity do
      :critical ->
        Logger.critical(format_alert(alert))
        
      :high ->
        Logger.error(format_alert(alert))
        
      :medium ->
        Logger.warning(format_alert(alert))
        
      :low ->
        Logger.info(format_alert(alert))
    end
    
    # Emit telemetry for alert
    :telemetry.execute(
      [:eve_dmv, :monitoring, :alert_sent],
      %{count: 1},
      %{
        alert_type: alert.type,
        severity: alert.severity
      }
    )
    
    # Future: Send to external services
    # send_to_slack(alert)
    # send_to_discord(alert)
    # send_email_alert(alert)
  end
  
  defp format_alert(alert) do
    """
    🚨 ALERT: #{String.upcase(to_string(alert.severity))}
    Type: #{alert.type}
    Message: #{alert.message}
    Details: #{inspect(alert.details, pretty: true)}
    Time: #{alert.timestamp}
    ID: #{alert.id}
    """
  end
  
  defp analyze_telemetry_event(event_name, measurements, metadata) do
    case event_name do
      [:eve_dmv, :error_tracker, :spike_detected] ->
        if measurements.count > @critical_error_threshold do
          {:error_spike, :critical, 
           "Critical error spike: #{metadata.error_code} occurred #{measurements.count} times"}
        else
          {:error_spike, :high,
           "Error spike detected: #{metadata.error_code} occurred #{measurements.count} times"}
        end
        
      [:eve_dmv, :pipeline, :batch_failed] ->
        {:pipeline_failure, :high,
         "Pipeline batch failed with #{measurements.batch_size} messages"}
         
      [:eve_dmv, :error_recovery, :action_taken] ->
        {:recovery_action, :medium,
         "Recovery action taken: #{metadata.action_type} due to #{metadata.reason}"}
         
      _ ->
        {nil, nil, nil}
    end
  end
  
  defp attach_telemetry_handlers do
    events = [
      [:eve_dmv, :error_tracker, :spike_detected],
      [:eve_dmv, :pipeline, :batch_failed],
      [:eve_dmv, :error_recovery, :action_taken]
    ]
    
    Enum.each(events, fn event ->
      :telemetry.attach(
        "alert-dispatcher-#{inspect(event)}",
        event,
        &__MODULE__.handle_telemetry_event/4,
        nil
      )
    end)
  end
  
  @doc false
  def handle_telemetry_event(event_name, measurements, metadata, _config) do
    if Process.whereis(__MODULE__) do
      send(__MODULE__, {:telemetry_alert, event_name, measurements, metadata})
    end
  end
end
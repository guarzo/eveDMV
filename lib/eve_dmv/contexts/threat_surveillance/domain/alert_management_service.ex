defmodule EveDmv.Contexts.ThreatSurveillance.Domain.AlertManagementService do
  @moduledoc """
  Service for managing surveillance alerts and threat notifications.

  Handles alert configuration, processing surveillance matches,
  and coordinating alert delivery across multiple channels.
  """

  use GenServer

  alias EveDmv.Contexts.ThreatSurveillance.Domain.NotificationService
  alias EveDmv.Shared.Infrastructure.UnifiedCache
  alias EveDmv.Shared.Infrastructure.UnifiedRepository

  require Logger

  # Public API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Configure alert settings for a user.
  """
  def configure_alerts(user_id, alert_settings) do
    GenServer.call(__MODULE__, {:configure_alerts, user_id, alert_settings})
  end

  @doc """
  Process a surveillance match for alert generation.
  """
  def process_surveillance_match(match_event) do
    GenServer.cast(__MODULE__, {:process_surveillance_match, match_event})
  end

  @doc """
  Process a threat level change for alerts.
  """
  def process_threat_level_change(threat_event) do
    GenServer.cast(__MODULE__, {:process_threat_level_change, threat_event})
  end

  @doc """
  Get alert metrics.
  """
  def get_metrics do
    GenServer.call(__MODULE__, :get_metrics)
  end

  @doc """
  Get recent alerts.
  """
  def get_recent_alerts(options \\ []) do
    GenServer.call(__MODULE__, {:get_recent_alerts, options})
  end

  @doc """
  Get alert metrics with options.
  """
  def get_metrics(options) when is_list(options) do
    GenServer.call(__MODULE__, {:get_metrics, options})
  end

  # GenServer implementation

  @impl GenServer
  def init(_opts) do
    state = %{
      alerts_processed: 0,
      notifications_sent: 0,
      alert_configurations: %{}
    }

    Logger.info("AlertManagementService started")
    {:ok, state}
  end

  @impl GenServer
  def handle_call({:configure_alerts, user_id, alert_settings}, _from, state) do
    case update_alert_configuration(user_id, alert_settings) do
      {:ok, updated_config} ->
        # Cache the configuration
        cache_key = {:alert_config, user_id}
        # 30 minutes
        UnifiedCache.put(:surveillance, cache_key, updated_config, 1800)

        new_state = %{
          state
          | alert_configurations: Map.put(state.alert_configurations, user_id, updated_config)
        }

        {:reply, {:ok, updated_config}, new_state}

      error ->
        {:reply, error, state}
    end
  end

  @impl GenServer
  def handle_call(:get_metrics, _from, state) do
    metrics = %{
      alerts_processed: state.alerts_processed,
      notifications_sent: state.notifications_sent,
      active_configurations: map_size(state.alert_configurations)
    }

    {:reply, metrics, state}
  end

  @impl GenServer
  def handle_call({:get_metrics, _options}, _from, state) do
    # Options parameter reserved for future filtering (e.g., time range)
    metrics = %{
      alerts_processed: state.alerts_processed,
      notifications_sent: state.notifications_sent,
      active_configurations: map_size(state.alert_configurations)
    }

    {:reply, metrics, state}
  end

  @impl GenServer
  def handle_call(:health_check, _from, state) do
    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_cast({:process_surveillance_match, match_event}, state) do
    # Get users who should be alerted about this match
    interested_users = find_interested_users(match_event)

    # Generate alerts for each interested user
    alerts_generated =
      Enum.map(interested_users, fn user_id ->
        case generate_surveillance_alert(user_id, match_event) do
          {:ok, alert} ->
            # Send notification
            NotificationService.send_match_notification(alert)
            alert

          {:error, reason} ->
            Logger.error("Failed to generate alert for user #{user_id}: #{inspect(reason)}")
            nil
        end
      end)
      |> Enum.filter(& &1)

    new_state = %{
      state
      | alerts_processed: state.alerts_processed + length(alerts_generated),
        notifications_sent: state.notifications_sent + length(alerts_generated)
    }

    {:noreply, new_state}
  rescue
    error ->
      Logger.error("Failed to process surveillance match for alerts: #{inspect(error)}")
      {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:process_threat_level_change, threat_event}, state) do
    # Get users who should be alerted about threat level changes
    interested_users = find_users_interested_in_threat_changes(threat_event)

    # Generate threat alerts
    alerts_generated =
      Enum.map(interested_users, fn user_id ->
        case generate_threat_alert(user_id, threat_event) do
          {:ok, alert} ->
            # Send notification
            NotificationService.send_threat_alert(alert)
            alert

          {:error, reason} ->
            Logger.error(
              "Failed to generate threat alert for user #{user_id}: #{inspect(reason)}"
            )

            nil
        end
      end)
      |> Enum.filter(& &1)

    new_state = %{
      state
      | alerts_processed: state.alerts_processed + length(alerts_generated),
        notifications_sent: state.notifications_sent + length(alerts_generated)
    }

    {:noreply, new_state}
  rescue
    error ->
      Logger.error("Failed to process threat level change for alerts: #{inspect(error)}")
      {:noreply, state}
  end

  # Private functions

  defp update_alert_configuration(user_id, alert_settings) do
    # Validate alert settings
    validated_settings = validate_alert_settings(alert_settings)

    configuration = %{
      user_id: user_id,
      updated_at: DateTime.utc_now(),
      settings: validated_settings,
      channels: extract_notification_channels(alert_settings),
      filters: extract_alert_filters(alert_settings)
    }

    {:ok, configuration}
  rescue
    error ->
      Logger.error("Failed to update alert configuration: #{inspect(error)}")
      {:error, :invalid_configuration}
  end

  defp find_interested_users(match_event) do
    profile_id = match_event[:profile_id] || match_event.profile_id

    # Get profile owner and any shared profile users
    case get_profile_users(profile_id) do
      {:ok, users} -> users
      _ -> []
    end
  end

  defp find_users_interested_in_threat_changes(threat_event) do
    entity_id = threat_event[:entity_id] || threat_event.entity_id
    entity_type = threat_event[:entity_type] || threat_event.entity_type

    # Find users who have surveillance profiles watching this entity
    {:ok, users} = get_users_watching_entity(entity_id, entity_type)
    users
  end

  defp generate_surveillance_alert(user_id, match_event) do
    alert = %{
      id: generate_alert_id(),
      user_id: user_id,
      type: :surveillance_match,
      profile_id: match_event[:profile_id] || match_event.profile_id,
      killmail_id: match_event[:killmail_id] || match_event.killmail_id,
      match_details: extract_match_details(match_event),
      severity: determine_alert_severity(match_event),
      generated_at: DateTime.utc_now(),
      status: :pending
    }

    {:ok, alert}
  rescue
    error ->
      Logger.error("Failed to generate surveillance alert: #{inspect(error)}")
      {:error, :generation_failed}
  end

  defp generate_threat_alert(user_id, threat_event) do
    alert = %{
      id: generate_alert_id(),
      user_id: user_id,
      type: :threat_level_change,
      entity_id: threat_event[:entity_id] || threat_event.entity_id,
      entity_type: threat_event[:entity_type] || threat_event.entity_type,
      old_threat_level: threat_event[:old_level] || threat_event.old_level,
      new_threat_level: threat_event[:new_level] || threat_event.new_level,
      threat_details: extract_threat_details(threat_event),
      severity: determine_threat_alert_severity(threat_event),
      generated_at: DateTime.utc_now(),
      status: :pending
    }

    {:ok, alert}
  rescue
    error ->
      Logger.error("Failed to generate threat alert: #{inspect(error)}")
      {:error, :generation_failed}
  end

  defp validate_alert_settings(settings) do
    # Validate and sanitize alert settings
    %{
      enabled: Map.get(settings, :enabled, true),
      min_threat_level: Map.get(settings, :min_threat_level, :medium),
      notification_channels: Map.get(settings, :notification_channels, [:in_app]),
      frequency: Map.get(settings, :frequency, :immediate),
      quiet_hours: Map.get(settings, :quiet_hours, %{enabled: false})
    }
  end

  defp extract_notification_channels(alert_settings) do
    Map.get(alert_settings, :notification_channels, [:in_app])
  end

  defp extract_alert_filters(alert_settings) do
    Map.get(alert_settings, :filters, %{})
  end

  defp get_profile_users(profile_id) do
    # Get users associated with a surveillance profile
    case UnifiedRepository.get_surveillance_profile(profile_id) do
      {:ok, profile} ->
        users = [profile[:user_id] || profile.user_id]
        # Add any shared users
        shared_users = profile[:shared_with] || []
        {:ok, users ++ shared_users}

      error ->
        error
    end
  end

  defp get_users_watching_entity(_entity_id, _entity_type) do
    # Find users who have surveillance profiles that would match this entity
    # This would involve querying profiles with criteria matching the entity
    # Placeholder
    {:ok, []}
  end

  defp extract_match_details(match_event) do
    %{
      matched_criteria: match_event[:matched_criteria] || [],
      confidence_score: match_event[:confidence_score] || 0.0,
      match_timestamp: match_event[:matched_at] || DateTime.utc_now()
    }
  end

  defp extract_threat_details(threat_event) do
    %{
      threat_score: threat_event[:threat_score] || 0.0,
      risk_factors: threat_event[:risk_factors] || [],
      change_reason: threat_event[:change_reason] || "Unknown"
    }
  end

  defp determine_alert_severity(match_event) do
    confidence_score = match_event[:confidence_score] || 0.0

    cond do
      confidence_score >= 0.9 -> :critical
      confidence_score >= 0.7 -> :high
      confidence_score >= 0.5 -> :medium
      true -> :low
    end
  end

  defp determine_threat_alert_severity(threat_event) do
    new_level = threat_event[:new_level] || threat_event.new_level

    case new_level do
      :critical -> :critical
      :high -> :high
      :medium -> :medium
      _ -> :low
    end
  end

  defp generate_alert_id do
    "alert_#{System.system_time(:second)}_#{:rand.uniform(10_000)}"
  end
end

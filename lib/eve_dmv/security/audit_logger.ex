defmodule EveDmv.Security.AuditLogger do
  @moduledoc """
  Security audit logging system.

  Captures and logs security-relevant events for compliance and monitoring.
  """

  require Logger

  @doc """
  Set up audit logging handlers.
  """
  def setup_handlers do
    # Set up telemetry handlers for security events
    :telemetry.attach_many(
      "security-audit-handler",
      [
        [:eve_dmv, :auth, :login],
        [:eve_dmv, :auth, :logout],
        [:eve_dmv, :auth, :failed_login],
        [:eve_dmv, :api, :key_created],
        [:eve_dmv, :api, :key_revoked],
        [:eve_dmv, :security, :config_change]
      ],
      &handle_security_event/4,
      %{}
    )

    Logger.info("Security audit handlers initialized")
  end

  @doc """
  Log a session timeout event.
  """
  def log_session_timeout(character_id, timeout_seconds) do
    :telemetry.execute(
      [:eve_dmv, :auth, :session_timeout],
      %{timeout_seconds: timeout_seconds},
      %{character_id: character_id, timestamp: DateTime.utc_now()}
    )

    Logger.warning(
      "Session timeout for character #{character_id} after #{timeout_seconds} seconds"
    )
  end

  @doc """
  Log a configuration change event.
  """
  def log_config_change(component, setting, old_value, new_value) do
    :telemetry.execute(
      [:eve_dmv, :security, :config_change],
      %{},
      %{
        component: component,
        setting: setting,
        old_value: old_value,
        new_value: new_value,
        timestamp: DateTime.utc_now()
      }
    )

    Logger.info(
      "Configuration change: #{component}.#{setting} changed from #{inspect(old_value)} to #{inspect(new_value)}"
    )
  end

  @doc """
  Log an authentication attempt.
  """
  def log_auth_attempt(character_id, client_ip, success) do
    event_type = if success, do: :login, else: :failed_login

    :telemetry.execute(
      [:eve_dmv, :auth, event_type],
      %{},
      %{
        character_id: character_id,
        client_ip: client_ip,
        success: success,
        timestamp: DateTime.utc_now()
      }
    )

    if success do
      Logger.info("Successful login for character #{character_id} from #{client_ip}")
    else
      Logger.warning(
        "Failed login attempt for character #{character_id || "unknown"} from #{client_ip}"
      )
    end
  end

  @doc """
  Log an authentication event.
  """
  def log_auth_event(event_type, character_id, metadata \\ %{}) do
    :telemetry.execute(
      [:eve_dmv, :auth, event_type],
      %{},
      Map.merge(metadata, %{
        character_id: character_id,
        timestamp: DateTime.utc_now()
      })
    )

    case event_type do
      :login ->
        Logger.info("Successful login for character #{character_id}")

      :logout ->
        Logger.info("Logout for character #{character_id}")

      :failed_login ->
        Logger.warning("Failed login attempt for character #{character_id}")

      _ ->
        Logger.info("Auth event #{event_type} for character #{character_id}")
    end
  end

  @doc """
  Log an API key event.
  """
  def log_api_key_event(event_type, api_key_id, character_id, metadata \\ %{}) do
    :telemetry.execute(
      [:eve_dmv, :api, event_type],
      %{},
      Map.merge(metadata, %{
        api_key_id: api_key_id,
        character_id: character_id,
        timestamp: DateTime.utc_now()
      })
    )

    case event_type do
      :key_created ->
        Logger.info("API key created: #{api_key_id} for character #{character_id}")

      :key_revoked ->
        Logger.info("API key revoked: #{api_key_id} for character #{character_id}")

      :key_used ->
        Logger.debug("API key used: #{api_key_id}")

      _ ->
        Logger.info("API key event #{event_type}: #{api_key_id}")
    end
  end

  # Private functions

  defp handle_security_event(event_name, measurements, metadata, _config) do
    # Log to structured format for security monitoring
    security_log_entry = %{
      event: event_name,
      measurements: measurements,
      metadata: metadata,
      timestamp: DateTime.utc_now(),
      severity: determine_severity(event_name)
    }

    # Log as structured JSON for SIEM integration
    Logger.info("SECURITY_EVENT: #{Jason.encode!(security_log_entry)}")

    # Also store in database for local analysis if needed
    store_security_event(security_log_entry)
  end

  defp determine_severity(event_name) do
    case event_name do
      [:eve_dmv, :auth, :failed_login] -> :warning
      [:eve_dmv, :auth, :session_timeout] -> :info
      [:eve_dmv, :security, :config_change] -> :warning
      [:eve_dmv, :api, :key_created] -> :info
      [:eve_dmv, :api, :key_revoked] -> :info
      _ -> :info
    end
  end

  defp store_security_event(_event) do
    # TODO: Implement database storage for security events if needed
    # This could be useful for local security analysis and reporting
    :ok
  end
end

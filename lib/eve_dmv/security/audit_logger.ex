defmodule EveDmv.Security.AuditLogger do
  @moduledoc """
  Logs security-relevant events for monitoring and compliance.

  This module provides a centralized way to log security events with proper
  telemetry integration for monitoring, alerting, and audit trail purposes.
  """

  require Logger

  @doc """
  Log authentication attempt events.

  ## Parameters
  - character_id: EVE character ID attempting authentication
  - ip_address: IP address of the client  
  - success: boolean indicating if authentication succeeded
  """
  @spec log_auth_attempt(integer() | nil, String.t(), boolean()) :: :ok
  def log_auth_attempt(character_id, ip_address, success) do
    :telemetry.execute(
      [:eve_dmv, :security, :auth_attempt],
      %{count: 1},
      %{character_id: character_id, ip: ip_address, success: success}
    )

    Logger.info("Authentication attempt", %{
      character_id: character_id,
      ip: sanitize_ip(ip_address),
      success: success,
      event_type: :auth_attempt
    })
  end

  @doc """
  Log rate limiting events.

  ## Parameters  
  - ip_address: IP address that was rate limited
  - endpoint: The endpoint that was rate limited
  - attempts: Number of attempts made
  """
  @spec log_rate_limit_exceeded(String.t(), String.t(), integer()) :: :ok
  def log_rate_limit_exceeded(ip_address, endpoint, attempts) do
    :telemetry.execute(
      [:eve_dmv, :security, :rate_limit_exceeded],
      %{count: 1, attempts: attempts},
      %{ip: ip_address, endpoint: endpoint}
    )

    Logger.warning("Rate limit exceeded", %{
      ip: sanitize_ip(ip_address),
      endpoint: endpoint,
      attempts: attempts,
      event_type: :rate_limit_exceeded
    })
  end

  @doc """
  Log session timeout events.

  ## Parameters
  - character_id: EVE character ID whose session timed out
  - session_duration: How long the session lasted in seconds
  """
  @spec log_session_timeout(integer() | nil, integer()) :: :ok
  def log_session_timeout(character_id, session_duration) do
    :telemetry.execute(
      [:eve_dmv, :security, :session_timeout],
      %{count: 1, duration: session_duration},
      %{character_id: character_id}
    )

    Logger.info("Session timeout", %{
      character_id: character_id,
      session_duration: session_duration,
      event_type: :session_timeout
    })
  end

  @doc """
  Log suspicious activity events.

  ## Parameters
  - character_id: EVE character ID involved (may be nil)
  - ip_address: IP address involved
  - activity_type: Type of suspicious activity
  - details: Additional context about the activity
  """
  @spec log_suspicious_activity(integer() | nil, String.t(), atom(), map()) :: :ok
  def log_suspicious_activity(character_id, ip_address, activity_type, details \\ %{}) do
    :telemetry.execute(
      [:eve_dmv, :security, :suspicious_activity],
      %{count: 1},
      %{character_id: character_id, ip: ip_address, activity_type: activity_type}
    )

    Logger.warning("Suspicious activity detected", %{
      character_id: character_id,
      ip: sanitize_ip(ip_address),
      activity_type: activity_type,
      details: details,
      event_type: :suspicious_activity
    })
  end

  @doc """
  Log security configuration changes.

  ## Parameters
  - changed_by: Character ID or system identifier making the change
  - config_type: Type of configuration changed
  - old_value: Previous configuration value (sanitized)
  - new_value: New configuration value (sanitized)
  """
  @spec log_config_change(String.t(), atom(), term(), term()) :: :ok
  def log_config_change(changed_by, config_type, old_value, new_value) do
    :telemetry.execute(
      [:eve_dmv, :security, :config_change],
      %{count: 1},
      %{changed_by: changed_by, config_type: config_type}
    )

    Logger.info("Security configuration changed", %{
      changed_by: changed_by,
      config_type: config_type,
      old_value: sanitize_config_value(old_value),
      new_value: sanitize_config_value(new_value),
      event_type: :config_change
    })
  end

  @doc """
  Log data access events for sensitive operations.

  ## Parameters
  - character_id: Character ID accessing the data
  - resource_type: Type of resource being accessed
  - resource_id: ID of the specific resource
  - operation: Type of operation (read, write, delete)
  """
  @spec log_data_access(integer(), atom(), String.t() | integer(), atom()) :: :ok
  def log_data_access(character_id, resource_type, resource_id, operation) do
    :telemetry.execute(
      [:eve_dmv, :security, :data_access],
      %{count: 1},
      %{character_id: character_id, resource_type: resource_type, operation: operation}
    )

    Logger.info("Sensitive data access", %{
      character_id: character_id,
      resource_type: resource_type,
      resource_id: resource_id,
      operation: operation,
      event_type: :data_access
    })
  end

  @doc """
  Log privilege escalation attempts.

  ## Parameters
  - character_id: Character ID attempting privilege escalation
  - requested_privilege: The privilege being requested
  - success: Whether the escalation succeeded
  """
  @spec log_privilege_escalation(integer(), String.t(), boolean()) :: :ok
  def log_privilege_escalation(character_id, requested_privilege, success) do
    severity = if success, do: :info, else: :warning

    :telemetry.execute(
      [:eve_dmv, :security, :privilege_escalation],
      %{count: 1},
      %{character_id: character_id, privilege: requested_privilege, success: success}
    )

    Logger.log(severity, "Privilege escalation attempt", %{
      character_id: character_id,
      requested_privilege: requested_privilege,
      success: success,
      event_type: :privilege_escalation
    })
  end

  @doc """
  Set up telemetry event handlers for security monitoring.

  This should be called during application startup to enable
  security event monitoring and alerting.
  """
  @spec setup_handlers() :: :ok
  def setup_handlers do
    # Monitor failed authentication attempts
    :telemetry.attach(
      "security-failed-auth",
      [:eve_dmv, :security, :auth_attempt],
      &handle_auth_event/4,
      nil
    )

    # Monitor rate limiting events
    :telemetry.attach(
      "security-rate-limits",
      [:eve_dmv, :security, :rate_limit_exceeded],
      &handle_rate_limit_event/4,
      nil
    )

    # Monitor suspicious activity
    :telemetry.attach(
      "security-suspicious-activity",
      [:eve_dmv, :security, :suspicious_activity],
      &handle_suspicious_activity_event/4,
      nil
    )

    :ok
  end

  # Private helper functions

  defp sanitize_ip(ip) when is_binary(ip) do
    # Only show first 3 octets for privacy
    case String.split(ip, ".") do
      [a, b, c, _d] -> "#{a}.#{b}.#{c}.***"
      _ -> "***"
    end
  end

  defp sanitize_ip(_ip), do: "***"

  defp sanitize_config_value(value) when is_binary(value) do
    # Don't log actual config values, just indicate if they're present
    if String.length(value) > 0, do: "[REDACTED]", else: "[EMPTY]"
  end

  defp sanitize_config_value(value) when is_nil(value), do: "[NIL]"
  defp sanitize_config_value(_value), do: "[REDACTED]"

  # Event handlers for monitoring and alerting

  defp handle_auth_event(_event_name, _measurements, %{success: false} = metadata, _config) do
    # Alert on repeated failed authentication attempts
    if should_alert_on_failed_auth?(metadata) do
      Logger.error("Multiple failed authentication attempts detected", %{
        character_id: metadata.character_id,
        ip: sanitize_ip(metadata.ip)
      })
    end
  end

  defp handle_auth_event(_event_name, _measurements, _metadata, _config), do: :ok

  defp handle_rate_limit_event(_event_name, measurements, metadata, _config) do
    # Alert on excessive rate limiting
    if measurements.attempts > 10 do
      Logger.error("Excessive rate limiting detected", %{
        ip: sanitize_ip(metadata.ip),
        endpoint: metadata.endpoint,
        attempts: measurements.attempts
      })
    end
  end

  defp handle_suspicious_activity_event(_event_name, _measurements, metadata, _config) do
    # Always alert on suspicious activity
    Logger.error("Suspicious activity requires investigation", %{
      character_id: metadata.character_id,
      ip: sanitize_ip(metadata.ip),
      activity_type: metadata.activity_type
    })
  end

  defp should_alert_on_failed_auth?(_metadata) do
    # This could be enhanced to track patterns and only alert on suspicious patterns
    # For now, we rely on the rate limiter to handle this
    false
  end
end

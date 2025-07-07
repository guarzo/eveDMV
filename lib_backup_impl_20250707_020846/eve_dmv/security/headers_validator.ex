defmodule EveDmv.Security.HeadersValidator do
  @moduledoc """
  Security headers validation and monitoring.

  Provides periodic validation of security headers and monitoring for potential
  security issues with incoming requests.
  """

  use GenServer
  require Logger

  @validation_interval :timer.minutes(30)

  # Public API

  @doc """
  Set up periodic security headers validation.
  """
  def setup_periodic_validation do
    case GenServer.start_link(__MODULE__, %{}, name: __MODULE__) do
      {:ok, _pid} ->
        Logger.info("Security headers validator started")
        :ok

      {:error, {:already_started, _pid}} ->
        Logger.debug("Security headers validator already running")
        :ok

      {:error, reason} ->
        Logger.error("Failed to start security headers validator: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Validate security headers for a given request.
  """
  def validate_request_headers(conn) do
    headers = get_security_headers(conn)
    issues = find_security_issues(headers)

    if length(issues) > 0 do
      log_security_issues(conn, issues)
    end

    {:ok, issues}
  end

  @doc """
  Check the current status of security configuration.
  """
  def get_security_status do
    GenServer.call(__MODULE__, :get_status)
  end

  # GenServer callbacks

  @impl GenServer
  def init(state) do
    # Schedule the first validation
    Process.send_after(self(), :validate_headers, @validation_interval)
    {:ok, Map.put(state, :last_validation, nil)}
  end

  @impl GenServer
  def handle_call(:get_status, _from, state) do
    status = %{
      last_validation: state.last_validation,
      validation_interval_minutes: div(@validation_interval, 60_000),
      security_checks: %{
        csp_enabled: csp_configured?(),
        hsts_enabled: hsts_configured?(),
        security_headers_plug: security_headers_plug_enabled?()
      }
    }

    {:reply, status, state}
  end

  @impl GenServer
  def handle_info(:validate_headers, state) do
    perform_validation()

    # Schedule next validation
    Process.send_after(self(), :validate_headers, @validation_interval)

    {:noreply, Map.put(state, :last_validation, DateTime.utc_now())}
  end

  # Private functions

  defp perform_validation do
    Logger.debug("Performing periodic security headers validation")

    checks = [
      check_csp_configuration(),
      check_hsts_configuration(),
      check_security_headers_plug(),
      check_ssl_configuration()
    ]

    failed_checks = Enum.filter(checks, fn {status, _} -> status == :error end)

    if length(failed_checks) > 0 do
      Logger.warning("Security validation failed checks: #{inspect(failed_checks)}")
    else
      Logger.debug("All security checks passed")
    end
  end

  defp get_security_headers(conn) do
    %{
      content_security_policy: get_header_value(conn, "content-security-policy"),
      strict_transport_security: get_header_value(conn, "strict-transport-security"),
      x_frame_options: get_header_value(conn, "x-frame-options"),
      x_content_type_options: get_header_value(conn, "x-content-type-options"),
      referrer_policy: get_header_value(conn, "referrer-policy"),
      permissions_policy: get_header_value(conn, "permissions-policy")
    }
  end

  defp get_header_value(conn, header_name) do
    case Plug.Conn.get_resp_header(conn, header_name) do
      [value | _] -> value
      [] -> nil
    end
  end

  defp find_security_issues(headers) do
    initial_issues = []

    csp_issues =
      if is_nil(headers.content_security_policy) do
        ["Missing Content-Security-Policy header" | initial_issues]
      else
        initial_issues
      end

    sts_issues =
      if is_nil(headers.strict_transport_security) do
        ["Missing Strict-Transport-Security header" | csp_issues]
      else
        csp_issues
      end

    frame_issues =
      if is_nil(headers.x_frame_options) do
        ["Missing X-Frame-Options header" | sts_issues]
      else
        sts_issues
      end

    content_type_issues =
      if is_nil(headers.x_content_type_options) do
        ["Missing X-Content-Type-Options header" | frame_issues]
      else
        frame_issues
      end

    content_type_issues
  end

  defp log_security_issues(conn, issues) do
    client_ip = get_client_ip(conn)
    user_agent = get_user_agent(conn)

    Logger.warning("Security header issues detected", %{
      issues: issues,
      client_ip: client_ip,
      user_agent: user_agent,
      path: conn.request_path
    })
  end

  defp get_client_ip(conn) do
    case Plug.Conn.get_req_header(conn, "x-forwarded-for") do
      [forwarded_ips] ->
        forwarded_ips
        |> String.split(",")
        |> List.first()
        |> String.trim()

      [] ->
        conn.remote_ip
        |> :inet.ntoa()
        |> to_string()
    end
  end

  defp get_user_agent(conn) do
    case Plug.Conn.get_req_header(conn, "user-agent") do
      [ua] -> ua
      [] -> "unknown"
    end
  end

  defp check_csp_configuration do
    if csp_configured?() do
      {:ok, "CSP configured"}
    else
      {:error, "CSP not configured"}
    end
  end

  defp check_hsts_configuration do
    if hsts_configured?() do
      {:ok, "HSTS configured"}
    else
      {:error, "HSTS not configured"}
    end
  end

  defp check_security_headers_plug do
    if security_headers_plug_enabled?() do
      {:ok, "Security headers plug enabled"}
    else
      {:error, "Security headers plug not enabled"}
    end
  end

  defp check_ssl_configuration do
    # Basic SSL configuration check
    ssl_enabled = Application.get_env(:eve_dmv, EveDmvWeb.Endpoint)[:https] != nil

    if ssl_enabled do
      {:ok, "SSL configured"}
    else
      {:warning, "SSL not configured (development mode)"}
    end
  end

  defp csp_configured? do
    # Check if CSP is configured by looking for the security headers plug
    Code.ensure_loaded?(EveDmvWeb.Plugs.SecurityHeaders)
  end

  defp hsts_configured? do
    # Check if HSTS is configured in endpoint
    endpoint_config = Application.get_env(:eve_dmv, EveDmvWeb.Endpoint, [])
    https_config = Keyword.get(endpoint_config, :https, [])
    Keyword.has_key?(https_config, :hsts)
  end

  defp security_headers_plug_enabled? do
    # This would need to check the router configuration
    # For now, just check if the module exists
    Code.ensure_loaded?(EveDmvWeb.Plugs.SecurityHeaders)
  end
end

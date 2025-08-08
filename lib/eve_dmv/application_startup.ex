defmodule EveDmv.ApplicationStartup do
  @moduledoc """
  Application startup utilities for EVE DMV.

  Handles initialization tasks that need to run when the application starts,
  including DNS resolution, connectivity checks, and environment setup.
  """

  alias EveDmv.Core.Utils.DnsResolver
  alias EveDmvWeb.Telemetry.PerformanceTelemetry

  require Logger

  @doc """
  Run all startup initialization tasks.
  """
  def initialize do
    Logger.info("Starting EVE DMV application initialization...")

    tasks = [
      {:dns_resolution, &initialize_dns_resolution/0},
      {:connectivity_checks, &run_connectivity_checks/0},
      {:environment_validation, &validate_environment/0},
      {:performance_telemetry, &initialize_performance_telemetry/0}
    ]

    results = run_startup_tasks(tasks)

    # Log summary
    successful = Enum.count(results, fn {_task, result} -> result == :ok end)
    total = length(results)

    if successful == total do
      Logger.info(
        "✅ Application initialization completed successfully (#{successful}/#{total} tasks)"
      )
    else
      failed = total - successful

      Logger.warning(
        "⚠️ Application initialization completed with issues (#{successful}/#{total} tasks successful, #{failed} failed)"
      )
    end

    :ok
  end

  defp run_startup_tasks(tasks) do
    Enum.map(tasks, fn {name, task_fn} ->
      Logger.debug("Running startup task: #{name}")

      result =
        try do
          task_fn.()
        rescue
          error ->
            Logger.error("Startup task #{name} failed: #{inspect(error)}")
            {:error, error}
        end

      {name, result}
    end)
  end

  defp initialize_dns_resolution do
    Logger.info("🔍 Initializing DNS resolution...")
    DnsResolver.initialize()
  end

  defp run_connectivity_checks do
    Logger.info("🌐 Running connectivity checks...")

    # Test core external services
    services = [
      {"EVE ESI API", "https://esi.evetech.net"},
      {"EVE SSO", "https://login.eveonline.com"},
      {"zkillboard", "https://zkillboard.com"}
    ]

    results =
      Enum.map(services, fn {name, url} ->
        case DnsResolver.test_connectivity(url, 5000) do
          {:ok, :reachable} ->
            Logger.debug("✅ #{name}: reachable")
            :ok

          {:error, reason} ->
            Logger.warning("⚠️ #{name}: unreachable (#{inspect(reason)})")
            {:error, reason}
        end
      end)

    # Check if any critical services failed
    failures = Enum.count(results, fn result -> match?({:error, _}, result) end)

    if failures > 0 do
      Logger.warning("#{failures} external services are unreachable - some features may not work")
    else
      Logger.info("All external services are reachable")
    end

    :ok
  end

  defp validate_environment do
    Logger.info("⚙️ Validating environment configuration...")

    # Check critical environment variables
    required_vars = [
      "DATABASE_URL",
      "SECRET_KEY_BASE"
    ]

    optional_vars = [
      "EVE_SSO_CLIENT_ID",
      "EVE_SSO_CLIENT_SECRET",
      "WANDERER_KILLS_SSE_URL"
    ]

    # Check required variables
    missing_required =
      Enum.filter(required_vars, fn var ->
        case System.get_env(var) do
          nil -> true
          "" -> true
          _value -> false
        end
      end)

    if Enum.empty?(missing_required) do
      Logger.info("✅ All required environment variables are set")

      # Check optional variables
      missing_optional =
        Enum.filter(optional_vars, fn var ->
          case System.get_env(var) do
            nil -> true
            "" -> true
            _value -> false
          end
        end)

      if Enum.empty?(missing_optional) do
        # All optional variables are set
      else
        Logger.info(
          "ℹ️ Optional environment variables not set: #{Enum.join(missing_optional, ", ")}"
        )

        Logger.info("   Some features may be limited without these variables")
      end

      :ok
    else
      Logger.error(
        "❌ Missing required environment variables: #{Enum.join(missing_required, ", ")}"
      )

      {:error, :missing_required_env_vars}
    end
  end

  defp initialize_performance_telemetry do
    Logger.info("📊 Initializing performance telemetry...")

    try do
      PerformanceTelemetry.attach_handlers()
      Logger.info("✅ Performance telemetry handlers attached successfully")
      :ok
    rescue
      error ->
        Logger.warning("⚠️ Failed to attach performance telemetry: #{inspect(error)}")
        {:error, error}
    end
  end

  @doc """
  Handle application startup errors gracefully.
  """
  def handle_startup_error(error, context) do
    Logger.error("Startup error in #{context}: #{inspect(error)}")

    case error do
      %{reason: :nxdomain} ->
        Logger.error("DNS resolution failed - check network connectivity and DNS settings")

      %{reason: :econnrefused} ->
        Logger.error("Connection refused - external services may be down")

      %{reason: :timeout} ->
        Logger.error("Connection timeout - network may be slow or services overloaded")

      _ ->
        Logger.error("Unexpected startup error - check logs for details")
    end

    # Don't crash the application on startup errors
    :ok
  end
end

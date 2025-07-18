# credo:disable-for-this-file Credo.Check.Design.DuplicatedCode
# credo:disable-for-this-file Credo.Check.Refactor.ModuleDependencies
defmodule EveDmv.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  alias EveDmv.Config.RateLimit
  alias EveDmv.Eve.NameResolver
  alias EveDmv.Eve.StaticDataLoader
  alias EveDmv.Performance.RegressionDetector

  @impl Application
  def start(_type, _args) do
    # Initialize ETS table for fitting cache
    :ets.new(:battle_fitting_cache, [:set, :public, :named_table])

    # Initialize EVE name resolver cache early
    NameResolver.start_cache()

    # Only set up security handlers in non-test environments
    if Application.get_env(:eve_dmv, :environment, :prod) != :test do
      # Set up security monitoring handlers
      # EveDmv.Security.AuditLogger.setup_handlers()

      # Set up periodic security headers validation
      # EveDmv.Security.HeadersValidator.setup_periodic_validation()
    end

    # Add logger filter for db_connection noise
    :logger.add_primary_filter(
      :db_connection_noise,
      {&EveDmvWeb.LoggerFilter.filter_db_connection_noise/2, nil}
    )

    base_children = [
      EveDmvWeb.Telemetry,
      # Task supervisor for background tasks (start early)
      {Task.Supervisor, name: EveDmv.TaskSupervisor},
      # Auto-recompilation in dev environment (handled by exsync application)
      # ESI reliability supervisor (includes Registry and circuit breakers)
      EveDmv.Eve.ReliabilitySupervisor,
      # Error monitoring and recovery supervisor
      EveDmv.Monitoring.ErrorRecoverySupervisor,
      EveDmv.Repo,
      {DNSCluster, query: Application.get_env(:eve_dmv, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: EveDmv.PubSub},
      # Domain event infrastructure
      EveDmv.Infrastructure.EventBusSupervisor,
      # Start the Finch HTTP client for sending emails
      {Finch, name: EveDmv.Finch},
      # Start the price cache
      EveDmv.Market.PriceCache,
      # Start the ESI cache
      EveDmv.Eve.EsiCache,
      # Start the analysis cache for character and corporation intelligence
      EveDmv.Cache.AnalysisCache,
      # Start the static data cache for system/ship names
      EveDmv.Cache.StaticDataCache,
      # Start the query cache for expensive database queries
      EveDmv.Cache.QueryCache,
      # Start the performance tracker
      EveDmv.Monitoring.PerformanceTracker,
      # Start the corporation analyzer service
      EveDmv.Contexts.CorporationAnalysis.Domain.CorporationAnalyzer,
      # Start the battle analysis service for combat intelligence
      EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysisService,
      # Start the streaming battle analyzer for large dataset processing
      EveDmv.Contexts.CombatIntelligence.Domain.StreamingBattleAnalyzer,
      # Start the intelligence event publisher for real-time updates
      EveDmv.Intelligence.EventPublisher,
      # Start the real-time intelligence coordinator
      EveDmv.Intelligence.RealTimeCoordinator,
      # Start the token refresh service for automatic EVE SSO token renewal
      EveDmv.Users.TokenRefreshService,
      # Start rate limiter for Janice API (5 requests per second)
      {EveDmv.Market.RateLimiter, [name: :janice_rate_limiter] ++ RateLimit.janice_rate_limit()},
      # Start the Janice API client for market pricing
      EveDmv.Contexts.MarketIntelligence.Infrastructure.JaniceClient,
      # Start the surveillance context (includes matching engine, profile repository, etc.)
      maybe_start_surveillance_context(),
      # Conditionally start database-dependent processes
      maybe_start_database_processes(),
      # Start the Wanderer API client for chain intelligence
      maybe_start_process(EveDmv.Intelligence.WandererClient),
      # Start the Wanderer SSE client for real-time events
      maybe_start_process(EveDmv.Intelligence.WandererSSE),
      # Start the chain monitoring system
      maybe_start_process(EveDmv.Intelligence.ChainAnalysis.ChainMonitor),
      # Start mock SSE server in development
      maybe_start_mock_sse_server(),
      # Start the killmail ingestion pipeline
      maybe_start_pipeline(),
      # Start background static data loader
      static_data_loader_spec(),
      # Start SDE automatic update service
      maybe_start_sde_startup_service(),
      # Start a worker by calling: EveDmv.Worker.start_link(arg)
      # {EveDmv.Worker, arg},
      # Start to serve requests, typically the last entry
      EveDmvWeb.Endpoint
    ]

    children = List.flatten(base_children)

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: EveDmv.Supervisor]

    # Start the supervisor
    case Supervisor.start_link(children, opts) do
      {:ok, pid} ->
        # Initialize DNS resolution and connectivity checks
        Task.start(fn ->
          try do
            EveDmv.ApplicationStartup.initialize()
          rescue
            error ->
              EveDmv.ApplicationStartup.handle_startup_error(error, "DNS initialization")
          end
        end)

        # Bootstrap admin users from environment variables
        Task.start(fn ->
          try do
            # Wait for database to be ready
            wait_for_database_ready()

            if EveDmv.Admin.Bootstrap.bootstrap_configured?() do
              # Skip if admin users already exist
              case check_existing_admin_users() do
                {:ok, false} ->
                  EveDmv.Admin.Bootstrap.bootstrap_from_env()

                {:ok, true} ->
                  require Logger
                  Logger.info("Admin users already exist, skipping bootstrap")

                {:error, _} ->
                  # Database not ready or other issue, proceed with bootstrap attempt
                  EveDmv.Admin.Bootstrap.bootstrap_from_env()
              end
            end
          rescue
            error ->
              require Logger
              Logger.error("Admin bootstrap failed: #{inspect(error)}")
          end
        end)

        # Attach global error telemetry handlers
        EveDmv.ErrorHandler.attach_telemetry_handlers()

        # Attach query performance monitoring
        EveDmv.Performance.QueryMonitor.attach_telemetry_handlers()

        # Start performance regression detection
        if Application.get_env(:eve_dmv, :environment, :prod) != :test do
          RegressionDetector.start_link()
        end

        {:ok, pid}

      error ->
        error
    end
  end

  # Conditionally start database-dependent processes
  defp maybe_start_database_processes do
    if Application.get_env(:eve_dmv, :environment, :prod) != :test do
      [
        EveDmv.Telemetry.QueryMonitor,
        # EveDmv.Database.QueryCache, # Removed - duplicate of EveDmv.Cache.QueryCache
        EveDmv.Database.CacheWarmer,
        EveDmv.Database.ConnectionPoolMonitor,
        EveDmv.Database.PartitionManager,
        EveDmv.Database.CacheInvalidator,
        EveDmv.Database.CacheHashManager,
        EveDmv.Database.QueryPlanAnalyzer,
        EveDmv.Database.MaterializedViewManager,
        EveDmv.Database.ArchiveManager,
        EveDmv.Enrichment.ReEnrichmentWorker,
        EveDmv.Enrichment.RealTimePriceUpdater,
        # Ship role analysis worker for continuous fleet intelligence
        EveDmv.Workers.ShipRoleAnalysisWorker,
        # Intelligence analysis supervisor for managing analysis tasks
        EveDmv.Intelligence.Core.Supervisor,
        # Historical import pipeline (Sprint 15A)
        EveDmv.Historical.ImportPipeline,
        EveDmv.Historical.ImportProgressMonitor,
        # Performance monitoring dashboard (Sprint 15A)
        EveDmv.Monitoring.PerformanceDashboard
      ]
    else
      []
    end
  end

  # Conditionally start surveillance context
  defp maybe_start_surveillance_context do
    if Application.get_env(:eve_dmv, :environment, :prod) != :test do
      EveDmv.Contexts.Surveillance
    else
      %{
        id: EveDmv.Contexts.Surveillance,
        start: {Task, :start_link, [fn -> Process.sleep(:infinity) end]}
      }
    end
  end

  # Conditionally start a process based on environment
  defp maybe_start_process(module) do
    if Application.get_env(:eve_dmv, :environment, :prod) != :test do
      module
    else
      %{id: module, start: {Task, :start_link, [fn -> Process.sleep(:infinity) end]}}
    end
  end

  # Conditionally start the mock SSE server in development
  defp maybe_start_mock_sse_server do
    # Check both application config and environment variable directly
    # since .env loading might happen after application config
    enabled =
      Application.get_env(:eve_dmv, :mock_sse_server_enabled, false) or
        System.get_env("MOCK_SSE_SERVER_ENABLED", "false") == "true"

    if enabled do
      EveDmv.Killmails.MockSSEServer
    else
      # Return a no-op process if mock server is disabled
      %{id: :noop_mock_server, start: {Task, :start_link, [fn -> Process.sleep(:infinity) end]}}
    end
  end

  # Conditionally start the killmail pipeline based on configuration
  defp maybe_start_pipeline do
    pipeline_enabled = Application.get_env(:eve_dmv, :pipeline_enabled, true)

    if pipeline_enabled do
      EveDmv.Killmails.KillmailPipeline
    else
      # Return a no-op process if pipeline is disabled
      %{id: :noop_pipeline, start: {Task, :start_link, [fn -> Process.sleep(:infinity) end]}}
    end
  end

  # Spec for background static data loader
  defp static_data_loader_spec do
    if Application.get_env(:eve_dmv, :environment, :prod) != :test do
      %{
        id: :static_data_loader,
        start: {
          Task,
          :start_link,
          [
            fn ->
              delay_ms = Application.get_env(:eve_dmv, :static_data_load_delay, 5_000)
              Process.sleep(delay_ms)
              ensure_static_data_loaded()
            end
          ]
        },
        restart: :transient
      }
    else
      # No-op process for tests
      %{
        id: :static_data_loader_noop,
        start: {Task, :start_link, [fn -> Process.sleep(:infinity) end]}
      }
    end
  end

  # Conditionally start the SDE automatic update service
  defp maybe_start_sde_startup_service do
    if Application.get_env(:eve_dmv, :environment, :prod) != :test do
      EveDmv.Eve.StaticDataLoader.SdeStartupService
    else
      # No-op process for tests
      %{
        id: :sde_startup_service_noop,
        start: {Task, :start_link, [fn -> Process.sleep(:infinity) end]}
      }
    end
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl Application
  def config_change(changed, _new, removed) do
    EveDmvWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  # Ensure static data is loaded, but don't block application startup
  defp ensure_static_data_loaded do
    require Logger

    case StaticDataLoader.static_data_loaded?() do
      %{item_types: true, solar_systems: true} ->
        Logger.info("Static data already loaded")

      _ ->
        Logger.info("Static data not found, loading EVE static data in background...")

        case StaticDataLoader.load_all_static_data() do
          {:ok, %{item_types: item_count, solar_systems: system_count}} ->
            Logger.info(
              "Successfully loaded #{item_count} item types and #{system_count} solar systems"
            )

            # Warm the cache after loading
            NameResolver.warm_cache()
            Logger.info("Name resolver cache warmed")

          {:error, reason} ->
            Logger.error("Failed to load static data: #{inspect(reason)}")
        end
    end
  end

  # Wait for database to be ready with exponential backoff
  defp wait_for_database_ready(attempts \\ 0, max_attempts \\ 10) do
    require Logger

    if attempts >= max_attempts do
      Logger.warning("Database readiness check timeout after #{max_attempts} attempts")
      :timeout
    else
      case check_database_connection() do
        :ok ->
          Logger.info("Database is ready")
          :ok

        {:error, reason} ->
          wait_time = (:math.pow(2, attempts) * 100) |> round() |> min(5000)
          Logger.debug("Database not ready (#{reason}), retrying in #{wait_time}ms...")
          Process.sleep(wait_time)
          wait_for_database_ready(attempts + 1, max_attempts)
      end
    end
  end

  # Check if database connection is available
  defp check_database_connection do
    try do
      case Ecto.Adapters.SQL.query(EveDmv.Repo, "SELECT 1", []) do
        {:ok, _} -> :ok
        {:error, %{message: message}} -> {:error, message}
        _ -> {:error, "Unknown database error"}
      end
    rescue
      error -> {:error, inspect(error)}
    end
  end

  # Check if admin users already exist
  defp check_existing_admin_users do
    try do
      case Ecto.Adapters.SQL.query(
             EveDmv.Repo,
             "SELECT EXISTS(SELECT 1 FROM users WHERE is_admin = true)",
             []
           ) do
        {:ok, %{rows: [[true]]}} -> {:ok, true}
        {:ok, %{rows: [[false]]}} -> {:ok, false}
        {:error, reason} -> {:error, reason}
      end
    rescue
      error -> {:error, inspect(error)}
    end
  end
end

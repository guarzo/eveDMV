defmodule EveDmv.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Initialize EVE name resolver cache early
    EveDmv.Eve.NameResolver.start_cache()

    # Only set up security handlers in non-test environments  
    if Mix.env() != :test do
      # Set up security monitoring handlers
      # EveDmv.Security.AuditLogger.setup_handlers()

      # Set up periodic security headers validation
      # EveDmv.Security.HeadersValidator.setup_periodic_validation()
    end

    base_children = [
      EveDmvWeb.Telemetry,
      # Task supervisor for background tasks (start early)
      {Task.Supervisor, name: EveDmv.TaskSupervisor},
      # ESI reliability supervisor (includes Registry and circuit breakers)
      EveDmv.Eve.ReliabilitySupervisor,
      EveDmv.Repo,
      {DNSCluster, query: Application.get_env(:eve_dmv, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: EveDmv.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: EveDmv.Finch},
      # Start the price cache
      EveDmv.Market.PriceCache,
      # Start the ESI cache
      EveDmv.Eve.EsiCache,
      # Start rate limiter for Janice API (5 requests per second)
      {EveDmv.Market.RateLimiter,
       [name: :janice_rate_limiter] ++ EveDmv.Config.RateLimit.janice_rate_limit()},
      # Start the surveillance matching engine
      maybe_start_surveillance_engine(),
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
      # Start a worker by calling: EveDmv.Worker.start_link(arg)
      # {EveDmv.Worker, arg},
      # Start to serve requests, typically the last entry
      EveDmvWeb.Endpoint
    ]

    children = List.flatten(base_children)

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: EveDmv.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Conditionally start database-dependent processes
  defp maybe_start_database_processes do
    if Mix.env() != :test do
      [
        EveDmv.Telemetry.QueryMonitor,
        EveDmv.Database.QueryCache,
        EveDmv.Database.CacheWarmer,
        EveDmv.Database.ConnectionPoolMonitor,
        EveDmv.Database.PartitionManager,
        EveDmv.Database.CacheInvalidator,
        EveDmv.Database.QueryPlanAnalyzer,
        EveDmv.Database.MaterializedViewManager,
        EveDmv.Database.ArchiveManager,
        EveDmv.Enrichment.ReEnrichmentWorker,
        EveDmv.Enrichment.RealTimePriceUpdater,
        # Intelligence analysis cache with Cachex
        EveDmv.Intelligence.Cache.AnalysisCache,
        # Intelligence analysis supervisor for managing analysis tasks
        EveDmv.Intelligence.Core.Supervisor
      ]
    else
      []
    end
  end

  # Conditionally start surveillance engine
  defp maybe_start_surveillance_engine do
    if Mix.env() != :test do
      EveDmv.Surveillance.MatchingEngine
    else
      %{
        id: EveDmv.Surveillance.MatchingEngine,
        start: {Task, :start_link, [fn -> Process.sleep(:infinity) end]}
      }
    end
  end

  # Conditionally start a process based on environment
  defp maybe_start_process(module) do
    if Mix.env() != :test do
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
    if Mix.env() != :test do
      %{
        id: :static_data_loader,
        start: {
          Task,
          :start_link,
          [
            fn ->
              delay_ms = Application.get_env(:eve_dmv, :static_data_load_delay, 5000)
              Process.sleep(delay_ms)
              ensure_static_data_loaded()
            end
          ]
        },
        restart: :transient
      }
    else
      %{
        id: :static_data_loader_noop,
        start: {Task, :start_link, [fn -> Process.sleep(:infinity) end]}
      }
    end
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    EveDmvWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  # Ensure static data is loaded, but don't block application startup
  defp ensure_static_data_loaded do
    alias EveDmv.Eve.StaticDataLoader
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
            EveDmv.Eve.NameResolver.warm_cache()
            Logger.info("Name resolver cache warmed")

          {:error, reason} ->
            Logger.error("Failed to load static data: #{inspect(reason)}")
        end
    end
  end
end

defmodule EveDmv.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Initialize EVE name resolver cache early
    EveDmv.Eve.NameResolver.start_cache()

    # Set up security monitoring handlers
    EveDmv.Security.AuditLogger.setup_handlers()
    
    # Set up periodic security headers validation
    EveDmv.Security.HeadersValidator.setup_periodic_validation()

    children = [
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
      {EveDmv.Market.RateLimiter, name: :janice_rate_limiter, max_tokens: 5, refill_rate: 5},
      # Start the surveillance matching engine
      EveDmv.Surveillance.MatchingEngine,
      # Start the query performance monitor
      EveDmv.Telemetry.QueryMonitor,
      # Start the query result cache
      EveDmv.Database.QueryCache,
      # Start the intelligent cache warmer
      EveDmv.Database.CacheWarmer,
      # Start the re-enrichment worker
      EveDmv.Enrichment.ReEnrichmentWorker,
      # Start the real-time price updater
      EveDmv.Enrichment.RealTimePriceUpdater,
      # Start the Wanderer API client for chain intelligence
      EveDmv.Intelligence.WandererClient,
      # Start the Wanderer SSE client for real-time events
      EveDmv.Intelligence.WandererSSE,
      # Start the chain monitoring system
      EveDmv.Intelligence.ChainMonitor,
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

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: EveDmv.Supervisor]
    Supervisor.start_link(children, opts)
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

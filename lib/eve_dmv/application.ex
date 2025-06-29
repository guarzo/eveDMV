defmodule EveDmv.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Initialize EVE name resolver cache early
    :ok = EveDmv.Eve.NameResolver.start_cache()

    children = [
      EveDmvWeb.Telemetry,
      EveDmv.Repo,
      {DNSCluster, query: Application.get_env(:eve_dmv, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: EveDmv.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: EveDmv.Finch},
      # Start mock SSE server in development
      maybe_start_mock_sse_server(),
      # Start the killmail ingestion pipeline
      maybe_start_pipeline(),
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

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    EveDmvWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end

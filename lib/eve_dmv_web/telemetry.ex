defmodule EveDmvWeb.Telemetry do
  @moduledoc """
  Telemetry supervisor for monitoring and metrics collection.
  """

  use Supervisor
  import Telemetry.Metrics

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    children = [
      # Telemetry poller will execute the given period measurements
      # every 10_000ms. Learn more here: https://hexdocs.pm/telemetry_metrics
      {:telemetry_poller, measurements: periodic_measurements(), period: 10_000}
      # Add reporters as children of your supervision tree.
      # {Telemetry.Metrics.ConsoleReporter, metrics: metrics()}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def metrics do
    [
      # Phoenix Metrics
      summary("phoenix.endpoint.start.system_time",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.endpoint.stop.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.start.system_time",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.exception.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.stop.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.socket_connected.duration",
        unit: {:native, :millisecond}
      ),
      sum("phoenix.socket_drain.count"),
      summary("phoenix.channel_joined.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.channel_handled_in.duration",
        tags: [:event],
        unit: {:native, :millisecond}
      ),

      # Database Metrics
      summary("eve_dmv.repo.query.total_time",
        unit: {:native, :millisecond},
        description: "The sum of the other measurements"
      ),
      summary("eve_dmv.repo.query.decode_time",
        unit: {:native, :millisecond},
        description: "The time spent decoding the data received from the database"
      ),
      summary("eve_dmv.repo.query.query_time",
        unit: {:native, :millisecond},
        description: "The time spent executing the query"
      ),
      summary("eve_dmv.repo.query.queue_time",
        unit: {:native, :millisecond},
        description: "The time spent waiting for a database connection"
      ),
      summary("eve_dmv.repo.query.idle_time",
        unit: {:native, :millisecond},
        description:
          "The time the connection spent waiting before being checked out for the query"
      ),

      # VM Metrics
      summary("vm.memory.total", unit: {:byte, :kilobyte}),
      summary("vm.total_run_queue_lengths.total"),
      summary("vm.total_run_queue_lengths.cpu"),
      summary("vm.total_run_queue_lengths.io"),

      # EVE DMV Pipeline Metrics
      counter("eve_dmv.killmail.processed.count",
        description: "Total killmails processed by the pipeline"
      ),
      counter("eve_dmv.killmail.enriched.count",
        description: "Total killmails successfully enriched"
      ),
      counter("eve_dmv.killmail.failed.count",
        description: "Total killmail processing failures"
      ),
      summary("eve_dmv.killmail.processing_time",
        unit: {:native, :millisecond},
        description: "Time taken to process each killmail"
      ),
      summary("eve_dmv.killmail.batch_size",
        description: "Number of killmails processed per batch"
      ),

      # Price Service Metrics
      counter("eve_dmv.price.lookup.count",
        tags: [:source],
        description: "Price lookups by source (janice, mutamarket, esi, base)"
      ),
      counter("eve_dmv.price.cache.hit.count",
        description: "Price cache hits"
      ),
      counter("eve_dmv.price.cache.miss.count",
        description: "Price cache misses"
      ),
      summary("eve_dmv.price.lookup_time",
        tags: [:source],
        unit: {:native, :millisecond},
        description: "Time taken for price lookups"
      ),

      # Surveillance Metrics
      counter("eve_dmv.surveillance.profile.match.count",
        description: "Total surveillance profile matches"
      ),
      counter("eve_dmv.surveillance.profile.evaluated.count",
        description: "Total profiles evaluated against killmails"
      ),
      summary("eve_dmv.surveillance.matching_time",
        unit: {:native, :millisecond},
        description: "Time taken to match killmails against profiles"
      ),
      summary("eve_dmv.surveillance.active_profiles",
        description: "Number of active surveillance profiles"
      ),

      # Name Resolution Metrics
      counter("eve_dmv.name_resolver.lookup.count",
        tags: [:type],
        description: "Name resolution lookups by type (character, corp, alliance, ship, system)"
      ),
      counter("eve_dmv.name_resolver.cache.hit.count",
        tags: [:type],
        description: "Name resolver cache hits by type"
      ),
      counter("eve_dmv.name_resolver.cache.miss.count",
        tags: [:type],
        description: "Name resolver cache misses by type"
      ),
      summary("eve_dmv.name_resolver.lookup_time",
        tags: [:type],
        unit: {:native, :millisecond},
        description: "Time taken for name resolution"
      ),

      # ESI Client Metrics
      counter("eve_dmv.esi.request.count",
        tags: [:endpoint, :status],
        description: "ESI API requests by endpoint and status"
      ),
      summary("eve_dmv.esi.request_time",
        tags: [:endpoint],
        unit: {:native, :millisecond},
        description: "ESI API request duration"
      ),
      counter("eve_dmv.esi.rate_limit.hit.count",
        description: "ESI rate limit hits"
      ),

      # Re-enrichment Metrics
      counter("eve_dmv.re_enrichment.price_update.count",
        description: "Price re-enrichment operations"
      ),
      counter("eve_dmv.re_enrichment.name_update.count",
        description: "Name re-enrichment operations"
      ),
      summary("eve_dmv.re_enrichment.batch_time",
        tags: [:type],
        unit: {:native, :millisecond},
        description: "Time taken for re-enrichment batches"
      )
    ]
  end

  defp periodic_measurements do
    [
      # EVE DMV specific measurements
      {__MODULE__, :measure_surveillance_profiles, []},
      {__MODULE__, :measure_cache_stats, []},
      {__MODULE__, :measure_pipeline_stats, []}
    ]
  end

  @doc """
  Measure surveillance profile statistics.
  """
  def measure_surveillance_profiles do
    case EveDmv.Surveillance.MatchingEngine.get_stats() do
      %{profiles_loaded: count} when is_integer(count) ->
        :telemetry.execute([:eve_dmv, :surveillance, :active_profiles], %{}, %{value: count})

      _ ->
        :ok
    end
  catch
    :exit, {:noproc, _} ->
      # MatchingEngine not started yet
      :ok

    _, _ ->
      # Any other error
      :ok
  end

  @doc """
  Measure cache statistics.
  """
  def measure_cache_stats do
    # Name resolver cache stats
    case :ets.whereis(:eve_name_cache) do
      :undefined ->
        :ok

      _pid ->
        cache_size = :ets.info(:eve_name_cache, :size)

        :telemetry.execute([:eve_dmv, :name_resolver, :cache_size], %{}, %{
          size: cache_size || 0
        })
    end

    # Price cache stats
    case :ets.whereis(:price_cache) do
      :undefined ->
        :ok

      _pid ->
        price_cache_size = :ets.info(:price_cache, :size)
        :telemetry.execute([:eve_dmv, :price, :cache_size], %{}, %{size: price_cache_size || 0})
    end
  rescue
    _ -> :ok
  end

  @doc """
  Measure pipeline statistics.
  """
  def measure_pipeline_stats do
    # Broadway pipeline stats would go here
    # For now, just emit a heartbeat
    :telemetry.execute([:eve_dmv, :pipeline, :heartbeat], %{}, %{
      timestamp: System.system_time(:second)
    })
  rescue
    _ -> :ok
  end
end

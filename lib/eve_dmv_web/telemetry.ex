defmodule EveDmvWeb.Telemetry do
  @moduledoc """
  Telemetry supervisor for monitoring and metrics collection.
  """

  use Supervisor
  import Telemetry.Metrics

  alias EveDmv.Surveillance.MatchingEngine

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl Supervisor
  def init(_arg) do
    # Set up simple telemetry handlers for basic monitoring
    EveDmv.Telemetry.setup()

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
      ),

      # Database Connection Pool Metrics
      counter("eve_dmv.database.pool.alert.count",
        tags: [:type, :severity],
        description: "Database pool alerts by type and severity"
      ),
      last_value("eve_dmv.database.pool.utilization",
        description: "Database pool utilization percentage"
      ),
      last_value("eve_dmv.database.pool.queue_length",
        description: "Number of processes waiting for database connections"
      ),
      last_value("eve_dmv.database.pool.available",
        description: "Available database connections"
      )
    ]
  end

  defp periodic_measurements do
    [
      # EVE DMV specific measurements
      {__MODULE__, :measure_surveillance_profiles, []},
      {__MODULE__, :measure_cache_stats, []},
      {__MODULE__, :measure_pipeline_stats, []},
      {__MODULE__, :measure_database_pool, []}
    ]
  end

  @doc """
  Measure surveillance profile statistics.
  """
  def measure_surveillance_profiles do
    case MatchingEngine.get_stats() do
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

  @doc """
  Measure database connection pool statistics.

  **Important**: These metrics are heuristic estimates, not exact pool state.

  DBConnection pools do not expose their internal busy/idle connection counts directly.
  Instead, this function estimates pool utilization by measuring the time it takes to
  check out a connection and execute a trivial query. Fast checkouts indicate a healthy
  pool with available connections, while slow checkouts suggest contention.

  The returned metrics (`utilization`, `available`, `queue_length`) should be treated
  as approximate indicators of pool health rather than precise measurements. For exact
  pool state, consider using DBConnection telemetry events or implementing a custom
  pool wrapper that tracks connection state transitions.

  See `get_pool_stats/0` for details on the estimation methodology.
  """
  def measure_database_pool do
    case get_pool_stats() do
      {:ok, %{busy: busy, idle: idle, queue_length: queue_length, pool_size: _pool_size}} ->
        available = idle
        total = busy + idle
        utilization = if total > 0, do: busy / total * 100, else: 0.0

        :telemetry.execute(
          [:eve_dmv, :database, :pool, :utilization],
          %{value: utilization},
          %{}
        )

        :telemetry.execute(
          [:eve_dmv, :database, :pool, :queue_length],
          %{value: queue_length},
          %{}
        )

        :telemetry.execute(
          [:eve_dmv, :database, :pool, :available],
          %{value: available},
          %{}
        )

      {:error, _reason, pool_size} ->
        # Pool not available, emit zeros
        :telemetry.execute(
          [:eve_dmv, :database, :pool, :utilization],
          %{value: 0.0},
          %{}
        )

        :telemetry.execute(
          [:eve_dmv, :database, :pool, :queue_length],
          %{value: 0},
          %{}
        )

        :telemetry.execute(
          [:eve_dmv, :database, :pool, :available],
          %{value: pool_size},
          %{}
        )
    end
  rescue
    _ -> :ok
  end

  # Estimates pool statistics using checkout timing as a proxy for pool saturation.
  #
  # **Why estimation is necessary**: DBConnection pools (used by Ecto) do not expose
  # their internal state (busy/idle connection counts, queue length) through a public
  # API. The pool manages connections internally and only provides checkout/checkin
  # operations.
  #
  # **Methodology**: This function performs a trivial `SELECT 1` query and measures
  # the checkout time. The checkout time reflects how long the caller waited for a
  # connection to become available:
  #
  #   - Fast checkout (<1ms): Pool has idle connections readily available
  #   - Slow checkout (>10ms): Pool is saturated, requests are likely queuing
  #
  # **Limitations**:
  #   - The busy/idle counts are rough estimates, not actual values
  #   - The queue_length is a binary indicator (0 or 1), not an actual count
  #   - A single measurement may not reflect sustained pool pressure
  #   - Network latency to the database affects timing
  #
  # **Alternatives for precise metrics**:
  #   - Subscribe to DBConnection telemetry events (`:db_connection` events)
  #   - Use a custom pool implementation that tracks state
  #   - Monitor PostgreSQL's `pg_stat_activity` for connection state
  defp get_pool_stats do
    repo_config = EveDmv.Repo.config()
    pool_size = Keyword.get(repo_config, :pool_size, 10)

    # Get the pool from the repo and query its state
    # DBConnection pools track busy/idle connections internally
    repo_pid = Process.whereis(EveDmv.Repo)

    if repo_pid && Process.alive?(repo_pid) do
      # Use Ecto's internal pool query mechanism
      # The pool is typically a DBConnection.ConnectionPool
      try do
        # Get pool status via checkout timing - a quick checkout indicates healthy pool
        checkout_start = System.monotonic_time(:microsecond)

        result =
          Ecto.Adapters.SQL.query(
            EveDmv.Repo,
            "SELECT 1",
            [],
            timeout: 100,
            queue_target: 50
          )

        checkout_time = System.monotonic_time(:microsecond) - checkout_start

        case result do
          {:ok, _} ->
            # Estimate pool health based on checkout time
            # Fast checkout (<1ms) = healthy pool, slow checkout = pressure

            # Estimate busy connections based on checkout latency.
            # Since DBConnection pools don't expose busy/idle counts directly,
            # we use checkout timing as a proxy for pool saturation.
            #
            # Threshold rationale (all values in microseconds):
            #   < 1,000 us (1ms): Pool is healthy with ample idle connections.
            #                     Immediate checkout indicates no contention.
            #                     Estimated busy = 0 (all connections readily available).
            #
            #   < 5,000 us (5ms): Minor contention, ~25% pool utilization.
            #                     Slight delay suggests some connections are busy
            #                     but the pool is not under significant pressure.
            #                     Estimated busy = pool_size / 4.
            #
            #   < 10,000 us (10ms): Moderate contention, ~50% pool utilization.
            #                       Noticeable checkout delay indicates half the
            #                       connections are likely in use.
            #                       Estimated busy = pool_size / 2.
            #
            #   >= 10,000 us: High contention, pool nearly saturated.
            #                 Long checkout times indicate most connections are
            #                 busy and requests may be queuing.
            #                 Estimated busy = pool_size - 1.
            estimated_busy =
              cond do
                checkout_time < 1_000 -> 0
                checkout_time < 5_000 -> div(pool_size, 4)
                checkout_time < 10_000 -> div(pool_size, 2)
                true -> pool_size - 1
              end

            # queue_length is a coarse binary estimate (0 or 1) based on checkout time.
            # This is NOT the actual number of processes waiting for connections.
            # It serves as a simple indicator: 1 means the pool is likely saturated
            # and requests are probably queuing; 0 means the pool appears healthy.
            # For precise queue metrics, consider using DBConnection telemetry events
            # or implementing a custom pool wrapper.
            {:ok,
             %{
               busy: estimated_busy,
               idle: pool_size - estimated_busy,
               queue_length: if(checkout_time > 10_000, do: 1, else: 0),
               pool_size: pool_size
             }}

          {:error, _} ->
            {:error, :query_failed, pool_size}
        end
      rescue
        DBConnection.ConnectionError ->
          {:error, :connection_error, pool_size}

        _ ->
          {:error, :unknown, pool_size}
      end
    else
      {:error, :repo_not_started, pool_size}
    end
  end
end

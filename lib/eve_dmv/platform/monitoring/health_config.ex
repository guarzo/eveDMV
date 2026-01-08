defmodule EveDmv.Platform.Monitoring.HealthConfig do
  @moduledoc """
  Configuration constants for health monitoring thresholds.

  All values are documented with rationale based on production system
  monitoring best practices and Phoenix/Elixir application behavior.

  ## Status Levels

  Health status is classified into three levels:
  - `:healthy` - System operating within normal parameters
  - `:warning` - System approaching resource limits, investigation recommended
  - `:critical` - System at risk of degradation, immediate action required

  ## Database Pool Thresholds

  Database connection pool utilization thresholds are based on Ecto pool
  behavior. When the pool approaches capacity, connection checkout times
  increase and application latency rises.

  - `pool_utilization_critical` (90%): At 90% utilization, the pool is nearly
    exhausted. Any burst in traffic may cause connection timeouts.
  - `pool_utilization_warning` (70%): At 70% utilization, the pool is under
    significant load. Consider scaling or optimizing queries.
  - `pool_queue_warning` (5): More than 5 requests waiting for connections
    indicates pool saturation is imminent.

  ## Pipeline Thresholds

  Broadway pipeline success rates indicate data ingestion health. Killmail
  processing should maintain high reliability.

  - `pipeline_success_rate_critical` (90%): Below 90% success rate indicates
    significant data loss that requires immediate investigation.
  - `pipeline_success_rate_warning` (95%): Below 95% success rate indicates
    some processing failures that should be monitored.
  - `pipeline_failed_messages_warning` (100): More than 100 failed messages
    accumulated indicates a persistent issue.

  ## Cache Thresholds

  Cache hit rates affect application performance. Low hit rates indicate
  cache misses are forcing database queries.

  - `cache_hit_rate_critical` (50%): Below 50% hit rate means the cache is
    not effective and adds overhead. Investigate cache configuration.
  - `cache_hit_rate_warning` (70%): Below 70% hit rate indicates suboptimal
    caching. Consider increasing TTL or cache size.

  ## Memory Thresholds

  BEAM memory thresholds are based on typical Phoenix application behavior.
  Memory usage varies by workload, but sustained high usage can lead to
  garbage collection pressure.

  - `memory_mb_critical` (4096 MB / 4 GB): At 4GB, the application is consuming
    significant memory. Risk of OOM if load increases.
  - `memory_mb_warning` (2048 MB / 2 GB): At 2GB, memory usage is elevated.
    Monitor for memory leaks or inefficient data structures.

  ## LiveView Thresholds

  LiveView socket counts indicate concurrent user load. Each LiveView
  maintains a persistent WebSocket connection.

  - `liveview_sockets_critical` (5000): 5000+ concurrent sockets indicates
    very high load. Consider horizontal scaling.
  - `liveview_sockets_warning` (1000): 1000+ concurrent sockets indicates
    significant user activity. Monitor resource usage.

  ## Query Health Thresholds

  Slow query and N+1 detection thresholds help identify database performance
  issues before they impact users.

  - `slow_queries_critical` (10): More than 10 slow queries indicates
    systemic performance issues requiring optimization.
  - `slow_queries_warning` (5): More than 5 slow queries warrants
    investigation to prevent degradation.
  - `n_plus_one_warning` (3): More than 3 N+1 query patterns detected
    indicates inefficient data loading.
  """

  # =============================================================================
  # Database Pool Thresholds
  # =============================================================================

  # At 90% utilization, the connection pool is nearly exhausted.
  # Any burst in traffic may cause connection checkout timeouts.
  # Based on Ecto pool documentation recommending headroom for traffic spikes.
  @pool_utilization_critical 90

  # At 70% utilization, the pool is under significant load.
  # This threshold provides early warning before reaching critical levels.
  @pool_utilization_warning 70

  # More than 5 requests waiting for connections indicates pool saturation.
  # Queue buildup is an early indicator of pool exhaustion.
  @pool_queue_warning 5

  # =============================================================================
  # Pipeline Thresholds
  # =============================================================================

  # Below 90% success rate indicates significant data loss in the killmail
  # ingestion pipeline. At this level, investigation is urgent.
  @pipeline_success_rate_critical 90

  # Below 95% success rate indicates processing failures that should be
  # monitored. Some message loss is expected during error conditions.
  @pipeline_success_rate_warning 95

  # More than 100 accumulated failed messages indicates a persistent issue
  # rather than transient failures.
  @pipeline_failed_messages_warning 100

  # =============================================================================
  # Cache Thresholds
  # =============================================================================

  # Below 50% hit rate, the cache is not providing value and adds overhead.
  # This typically indicates cache configuration issues or access patterns
  # that don't benefit from caching.
  @cache_hit_rate_critical 50

  # Below 70% hit rate indicates suboptimal caching performance.
  # Consider reviewing TTL settings, cache size, or access patterns.
  @cache_hit_rate_warning 70

  # =============================================================================
  # Memory Thresholds (in MB)
  # =============================================================================

  # At 4GB memory usage, the BEAM is consuming significant resources.
  # Risk of OOM under increased load. Based on typical container limits.
  @memory_mb_critical 4096

  # At 2GB memory usage, investigate for potential memory leaks or
  # inefficient data structures. Provides time to address before critical.
  @memory_mb_warning 2048

  # =============================================================================
  # LiveView Socket Thresholds
  # =============================================================================

  # 5000+ concurrent LiveView sockets indicates very high load.
  # Each socket maintains state and requires memory. Consider scaling.
  @liveview_sockets_critical 5000

  # 1000+ concurrent sockets indicates significant user activity.
  # Monitor memory and CPU usage at this level.
  @liveview_sockets_warning 1000

  # =============================================================================
  # Query Health Thresholds
  # =============================================================================

  # More than 10 slow queries indicates systemic database performance issues.
  # Immediate optimization required to prevent user-facing latency.
  @slow_queries_critical 10

  # More than 5 slow queries warrants investigation.
  # Provides early warning of emerging performance issues.
  @slow_queries_warning 5

  # More than 3 N+1 query patterns indicates inefficient data loading.
  # These should be resolved with preloading or query optimization.
  @n_plus_one_warning 3

  # =============================================================================
  # Public API - Database Pool Thresholds
  # =============================================================================

  @doc """
  Returns the critical threshold for database pool utilization (90%).

  At this level, the connection pool is nearly exhausted and any traffic
  burst may cause connection timeouts.
  """
  @spec pool_utilization_critical() :: integer()
  def pool_utilization_critical, do: @pool_utilization_critical

  @doc """
  Returns the warning threshold for database pool utilization (70%).

  At this level, the pool is under significant load and should be monitored.
  """
  @spec pool_utilization_warning() :: integer()
  def pool_utilization_warning, do: @pool_utilization_warning

  @doc """
  Returns the warning threshold for database pool queue length (5).

  More than this many requests waiting indicates pool saturation is imminent.
  """
  @spec pool_queue_warning() :: integer()
  def pool_queue_warning, do: @pool_queue_warning

  # =============================================================================
  # Public API - Pipeline Thresholds
  # =============================================================================

  @doc """
  Returns the critical threshold for pipeline success rate (90%).

  Below this rate indicates significant data loss requiring investigation.
  """
  @spec pipeline_success_rate_critical() :: integer()
  def pipeline_success_rate_critical, do: @pipeline_success_rate_critical

  @doc """
  Returns the warning threshold for pipeline success rate (95%).

  Below this rate indicates processing failures that should be monitored.
  """
  @spec pipeline_success_rate_warning() :: integer()
  def pipeline_success_rate_warning, do: @pipeline_success_rate_warning

  @doc """
  Returns the warning threshold for accumulated failed messages (100).

  More than this many failures indicates a persistent processing issue.
  """
  @spec pipeline_failed_messages_warning() :: integer()
  def pipeline_failed_messages_warning, do: @pipeline_failed_messages_warning

  # =============================================================================
  # Public API - Cache Thresholds
  # =============================================================================

  @doc """
  Returns the critical threshold for cache hit rate (50%).

  Below this rate, the cache is not providing value and adds overhead.
  """
  @spec cache_hit_rate_critical() :: integer()
  def cache_hit_rate_critical, do: @cache_hit_rate_critical

  @doc """
  Returns the warning threshold for cache hit rate (70%).

  Below this rate indicates suboptimal caching performance.
  """
  @spec cache_hit_rate_warning() :: integer()
  def cache_hit_rate_warning, do: @cache_hit_rate_warning

  # =============================================================================
  # Public API - Memory Thresholds
  # =============================================================================

  @doc """
  Returns the critical threshold for total BEAM memory usage in MB (4096 MB / 4 GB).

  At this level, the application is consuming significant resources with OOM risk.
  """
  @spec memory_mb_critical() :: integer()
  def memory_mb_critical, do: @memory_mb_critical

  @doc """
  Returns the warning threshold for total BEAM memory usage in MB (2048 MB / 2 GB).

  At this level, investigate for potential memory leaks.
  """
  @spec memory_mb_warning() :: integer()
  def memory_mb_warning, do: @memory_mb_warning

  # =============================================================================
  # Public API - LiveView Thresholds
  # =============================================================================

  @doc """
  Returns the critical threshold for concurrent LiveView sockets (5000).

  At this level, consider horizontal scaling to handle the load.
  """
  @spec liveview_sockets_critical() :: integer()
  def liveview_sockets_critical, do: @liveview_sockets_critical

  @doc """
  Returns the warning threshold for concurrent LiveView sockets (1000).

  At this level, monitor memory and CPU usage closely.
  """
  @spec liveview_sockets_warning() :: integer()
  def liveview_sockets_warning, do: @liveview_sockets_warning

  # =============================================================================
  # Public API - Query Health Thresholds
  # =============================================================================

  @doc """
  Returns the critical threshold for slow query count (10).

  More than this many slow queries indicates systemic performance issues.
  """
  @spec slow_queries_critical() :: integer()
  def slow_queries_critical, do: @slow_queries_critical

  @doc """
  Returns the warning threshold for slow query count (5).

  More than this many slow queries warrants investigation.
  """
  @spec slow_queries_warning() :: integer()
  def slow_queries_warning, do: @slow_queries_warning

  @doc """
  Returns the warning threshold for N+1 query patterns (3).

  More than this many N+1 patterns indicates inefficient data loading.
  """
  @spec n_plus_one_warning() :: integer()
  def n_plus_one_warning, do: @n_plus_one_warning

  # =============================================================================
  # Public API - Status Determination Functions
  # =============================================================================

  @doc """
  Determines database health status based on pool statistics.

  Returns `:critical`, `:warning`, or `:healthy` based on utilization and queue length.
  """
  @spec database_status(map()) :: :critical | :warning | :healthy
  def database_status(pool_stats) do
    cond do
      pool_stats.utilization >= @pool_utilization_critical -> :critical
      pool_stats.utilization >= @pool_utilization_warning -> :warning
      pool_stats.queue_length > @pool_queue_warning -> :warning
      true -> :healthy
    end
  end

  @doc """
  Determines pipeline health status based on success rate and failure count.

  Returns `:critical`, `:warning`, or `:healthy`.
  """
  @spec pipeline_status(number(), integer()) :: :critical | :warning | :healthy
  def pipeline_status(success_rate, messages_failed) do
    cond do
      success_rate < @pipeline_success_rate_critical -> :critical
      success_rate < @pipeline_success_rate_warning -> :warning
      messages_failed > @pipeline_failed_messages_warning -> :warning
      true -> :healthy
    end
  end

  @doc """
  Determines cache health status based on hit rate.

  Returns `:critical`, `:warning`, or `:healthy`.
  """
  @spec cache_status(map()) :: :critical | :warning | :healthy
  def cache_status(stats) do
    cond do
      stats.hit_rate < @cache_hit_rate_critical -> :critical
      stats.hit_rate < @cache_hit_rate_warning -> :warning
      true -> :healthy
    end
  end

  @doc """
  Determines memory health status based on total BEAM memory in MB.

  Returns `:critical`, `:warning`, or `:healthy`.
  """
  @spec memory_status(number()) :: :critical | :warning | :healthy
  def memory_status(total_mb) do
    cond do
      total_mb > @memory_mb_critical -> :critical
      total_mb > @memory_mb_warning -> :warning
      true -> :healthy
    end
  end

  @doc """
  Determines LiveView health status based on active socket count.

  Returns `:critical`, `:warning`, or `:healthy`.
  """
  @spec liveview_status(integer()) :: :critical | :warning | :healthy
  def liveview_status(count) do
    cond do
      count > @liveview_sockets_critical -> :critical
      count > @liveview_sockets_warning -> :warning
      true -> :healthy
    end
  end

  @doc """
  Determines query health status based on slow query and N+1 alert counts.

  Returns `:critical`, `:warning`, or `:healthy`.
  """
  @spec query_health_status(list(), list()) :: :critical | :warning | :healthy
  def query_health_status(slow_queries, n_plus_one) do
    cond do
      length(slow_queries) > @slow_queries_critical -> :critical
      length(slow_queries) > @slow_queries_warning -> :warning
      length(n_plus_one) > @n_plus_one_warning -> :warning
      true -> :healthy
    end
  end
end

defmodule EveDmv.Config.Pipeline do
  @moduledoc """
  Pipeline configuration management.

  Centralizes Broadway pipeline settings, batch processing parameters,
  and concurrent task limits across the application.
  """

  alias EveDmv.Config

  # Default pipeline settings
  @default_max_concurrency 5
  @default_task_timeout 30_000
  @default_batch_size 100
  @default_warm_cache_interval_minutes 30
  @default_warm_cache_delay_ms 100

  # Logging and monitoring intervals
  @default_summary_log_interval_minutes 1
  @default_health_check_interval_minutes 5

  @doc """
  Get maximum concurrency for pipeline tasks.

  Environment: EVE_DMV_PIPELINE_MAX_CONCURRENCY (default: 5)
  """
  @spec max_concurrency() :: pos_integer()
  def max_concurrency do
    Config.get(:eve_dmv, :pipeline_max_concurrency, @default_max_concurrency)
  end

  @doc """
  Get task timeout in milliseconds.

  Environment: EVE_DMV_PIPELINE_TASK_TIMEOUT_MS (default: 30000)
  """
  @spec task_timeout() :: pos_integer()
  def task_timeout do
    Config.get(:eve_dmv, :pipeline_task_timeout_ms, @default_task_timeout)
  end

  @doc """
  Get batch size for bulk operations.

  Environment: EVE_DMV_PIPELINE_BATCH_SIZE (default: 100)
  """
  @spec batch_size() :: pos_integer()
  def batch_size do
    Config.get(:eve_dmv, :pipeline_batch_size, @default_batch_size)
  end

  @doc """
  Get cache warming interval in milliseconds.

  Environment: EVE_DMV_PIPELINE_WARM_CACHE_INTERVAL_MINUTES (default: 30)
  """
  @spec warm_cache_interval() :: pos_integer()
  def warm_cache_interval do
    minutes =
      Config.get(
        :eve_dmv,
        :pipeline_warm_cache_interval_minutes,
        @default_warm_cache_interval_minutes
      )

    :timer.minutes(minutes)
  end

  @doc """
  Get delay between cache warming operations in milliseconds.

  Environment: EVE_DMV_PIPELINE_WARM_CACHE_DELAY_MS (default: 100)
  """
  @spec warm_cache_delay() :: pos_integer()
  def warm_cache_delay do
    Config.get(:eve_dmv, :pipeline_warm_cache_delay_ms, @default_warm_cache_delay_ms)
  end

  @doc """
  Get summary logging interval in milliseconds.

  Environment: EVE_DMV_PIPELINE_SUMMARY_LOG_INTERVAL_MINUTES (default: 1)
  """
  @spec summary_log_interval() :: pos_integer()
  def summary_log_interval do
    minutes =
      Config.get(
        :eve_dmv,
        :pipeline_summary_log_interval_minutes,
        @default_summary_log_interval_minutes
      )

    :timer.minutes(minutes)
  end

  @doc """
  Get health check interval in milliseconds.

  Environment: EVE_DMV_PIPELINE_HEALTH_CHECK_INTERVAL_MINUTES (default: 5)
  """
  @spec health_check_interval() :: pos_integer()
  def health_check_interval do
    minutes =
      Config.get(
        :eve_dmv,
        :pipeline_health_check_interval_minutes,
        @default_health_check_interval_minutes
      )

    :timer.minutes(minutes)
  end

  @doc """
  Get Broadway producer configuration.
  """
  @spec broadway_producer_config() :: keyword()
  def broadway_producer_config do
    [
      concurrency: max_concurrency(),
      max_demand: batch_size()
    ]
  end

  @doc """
  Get Broadway processor configuration.
  """
  @spec broadway_processor_config() :: keyword()
  def broadway_processor_config do
    [
      concurrency: max_concurrency(),
      max_demand: batch_size(),
      timeout: task_timeout()
    ]
  end

  @doc """
  Get Broadway batch processor configuration.
  """
  @spec broadway_batcher_config() :: keyword()
  def broadway_batcher_config do
    [
      concurrency: max_concurrency(),
      batch_size: batch_size(),
      batch_timeout: task_timeout()
    ]
  end

  @doc """
  Get Task.async_stream configuration.
  """
  @spec async_stream_config() :: keyword()
  def async_stream_config do
    [
      max_concurrency: max_concurrency(),
      timeout: task_timeout(),
      on_timeout: :kill_task
    ]
  end

  @doc """
  Whether pipeline is enabled.

  Environment: PIPELINE_ENABLED (default: true)
  """
  @spec enabled?() :: boolean()
  def enabled? do
    Config.get(:eve_dmv, :pipeline_enabled, true)
  end
end

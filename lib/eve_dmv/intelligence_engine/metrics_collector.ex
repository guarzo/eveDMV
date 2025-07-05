defmodule EveDmv.IntelligenceEngine.MetricsCollector do
  @moduledoc """
  Performance metrics collection for the Intelligence Engine.

  Tracks analysis performance, plugin execution times, success rates,
  and system health metrics to enable monitoring and optimization
  of the intelligence analysis pipeline.
  """

  require Logger

  @type domain :: atom()
  @type plugin_name :: atom()
  @type duration_ms :: integer()
  @type analysis_result :: {:ok, term()} | {:error, term()}

  defstruct [
    :analysis_metrics,
    :plugin_metrics,
    :system_metrics,
    :config
  ]

  @doc """
  Initialize a new metrics collector.
  """
  @spec initialize() :: %__MODULE__{}
  def initialize do
    %__MODULE__{
      analysis_metrics: %{
        total_analyses: 0,
        successful_analyses: 0,
        failed_analyses: 0,
        total_duration_ms: 0,
        by_domain: %{}
      },
      plugin_metrics: %{
        total_executions: 0,
        successful_executions: 0,
        failed_executions: 0,
        total_duration_ms: 0,
        by_plugin: %{}
      },
      system_metrics: %{
        active_analyses: 0,
        peak_concurrent_analyses: 0,
        cache_hit_rate: 0.0,
        avg_response_time_ms: 0
      },
      config: %{
        enable_telemetry: true,
        slow_analysis_threshold_ms: 5000,
        slow_plugin_threshold_ms: 1000,
        metrics_retention_hours: 24
      }
    }
  end

  @doc """
  Record completion of an analysis operation.
  """
  @spec record_analysis(%__MODULE__{}, domain(), duration_ms(), analysis_result()) :: :ok
  def record_analysis(collector, domain, duration_ms, result) do
    # Update overall analysis metrics
    collector = update_in(collector.analysis_metrics.total_analyses, &(&1 + 1))
    collector = update_in(collector.analysis_metrics.total_duration_ms, &(&1 + duration_ms))

    collector =
      case result do
        {:ok, _} ->
          update_in(collector.analysis_metrics.successful_analyses, &(&1 + 1))

        {:error, _} ->
          update_in(collector.analysis_metrics.failed_analyses, &(&1 + 1))
      end

    # Update domain-specific metrics
    domain_metrics =
      get_in(collector.analysis_metrics.by_domain, [domain]) || initialize_domain_metrics()

    domain_metrics = update_domain_metrics(domain_metrics, duration_ms, result)
    collector = put_in(collector.analysis_metrics.by_domain[domain], domain_metrics)

    # Emit telemetry if enabled
    if collector.config.enable_telemetry do
      emit_analysis_telemetry(domain, duration_ms, result)
    end

    # Check for slow analysis
    if duration_ms > collector.config.slow_analysis_threshold_ms do
      Logger.warning("Slow intelligence analysis detected",
        domain: domain,
        duration_ms: duration_ms,
        threshold_ms: collector.config.slow_analysis_threshold_ms
      )
    end

    :ok
  end

  @doc """
  Record execution of a specific plugin.
  """
  @spec record_plugin_execution(
          %__MODULE__{},
          domain(),
          plugin_name(),
          duration_ms(),
          analysis_result()
        ) :: :ok
  def record_plugin_execution(collector, domain, plugin_name, duration_ms, result) do
    # Update overall plugin metrics
    collector = update_in(collector.plugin_metrics.total_executions, &(&1 + 1))
    collector = update_in(collector.plugin_metrics.total_duration_ms, &(&1 + duration_ms))

    collector =
      case result do
        {:ok, _} ->
          update_in(collector.plugin_metrics.successful_executions, &(&1 + 1))

        {:error, _} ->
          update_in(collector.plugin_metrics.failed_executions, &(&1 + 1))
      end

    # Update plugin-specific metrics
    plugin_key = {domain, plugin_name}

    plugin_metrics =
      get_in(collector.plugin_metrics.by_plugin, [plugin_key]) || initialize_plugin_metrics()

    plugin_metrics = update_plugin_metrics(plugin_metrics, duration_ms, result)
    collector = put_in(collector.plugin_metrics.by_plugin[plugin_key], plugin_metrics)

    # Emit telemetry if enabled
    if collector.config.enable_telemetry do
      emit_plugin_telemetry(domain, plugin_name, duration_ms, result)
    end

    # Check for slow plugin
    if duration_ms > collector.config.slow_plugin_threshold_ms do
      Logger.info("Slow plugin execution detected",
        domain: domain,
        plugin: plugin_name,
        duration_ms: duration_ms,
        threshold_ms: collector.config.slow_plugin_threshold_ms
      )
    end

    :ok
  end

  @doc """
  Get comprehensive metrics summary.
  """
  @spec get_metrics(%__MODULE__{}) :: map()
  def get_metrics(collector) do
    %{
      analysis: format_analysis_metrics(collector.analysis_metrics),
      plugins: format_plugin_metrics(collector.plugin_metrics),
      system: collector.system_metrics,
      config: collector.config,
      generated_at: DateTime.utc_now()
    }
  end

  @doc """
  Get metrics for a specific domain.
  """
  @spec get_domain_metrics(%__MODULE__{}, domain()) :: map()
  def get_domain_metrics(collector, domain) do
    case get_in(collector.analysis_metrics.by_domain, [domain]) do
      nil -> %{domain: domain, analyses: 0, message: "No data available"}
      metrics -> Map.put(metrics, :domain, domain)
    end
  end

  @doc """
  Get metrics for a specific plugin.
  """
  @spec get_plugin_metrics(%__MODULE__{}, domain(), plugin_name()) :: map()
  def get_plugin_metrics(collector, domain, plugin_name) do
    plugin_key = {domain, plugin_name}

    case get_in(collector.plugin_metrics.by_plugin, [plugin_key]) do
      nil -> %{domain: domain, plugin: plugin_name, executions: 0, message: "No data available"}
      metrics -> Map.merge(metrics, %{domain: domain, plugin: plugin_name})
    end
  end

  @doc """
  Reset all metrics.
  """
  @spec reset_metrics(%__MODULE__{}) :: %__MODULE__{}
  def reset_metrics(collector) do
    %{
      collector
      | analysis_metrics: %{
          total_analyses: 0,
          successful_analyses: 0,
          failed_analyses: 0,
          total_duration_ms: 0,
          by_domain: %{}
        },
        plugin_metrics: %{
          total_executions: 0,
          successful_executions: 0,
          failed_executions: 0,
          total_duration_ms: 0,
          by_plugin: %{}
        }
    }
  end

  @doc """
  Update system metrics.
  """
  @spec update_system_metrics(%__MODULE__{}, map()) :: %__MODULE__{}
  def update_system_metrics(collector, updates) do
    system_metrics = Map.merge(collector.system_metrics, updates)
    %{collector | system_metrics: system_metrics}
  end

  # Private helper functions

  defp initialize_domain_metrics do
    %{
      analyses: 0,
      successful: 0,
      failed: 0,
      total_duration_ms: 0,
      avg_duration_ms: 0,
      success_rate: 0.0
    }
  end

  defp initialize_plugin_metrics do
    %{
      executions: 0,
      successful: 0,
      failed: 0,
      total_duration_ms: 0,
      avg_duration_ms: 0,
      success_rate: 0.0
    }
  end

  defp update_domain_metrics(metrics, duration_ms, result) do
    metrics = update_in(metrics.analyses, &(&1 + 1))
    metrics = update_in(metrics.total_duration_ms, &(&1 + duration_ms))

    metrics =
      case result do
        {:ok, _} -> update_in(metrics.successful, &(&1 + 1))
        {:error, _} -> update_in(metrics.failed, &(&1 + 1))
      end

    # Calculate derived metrics
    metrics = put_in(metrics.avg_duration_ms, div(metrics.total_duration_ms, metrics.analyses))
    metrics = put_in(metrics.success_rate, metrics.successful / metrics.analyses)

    metrics
  end

  defp update_plugin_metrics(metrics, duration_ms, result) do
    metrics = update_in(metrics.executions, &(&1 + 1))
    metrics = update_in(metrics.total_duration_ms, &(&1 + duration_ms))

    metrics =
      case result do
        {:ok, _} -> update_in(metrics.successful, &(&1 + 1))
        {:error, _} -> update_in(metrics.failed, &(&1 + 1))
      end

    # Calculate derived metrics
    metrics = put_in(metrics.avg_duration_ms, div(metrics.total_duration_ms, metrics.executions))
    metrics = put_in(metrics.success_rate, metrics.successful / metrics.executions)

    metrics
  end

  defp format_analysis_metrics(metrics) do
    total = metrics.total_analyses
    avg_duration = if total > 0, do: div(metrics.total_duration_ms, total), else: 0
    success_rate = if total > 0, do: metrics.successful_analyses / total, else: 0.0

    %{
      total_analyses: total,
      successful_analyses: metrics.successful_analyses,
      failed_analyses: metrics.failed_analyses,
      avg_duration_ms: avg_duration,
      success_rate: success_rate,
      by_domain: metrics.by_domain
    }
  end

  defp format_plugin_metrics(metrics) do
    total = metrics.total_executions
    avg_duration = if total > 0, do: div(metrics.total_duration_ms, total), else: 0
    success_rate = if total > 0, do: metrics.successful_executions / total, else: 0.0

    %{
      total_executions: total,
      successful_executions: metrics.successful_executions,
      failed_executions: metrics.failed_executions,
      avg_duration_ms: avg_duration,
      success_rate: success_rate,
      by_plugin: metrics.by_plugin
    }
  end

  defp emit_analysis_telemetry(domain, duration_ms, result) do
    status =
      case result do
        {:ok, _} -> :success
        {:error, _} -> :error
      end

    :telemetry.execute(
      [:eve_dmv, :intelligence_engine, :analysis],
      %{duration_ms: duration_ms},
      %{domain: domain, status: status}
    )
  end

  defp emit_plugin_telemetry(domain, plugin_name, duration_ms, result) do
    status =
      case result do
        {:ok, _} -> :success
        {:error, _} -> :error
      end

    :telemetry.execute(
      [:eve_dmv, :intelligence_engine, :plugin],
      %{duration_ms: duration_ms},
      %{domain: domain, plugin: plugin_name, status: status}
    )
  end
end

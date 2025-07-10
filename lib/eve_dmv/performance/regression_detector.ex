defmodule EveDmv.Performance.RegressionDetector do
  @moduledoc """
  Automated performance regression detection system.

  Monitors key performance metrics and alerts when performance 
  degrades beyond acceptable thresholds.
  """

  use GenServer
  require Logger

  # Performance thresholds
  # Alert if queries take > 2s
  @query_time_threshold_ms 2000
  # Alert if memory grows > 50MB
  @memory_growth_threshold 50 * 1024 * 1024

  # Storage for baseline metrics
  @baseline_table :performance_baselines
  @metrics_table :performance_metrics

  # Measurement intervals
  # Measure every 5 minutes
  @measurement_interval :timer.minutes(5)
  # Update baselines daily
  @baseline_update_interval :timer.hours(24)

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def record_metric(metric_name, value, metadata \\ %{}) do
    GenServer.cast(__MODULE__, {:record_metric, metric_name, value, metadata})
  end

  def get_current_metrics do
    GenServer.call(__MODULE__, :get_current_metrics)
  end

  def get_baselines do
    GenServer.call(__MODULE__, :get_baselines)
  end

  def force_regression_check do
    GenServer.cast(__MODULE__, :force_regression_check)
  end

  def update_baselines do
    GenServer.cast(__MODULE__, :update_baselines)
  end

  # Server callbacks

  def init(_opts) do
    # Create ETS tables for storing metrics
    :ets.new(@baseline_table, [:named_table, :public, :set])
    :ets.new(@metrics_table, [:named_table, :public, :bag])

    # Schedule periodic measurements
    schedule_measurement()
    schedule_baseline_update()

    # Initialize with current system metrics
    initialize_baselines()

    state = %{
      last_measurement: nil,
      alerts_sent: MapSet.new(),
      measurement_count: 0
    }

    Logger.info("Performance regression detector started")

    {:ok, state}
  end

  def handle_cast({:record_metric, metric_name, value, metadata}, state) do
    timestamp = DateTime.utc_now()

    # Store metric in ETS
    :ets.insert(@metrics_table, {metric_name, timestamp, value, metadata})

    # Clean up old metrics (keep last 1000 per metric)
    cleanup_old_metrics(metric_name)

    # Check for immediate regressions
    check_metric_regression(metric_name, value, metadata)

    {:noreply, state}
  end

  def handle_cast(:force_regression_check, state) do
    new_state = perform_regression_analysis(state)
    {:noreply, new_state}
  end

  def handle_cast(:update_baselines, state) do
    update_performance_baselines()
    {:noreply, state}
  end

  def handle_call(:get_current_metrics, _from, state) do
    metrics = get_recent_metrics()
    {:reply, metrics, state}
  end

  def handle_call(:get_baselines, _from, state) do
    baselines = :ets.tab2list(@baseline_table) |> Enum.into(%{})
    {:reply, baselines, state}
  end

  def handle_info(:perform_measurement, state) do
    new_state = perform_system_measurement(state)
    schedule_measurement()
    {:noreply, new_state}
  end

  def handle_info(:update_baselines, state) do
    update_performance_baselines()
    schedule_baseline_update()
    {:noreply, state}
  end

  def handle_info(_, state), do: {:noreply, state}

  # Private functions

  defp schedule_measurement do
    Process.send_after(self(), :perform_measurement, @measurement_interval)
  end

  defp schedule_baseline_update do
    Process.send_after(self(), :update_baselines, @baseline_update_interval)
  end

  defp initialize_baselines do
    # Set initial baselines based on current system state
    current_metrics = collect_system_metrics()

    Enum.each(current_metrics, fn {metric_name, value} ->
      :ets.insert(@baseline_table, {metric_name, value})
    end)

    Logger.info("Initialized performance baselines with #{length(current_metrics)} metrics")
  end

  defp collect_system_metrics do
    memory_info = EveDmv.Performance.MemoryProfiler.get_memory_info()
    query_metrics = EveDmv.Performance.QueryMonitor.get_performance_metrics()

    base_metrics = %{
      "memory.total" => memory_info.total,
      "memory.processes" => memory_info.processes,
      "memory.ets" => memory_info.ets,
      "system.process_count" => length(Process.list())
    }

    # Add query metrics
    query_metrics_map =
      Enum.reduce(query_metrics, %{}, fn metric, acc ->
        acc
        |> Map.put("query.#{metric.table}.avg_time", metric.avg_time_ms)
        |> Map.put("query.#{metric.table}.max_time", metric.max_time_ms)
      end)

    Map.merge(base_metrics, query_metrics_map)
  end

  defp perform_system_measurement(state) do
    current_metrics = collect_system_metrics()
    timestamp = DateTime.utc_now()

    # Store all current metrics
    Enum.each(current_metrics, fn {metric_name, value} ->
      :ets.insert(@metrics_table, {metric_name, timestamp, value, %{}})
    end)

    # Perform regression analysis
    perform_regression_analysis(state)

    %{state | last_measurement: timestamp, measurement_count: state.measurement_count + 1}
  end

  defp perform_regression_analysis(state) do
    baselines = :ets.tab2list(@baseline_table) |> Enum.into(%{})
    current_metrics = collect_system_metrics()

    regressions =
      Enum.reduce(current_metrics, [], fn {metric_name, current_value}, acc ->
        case Map.get(baselines, metric_name) do
          nil ->
            # No baseline to compare against
            acc

          baseline_value ->
            regression = detect_regression(metric_name, baseline_value, current_value)
            if regression, do: [regression | acc], else: acc
        end
      end)

    # Send alerts for new regressions
    new_alerts =
      Enum.reject(regressions, fn reg ->
        MapSet.member?(state.alerts_sent, reg.alert_key)
      end)

    Enum.each(new_alerts, &send_regression_alert/1)

    # Update alerts sent
    new_alert_keys = Enum.map(new_alerts, & &1.alert_key) |> MapSet.new()
    updated_alerts = MapSet.union(state.alerts_sent, new_alert_keys)

    %{state | alerts_sent: updated_alerts}
  end

  defp detect_regression(metric_name, baseline, current) do
    cond do
      # Memory metrics - alert on significant increase
      String.starts_with?(metric_name, "memory.") ->
        growth = current - baseline
        growth_percentage = if baseline > 0, do: growth / baseline * 100, else: 0

        if growth > @memory_growth_threshold or growth_percentage > 50 do
          %{
            type: :memory_regression,
            metric: metric_name,
            baseline: baseline,
            current: current,
            growth: growth,
            growth_percentage: growth_percentage,
            severity: determine_severity(growth_percentage),
            alert_key: "memory_#{metric_name}"
          }
        else
          nil
        end

      # Query time metrics - alert on significant increase
      String.contains?(metric_name, "time") ->
        if current > @query_time_threshold_ms or current > baseline * 2 do
          %{
            type: :query_regression,
            metric: metric_name,
            baseline: baseline,
            current: current,
            slowdown_factor: if(baseline > 0, do: current / baseline, else: 1),
            severity: determine_query_severity(current),
            alert_key: "query_#{metric_name}"
          }
        else
          nil
        end

      # Process count - alert on significant increase
      String.contains?(metric_name, "process_count") ->
        growth = current - baseline
        growth_percentage = if baseline > 0, do: growth / baseline * 100, else: 0

        # More than 100% increase in processes
        if growth_percentage > 100 do
          %{
            type: :process_regression,
            metric: metric_name,
            baseline: baseline,
            current: current,
            growth: growth,
            growth_percentage: growth_percentage,
            severity: :medium,
            alert_key: "process_#{metric_name}"
          }
        else
          nil
        end

      true ->
        nil
    end
  end

  defp determine_severity(growth_percentage) do
    cond do
      growth_percentage > 200 -> :critical
      growth_percentage > 100 -> :high
      growth_percentage > 50 -> :medium
      true -> :low
    end
  end

  defp determine_query_severity(query_time_ms) do
    cond do
      # > 10s
      query_time_ms > 10000 -> :critical
      # > 5s
      query_time_ms > 5000 -> :high
      # > 2s
      query_time_ms > 2000 -> :medium
      true -> :low
    end
  end

  defp send_regression_alert(regression) do
    Logger.error("""
    🚨 PERFORMANCE REGRESSION DETECTED 🚨
    Type: #{regression.type}
    Metric: #{regression.metric}
    Severity: #{regression.severity}
    Baseline: #{format_metric_value(regression.baseline)}
    Current: #{format_metric_value(regression.current)}
    Details: #{format_regression_details(regression)}
    """)

    # Could also send to external monitoring systems here
    # send_to_monitoring_system(regression)
  end

  defp format_metric_value(value) when is_number(value) do
    cond do
      value > 1_000_000 -> "#{Float.round(value / 1_000_000, 2)}M"
      value > 1_000 -> "#{Float.round(value / 1_000, 2)}K"
      true -> "#{value}"
    end
  end

  defp format_regression_details(regression) do
    case regression.type do
      :memory_regression ->
        "Growth: +#{format_metric_value(regression.growth)} (+#{Float.round(regression.growth_percentage, 1)}%)"

      :query_regression ->
        "Slowdown: #{Float.round(regression.slowdown_factor, 2)}x slower"

      :process_regression ->
        "Growth: +#{regression.growth} processes (+#{Float.round(regression.growth_percentage, 1)}%)"

      _ ->
        "No additional details"
    end
  end

  defp check_metric_regression(metric_name, value, _metadata) do
    # Check immediate regressions for real-time metrics
    case :ets.lookup(@baseline_table, metric_name) do
      [{^metric_name, baseline}] ->
        if regression = detect_regression(metric_name, baseline, value) do
          send_regression_alert(regression)
        end

      _ ->
        # No baseline yet, store as baseline if this looks like a good value
        if is_reasonable_baseline?(metric_name, value) do
          :ets.insert(@baseline_table, {metric_name, value})
        end
    end
  end

  defp is_reasonable_baseline?(metric_name, value) do
    cond do
      # Reasonable query time
      String.contains?(metric_name, "time") -> value > 0 and value < 30_000
      # At least 1MB
      String.starts_with?(metric_name, "memory.") -> value > 1_000_000
      true -> value > 0
    end
  end

  defp cleanup_old_metrics(metric_name) do
    # Get all entries for this metric
    entries = :ets.lookup(@metrics_table, metric_name)

    if length(entries) > 1000 do
      # Sort by timestamp and keep only the newest 1000
      sorted_entries =
        Enum.sort(entries, fn {_, ts1, _, _}, {_, ts2, _, _} ->
          DateTime.compare(ts1, ts2) == :gt
        end)

      {_keep, remove} = Enum.split(sorted_entries, 1000)

      # Remove old entries
      Enum.each(remove, fn entry ->
        :ets.delete_object(@metrics_table, entry)
      end)
    end
  end

  defp update_performance_baselines do
    Logger.info("Updating performance baselines...")

    # Calculate new baselines based on recent performance
    current_metrics = collect_system_metrics()

    Enum.each(current_metrics, fn {metric_name, current_value} ->
      # Get recent values for this metric
      recent_values =
        @metrics_table
        |> :ets.lookup(metric_name)
        |> Enum.map(fn {_, _, value, _} -> value end)
        # Last 100 measurements
        |> Enum.take(100)

      if length(recent_values) >= 10 do
        # Calculate median as new baseline (more stable than mean)
        new_baseline = median(recent_values)
        :ets.insert(@baseline_table, {metric_name, new_baseline})

        Logger.debug("Updated baseline for #{metric_name}: #{new_baseline}")
      else
        # Not enough data, use current value
        :ets.insert(@baseline_table, {metric_name, current_value})
      end
    end)

    Logger.info("Performance baselines updated")
  end

  defp get_recent_metrics do
    # Get metrics from the last hour
    one_hour_ago = DateTime.add(DateTime.utc_now(), -3600, :second)

    @metrics_table
    |> :ets.tab2list()
    |> Enum.filter(fn {_, timestamp, _, _} ->
      DateTime.compare(timestamp, one_hour_ago) == :gt
    end)
    |> Enum.group_by(fn {metric_name, _, _, _} -> metric_name end)
    |> Enum.map(fn {metric_name, entries} ->
      values = Enum.map(entries, fn {_, _, value, _} -> value end)

      %{
        metric: metric_name,
        count: length(values),
        min: Enum.min(values),
        max: Enum.max(values),
        avg: Enum.sum(values) / length(values),
        latest: List.first(values)
      }
    end)
  end

  defp median([]), do: 0

  defp median(list) do
    sorted = Enum.sort(list)
    length = length(sorted)

    if rem(length, 2) == 0 do
      # Even number of elements
      mid = div(length, 2)
      (Enum.at(sorted, mid - 1) + Enum.at(sorted, mid)) / 2
    else
      # Odd number of elements
      Enum.at(sorted, div(length, 2))
    end
  end
end

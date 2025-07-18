defmodule EveDmv.Telemetry.PerformanceTestHelper do
  @moduledoc """
  Helper tools for performance testing in development environment.

  Provides utilities to:
  - Load production performance data for analysis
  - Simulate production query patterns
  - Benchmark query performance changes
  - Generate test data that matches production patterns
  """

  alias EveDmv.Repo
  # alias EveDmv.Telemetry.QueryMonitor # Currently unused

  @doc """
  Load production performance data from exported JSON file.
  """
  def load_production_data(filepath) do
    case File.read(filepath) do
      {:ok, content} ->
        case Jason.decode(content, keys: :atoms!) do
          {:ok, data} -> {:ok, data}
          {:error, reason} -> {:error, "Failed to parse JSON: #{inspect(reason)}"}
        end

      {:error, reason} ->
        {:error, "Failed to read file: #{inspect(reason)}"}
    end
  end

  @doc """
  Benchmark a query against production patterns.

  Runs the query multiple times and compares performance against
  production baseline data.
  """
  def benchmark_query(query, params \\ [], opts \\ []) do
    iterations = Keyword.get(opts, :iterations, 10)
    warmup = Keyword.get(opts, :warmup, 2)

    # Warmup runs
    for _ <- 1..warmup do
      Ecto.Adapters.SQL.query(Repo, query, params)
    end

    # Benchmark runs
    times =
      for _ <- 1..iterations do
        {time, _result} =
          :timer.tc(fn ->
            Ecto.Adapters.SQL.query(Repo, query, params)
          end)

        # Convert to milliseconds
        time / 1000
      end

    %{
      query: query,
      iterations: iterations,
      times_ms: times,
      avg_time_ms: Enum.sum(times) / iterations,
      min_time_ms: Enum.min(times),
      max_time_ms: Enum.max(times),
      median_time_ms: median(times),
      p95_time_ms: percentile(times, 95),
      p99_time_ms: percentile(times, 99)
    }
  end

  @doc """
  Compare current query performance against production baseline.
  """
  def compare_with_production(query, production_data, opts \\ []) do
    current_benchmark = benchmark_query(query, [], opts)

    # Find matching production query pattern
    sanitized_query = sanitize_query_for_comparison(query)

    production_match =
      Enum.find(production_data.slow_queries, fn pq ->
        similarity(pq.query_pattern, sanitized_query) > 0.8
      end)

    case production_match do
      nil ->
        {:error, "No matching production query pattern found"}

      prod_query ->
        performance_ratio = current_benchmark.avg_time_ms / prod_query.avg_time_ms

        %{
          current: current_benchmark,
          production: prod_query,
          performance_ratio: performance_ratio,
          status:
            cond do
              performance_ratio <= 0.8 -> :improved
              performance_ratio <= 1.2 -> :similar
              performance_ratio <= 2.0 -> :degraded
              true -> :severely_degraded
            end,
          recommendation:
            generate_recommendation(performance_ratio, current_benchmark, prod_query)
        }
    end
  end

  @doc """
  Generate test data that simulates production data volume and distribution.
  """
  def generate_test_data_plan(production_metrics) do
    table_stats = production_metrics.database_metrics.table_stats || []

    plans =
      Enum.map(table_stats, fn stat ->
        %{
          table: stat.table,
          estimated_rows: estimate_row_count(stat),
          data_distribution: analyze_distribution(stat),
          suggested_test_size: calculate_test_size(stat)
        }
      end)

    %{
      total_database_size: production_metrics.database_metrics.database_size,
      table_plans: plans,
      scaling_factor: calculate_scaling_factor(production_metrics)
    }
  end

  @doc """
  Monitor query performance during development and compare with production patterns.
  """
  def start_performance_monitoring do
    # Attach telemetry handler for development performance tracking
    :telemetry.attach(
      "dev-performance-monitor",
      [:ecto, :repo, :query],
      &handle_query_telemetry/4,
      %{}
    )
  end

  @doc """
  Stop performance monitoring.
  """
  def stop_performance_monitoring do
    :telemetry.detach("dev-performance-monitor")
  end

  # Private functions

  defp handle_query_telemetry(_event, measurements, metadata, _config) do
    query_time = measurements.total_time

    # Log queries > 100ms in development
    if query_time > 100_000 do
      IO.puts("""
      [DEV PERFORMANCE] Slow query detected:
      Time: #{query_time / 1_000_000}ms
      Query: #{inspect(metadata.query)}
      Source: #{metadata.source || "unknown"}
      """)
    end
  end

  defp sanitize_query_for_comparison(query) do
    query
    |> String.replace(~r/\b\d+\b/, "?")
    |> String.replace(~r/'[^']*'/, "'?'")
    |> String.replace(~r/\$\d+/, "$?")
    |> String.downcase()
    |> String.trim()
  end

  defp similarity(str1, str2) do
    # Simple similarity calculation using Levenshtein distance
    max_len = max(String.length(str1), String.length(str2))

    if max_len == 0 do
      1.0
    else
      distance = String.jaro_distance(str1, str2)
      distance
    end
  end

  defp median(list) do
    sorted = Enum.sort(list)
    len = length(sorted)

    if rem(len, 2) == 0 do
      (Enum.at(sorted, div(len, 2) - 1) + Enum.at(sorted, div(len, 2))) / 2
    else
      Enum.at(sorted, div(len, 2))
    end
  end

  defp percentile(list, p) do
    sorted = Enum.sort(list)
    len = length(sorted)
    index = (p / 100 * (len - 1)) |> round()
    Enum.at(sorted, index)
  end

  defp estimate_row_count(stat) do
    # Estimate based on n_distinct and other statistics
    # This is a simplified estimation
    case stat.n_distinct do
      # Rough estimation
      n when n > 0 -> round(n * 10)
      # Default fallback
      _ -> 1000
    end
  end

  defp analyze_distribution(stat) do
    %{
      column: stat.column,
      distinctness: stat.n_distinct,
      correlation: stat.correlation,
      distribution_type: classify_distribution(stat)
    }
  end

  defp classify_distribution(stat) do
    cond do
      stat.correlation && stat.correlation > 0.8 -> :highly_correlated
      stat.correlation && stat.correlation > 0.3 -> :correlated
      stat.n_distinct && stat.n_distinct < 10 -> :low_cardinality
      stat.n_distinct && stat.n_distinct > 1000 -> :high_cardinality
      true -> :unknown
    end
  end

  defp calculate_test_size(stat) do
    base_size = estimate_row_count(stat)
    # Scale down for development testing
    max(round(base_size * 0.1), 100)
  end

  defp calculate_scaling_factor(production_metrics) do
    _prod_size = production_metrics.database_metrics.database_size.size_bytes || 1_000_000_000
    # Aim for 1/10th of production size in development
    1.0 / 10.0
  end

  defp generate_recommendation(ratio, _current, _production) do
    cond do
      ratio > 2.0 ->
        "Query performance is significantly degraded. Consider:\n" <>
          "- Checking if indexes are present\n" <>
          "- Analyzing query execution plan\n" <>
          "- Reviewing data volume differences"

      ratio > 1.5 ->
        "Query performance is worse than production. Investigate:\n" <>
          "- Index usage and optimization\n" <>
          "- Query plan differences\n" <>
          "- Hardware/configuration differences"

      ratio < 0.5 ->
        "Query performance is significantly better than production. This might indicate:\n" <>
          "- Smaller data volume in development\n" <>
          "- Different hardware characteristics\n" <>
          "- Missing production-like data distribution"

      true ->
        "Query performance is similar to production baseline."
    end
  end
end

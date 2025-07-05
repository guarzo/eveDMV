defmodule EveDmv.Quality.MetricsCollector.PerformanceMetrics do
  @moduledoc """
  Performance metrics collection and analysis.

  Handles test execution performance, benchmarks,
  database performance, and memory usage analysis.
  """

  @doc """
  Collects comprehensive performance metrics.
  """
  def collect_performance_metrics do
    %{
      test_execution_metrics: analyze_test_performance(),
      benchmark_results: collect_benchmark_results(),
      database_performance: analyze_database_performance(),
      memory_usage: analyze_memory_usage()
    }
  end

  @doc """
  Calculates performance score based on metrics.
  """
  def calculate_performance_score(performance_metrics) do
    # Base score
    base_score = 85

    # Adjust based on memory usage
    memory_data = performance_metrics.memory_usage
    process_count = memory_data.process_count

    # Penalty for high process count
    process_penalty =
      if process_count > 10000 do
        10
      else
        0
      end

    # Bonus for having benchmarks
    benchmark_bonus =
      if performance_metrics.benchmark_results.benchmark_count > 0 do
        5
      else
        0
      end

    max(0, min(100, base_score - process_penalty + benchmark_bonus))
  end

  @doc """
  Generates performance recommendations.
  """
  def generate_performance_recommendations(performance_metrics) do
    recommendations = []

    # Check for high process count
    process_count = performance_metrics.memory_usage.process_count

    recommendations =
      if process_count > 10000 do
        ["High process count (#{process_count}). Review for process leaks." | recommendations]
      else
        recommendations
      end

    # Check for benchmarks
    benchmark_count = performance_metrics.benchmark_results.benchmark_count

    recommendations =
      if benchmark_count == 0 do
        ["Add performance benchmarks to track critical paths" | recommendations]
      else
        recommendations
      end

    # Check atom count (potential atom leak)
    atom_count = performance_metrics.memory_usage.atom_count

    recommendations =
      if atom_count > 1_000_000 do
        ["High atom count (#{atom_count}). Check for atom generation in loops." | recommendations]
      else
        recommendations
      end

    recommendations
  end

  # Test performance analysis

  defp analyze_test_performance do
    %{
      average_test_time: measure_average_test_time(),
      slow_tests: identify_slow_tests(),
      test_parallelization: analyze_test_parallelization()
    }
  end

  defp measure_average_test_time do
    # This would parse test output for timing information
    # Placeholder for now
    0
  end

  defp identify_slow_tests do
    # This would identify tests taking > 1 second
    # Placeholder for now
    []
  end

  defp analyze_test_parallelization do
    # Check if tests are running in parallel
    case System.cmd("mix", ["test", "--help"], stderr_to_stdout: true) do
      {output, 0} ->
        max_cases =
          if String.contains?(output, "--max-cases") do
            System.schedulers_online()
          else
            1
          end

        %{
          parallel_tests: max_cases,
          available_cores: System.schedulers_online()
        }

      _ ->
        %{parallel_tests: 1, available_cores: System.schedulers_online()}
    end
  rescue
    _ -> %{parallel_tests: 1, available_cores: 1}
  end

  # Benchmark collection

  defp collect_benchmark_results do
    benchmark_files = Path.wildcard("test/benchmarks/**/*.exs")

    %{
      benchmark_count: length(benchmark_files),
      benchmark_files: Enum.map(benchmark_files, &Path.basename/1),
      last_run_results: load_last_benchmark_results()
    }
  end

  defp load_last_benchmark_results do
    # This would load results from benchee output files
    # Placeholder for now
    %{
      last_run: nil,
      fastest_operations: [],
      slowest_operations: []
    }
  end

  # Database performance

  defp analyze_database_performance do
    %{
      connection_pool_size: get_connection_pool_size(),
      average_query_time: measure_average_query_time(),
      slow_queries: identify_slow_queries(),
      pool_metrics: get_pool_metrics()
    }
  end

  defp get_connection_pool_size do
    # Get from Ecto configuration
    repo_config = Application.get_env(:eve_dmv, EveDmv.Repo, [])
    Keyword.get(repo_config, :pool_size, 10)
  end

  defp measure_average_query_time do
    # This would query telemetry metrics or database logs
    # Placeholder for now
    0
  end

  defp identify_slow_queries do
    # This would analyze database logs for slow queries
    # Placeholder for now
    []
  end

  defp get_pool_metrics do
    # This would get actual pool metrics from Ecto
    %{
      pool_size: get_connection_pool_size(),
      overflow: 0,
      queue_target: 50,
      queue_interval: 1000
    }
  end

  # Memory analysis

  defp analyze_memory_usage do
    memory_data = :erlang.memory()

    %{
      beam_memory: memory_data,
      process_count: :erlang.system_info(:process_count),
      atom_count: :erlang.system_info(:atom_count),
      atom_limit: :erlang.system_info(:atom_limit),
      port_count: :erlang.system_info(:port_count),
      ets_tables: length(:ets.all()),
      memory_breakdown: calculate_memory_breakdown(memory_data)
    }
  end

  defp calculate_memory_breakdown(memory_data) do
    total = memory_data[:total]

    if total > 0 do
      %{
        processes: round(memory_data[:processes] / total * 100),
        atom: round(memory_data[:atom] / total * 100),
        binary: round(memory_data[:binary] / total * 100),
        code: round(memory_data[:code] / total * 100),
        ets: round(memory_data[:ets] / total * 100)
      }
    else
      %{processes: 0, atom: 0, binary: 0, code: 0, ets: 0}
    end
  end
end

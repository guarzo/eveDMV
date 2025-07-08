defmodule EveDmv.Quality.MetricsCollector.TestMetrics do
  @moduledoc """
  Test metrics collection and analysis.

  Handles all test-related metrics including coverage, execution time,
  test categorization, and critical path analysis.
  """

  @doc """
  Collects comprehensive test metrics.
  """
  def collect_test_metrics do
    %{
      total_tests: count_total_tests(),
      test_coverage: get_test_coverage(),
      test_execution_time: measure_test_execution_time(),
      test_file_count: count_test_files(),
      critical_path_coverage: analyze_critical_path_coverage(),
      test_categories: categorize_tests(),
      skipped_tests: count_skipped_tests(),
      flaky_tests: identify_flaky_tests()
    }
  end

  @doc """
  Calculates test quality score.
  """
  def calculate_test_score(test_metrics) do
    coverage = test_metrics.test_coverage.overall || 0
    min(coverage, 100)
  end

  # Test counting functions

  defp count_total_tests do
    case System.cmd("mix", ["test", "--dry-run"], stderr_to_stdout: true, env: %{}) do
      {output, 0} ->
        output
        |> String.split("\n")
        |> Enum.filter(&String.contains?(&1, "test"))
        |> length()

      _ ->
        0
    end
  rescue
    _ -> 0
  end

  defp count_test_files do
    length(Path.wildcard("test/**/*_test.exs"))
  end

  defp count_skipped_tests do
    case System.cmd("grep", ["-r", "@tag :skip", "test/"], stderr_to_stdout: true, env: %{}) do
      {output, 0} ->
        String.split(output, "\n") |> Enum.reject(&(&1 == "")) |> length()

      _ ->
        0
    end
  rescue
    _ -> 0
  end

  # Coverage analysis

  defp get_test_coverage do
    case File.read("cover/excoveralls.json") do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, data} ->
            %{
              overall: Map.get(data, "coverage", 0),
              files:
                Enum.map(Map.get(data, "files", []), fn file ->
                  %{
                    name: Map.get(file, "name"),
                    coverage: Map.get(file, "coverage", 0)
                  }
                end)
            }

          _ ->
            %{overall: 0, files: []}
        end

      _ ->
        %{overall: 0, files: []}
    end
  end

  defp analyze_critical_path_coverage do
    critical_modules = [
      "EveDmv.Intelligence.CharacterAnalyzer",
      "EveDmv.Intelligence.Analyzers.HomeDefenseAnalyzer",
      "EveDmv.Intelligence.Analyzers.WHVettingAnalyzer",
      "EveDmv.Intelligence.WHFleetAnalyzer",
      "EveDmv.Killmails.KillmailPipeline",
      "EveDmv.Eve.CircuitBreaker"
    ]

    coverage_data = get_test_coverage()

    critical_coverage =
      coverage_data.files
      |> Enum.filter(fn file ->
        Enum.any?(critical_modules, &String.contains?(file.name, &1))
      end)
      |> Enum.map(& &1.coverage)

    %{
      modules_count: length(critical_modules),
      covered_modules: length(critical_coverage),
      average_coverage:
        if(length(critical_coverage) > 0,
          do: Enum.sum(critical_coverage) / length(critical_coverage),
          else: 0
        ),
      min_coverage: if(length(critical_coverage) > 0, do: Enum.min(critical_coverage), else: 0)
    }
  end

  # Test categorization

  defp categorize_tests do
    test_categories = %{
      unit: count_files_in_pattern("test/eve_dmv/**/*_test.exs"),
      integration: count_files_in_pattern("test/integration/**/*_test.exs"),
      e2e: count_files_in_pattern("test/e2e/**/*_test.exs"),
      performance: count_files_in_pattern("test/performance/**/*_test.exs"),
      benchmarks: count_files_in_pattern("test/benchmarks/**/*_test.exs"),
      live_view: count_files_in_pattern("test/eve_dmv_web/live/**/*_test.exs")
    }

    total = Enum.sum(Map.values(test_categories))
    Map.put(test_categories, :total, total)
  end

  defp count_files_in_pattern(pattern) do
    length(Path.wildcard(pattern))
  end

  # Performance measurement

  defp measure_test_execution_time do
    start_time = System.monotonic_time(:millisecond)

    case System.cmd("mix", ["test", "--trace"], stderr_to_stdout: true, env: %{}) do
      {_output, 0} ->
        end_time = System.monotonic_time(:millisecond)
        end_time - start_time

      _ ->
        nil
    end
  rescue
    _ -> nil
  end

  defp identify_flaky_tests do
    # This would require test history analysis
    # For now, return placeholder
    %{
      count: 0,
      tests: []
    }
  end

  @doc """
  Analyzes test performance metrics.
  """
  def analyze_test_performance do
    %{
      average_test_time: measure_average_test_time(),
      slow_tests: identify_slow_tests(),
      test_parallelization: analyze_test_parallelization()
    }
  end

  # Placeholder implementations for complex metrics
  defp measure_average_test_time, do: 0
  defp identify_slow_tests, do: []
  defp analyze_test_parallelization, do: %{parallel_tests: 0}
end

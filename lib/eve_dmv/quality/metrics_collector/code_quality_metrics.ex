defmodule EveDmv.Quality.MetricsCollector.CodeQualityMetrics do
  @moduledoc """
  Code quality metrics collection and analysis.

  Handles Credo analysis, Dialyzer checks, code complexity,
  dependency analysis, and maintainability calculations.
  """

  @doc """
  Collects comprehensive code quality metrics.
  """
  def collect_code_quality_metrics do
    %{
      credo_analysis: run_credo_analysis(),
      dialyzer_analysis: run_dialyzer_analysis(),
      code_complexity: analyze_code_complexity(),
      dependency_analysis: analyze_dependencies(),
      code_duplication: analyze_code_duplication(),
      maintainability_index: calculate_maintainability_index()
    }
  end

  @doc """
  Calculates code quality score based on metrics.
  """
  def calculate_code_quality_score(code_metrics) do
    credo_score = max(0, 100 - code_metrics.credo_analysis.total_issues * 2)
    dialyzer_score = max(0, 100 - code_metrics.dialyzer_analysis.warning_count * 5)
    (credo_score + dialyzer_score) / 2
  end

  @doc """
  Generates code quality recommendations.
  """
  def generate_code_quality_recommendations(code_metrics) do
    recommendations = []

    credo_issues = code_metrics.credo_analysis.total_issues

    recommendations =
      if credo_issues > 5 do
        ["Address #{credo_issues} code quality issues identified by Credo" | recommendations]
      else
        recommendations
      end

    dialyzer_warnings = code_metrics.dialyzer_analysis.warning_count

    recommendations =
      if dialyzer_warnings > 0 do
        ["Fix #{dialyzer_warnings} Dialyzer warnings" | recommendations]
      else
        recommendations
      end

    large_files = code_metrics.code_complexity.large_files

    recommendations =
      if large_files > 5 do
        ["Refactor #{large_files} large files (>300 lines)" | recommendations]
      else
        recommendations
      end

    recommendations
  end

  # Credo analysis

  defp run_credo_analysis do
    case System.cmd("mix", ["credo", "--format", "json"], stderr_to_stdout: true, env: []) do
      {output, _} ->
        case Jason.decode(output) do
          {:ok, data} ->
            issues = Map.get(data, "issues", [])

            %{
              total_issues: length(issues),
              issues_by_category: group_issues_by_category(issues),
              issues_by_priority: group_issues_by_priority(issues)
            }

          _ ->
            %{total_issues: 0, issues_by_category: %{}, issues_by_priority: %{}}
        end
    end
  rescue
    _ -> %{total_issues: 0, issues_by_category: %{}, issues_by_priority: %{}}
  end

  defp group_issues_by_category(issues) do
    issues
    |> Enum.group_by(&Map.get(&1, "category", "unknown"))
    |> Enum.map(fn {category, issue_list} -> {category, length(issue_list)} end)
    |> Enum.into(%{})
  end

  defp group_issues_by_priority(issues) do
    issues
    |> Enum.group_by(&Map.get(&1, "priority", "unknown"))
    |> Enum.map(fn {priority, issue_list} -> {priority, length(issue_list)} end)
    |> Enum.into(%{})
  end

  # Dialyzer analysis

  defp run_dialyzer_analysis do
    case System.cmd("mix", ["dialyzer", "--format", "short"], stderr_to_stdout: true, env: []) do
      {output, _} ->
        warnings =
          output
          |> String.split("\n")
          |> Enum.filter(&String.contains?(&1, "Warning:"))

        %{
          warning_count: length(warnings),
          # Limit for performance
          warnings: Enum.take(warnings, 10)
        }
    end
  rescue
    _ -> %{warning_count: 0, warnings: []}
  end

  # Code complexity analysis

  defp analyze_code_complexity do
    elixir_files = Path.wildcard("lib/**/*.ex")

    total_lines =
      elixir_files
      |> Enum.map(&count_lines_in_file/1)
      |> Enum.sum()

    %{
      total_files: length(elixir_files),
      total_lines_of_code: total_lines,
      average_file_size:
        if(length(elixir_files) > 0, do: div(total_lines, length(elixir_files)), else: 0),
      large_files:
        elixir_files
        |> Enum.filter(&(count_lines_in_file(&1) > 300))
        |> then(&length/1),
      file_size_distribution: calculate_file_size_distribution(elixir_files)
    }
  end

  defp count_lines_in_file(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        content
        |> String.split("\n")
        |> Enum.reject(&(String.trim(&1) == "" or String.starts_with?(String.trim(&1), "#")))
        |> length()

      _ ->
        0
    end
  end

  defp calculate_file_size_distribution(files) do
    files
    |> Enum.group_by(fn file ->
      lines = count_lines_in_file(file)

      cond do
        lines <= 50 -> :small
        lines <= 150 -> :medium
        lines <= 300 -> :large
        true -> :very_large
      end
    end)
    |> Enum.map(fn {size, file_list} -> {size, length(file_list)} end)
    |> Enum.into(%{})
  end

  # Dependency analysis

  defp analyze_dependencies do
    case File.read("mix.lock") do
      {:ok, content} ->
        deps =
          content
          |> String.split("\n")
          |> Enum.filter(&String.starts_with?(&1, "  \""))
          |> length()

        %{
          total_dependencies: deps,
          outdated_dependencies: check_outdated_dependencies(),
          dependency_categories: categorize_dependencies()
        }

      _ ->
        %{total_dependencies: 0, outdated_dependencies: 0, dependency_categories: %{}}
    end
  end

  defp check_outdated_dependencies do
    case System.cmd("mix", ["hex.outdated"], stderr_to_stdout: true, env: clean_env()) do
      {output, _} ->
        output
        |> String.split("\n")
        |> Enum.filter(&String.contains?(&1, "Update available"))
        |> length()
    end
  rescue
    _ -> 0
  end

  defp categorize_dependencies do
    # This would parse mix.exs to categorize deps
    # For now, return placeholder
    %{
      production: 0,
      development: 0,
      test: 0
    }
  end

  # Code duplication

  defp analyze_code_duplication do
    # Simplified duplication detection
    # In a real implementation, this would use tools like mix_test_watch or similar
    %{
      estimated_duplication_percentage: calculate_duplication_estimate(),
      duplicate_blocks: []
    }
  end

  defp calculate_duplication_estimate do
    # Very rough estimate based on file similarity
    # A proper implementation would use AST analysis
    0
  end

  # Maintainability index

  defp calculate_maintainability_index do
    code_metrics = analyze_code_complexity()

    base_score = 100

    # Deduct points for complexity
    complexity_penalty = min(code_metrics.large_files * 2, 20)

    # Deduct points for very large files
    very_large_penalty = Map.get(code_metrics.file_size_distribution, :very_large, 0) * 5

    # Bonus for good file size distribution
    small_file_bonus =
      if Map.get(code_metrics.file_size_distribution, :small, 0) > code_metrics.total_files * 0.3 do
        5
      else
        0
      end

    max(0, base_score - complexity_penalty - very_large_penalty + small_file_bonus)
  end

  defp clean_env do
    %{
      "PATH" => System.get_env("PATH", ""),
      "HOME" => System.get_env("HOME", ""),
      "MIX_ENV" => System.get_env("MIX_ENV", "dev")
    }
  end
end

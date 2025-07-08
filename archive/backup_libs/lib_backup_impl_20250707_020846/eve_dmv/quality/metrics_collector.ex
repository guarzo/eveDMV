defmodule EveDmv.Quality.MetricsCollector do
  @moduledoc """
  Quality metrics collection and reporting for Team Delta quality gates.
  Collects comprehensive quality metrics across all aspects of the codebase.
  """

  alias EveDmv.Quality.MetricsCollector.CiCdMetrics
  alias EveDmv.Quality.MetricsCollector.CodeQualityMetrics
  alias EveDmv.Quality.MetricsCollector.DocumentationMetrics
  alias EveDmv.Quality.MetricsCollector.PerformanceMetrics
  alias EveDmv.Quality.MetricsCollector.SecurityMetrics
  alias EveDmv.Quality.MetricsCollector.TestMetrics

  @doc """
  Collects comprehensive quality metrics for the application.
  """
  def collect_metrics do
    %{
      test_metrics: TestMetrics.collect_test_metrics(),
      code_quality_metrics: CodeQualityMetrics.collect_code_quality_metrics(),
      performance_metrics: PerformanceMetrics.collect_performance_metrics(),
      security_metrics: SecurityMetrics.collect_security_metrics(),
      documentation_metrics: DocumentationMetrics.collect_documentation_metrics(),
      ci_cd_metrics: CiCdMetrics.collect_ci_cd_metrics(),
      timestamp: DateTime.utc_now()
    }
  end

  @doc """
  Generates a quality report based on collected metrics.
  """
  def generate_quality_report(metrics \\ nil) do
    metrics = metrics || collect_metrics()

    %{
      overall_score: calculate_overall_quality_score(metrics),
      grade: calculate_quality_grade(metrics),
      summary: generate_quality_summary(metrics),
      recommendations: generate_recommendations(metrics),
      metrics: metrics
    }
  end

  @doc """
  Exports quality metrics to various formats.
  """
  def export_metrics(format \\ :json, metrics \\ nil) do
    metrics = metrics || collect_metrics()

    case format do
      :json -> Jason.encode!(metrics, pretty: true)
      :csv -> export_to_csv(metrics)
      :html -> export_to_html(metrics)
      _ -> {:error, "Unsupported format"}
    end
  end

  # Quality Score Calculation

  defp calculate_overall_quality_score(metrics) do
    weights = %{
      test_metrics: 0.3,
      code_quality_metrics: 0.25,
      performance_metrics: 0.15,
      security_metrics: 0.15,
      documentation_metrics: 0.1,
      ci_cd_metrics: 0.05
    }

    scores = %{
      test_metrics: TestMetrics.calculate_test_score(metrics.test_metrics),
      code_quality_metrics:
        CodeQualityMetrics.calculate_code_quality_score(metrics.code_quality_metrics),
      performance_metrics:
        PerformanceMetrics.calculate_performance_score(metrics.performance_metrics),
      security_metrics: SecurityMetrics.calculate_security_score(metrics.security_metrics),
      documentation_metrics:
        DocumentationMetrics.calculate_documentation_score(metrics.documentation_metrics),
      ci_cd_metrics: CiCdMetrics.calculate_ci_cd_score(metrics.ci_cd_metrics)
    }

    weighted_score =
      Enum.reduce(weights, 0, fn {category, weight}, acc ->
        acc + scores[category] * weight
      end)
    round(weighted_score)
  end

  defp calculate_quality_grade(metrics) do
    score = calculate_overall_quality_score(metrics)

    cond do
      score >= 90 -> "A+"
      score >= 85 -> "A"
      score >= 80 -> "A-"
      score >= 75 -> "B+"
      score >= 70 -> "B"
      score >= 65 -> "B-"
      score >= 60 -> "C+"
      score >= 55 -> "C"
      score >= 50 -> "C-"
      true -> "D"
    end
  end

  defp generate_quality_summary(metrics) do
    score = calculate_overall_quality_score(metrics)
    grade = calculate_quality_grade(metrics)

    "Overall Quality Score: #{score}/100 (Grade: #{grade})"
  end

  defp generate_recommendations(metrics) do
    initial_recommendations = []

    # Collect recommendations from each metrics module
    test_recommendations =
      initial_recommendations ++ generate_test_recommendations(metrics.test_metrics)

    code_quality_recommendations =
      test_recommendations ++
        CodeQualityMetrics.generate_code_quality_recommendations(metrics.code_quality_metrics)

    security_recommendations =
      code_quality_recommendations ++
        SecurityMetrics.generate_security_recommendations(metrics.security_metrics)

    documentation_recommendations =
      security_recommendations ++
        DocumentationMetrics.generate_documentation_recommendations(metrics.documentation_metrics)

    performance_recommendations =
      documentation_recommendations ++
        PerformanceMetrics.generate_performance_recommendations(metrics.performance_metrics)

    final_recommendations =
      performance_recommendations ++
        CiCdMetrics.generate_ci_cd_recommendations(metrics.ci_cd_metrics)

    if Enum.empty?(final_recommendations) do
      ["Great job! All quality metrics are within acceptable thresholds."]
    else
      final_recommendations
    end
  end

  defp generate_test_recommendations(test_metrics) do
    initial_recommendations = []

    # Test coverage recommendations
    coverage = test_metrics.test_coverage.overall || 0

    coverage_recommendations =
      if coverage < 70 do
        [
          "Increase test coverage to at least 70% (currently #{coverage}%)"
          | initial_recommendations
        ]
      else
        initial_recommendations
      end

    # Critical path coverage
    critical_coverage = test_metrics.critical_path_coverage

    critical_recommendations =
      if critical_coverage.average_coverage < 80 do
        [
          "Improve critical path test coverage (current: #{round(critical_coverage.average_coverage)}%)"
          | coverage_recommendations
        ]
      else
        coverage_recommendations
      end

    critical_recommendations
  end

  defp export_to_csv(metrics) do
    # Simplified CSV export
    "Category,Metric,Value\n" <>
      "Test,Coverage,#{metrics.test_metrics.test_coverage.overall}\n" <>
      "Test,Total Tests,#{metrics.test_metrics.total_tests}\n" <>
      "Quality,Credo Issues,#{metrics.code_quality_metrics.credo_analysis.total_issues}\n" <>
      "Security,Vulnerabilities,#{metrics.security_metrics.dependency_audit.vulnerabilities}\n"
  end

  defp export_to_html(metrics) do
    """
    <!DOCTYPE html>
    <html>
    <head><title>Quality Metrics Report</title></head>
    <body>
      <h1>Quality Metrics Report</h1>
      <h2>Overall Score: #{calculate_overall_quality_score(metrics)}/100</h2>
      <h3>Grade: #{calculate_quality_grade(metrics)}</h3>
      <p>Generated: #{metrics.timestamp}</p>
    </body>
    </html>
    """
  end
end

defmodule EveDmv.Quality.MetricsCollector.CiCdMetrics do
  @moduledoc """
  CI/CD metrics collection and analysis.

  Handles GitHub Actions analysis, script quality checks,
  deployment configuration, and monitoring setup verification.
  """

  import Bitwise

  @doc """
  Collects comprehensive CI/CD metrics.
  """
  def collect_ci_cd_metrics do
    %{
      github_actions: analyze_github_actions(),
      scripts_quality: analyze_scripts_quality(),
      deployment_config: analyze_deployment_config(),
      monitoring_setup: check_monitoring_setup()
    }
  end

  @doc """
  Calculates CI/CD score based on metrics.
  """
  def calculate_ci_cd_score(ci_cd_metrics) do
    base_score = 90

    # Adjust based on GitHub Actions
    actions_bonus =
      if ci_cd_metrics.github_actions.has_ci_workflow, do: 10, else: 0

    # Adjust based on deployment config
    deployment_bonus =
      if ci_cd_metrics.deployment_config.has_dockerfile, do: 5, else: 0

    # Adjust based on monitoring
    monitoring_bonus =
      if ci_cd_metrics.monitoring_setup.has_telemetry, do: 5, else: 0

    min(100, base_score + actions_bonus + deployment_bonus + monitoring_bonus)
  end

  @doc """
  Generates CI/CD recommendations.
  """
  def generate_ci_cd_recommendations(ci_cd_metrics) do
    recommendations = []

    # Check GitHub Actions
    gh_actions = ci_cd_metrics.github_actions

    recommendations =
      cond do
        gh_actions.workflow_count == 0 ->
          ["Add GitHub Actions workflows for CI/CD" | recommendations]

        not gh_actions.has_ci_workflow ->
          ["Add CI workflow for automated testing" | recommendations]

        true ->
          recommendations
      end

    # Check deployment config
    deploy_config = ci_cd_metrics.deployment_config

    recommendations =
      if not deploy_config.has_dockerfile do
        ["Add Dockerfile for containerized deployments" | recommendations]
      else
        recommendations
      end

    # Check monitoring
    monitoring = ci_cd_metrics.monitoring_setup

    recommendations =
      if not monitoring.has_health_checks do
        ["Add health check endpoints for monitoring" | recommendations]
      else
        recommendations
      end

    recommendations
  end

  # GitHub Actions analysis

  defp analyze_github_actions do
    workflow_files =
      Path.wildcard(".github/workflows/*.yml") ++
        Path.wildcard(".github/workflows/*.yaml")

    workflow_analysis =
      workflow_files
      |> Enum.map(&analyze_workflow_file/1)
      |> Enum.reduce(%{ci: false, cd: false, quality: false, security: false}, fn analysis, acc ->
        %{
          ci: acc.ci or analysis.has_test_job,
          cd: acc.cd or analysis.has_deploy_job,
          quality: acc.quality or analysis.has_quality_checks,
          security: acc.security or analysis.has_security_checks
        }
      end)

    %{
      workflow_count: length(workflow_files),
      workflow_files: Enum.map(workflow_files, &Path.basename/1),
      has_ci_workflow: workflow_analysis.ci,
      has_cd_workflow: workflow_analysis.cd,
      has_quality_checks: workflow_analysis.quality,
      has_security_checks: workflow_analysis.security,
      workflow_triggers: extract_workflow_triggers(workflow_files)
    }
  end

  defp analyze_workflow_file(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        %{
          file: Path.basename(file_path),
          has_test_job:
            String.contains?(content, "mix test") or String.contains?(content, "test:"),
          has_deploy_job:
            String.contains?(content, "deploy") or String.contains?(content, "release"),
          has_quality_checks:
            String.contains?(content, "credo") or String.contains?(content, "dialyzer"),
          has_security_checks:
            String.contains?(content, "deps.audit") or String.contains?(content, "security")
        }

      _ ->
        %{
          file: Path.basename(file_path),
          has_test_job: false,
          has_deploy_job: false,
          has_quality_checks: false,
          has_security_checks: false
        }
    end
  end

  defp extract_workflow_triggers(workflow_files) do
    workflow_files
    |> Enum.flat_map(fn file ->
      case File.read(file) do
        {:ok, content} ->
          cond do
            String.contains?(content, "push:") -> [:push]
            String.contains?(content, "pull_request:") -> [:pull_request]
            String.contains?(content, "schedule:") -> [:schedule]
            String.contains?(content, "workflow_dispatch:") -> [:manual]
            true -> []
          end

        _ ->
          []
      end
    end)
    |> Enum.uniq()
  end

  # Scripts quality analysis

  defp analyze_scripts_quality do
    script_files = Path.wildcard("scripts/*.sh")

    quality_checks =
      script_files
      |> Enum.map(&analyze_script_file/1)

    %{
      script_count: length(script_files),
      quality_checks: quality_checks,
      well_documented_scripts: Enum.count(quality_checks, & &1.has_documentation),
      executable_scripts: Enum.count(quality_checks, & &1.is_executable),
      error_handling_scripts: Enum.count(quality_checks, & &1.has_error_handling),
      average_quality_score: calculate_average_script_quality(quality_checks)
    }
  end

  defp analyze_script_file(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        %{
          file: Path.basename(file_path),
          has_error_handling:
            String.contains?(content, "set -e") or String.contains?(content, "set -euo pipefail"),
          has_documentation: count_script_comments(content) >= 5,
          is_executable: executable?(file_path),
          has_shebang: String.starts_with?(content, "#!/"),
          lines_of_code: count_script_lines(content)
        }

      _ ->
        %{
          file: Path.basename(file_path),
          has_error_handling: false,
          has_documentation: false,
          is_executable: false,
          has_shebang: false,
          lines_of_code: 0
        }
    end
  end

  defp executable?(file_path) do
    case File.stat(file_path) do
      {:ok, %File.Stat{mode: mode}} ->
        # Check if owner-executable bit is set
        band(mode, 0o100) != 0

      _ ->
        false
    end
  end

  defp count_script_comments(content) do
    content
    |> String.split("\n")
    |> Enum.count(
      &(String.starts_with?(String.trim(&1), "#") and not String.starts_with?(&1, "#!"))
    )
  end

  defp count_script_lines(content) do
    content
    |> String.split("\n")
    |> Enum.reject(&(String.trim(&1) == "" or String.starts_with?(String.trim(&1), "#")))
    |> length()
  end

  defp calculate_average_script_quality(quality_checks) do
    if Enum.empty?(quality_checks) do
      0
    else
      total_score =
        quality_checks
        |> Enum.map(fn check ->
          score = 0
          score = if check.has_error_handling, do: score + 25, else: score
          score = if check.has_documentation, do: score + 25, else: score
          score = if check.is_executable, do: score + 25, else: score
          score = if check.has_shebang, do: score + 25, else: score
          score
        end)
        |> Enum.sum()

      round(total_score / length(quality_checks))
    end
  end

  # Deployment configuration

  defp analyze_deployment_config do
    %{
      has_dockerfile: File.exists?("Dockerfile"),
      has_docker_compose:
        File.exists?("docker-compose.yml") or File.exists?("docker-compose.yaml"),
      has_k8s_config:
        File.exists?("k8s") or File.exists?("kubernetes") or File.exists?("deploy/k8s"),
      has_release_config: check_release_config(),
      has_env_example: File.exists?(".env.example") or File.exists?(".env.sample"),
      deployment_readiness: calculate_deployment_readiness()
    }
  end

  defp check_release_config do
    File.exists?("rel") or
      File.exists?("config/releases.exs") or
      check_mix_release_config()
  end

  defp check_mix_release_config do
    case File.read("mix.exs") do
      {:ok, content} ->
        String.contains?(content, "releases:")

      _ ->
        false
    end
  end

  defp calculate_deployment_readiness do
    scores = [
      if(File.exists?("Dockerfile"), do: 30, else: 0),
      if(check_release_config(), do: 30, else: 0),
      if(File.exists?(".env.example"), do: 20, else: 0),
      if(File.exists?("docker-compose.yml"), do: 20, else: 0)
    ]

    Enum.sum(scores)
  end

  # Monitoring setup

  defp check_monitoring_setup do
    %{
      has_telemetry: check_telemetry_setup(),
      has_logging_config: check_logging_config(),
      has_health_checks: check_health_endpoints(),
      has_metrics_endpoint: check_metrics_endpoint(),
      monitoring_completeness: calculate_monitoring_completeness()
    }
  end

  defp check_telemetry_setup do
    # Check if telemetry is configured
    File.exists?("lib/eve_dmv/telemetry.ex") or
      File.exists?("lib/eve_dmv_web/telemetry.ex") or
      check_telemetry_dependency()
  end

  defp check_telemetry_dependency do
    case File.read("mix.exs") do
      {:ok, content} ->
        String.contains?(content, ":telemetry") or String.contains?(content, ":telemetry_metrics")

      _ ->
        false
    end
  end

  defp check_logging_config do
    # Check for logging configuration
    Application.get_env(:logger, :backends) != nil or
      File.exists?("config/logger.exs")
  end

  defp check_health_endpoints do
    # Check for health check endpoints
    router_file = "lib/eve_dmv_web/router.ex"

    case File.read(router_file) do
      {:ok, content} ->
        String.contains?(content, "health") or String.contains?(content, "status")

      _ ->
        false
    end
  end

  defp check_metrics_endpoint do
    # Check for metrics endpoint
    router_file = "lib/eve_dmv_web/router.ex"

    case File.read(router_file) do
      {:ok, content} ->
        String.contains?(content, "metrics") or String.contains?(content, "prometheus")

      _ ->
        false
    end
  end

  defp calculate_monitoring_completeness do
    scores = [
      if(check_telemetry_setup(), do: 30, else: 0),
      if(check_logging_config(), do: 25, else: 0),
      if(check_health_endpoints(), do: 25, else: 0),
      if(check_metrics_endpoint(), do: 20, else: 0)
    ]

    Enum.sum(scores)
  end
end

defmodule EveDmv.Quality.MetricsCollector.SecurityMetrics do
  @moduledoc """
  Security metrics collection and analysis.

  Handles dependency auditing, code security scanning,
  authentication configuration analysis, and secrets detection.
  """

  @doc """
  Collects comprehensive security metrics.
  """
  def collect_security_metrics do
    %{
      dependency_audit: run_dependency_audit(),
      code_security_scan: run_security_scan(),
      authentication_config: analyze_auth_config(),
      secrets_detection: scan_for_secrets()
    }
  end

  @doc """
  Calculates security score based on metrics.
  """
  def calculate_security_score(security_metrics) do
    base_score = 100

    # Deduct for vulnerabilities
    vuln_penalty = security_metrics.dependency_audit.vulnerabilities * 10

    # Deduct for potential secrets
    secrets_penalty = min(security_metrics.secrets_detection.potential_secrets_count * 2, 20)

    # Bonus for proper auth config
    auth_bonus = if security_metrics.authentication_config.eve_sso_configured, do: 5, else: 0

    max(0, base_score - vuln_penalty - secrets_penalty + auth_bonus)
  end

  @doc """
  Generates security recommendations based on metrics.
  """
  def generate_security_recommendations(security_metrics) do
    initial_recommendations = []

    vulns = security_metrics.dependency_audit.vulnerabilities

    vuln_recommendations =
      if vulns > 0 do
        ["Fix #{vulns} security vulnerabilities in dependencies" | initial_recommendations]
      else
        initial_recommendations
      end

    secrets = security_metrics.secrets_detection.potential_secrets_count

    final_recommendations =
      if secrets > 0 do
        [
          "Review #{secrets} potential secrets in #{security_metrics.secrets_detection.files_with_secrets} files"
          | vuln_recommendations
        ]
      else
        vuln_recommendations
      end

    final_recommendations
  end

  # Dependency auditing

  defp run_dependency_audit do
    case System.cmd("mix", ["deps.audit"], stderr_to_stdout: true, env: clean_env()) do
      {_output, 0} ->
        %{status: "passed", vulnerabilities: 0}

      {output, _} ->
        vulnerability_count =
          output
          |> String.split("\n")
          |> Enum.filter(&String.contains?(&1, "vulnerability"))
          |> length()

        %{status: "failed", vulnerabilities: vulnerability_count}
    end
  rescue
    _ -> %{status: "error", vulnerabilities: 0}
  end

  # Security scanning

  defp run_security_scan do
    %{
      hardcoded_secrets: scan_for_hardcoded_secrets(),
      sql_injection_risks: scan_for_sql_injection(),
      xss_risks: scan_for_xss_risks()
    }
  end

  defp scan_for_hardcoded_secrets do
    # Count files with potential hardcoded secrets
    secret_patterns = ["password", "secret", "key", "token"]

    Path.wildcard("lib/**/*.ex")
    |> Enum.count(fn file ->
      case File.read(file) do
        {:ok, content} ->
          # Look for hardcoded values (quoted strings after secret patterns)
          secret_patterns
          |> Enum.any?(fn pattern ->
            Regex.match?(~r/#{pattern}\s*[:=]\s*"[^"]+"/i, content)
          end)

        _ ->
          false
      end
    end)
  end

  defp scan_for_sql_injection do
    # Simplified SQL injection risk detection
    Path.wildcard("lib/**/*.ex")
    |> Enum.count(fn file ->
      case File.read(file) do
        {:ok, content} ->
          # Look for string interpolation in query contexts
          String.contains?(content, "from(") and String.contains?(content, "\#{")

        _ ->
          false
      end
    end)
  end

  defp scan_for_xss_risks do
    # Simplified XSS risk detection
    Path.wildcard("lib/**/*.ex")
    |> Enum.count(fn file ->
      case File.read(file) do
        {:ok, content} ->
          # Look for raw HTML output
          String.contains?(content, "raw(") or String.contains?(content, "Phoenix.HTML.raw")

        _ ->
          false
      end
    end)
  end

  # Authentication configuration

  defp analyze_auth_config do
    %{
      eve_sso_configured: check_eve_sso_config(),
      session_security: analyze_session_config(),
      api_rate_limiting: check_rate_limiting_config()
    }
  end

  defp check_eve_sso_config do
    # Check if EVE SSO is properly configured
    File.exists?("lib/eve_dmv_web/controllers/auth_controller.ex") and
      Application.get_env(:eve_dmv, :eve_sso_client_id) != nil
  end

  defp analyze_session_config do
    # Check session security configuration
    session_options = Application.get_env(:eve_dmv, EveDmvWeb.Endpoint)[:session_options] || []

    %{
      secure: Keyword.get(session_options, :secure, false),
      http_only: Keyword.get(session_options, :http_only, true),
      same_site: Keyword.get(session_options, :same_site, "Lax")
    }
  end

  defp check_rate_limiting_config do
    # Check if rate limiting is configured
    File.exists?("lib/eve_dmv_web/plugs/rate_limiter.ex") or
      Application.get_env(:eve_dmv, :rate_limiting) != nil
  end

  # Secrets detection

  defp scan_for_secrets do
    secret_patterns = ["password", "secret", "key", "token"]

    findings =
      Path.wildcard("lib/**/*.ex")
      |> Enum.flat_map(fn file ->
        case File.read(file) do
          {:ok, content} ->
            secret_patterns
            |> Enum.filter(&String.contains?(String.downcase(content), &1))
            |> Enum.map(&{file, &1})

          _ ->
            []
        end
      end)

    %{
      potential_secrets_count: length(findings),
      files_with_secrets:
        findings
        |> Enum.map(&elem(&1, 0))
        |> Enum.uniq()
        |> then(&length/1)
    }
  end

  defp clean_env do
    %{
      "PATH" => System.get_env("PATH", ""),
      "HOME" => System.get_env("HOME", ""),
      "MIX_ENV" => System.get_env("MIX_ENV", "dev")
    }
  end
end

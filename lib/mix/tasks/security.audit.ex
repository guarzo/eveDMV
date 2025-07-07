defmodule Mix.Tasks.Security.Audit do
  @moduledoc """
  Mix task to run comprehensive security audits.

  This task performs database and container security audits and generates
  detailed reports with recommendations for security improvements.

  ## Examples

      mix security.audit
      mix security.audit --database
      mix security.audit --container
      mix security.audit --format json
  """

  @shortdoc "Run security audits for database and container infrastructure"

  use Mix.Task

  # Security review modules not yet implemented
  #   alias EveDmv.Security.ContainerSecurityReview
  alias EveDmv.Security.DatabaseSecurityReview

  @impl Mix.Task
  def run(args) do
    {opts, _args, _invalid} =
      OptionParser.parse(args,
        switches: [
          database: :boolean,
          container: :boolean,
          format: :string,
          output: :string
        ],
        aliases: [
          d: :database,
          c: :container,
          f: :format,
          o: :output
        ]
      )

    # Start the application if needed
    Mix.Task.run("app.start")

    format = Keyword.get(opts, :format, "text")
    output_file = Keyword.get(opts, :output)

    # Determine which audits to run
    run_database = Keyword.get(opts, :database, true)
    run_container = Keyword.get(opts, :container, true)

    # If specific audit is requested, only run that one
    {final_run_database, final_run_container} =
      if Keyword.has_key?(opts, :database) or Keyword.has_key?(opts, :container) do
        {Keyword.get(opts, :database, false), Keyword.get(opts, :container, false)}
      else
        {run_database, run_container}
      end

    Mix.shell().info("🔒 Starting EVE DMV Security Audit...")
    Mix.shell().info("")

    audit_results = %{
      timestamp: DateTime.utc_now(),
      database_audit: if(final_run_database, do: run_database_audit(), else: nil),
      container_audit: if(final_run_container, do: run_container_audit(), else: nil)
    }

    # Generate and display report
    case format do
      "json" ->
        output_json_report(audit_results, output_file)

      "html" ->
        output_html_report(audit_results, output_file)

      _ ->
        output_text_report(audit_results, output_file)
    end

    # Summary
    display_audit_summary(audit_results)
  end

  defp run_database_audit do
    Mix.shell().info("📊 Running Database Security Audit...")

    # Database security review implementation deferred pending security requirements
    results = %{
      status: :not_implemented,
      message: "Database security review module not yet implemented",
      timestamp: DateTime.utc_now()
    }

    Mix.shell().info("⚠️  Database audit not implemented yet")
    results
  end

  defp run_container_audit do
    Mix.shell().info("🐳 Running Container Security Audit...")

    # Container security review implementation deferred pending containerization
    results = %{
      status: :not_implemented,
      message: "Container security review module not yet implemented",
      timestamp: DateTime.utc_now()
    }

    Mix.shell().info("⚠️  Container audit not implemented yet")
    results
  end

  defp output_text_report(audit_results, output_file) do
    report = generate_text_report(audit_results)

    if output_file do
      File.write!(output_file, report)
      Mix.shell().info("📄 Report written to #{output_file}")
    else
      Mix.shell().info(report)
    end
  end

  defp output_json_report(audit_results, output_file) do
    json_report = Jason.encode!(audit_results, pretty: true)

    if output_file do
      File.write!(output_file, json_report)
      Mix.shell().info("📄 JSON report written to #{output_file}")
    else
      Mix.shell().info(json_report)
    end
  end

  defp output_html_report(audit_results, output_file) do
    html_report = generate_html_report(audit_results)
    output_file = output_file || "security_audit_report.html"

    File.write!(output_file, html_report)
    Mix.shell().info("📄 HTML report written to #{output_file}")
  end

  defp generate_text_report(audit_results) do
    initial_report = []

    summary_report = [
      "🔒 EVE DMV Security Audit Report",
      String.duplicate("=", 50),
      "Generated: #{DateTime.to_string(audit_results.timestamp)}",
      ""
      | initial_report
    ]

    # Database audit section
    detailed_report =
      if audit_results.database_audit do
        summary_report ++ generate_database_text_section(audit_results.database_audit)
      else
        summary_report
      end

    # Container audit section
    final_report =
      if audit_results.container_audit do
        detailed_report ++ generate_container_text_section(audit_results.container_audit)
      else
        detailed_report
      end

    final_report
    |> Enum.reverse()
    |> Enum.join("\n")
  end

  defp generate_database_text_section(db_audit) do
    [
      "",
      "📊 DATABASE SECURITY AUDIT",
      String.duplicate("-", 30),
      "",
      "Connection Security:",
      "  SSL Enabled: #{format_status(db_audit.connection_security.ssl_enabled)}",
      "  Connection Encryption: #{format_status(db_audit.connection_security.connection_encryption)}",
      "",
      "Access Controls:",
      "  User Privileges: #{format_status(db_audit.access_controls.user_privileges)}",
      "  Schema Permissions: #{format_status(db_audit.access_controls.schema_permissions)}",
      "",
      "Data Protection:",
      "  Encryption at Rest: #{format_status(db_audit.data_encryption.encryption_at_rest)}",
      "  PII Protection: #{format_status(db_audit.sensitive_data_handling.pii_protection)}",
      "",
      "Recommendations:",
      format_recommendations(db_audit.recommendations, "  "),
      ""
    ]
  end

  defp generate_container_text_section(container_audit) do
    [
      "",
      "🐳 CONTAINER SECURITY AUDIT",
      String.duplicate("-", 30),
      "",
      "Image Security:",
      "  Vulnerability Scanning: #{format_status(container_audit.image_security.vulnerability_scanning)}",
      "  Base Image Security: #{format_status(container_audit.dockerfile_security.base_image_security)}",
      "",
      "Runtime Security:",
      "  User Privileges: #{format_status(container_audit.dockerfile_security.user_privileges)}",
      "  Security Contexts: #{format_status(container_audit.runtime_security.security_contexts)}",
      "",
      "Secrets Management:",
      "  Environment Variables: #{format_status(container_audit.secrets_management.environment_variables)}",
      "  Secrets Storage: #{format_status(container_audit.secrets_management.secrets_storage)}",
      "",
      "Recommendations:",
      format_recommendations(container_audit.recommendations, "  "),
      ""
    ]
  end

  defp format_status(%{status: status, message: message}) do
    status_icon =
      case status do
        :secure -> "✅"
        :warning -> "⚠️"
        :info -> "ℹ️"
        _ -> "❓"
      end

    "#{status_icon} #{message}"
  end

  defp format_recommendations(recommendations, indent) do
    recommendations
    |> Enum.with_index(1)
    |> Enum.map(fn {rec, index} ->
      priority_icon =
        case rec.priority do
          :high -> "🔴"
          :medium -> "🟡"
          :low -> "🟢"
          _ -> "⚪"
        end

      [
        "#{indent}#{index}. #{priority_icon} #{rec.title}",
        "#{indent}   #{rec.description}",
        "#{indent}   Implementation: #{rec.implementation}",
        ""
      ]
    end)
    |> List.flatten()
    |> Enum.join("\n")
  end

  defp generate_html_report(audit_results) do
    """
    <!DOCTYPE html>
    <html>
    <head>
        <title>EVE DMV Security Audit Report</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 20px; }
            .header { background: #2563eb; color: white; padding: 20px; border-radius: 8px; }
            .section { margin: 20px 0; padding: 20px; border: 1px solid #e5e7eb; border-radius: 8px; }
            .status-secure { color: #16a34a; }
            .status-warning { color: #ea580c; }
            .status-info { color: #2563eb; }
            .recommendation { margin: 10px 0; padding: 10px; background: #f8fafc; border-radius: 4px; }
            .priority-high { border-left: 4px solid #dc2626; }
            .priority-medium { border-left: 4px solid #ea580c; }
            .priority-low { border-left: 4px solid #16a34a; }
        </style>
    </head>
    <body>
        <div class="header">
            <h1>🔒 EVE DMV Security Audit Report</h1>
            <p>Generated: #{DateTime.to_string(audit_results.timestamp)}</p>
        </div>

        #{if audit_results.database_audit, do: generate_database_html_section(audit_results.database_audit), else: ""}
        #{if audit_results.container_audit, do: generate_container_html_section(audit_results.container_audit), else: ""}
    </body>
    </html>
    """
  end

  defp generate_database_html_section(db_audit) do
    """
    <div class="section">
        <h2>📊 Database Security Audit</h2>
        <h3>Connection Security</h3>
        <ul>
            <li>SSL Enabled: #{format_html_status(db_audit.connection_security.ssl_enabled)}</li>
            <li>Connection Encryption: #{format_html_status(db_audit.connection_security.connection_encryption)}</li>
        </ul>

        <h3>Recommendations</h3>
        #{format_html_recommendations(db_audit.recommendations)}
    </div>
    """
  end

  defp generate_container_html_section(container_audit) do
    """
    <div class="section">
        <h2>🐳 Container Security Audit</h2>
        <h3>Image Security</h3>
        <ul>
            <li>Vulnerability Scanning: #{format_html_status(container_audit.image_security.vulnerability_scanning)}</li>
            <li>Base Image Security: #{format_html_status(container_audit.dockerfile_security.base_image_security)}</li>
        </ul>

        <h3>Recommendations</h3>
        #{format_html_recommendations(container_audit.recommendations)}
    </div>
    """
  end

  defp format_html_status(%{status: status, message: message}) do
    class = "status-#{status}"
    "<span class=\"#{class}\">#{message}</span>"
  end

  defp format_html_recommendations(recommendations) do
    Enum.map_join(recommendations, "", fn rec ->
      priority_class = "priority-#{rec.priority}"

      """
      <div class="recommendation #{priority_class}">
          <strong>#{rec.title}</strong><br>
          #{rec.description}<br>
          <em>Implementation: #{rec.implementation}</em>
      </div>
      """
    end)
  end

  defp display_audit_summary(audit_results) do
    Mix.shell().info("")
    Mix.shell().info("📋 AUDIT SUMMARY")
    Mix.shell().info(String.duplicate("=", 20))

    total_recommendations = 0
    high_priority = 0

    {db_total_recommendations, db_high_priority} =
      if audit_results.database_audit do
        db_recs = length(audit_results.database_audit.recommendations)

        db_high =
          Enum.count(audit_results.database_audit.recommendations, &(&1.priority == :high))

        new_total = total_recommendations + db_recs
        new_high = high_priority + db_high
        Mix.shell().info("Database: #{db_recs} recommendations (#{db_high} high priority)")
        {new_total, new_high}
      else
        {total_recommendations, high_priority}
      end

    {final_total_recommendations, final_high_priority} =
      if audit_results.container_audit do
        container_recs = length(audit_results.container_audit.recommendations)

        container_high =
          Enum.count(audit_results.container_audit.recommendations, &(&1.priority == :high))

        new_total = db_total_recommendations + container_recs
        new_high = db_high_priority + container_high

        Mix.shell().info(
          "Container: #{container_recs} recommendations (#{container_high} high priority)"
        )

        {new_total, new_high}
      else
        {db_total_recommendations, db_high_priority}
      end

    Mix.shell().info("")

    Mix.shell().info(
      "Total: #{final_total_recommendations} recommendations (#{final_high_priority} high priority)"
    )

    if final_high_priority > 0 do
      Mix.shell().info("⚠️  Address high priority recommendations first!")
    else
      Mix.shell().info("✅ No high priority security issues found")
    end
  end
end

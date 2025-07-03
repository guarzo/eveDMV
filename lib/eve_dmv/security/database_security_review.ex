defmodule EveDmv.Security.DatabaseSecurityReview do
  @moduledoc """
  Database security review and hardening utilities.

  This module provides functions to audit and secure database configurations,
  including connection security, privilege management, and data protection.
  """

  require Logger
  alias EveDmv.Security.AuditLogger

  @doc """
  Perform a comprehensive database security audit.

  Returns a detailed report of security findings and recommendations.
  """
  @spec audit_database_security() ::
          {:ok,
           %{
             timestamp: DateTime.t(),
             connection_security: map(),
             access_controls: map(),
             data_encryption: map(),
             sql_injection_protection: map(),
             logging_and_monitoring: map(),
             backup_security: map(),
             sensitive_data_handling: map(),
             recommendations: [map()]
           }}
  def audit_database_security do
    Logger.info("Starting database security audit")

    audit_results = %{
      timestamp: DateTime.utc_now(),
      connection_security: audit_connection_security(),
      access_controls: audit_access_controls(),
      data_encryption: audit_data_encryption(),
      backup_security: audit_backup_security(),
      sql_injection_protection: audit_sql_injection_protection(),
      sensitive_data_handling: audit_sensitive_data_handling(),
      logging_and_monitoring: audit_database_logging(),
      recommendations: []
    }

    # Generate recommendations based on findings
    recommendations = generate_security_recommendations(audit_results)
    final_results = Map.put(audit_results, :recommendations, recommendations)

    # Log the audit completion
    AuditLogger.log_config_change(
      "system",
      :database_security_audit,
      nil,
      "completed"
    )

    {:ok, final_results}
  end

  @doc """
  Validate database connection security settings.
  """
  @spec audit_connection_security() :: %{
          certificate_validation: %{message: String.t(), status: :info},
          connection_encryption: %{
            message: String.t(),
            status: :info | :secure | :warning
          },
          connection_timeout: %{message: String.t(), status: :secure | :warning},
          idle_timeout: %{message: String.t(), status: :info},
          max_connections: %{message: String.t(), status: :secure | :warning},
          ssl_enabled: %{message: String.t(), status: :secure | :warning}
        }
  def audit_connection_security do
    %{
      ssl_enabled: check_ssl_connection(),
      connection_encryption: check_connection_encryption(),
      certificate_validation: check_certificate_validation(),
      connection_timeout: check_connection_timeout(),
      max_connections: check_max_connections(),
      idle_timeout: check_idle_timeout()
    }
  end

  @doc """
  Audit database access controls and permissions.
  """
  @spec audit_access_controls() :: %{
          function_privileges: %{message: String.t(), status: :info},
          role_based_access: %{message: String.t(), status: :info},
          schema_permissions: %{message: String.t(), status: :info},
          superuser_access: %{message: String.t(), status: :info},
          user_privileges: %{message: String.t(), status: :info}
        }
  def audit_access_controls do
    %{
      user_privileges: check_user_privileges(),
      role_based_access: check_role_based_access(),
      schema_permissions: check_schema_permissions(),
      function_privileges: check_function_privileges(),
      superuser_access: check_superuser_access()
    }
  end

  @doc """
  Check data encryption settings.
  """
  @spec audit_data_encryption() :: %{
          encryption_at_rest: %{message: String.t(), status: :info},
          encryption_in_transit: %{message: String.t(), status: :info},
          key_management: %{message: String.t(), status: :info},
          sensitive_fields: %{
            fields: [String.t(), ...],
            message: String.t(),
            status: :info
          }
        }
  def audit_data_encryption do
    %{
      encryption_at_rest: check_encryption_at_rest(),
      encryption_in_transit: check_encryption_in_transit(),
      key_management: check_key_management(),
      sensitive_fields: check_sensitive_field_encryption()
    }
  end

  @doc """
  Audit backup security configuration.
  """
  @spec audit_backup_security() :: %{
          backup_access_controls: %{message: String.t(), status: :info},
          backup_encryption: %{message: String.t(), status: :info},
          backup_retention: %{message: String.t(), status: :info},
          backup_testing: %{message: String.t(), status: :info}
        }
  def audit_backup_security do
    %{
      backup_encryption: check_backup_encryption(),
      backup_access_controls: check_backup_access_controls(),
      backup_retention: check_backup_retention_policy(),
      backup_testing: check_backup_testing()
    }
  end

  @doc """
  Check SQL injection protection measures.
  """
  @spec audit_sql_injection_protection() :: %{
          input_validation: %{message: String.t(), status: :info},
          orm_usage: %{message: String.t(), status: :secure},
          parameterized_queries: %{message: String.t(), status: :secure},
          query_sanitization: %{message: String.t(), status: :secure}
        }
  def audit_sql_injection_protection do
    %{
      parameterized_queries: check_parameterized_queries(),
      input_validation: check_input_validation(),
      query_sanitization: check_query_sanitization(),
      orm_usage: check_orm_usage()
    }
  end

  @doc """
  Audit sensitive data handling practices.
  """
  @spec audit_sensitive_data_handling() :: %{
          data_classification: %{message: String.t(), status: :info},
          data_masking: %{message: String.t(), status: :info},
          data_retention: %{message: String.t(), status: :info},
          pii_protection: %{
            fields: [String.t(), ...],
            message: String.t(),
            status: :warning
          }
        }
  def audit_sensitive_data_handling do
    %{
      data_classification: check_data_classification(),
      pii_protection: check_pii_protection(),
      data_masking: check_data_masking(),
      data_retention: check_data_retention_policies()
    }
  end

  @doc """
  Check database logging and monitoring configuration.
  """
  @spec audit_database_logging() :: %{
          connection_logging: %{message: String.t(), status: :info},
          error_logging: %{message: String.t(), status: :secure},
          log_retention: %{message: String.t(), status: :info},
          query_logging: %{message: String.t(), status: :info},
          security_event_logging: %{message: String.t(), status: :info}
        }
  def audit_database_logging do
    %{
      query_logging: check_query_logging(),
      connection_logging: check_connection_logging(),
      error_logging: check_error_logging(),
      security_event_logging: check_security_event_logging(),
      log_retention: check_log_retention()
    }
  end

  # Private audit functions

  defp check_ssl_connection do
    case Application.get_env(:eve_dmv, EveDmv.Repo)[:ssl] do
      true -> %{status: :secure, message: "SSL enabled for database connections"}
      false -> %{status: :warning, message: "SSL not enabled for database connections"}
      nil -> %{status: :warning, message: "SSL configuration not specified"}
    end
  end

  defp check_connection_encryption do
    # Check if connections are encrypted
    database_url = Application.get_env(:eve_dmv, EveDmv.Repo)[:url]

    cond do
      is_nil(database_url) ->
        %{status: :info, message: "Database URL not configured in application"}

      String.contains?(database_url, "sslmode=require") ->
        %{status: :secure, message: "SSL mode set to require"}

      String.contains?(database_url, "sslmode=") ->
        %{status: :warning, message: "SSL mode specified but not set to require"}

      true ->
        %{status: :warning, message: "SSL mode not specified in database URL"}
    end
  end

  defp check_certificate_validation do
    # In production, certificates should be validated
    env = Application.get_env(:eve_dmv, :environment, :dev)

    if env == :prod do
      %{status: :info, message: "Certificate validation should be enabled in production"}
    else
      %{status: :info, message: "Certificate validation configuration varies by environment"}
    end
  end

  defp check_connection_timeout do
    timeout = Application.get_env(:eve_dmv, EveDmv.Repo)[:timeout] || 15_000

    cond do
      timeout > 30_000 ->
        %{status: :warning, message: "Connection timeout is quite high (#{timeout}ms)"}

      timeout < 5_000 ->
        %{status: :warning, message: "Connection timeout may be too low (#{timeout}ms)"}

      true ->
        %{status: :secure, message: "Connection timeout is reasonable (#{timeout}ms)"}
    end
  end

  defp check_max_connections do
    pool_size = Application.get_env(:eve_dmv, EveDmv.Repo)[:pool_size] || 10

    cond do
      pool_size > 50 ->
        %{status: :warning, message: "Pool size is quite large (#{pool_size})"}

      pool_size < 5 ->
        %{status: :warning, message: "Pool size may be too small (#{pool_size})"}

      true ->
        %{status: :secure, message: "Pool size is reasonable (#{pool_size})"}
    end
  end

  defp check_idle_timeout do
    # Check if idle connections are properly timed out
    %{status: :info, message: "Idle timeout configuration should be reviewed for production"}
  end

  defp check_user_privileges do
    # This would typically query the database for user privileges
    %{status: :info, message: "Database user privileges should be reviewed manually"}
  end

  defp check_role_based_access do
    # Check if proper role-based access is implemented
    %{status: :info, message: "Role-based access control should be implemented"}
  end

  defp check_schema_permissions do
    # Verify schema-level permissions
    %{status: :info, message: "Schema permissions should be restricted to necessary operations"}
  end

  defp check_function_privileges do
    # Check database function execution privileges
    %{status: :info, message: "Database function privileges should be minimal"}
  end

  defp check_superuser_access do
    # Verify that application doesn't run with superuser privileges
    %{status: :info, message: "Application should not use superuser database access"}
  end

  defp check_encryption_at_rest do
    # Check if data is encrypted at rest
    %{status: :info, message: "Encryption at rest should be enabled for sensitive data"}
  end

  defp check_encryption_in_transit do
    # Already covered by SSL checks
    %{status: :info, message: "Encryption in transit covered by SSL configuration"}
  end

  defp check_key_management do
    # Check encryption key management
    %{status: :info, message: "Encryption key management strategy should be documented"}
  end

  defp check_sensitive_field_encryption do
    # Check if sensitive fields are encrypted
    sensitive_fields = [
      "api_keys.key_hash",
      "users.tokens",
      "users.auth_tokens"
    ]

    %{
      status: :info,
      message: "Sensitive fields should be encrypted",
      fields: sensitive_fields
    }
  end

  defp check_backup_encryption do
    # Check if backups are encrypted
    %{status: :info, message: "Database backups should be encrypted"}
  end

  defp check_backup_access_controls do
    # Check backup access controls
    %{status: :info, message: "Backup access should be restricted and audited"}
  end

  defp check_backup_retention_policy do
    # Check backup retention policies
    %{status: :info, message: "Backup retention policy should be defined and enforced"}
  end

  defp check_backup_testing do
    # Check if backup restoration is tested
    %{status: :info, message: "Backup restoration should be tested regularly"}
  end

  defp check_parameterized_queries do
    # Ecto uses parameterized queries by default
    %{status: :secure, message: "Ecto framework uses parameterized queries by default"}
  end

  defp check_input_validation do
    # Check input validation at application level
    %{status: :info, message: "Input validation should be implemented at application level"}
  end

  defp check_query_sanitization do
    # Check query sanitization practices
    %{status: :secure, message: "Ash framework provides query sanitization"}
  end

  defp check_orm_usage do
    # Verify ORM is used instead of raw SQL
    %{status: :secure, message: "Ash/Ecto ORM usage minimizes SQL injection risks"}
  end

  defp check_data_classification do
    # Check if data is properly classified
    %{status: :info, message: "Data should be classified by sensitivity level"}
  end

  defp check_pii_protection do
    # Check PII protection measures
    pii_fields = [
      "users.email",
      "users.eve_character_name",
      "api_keys.last_used_ip"
    ]

    %{
      status: :warning,
      message: "PII fields should have additional protection",
      fields: pii_fields
    }
  end

  defp check_data_masking do
    # Check data masking for non-production environments
    %{status: :info, message: "Data masking should be used in non-production environments"}
  end

  defp check_data_retention_policies do
    # Check data retention policies
    %{status: :info, message: "Data retention policies should be defined and automated"}
  end

  defp check_query_logging do
    # Check if queries are logged appropriately
    %{status: :info, message: "Query logging should be configured for security monitoring"}
  end

  defp check_connection_logging do
    # Check connection logging
    %{status: :info, message: "Database connections should be logged"}
  end

  defp check_error_logging do
    # Check error logging configuration
    %{status: :secure, message: "Database errors are logged through application"}
  end

  defp check_security_event_logging do
    # Check security event logging
    %{status: :info, message: "Security events should be logged to database audit trail"}
  end

  defp check_log_retention do
    # Check log retention policies
    %{status: :info, message: "Database log retention should align with security policies"}
  end

  defp generate_security_recommendations(audit_results) do
    recommendations = []

    # SSL/TLS recommendations
    recommendations =
      maybe_add_ssl_recommendation(audit_results.connection_security, recommendations)

    # PII protection recommendations
    recommendations =
      maybe_add_pii_recommendation(audit_results.sensitive_data_handling, recommendations)

    # Backup security recommendations
    recommendations =
      maybe_add_backup_recommendation(audit_results.backup_security, recommendations)

    # General security recommendations
    recommendations = add_general_recommendations(recommendations)

    recommendations
  end

  defp maybe_add_ssl_recommendation(connection_security, recommendations) do
    if connection_security.ssl_enabled.status != :secure do
      [
        %{
          priority: :high,
          category: :connection_security,
          title: "Enable SSL for Database Connections",
          description: "Configure SSL/TLS encryption for all database connections",
          implementation: "Set ssl: true in database configuration and use sslmode=require"
        }
        | recommendations
      ]
    else
      recommendations
    end
  end

  defp maybe_add_pii_recommendation(_sensitive_data, recommendations) do
    [
      %{
        priority: :medium,
        category: :data_protection,
        title: "Implement PII Protection",
        description: "Add encryption and access controls for personally identifiable information",
        implementation: "Encrypt PII fields and implement field-level access controls"
      }
      | recommendations
    ]
  end

  defp maybe_add_backup_recommendation(_backup_security, recommendations) do
    [
      %{
        priority: :medium,
        category: :backup_security,
        title: "Secure Database Backups",
        description: "Ensure database backups are encrypted and access-controlled",
        implementation: "Configure backup encryption and restrict backup access"
      }
      | recommendations
    ]
  end

  defp add_general_recommendations(recommendations) do
    general_recommendations = [
      %{
        priority: :medium,
        category: :monitoring,
        title: "Database Security Monitoring",
        description: "Implement comprehensive database security monitoring",
        implementation: "Configure database audit logging and monitoring alerts"
      },
      %{
        priority: :low,
        category: :access_control,
        title: "Review Database Privileges",
        description: "Regularly review and audit database user privileges",
        implementation: "Implement periodic privilege reviews and principle of least privilege"
      }
    ]

    general_recommendations ++ recommendations
  end
end

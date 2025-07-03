defmodule EveDmv.Security.ContainerSecurityReview do
  @moduledoc """
  Container security review and hardening utilities.

  This module provides functions to audit and secure Docker container configurations,
  including image security, runtime security, and orchestration security.
  """

  require Logger
  alias EveDmv.Security.AuditLogger

  @doc """
  Perform a comprehensive container security audit.

  Returns a detailed report of container security findings and recommendations.
  """
  @spec audit_container_security() ::
          {:ok,
           %{
             timestamp: DateTime.t(),
             dockerfile_security: %{
               base_image_security: %{message: String.t(), status: :info | :secure | :warning},
               dockerfile_exists: %{
                 message: String.t(),
                 path: String.t(),
                 status: :info | :secure
               },
               exposed_ports: %{message: String.t(), status: :info | :warning, ports: list(any())},
               health_checks: %{message: String.t(), status: :info | :secure | :warning},
               layer_optimization: %{
                 message: String.t(),
                 status: :info | :secure | :warning,
                 run_commands: non_neg_integer()
               },
               secret_handling: %{message: String.t(), status: :info | :secure | :warning},
               user_privileges: %{message: String.t(), status: :info | :secure | :warning}
             },
             image_security: %{
               image_provenance: %{message: String.t(), status: :info},
               image_signing: %{
                 message: String.t(),
                 status: :info,
                 technologies: list(String.t())
               },
               minimal_images: %{message: String.t(), status: :info},
               registry_security: %{
                 considerations: list(String.t()),
                 message: String.t(),
                 status: :info
               },
               vulnerability_scanning: %{
                 message: String.t(),
                 status: :info,
                 tools: list(String.t())
               }
             },
             monitoring_logging: %{
               alerting: %{message: String.t(), status: :info},
               log_aggregation: %{message: String.t(), status: :info},
               metrics_collection: %{message: String.t(), status: :info},
               security_monitoring: %{message: String.t(), status: :info}
             },
             network_security: %{
               ingress_security: %{message: String.t(), status: :info},
               network_policies: %{message: String.t(), status: :info},
               network_segmentation: %{message: String.t(), status: :info},
               service_mesh: %{message: String.t(), status: :info},
               tls_encryption: %{message: String.t(), status: :info}
             },
             recommendations: list(map()),
             resource_limits: %{
               cpu_limits: %{message: String.t(), status: :info},
               disk_quotas: %{message: String.t(), status: :info},
               memory_limits: %{message: String.t(), status: :info},
               process_limits: %{message: String.t(), status: :info}
             },
             runtime_security: %{
               apparmor_selinux: %{message: String.t(), status: :info},
               capabilities: %{message: String.t(), status: :info},
               privilege_escalation: %{message: String.t(), status: :info},
               read_only_filesystem: %{message: String.t(), status: :info},
               seccomp_profiles: %{message: String.t(), status: :info},
               security_contexts: %{message: String.t(), status: :info}
             },
             secrets_management: %{
               environment_variables: %{message: String.t(), status: :warning},
               secrets_access: %{message: String.t(), status: :info},
               secrets_rotation: %{message: String.t(), status: :info},
               secrets_storage: %{message: String.t(), status: :info}
             }
           }}
  def audit_container_security do
    Logger.info("Starting container security audit")

    audit_results = %{
      timestamp: DateTime.utc_now(),
      dockerfile_security: audit_dockerfile_security(),
      image_security: audit_image_security(),
      runtime_security: audit_runtime_security(),
      network_security: audit_network_security(),
      secrets_management: audit_secrets_management(),
      resource_limits: audit_resource_limits(),
      monitoring_logging: audit_container_monitoring(),
      recommendations: []
    }

    # Generate recommendations based on findings
    recommendations = generate_container_recommendations(audit_results)
    final_results = Map.put(audit_results, :recommendations, recommendations)

    # Log the audit completion
    AuditLogger.log_config_change(
      "system",
      :container_security_audit,
      nil,
      "completed"
    )

    {:ok, final_results}
  end

  @doc """
  Audit Dockerfile security best practices.
  """
  @spec audit_dockerfile_security() :: %{
          base_image_security: %{
            message: String.t(),
            status: :info | :secure | :warning
          },
          dockerfile_exists: %{
            message: String.t(),
            path: String.t(),
            status: :info | :secure
          },
          exposed_ports: %{
            message: String.t(),
            status: :info | :warning,
            ports: list(any())
          },
          health_checks: %{
            message: String.t(),
            status: :info | :secure | :warning
          },
          layer_optimization: %{
            message: String.t(),
            status: :info | :secure | :warning,
            run_commands: non_neg_integer()
          },
          secret_handling: %{
            message: String.t(),
            status: :info | :secure | :warning
          },
          user_privileges: %{
            message: String.t(),
            status: :info | :secure | :warning
          }
        }
  def audit_dockerfile_security do
    dockerfile_path = "Dockerfile"

    %{
      dockerfile_exists: check_dockerfile_exists(dockerfile_path),
      base_image_security: check_base_image_security(dockerfile_path),
      user_privileges: check_user_privileges(dockerfile_path),
      exposed_ports: check_exposed_ports(dockerfile_path),
      secret_handling: check_dockerfile_secrets(dockerfile_path),
      layer_optimization: check_layer_optimization(dockerfile_path),
      health_checks: check_health_checks(dockerfile_path)
    }
  end

  @doc """
  Audit container image security.
  """
  @spec audit_image_security() :: %{
          image_provenance: %{message: String.t(), status: :info},
          image_signing: %{
            message: String.t(),
            status: :info,
            technologies: list(String.t())
          },
          minimal_images: %{message: String.t(), status: :info},
          registry_security: %{
            considerations: list(String.t()),
            message: String.t(),
            status: :info
          },
          vulnerability_scanning: %{
            message: String.t(),
            status: :info,
            tools: list(String.t())
          }
        }
  def audit_image_security do
    %{
      vulnerability_scanning: check_vulnerability_scanning(),
      image_signing: check_image_signing(),
      registry_security: check_registry_security(),
      image_provenance: check_image_provenance(),
      minimal_images: check_minimal_images()
    }
  end

  @doc """
  Audit container runtime security.
  """
  @spec audit_runtime_security() :: %{
          apparmor_selinux: %{message: String.t(), status: :info},
          capabilities: %{message: String.t(), status: :info},
          privilege_escalation: %{message: String.t(), status: :info},
          read_only_filesystem: %{message: String.t(), status: :info},
          seccomp_profiles: %{message: String.t(), status: :info},
          security_contexts: %{message: String.t(), status: :info}
        }
  def audit_runtime_security do
    %{
      privilege_escalation: check_privilege_escalation(),
      capabilities: check_linux_capabilities(),
      security_contexts: check_security_contexts(),
      read_only_filesystem: check_read_only_filesystem(),
      seccomp_profiles: check_seccomp_profiles(),
      apparmor_selinux: check_apparmor_selinux()
    }
  end

  @doc """
  Audit container network security.
  """
  @spec audit_network_security() :: %{
          ingress_security: %{message: String.t(), status: :info},
          network_policies: %{message: String.t(), status: :info},
          network_segmentation: %{message: String.t(), status: :info},
          service_mesh: %{message: String.t(), status: :info},
          tls_encryption: %{message: String.t(), status: :info}
        }
  def audit_network_security do
    %{
      network_policies: check_network_policies(),
      service_mesh: check_service_mesh(),
      tls_encryption: check_tls_encryption(),
      network_segmentation: check_network_segmentation(),
      ingress_security: check_ingress_security()
    }
  end

  @doc """
  Audit secrets management in containers.
  """
  @spec audit_secrets_management() :: %{
          environment_variables: %{message: String.t(), status: :warning},
          secrets_access: %{message: String.t(), status: :info},
          secrets_rotation: %{message: String.t(), status: :info},
          secrets_storage: %{message: String.t(), status: :info}
        }
  def audit_secrets_management do
    %{
      environment_variables: check_environment_secrets(),
      secrets_storage: check_secrets_storage(),
      secrets_rotation: check_secrets_rotation(),
      secrets_access: check_secrets_access()
    }
  end

  @doc """
  Audit container resource limits and quotas.
  """
  @spec audit_resource_limits() :: %{
          cpu_limits: %{message: String.t(), status: :info},
          disk_quotas: %{message: String.t(), status: :info},
          memory_limits: %{message: String.t(), status: :info},
          process_limits: %{message: String.t(), status: :info}
        }
  def audit_resource_limits do
    %{
      memory_limits: check_memory_limits(),
      cpu_limits: check_cpu_limits(),
      disk_quotas: check_disk_quotas(),
      process_limits: check_process_limits()
    }
  end

  @doc """
  Audit container monitoring and logging.
  """
  @spec audit_container_monitoring() :: %{
          alerting: %{message: String.t(), status: :info},
          log_aggregation: %{message: String.t(), status: :info},
          metrics_collection: %{message: String.t(), status: :info},
          security_monitoring: %{message: String.t(), status: :info}
        }
  def audit_container_monitoring do
    %{
      log_aggregation: check_log_aggregation(),
      metrics_collection: check_metrics_collection(),
      security_monitoring: check_security_monitoring(),
      alerting: check_alerting_configuration()
    }
  end

  # Private audit functions

  defp check_dockerfile_exists(dockerfile_path) do
    if File.exists?(dockerfile_path) do
      %{status: :secure, message: "Dockerfile found", path: dockerfile_path}
    else
      %{
        status: :info,
        message: "Dockerfile not found - may be using external build",
        path: dockerfile_path
      }
    end
  end

  defp check_base_image_security(dockerfile_path) do
    if File.exists?(dockerfile_path) do
      case File.read(dockerfile_path) do
        {:ok, content} ->
          analyze_base_image(content)

        {:error, _} ->
          %{status: :warning, message: "Could not read Dockerfile"}
      end
    else
      %{status: :info, message: "No Dockerfile to analyze"}
    end
  end

  defp analyze_base_image(dockerfile_content) do
    cond do
      String.contains?(dockerfile_content, "FROM scratch") ->
        %{status: :secure, message: "Using minimal scratch base image"}

      String.contains?(dockerfile_content, "FROM alpine") ->
        %{status: :secure, message: "Using minimal Alpine base image"}

      String.contains?(dockerfile_content, "FROM ubuntu") ->
        %{status: :warning, message: "Ubuntu base image - consider smaller alternatives"}

      String.contains?(dockerfile_content, "FROM debian") ->
        %{status: :warning, message: "Debian base image - consider smaller alternatives"}

      String.contains?(dockerfile_content, ":latest") ->
        %{status: :warning, message: "Using :latest tag - should pin specific versions"}

      true ->
        %{status: :info, message: "Base image should be reviewed for security"}
    end
  end

  defp check_user_privileges(dockerfile_path) do
    if File.exists?(dockerfile_path) do
      case File.read(dockerfile_path) do
        {:ok, content} ->
          if String.contains?(content, "USER ") and not String.contains?(content, "USER root") do
            %{status: :secure, message: "Non-root user specified in Dockerfile"}
          else
            %{status: :warning, message: "Container may run as root - specify non-root USER"}
          end

        {:error, _} ->
          %{status: :warning, message: "Could not read Dockerfile"}
      end
    else
      %{status: :info, message: "No Dockerfile to analyze user privileges"}
    end
  end

  defp check_exposed_ports(dockerfile_path) do
    if File.exists?(dockerfile_path) do
      case File.read(dockerfile_path) do
        {:ok, content} ->
          exposed_ports = extract_exposed_ports(content)

          %{
            status: :info,
            message: "Review exposed ports for necessity",
            ports: exposed_ports
          }

        {:error, _} ->
          %{status: :warning, message: "Could not read Dockerfile"}
      end
    else
      %{status: :info, message: "No Dockerfile to analyze exposed ports"}
    end
  end

  defp extract_exposed_ports(dockerfile_content) do
    dockerfile_content
    |> String.split("\n")
    |> Enum.filter(&String.starts_with?(&1, "EXPOSE "))
    |> Enum.map(&String.replace(&1, "EXPOSE ", ""))
    |> Enum.map(&String.trim/1)
  end

  defp check_dockerfile_secrets(dockerfile_path) do
    if File.exists?(dockerfile_path) do
      case File.read(dockerfile_path) do
        {:ok, content} ->
          if has_potential_secrets?(content) do
            %{status: :warning, message: "Potential secrets found in Dockerfile"}
          else
            %{status: :secure, message: "No obvious secrets in Dockerfile"}
          end

        {:error, _} ->
          %{status: :warning, message: "Could not read Dockerfile"}
      end
    else
      %{status: :info, message: "No Dockerfile to analyze for secrets"}
    end
  end

  defp has_potential_secrets?(content) do
    secret_patterns = [
      ~r/password/i,
      ~r/secret/i,
      ~r/token/i,
      ~r/key.*=/i,
      ~r/api.*key/i
    ]

    Enum.any?(secret_patterns, &Regex.match?(&1, content))
  end

  defp check_layer_optimization(dockerfile_path) do
    if File.exists?(dockerfile_path) do
      case File.read(dockerfile_path) do
        {:ok, content} ->
          run_commands = count_run_commands(content)

          if run_commands > 10 do
            %{
              status: :warning,
              message: "Many RUN commands - consider consolidating for smaller image",
              run_commands: run_commands
            }
          else
            %{
              status: :secure,
              message: "Reasonable number of layers",
              run_commands: run_commands
            }
          end

        {:error, _} ->
          %{status: :warning, message: "Could not read Dockerfile"}
      end
    else
      %{status: :info, message: "No Dockerfile to analyze layer optimization"}
    end
  end

  defp count_run_commands(dockerfile_content) do
    dockerfile_content
    |> String.split("\n")
    |> Enum.count(&String.starts_with?(&1, "RUN "))
  end

  defp check_health_checks(dockerfile_path) do
    if File.exists?(dockerfile_path) do
      case File.read(dockerfile_path) do
        {:ok, content} ->
          if String.contains?(content, "HEALTHCHECK") do
            %{status: :secure, message: "Health check configured in Dockerfile"}
          else
            %{
              status: :warning,
              message: "No health check configured - consider adding HEALTHCHECK"
            }
          end

        {:error, _} ->
          %{status: :warning, message: "Could not read Dockerfile"}
      end
    else
      %{status: :info, message: "No Dockerfile to analyze health checks"}
    end
  end

  defp check_vulnerability_scanning do
    %{
      status: :info,
      message: "Container images should be scanned for vulnerabilities",
      tools: ["trivy", "clair", "snyk", "grype"]
    }
  end

  defp check_image_signing do
    %{
      status: :info,
      message: "Container images should be signed for provenance verification",
      technologies: ["cosign", "notary", "docker_content_trust"]
    }
  end

  defp check_registry_security do
    %{
      status: :info,
      message: "Container registry should use authentication and access controls",
      considerations: ["RBAC", "image_scanning", "vulnerability_policies"]
    }
  end

  defp check_image_provenance do
    %{
      status: :info,
      message: "Image provenance and supply chain security should be verified"
    }
  end

  defp check_minimal_images do
    %{
      status: :info,
      message: "Use minimal base images (Alpine, distroless) to reduce attack surface"
    }
  end

  defp check_privilege_escalation do
    %{
      status: :info,
      message: "Containers should run with allowPrivilegeEscalation: false"
    }
  end

  defp check_linux_capabilities do
    %{
      status: :info,
      message: "Drop unnecessary Linux capabilities and add only required ones"
    }
  end

  defp check_security_contexts do
    %{
      status: :info,
      message: "Configure proper security contexts with non-root user and restricted permissions"
    }
  end

  defp check_read_only_filesystem do
    %{
      status: :info,
      message: "Configure read-only root filesystem where possible"
    }
  end

  defp check_seccomp_profiles do
    %{
      status: :info,
      message: "Use seccomp profiles to restrict system calls"
    }
  end

  defp check_apparmor_selinux do
    %{
      status: :info,
      message: "Configure AppArmor or SELinux policies for additional security"
    }
  end

  defp check_network_policies do
    %{
      status: :info,
      message: "Implement network policies to control pod-to-pod communication"
    }
  end

  defp check_service_mesh do
    %{
      status: :info,
      message: "Consider service mesh for advanced networking security and observability"
    }
  end

  defp check_tls_encryption do
    %{
      status: :info,
      message: "Encrypt all inter-service communication with TLS"
    }
  end

  defp check_network_segmentation do
    %{
      status: :info,
      message: "Implement proper network segmentation between environments"
    }
  end

  defp check_ingress_security do
    %{
      status: :info,
      message: "Secure ingress with proper TLS, authentication, and rate limiting"
    }
  end

  defp check_environment_secrets do
    %{
      status: :warning,
      message: "Avoid storing secrets in environment variables - use secret management"
    }
  end

  defp check_secrets_storage do
    %{
      status: :info,
      message: "Use proper secrets management (Kubernetes secrets, Vault, etc.)"
    }
  end

  defp check_secrets_rotation do
    %{
      status: :info,
      message: "Implement automatic secrets rotation"
    }
  end

  defp check_secrets_access do
    %{
      status: :info,
      message: "Restrict secrets access using RBAC and service accounts"
    }
  end

  defp check_memory_limits do
    %{
      status: :info,
      message: "Set appropriate memory limits and requests for all containers"
    }
  end

  defp check_cpu_limits do
    %{
      status: :info,
      message: "Set appropriate CPU limits and requests for all containers"
    }
  end

  defp check_disk_quotas do
    %{
      status: :info,
      message: "Configure disk quotas to prevent storage exhaustion"
    }
  end

  defp check_process_limits do
    %{
      status: :info,
      message: "Set process limits to prevent fork bombs"
    }
  end

  defp check_log_aggregation do
    %{
      status: :info,
      message: "Implement centralized log aggregation for container logs"
    }
  end

  defp check_metrics_collection do
    %{
      status: :info,
      message: "Collect container and application metrics for monitoring"
    }
  end

  defp check_security_monitoring do
    %{
      status: :info,
      message: "Implement runtime security monitoring for containers"
    }
  end

  defp check_alerting_configuration do
    %{
      status: :info,
      message: "Configure alerts for security events and resource violations"
    }
  end

  defp generate_container_recommendations(audit_results) do
    recommendations = [
      %{
        priority: :high,
        category: :image_security,
        title: "Implement Container Image Scanning",
        description: "Scan all container images for vulnerabilities before deployment",
        implementation:
          "Integrate vulnerability scanning into CI/CD pipeline using tools like Trivy or Grype"
      },
      %{
        priority: :high,
        category: :runtime_security,
        title: "Configure Security Contexts",
        description: "Run containers with non-root users and restricted security contexts",
        implementation:
          "Set runAsNonRoot: true, allowPrivilegeEscalation: false, and drop capabilities"
      },
      %{
        priority: :medium,
        category: :secrets_management,
        title: "Secure Secrets Management",
        description: "Use proper secrets management instead of environment variables",
        implementation: "Implement Kubernetes secrets or external secret management solutions"
      },
      %{
        priority: :medium,
        category: :network_security,
        title: "Network Segmentation",
        description: "Implement network policies for pod-to-pod communication control",
        implementation: "Define Kubernetes network policies and use service mesh if needed"
      },
      %{
        priority: :medium,
        category: :resource_limits,
        title: "Resource Constraints",
        description: "Set resource limits and requests for all containers",
        implementation: "Define CPU and memory limits/requests in pod specifications"
      },
      %{
        priority: :low,
        category: :monitoring,
        title: "Runtime Security Monitoring",
        description: "Implement runtime security monitoring for container workloads",
        implementation: "Deploy runtime security tools like Falco or similar solutions"
      }
    ]

    # Add specific recommendations based on audit findings
    recommendations =
      maybe_add_dockerfile_recommendations(audit_results.dockerfile_security, recommendations)

    recommendations
  end

  defp maybe_add_dockerfile_recommendations(dockerfile_security, recommendations) do
    dockerfile_recommendations = []

    # Add user privilege recommendation if needed
    dockerfile_recommendations =
      if dockerfile_security.user_privileges.status == :warning do
        [
          %{
            priority: :high,
            category: :dockerfile_security,
            title: "Fix Container User Privileges",
            description: dockerfile_security.user_privileges.message,
            implementation: "Add 'USER non-root-user' directive in Dockerfile"
          }
          | dockerfile_recommendations
        ]
      else
        dockerfile_recommendations
      end

    # Add health check recommendation if needed
    dockerfile_recommendations =
      if dockerfile_security.health_checks.status == :warning do
        [
          %{
            priority: :medium,
            category: :dockerfile_security,
            title: "Add Container Health Checks",
            description: dockerfile_security.health_checks.message,
            implementation: "Add HEALTHCHECK directive to Dockerfile"
          }
          | dockerfile_recommendations
        ]
      else
        dockerfile_recommendations
      end

    dockerfile_recommendations ++ recommendations
  end
end

defmodule EveDmv.Eve.ErrorClassifier do
  @moduledoc """
  Classifies API errors for better handling decisions.

  Categorizes errors by:
  - Persistence: transient vs permanent
  - Severity: critical vs warning vs info  
  - Retry strategy: retryable vs not_retryable
  - User impact: user_facing vs system_only
  """

  @type error_category :: :transient | :permanent | :configuration | :unknown
  @type error_severity :: :critical | :high | :medium | :low | :info
  @type retry_strategy :: :retryable | :retryable_with_backoff | :not_retryable
  @type user_impact :: :user_facing | :system_only | :background

  @type classification :: %{
          category: error_category(),
          severity: error_severity(),
          retry_strategy: retry_strategy(),
          user_impact: user_impact(),
          suggested_action: String.t(),
          fallback_available: boolean()
        }

  @doc """
  Classify an error for appropriate handling.
  """
  @spec classify(any()) :: classification()
  def classify(error) do
    case error do
      # HTTP Status Code Errors
      {:http_error, status} -> classify_http_error(status)
      # Connection and Network Errors
      {:connection_error, reason} -> classify_connection_error(reason)
      # Timeout Errors
      :timeout -> classify_timeout_error()
      # JSON/Parsing Errors
      {:json_error, _reason} -> classify_parsing_error()
      # ESI-specific Errors
      {:esi_error, reason} -> classify_esi_error(reason)
      # Authentication Errors
      {:auth_error, reason} -> classify_auth_error(reason)
      # Rate Limiting
      {:rate_limited, _} -> classify_rate_limit_error()
      # Cache Errors
      {:cache_error, reason} -> classify_cache_error(reason)
      # Circuit Breaker
      :circuit_open -> classify_circuit_breaker_error()
      # Fallback to unknown
      _ -> classify_unknown_error(error)
    end
  end

  @doc """
  Get retry delay for retryable errors.
  """
  @spec get_retry_delay(any(), integer()) :: integer()
  def get_retry_delay(error, attempt_number) do
    classification = classify(error)

    case classification.retry_strategy do
      :retryable ->
        # Simple exponential backoff: 1s, 2s, 4s, 8s (max 10s)
        min(1000 * :math.pow(2, attempt_number - 1), 10_000) |> round()

      :retryable_with_backoff ->
        # Longer backoff for rate limiting: 5s, 10s, 20s, 40s (max 60s)
        min(5000 * :math.pow(2, attempt_number - 1), 60_000) |> round()

      :not_retryable ->
        0
    end
  end

  @doc """
  Check if error should trigger circuit breaker.
  """
  @spec should_trigger_circuit_breaker?(any()) :: boolean()
  def should_trigger_circuit_breaker?(error) do
    classification = classify(error)

    case {classification.category, classification.severity} do
      {:transient, severity} when severity in [:critical, :high] -> true
      {:permanent, :critical} -> true
      _ -> false
    end
  end

  @doc """
  Get user-friendly error message.
  """
  @spec get_user_message(any()) :: String.t()
  def get_user_message(error) do
    classification = classify(error)

    case classification.user_impact do
      :user_facing ->
        case classification.category do
          :transient -> "Service temporarily unavailable. Please try again in a few moments."
          :permanent -> "This request cannot be completed. Please check your input and try again."
          :configuration -> "Service configuration issue. Please contact support."
          :unknown -> "An unexpected error occurred. Please try again or contact support."
        end

      _ ->
        # System-only errors don't need user messages
        nil
    end
  end

  # Private classification functions

  defp classify_http_error(status) do
    case status do
      # Server errors (5xx) - typically transient
      status when status in [500, 502, 503, 504] ->
        %{
          category: :transient,
          severity: :high,
          retry_strategy: :retryable,
          user_impact: :user_facing,
          suggested_action: "Retry with exponential backoff",
          fallback_available: true
        }

      # Rate limiting (429/420)
      status when status in [420, 429] ->
        %{
          category: :transient,
          severity: :medium,
          retry_strategy: :retryable_with_backoff,
          user_impact: :background,
          suggested_action: "Implement exponential backoff with jitter",
          fallback_available: true
        }

      # Client errors (4xx) - typically permanent
      401 ->
        %{
          category: :configuration,
          severity: :critical,
          retry_strategy: :not_retryable,
          user_impact: :user_facing,
          suggested_action: "Check authentication credentials",
          fallback_available: false
        }

      403 ->
        %{
          category: :permanent,
          severity: :high,
          retry_strategy: :not_retryable,
          user_impact: :user_facing,
          suggested_action: "Check permissions/scopes",
          fallback_available: false
        }

      404 ->
        %{
          category: :permanent,
          severity: :low,
          retry_strategy: :not_retryable,
          user_impact: :background,
          suggested_action: "Entity does not exist",
          fallback_available: true
        }

      400 ->
        %{
          category: :permanent,
          severity: :medium,
          retry_strategy: :not_retryable,
          user_impact: :user_facing,
          suggested_action: "Validate request parameters",
          fallback_available: false
        }

      _ ->
        %{
          category: :unknown,
          severity: :medium,
          retry_strategy: :not_retryable,
          user_impact: :user_facing,
          suggested_action: "Review HTTP status #{status}",
          fallback_available: false
        }
    end
  end

  defp classify_connection_error(reason) do
    case reason do
      :timeout ->
        %{
          category: :transient,
          severity: :high,
          retry_strategy: :retryable,
          user_impact: :user_facing,
          suggested_action: "Retry with shorter timeout",
          fallback_available: true
        }

      :econnrefused ->
        %{
          category: :transient,
          severity: :critical,
          retry_strategy: :retryable,
          user_impact: :user_facing,
          suggested_action: "Service appears down, implement circuit breaker",
          fallback_available: true
        }

      :nxdomain ->
        %{
          category: :configuration,
          severity: :critical,
          retry_strategy: :not_retryable,
          user_impact: :system_only,
          suggested_action: "Check DNS configuration",
          fallback_available: false
        }

      _ ->
        %{
          category: :transient,
          severity: :high,
          retry_strategy: :retryable,
          user_impact: :background,
          suggested_action: "Network issue: #{inspect(reason)}",
          fallback_available: true
        }
    end
  end

  defp classify_timeout_error do
    %{
      category: :transient,
      severity: :high,
      retry_strategy: :retryable,
      user_impact: :user_facing,
      suggested_action: "Retry with adjusted timeout or circuit breaker",
      fallback_available: true
    }
  end

  defp classify_parsing_error do
    %{
      category: :transient,
      severity: :medium,
      retry_strategy: :retryable,
      user_impact: :background,
      suggested_action: "API response format issue, may be temporary",
      fallback_available: true
    }
  end

  defp classify_esi_error(reason) do
    case reason do
      :character_not_found ->
        %{
          category: :permanent,
          severity: :low,
          retry_strategy: :not_retryable,
          user_impact: :user_facing,
          suggested_action: "Character does not exist or is not accessible",
          fallback_available: true
        }

      :invalid_character_id ->
        %{
          category: :permanent,
          severity: :low,
          retry_strategy: :not_retryable,
          user_impact: :user_facing,
          suggested_action: "Invalid character ID format",
          fallback_available: false
        }

      _ ->
        %{
          category: :unknown,
          severity: :medium,
          retry_strategy: :retryable,
          user_impact: :background,
          suggested_action: "ESI-specific error: #{inspect(reason)}",
          fallback_available: true
        }
    end
  end

  defp classify_auth_error(reason) do
    case reason do
      :token_expired ->
        %{
          category: :transient,
          severity: :high,
          retry_strategy: :not_retryable,
          user_impact: :user_facing,
          suggested_action: "Refresh authentication token",
          fallback_available: false
        }

      :invalid_scope ->
        %{
          category: :configuration,
          severity: :critical,
          retry_strategy: :not_retryable,
          user_impact: :user_facing,
          suggested_action: "Application needs additional scopes",
          fallback_available: false
        }

      _ ->
        %{
          category: :configuration,
          severity: :high,
          retry_strategy: :not_retryable,
          user_impact: :user_facing,
          suggested_action: "Authentication issue: #{inspect(reason)}",
          fallback_available: false
        }
    end
  end

  defp classify_rate_limit_error do
    %{
      category: :transient,
      severity: :medium,
      retry_strategy: :retryable_with_backoff,
      user_impact: :background,
      suggested_action: "Implement jittered exponential backoff",
      fallback_available: true
    }
  end

  defp classify_cache_error(reason) do
    case reason do
      :cache_miss ->
        %{
          category: :transient,
          severity: :info,
          retry_strategy: :retryable,
          user_impact: :background,
          suggested_action: "Normal cache miss, fetch from source",
          fallback_available: false
        }

      _ ->
        %{
          category: :transient,
          severity: :medium,
          retry_strategy: :retryable,
          user_impact: :background,
          suggested_action: "Cache system issue: #{inspect(reason)}",
          fallback_available: true
        }
    end
  end

  defp classify_circuit_breaker_error do
    %{
      category: :transient,
      severity: :high,
      retry_strategy: :not_retryable,
      user_impact: :user_facing,
      suggested_action: "Service is degraded, use fallback data if available",
      fallback_available: true
    }
  end

  defp classify_unknown_error(error) do
    %{
      category: :unknown,
      severity: :medium,
      retry_strategy: :not_retryable,
      user_impact: :system_only,
      suggested_action: "Unclassified error: #{inspect(error)}",
      fallback_available: false
    }
  end
end

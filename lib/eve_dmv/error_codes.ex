defmodule EveDmv.ErrorCodes do
  @moduledoc """
  Centralized error codes for consistent error handling across EVE DMV.

  Organizes error codes into categories for consistent handling and user experience.

  ## Categories

  - **Validation**: Input validation errors (4xx equivalent)
  - **Not Found**: Resource not found errors (404 equivalent)
  - **External Service**: External API/service errors
  - **System**: Internal system errors (5xx equivalent)
  - **Business Logic**: Domain-specific business rule violations
  - **Security**: Authentication and authorization errors

  ## Usage

      EveDmv.ErrorCodes.validation_error?(:invalid_input)  # => true
      EveDmv.ErrorCodes.category(:character_not_found)     # => :not_found
  """

  # Validation Errors (4xx equivalent)
  @validation_errors ~w[
    invalid_input
    missing_required_field
    invalid_entity_id
    invalid_character_id
    invalid_corporation_id
    invalid_alliance_id
    invalid_date_range
    invalid_filter_tree
    invalid_pagination
    invalid_search_params
    invalid_configuration
    malformed_request
    invalid_file_format
    invalid_json
    validation_failed
  ]a

  # Resource Errors (404 equivalent)
  @resource_errors ~w[
    character_not_found
    corporation_not_found
    alliance_not_found
    killmail_not_found
    profile_not_found
    user_not_found
    analysis_not_found
    resource_not_found
    map_not_found
    system_not_found
    item_not_found
    ship_not_found
  ]a

  # External Service Errors
  @external_errors ~w[
    esi_api_error
    esi_timeout
    esi_rate_limited
    esi_unavailable
    janice_api_error
    janice_timeout
    mutamarket_api_error
    mutamarket_timeout
    wanderer_connection_error
    wanderer_auth_error
    sse_stream_error
    sse_connection_failed
    external_service_unavailable
    api_key_invalid
    api_response_malformed
  ]a

  # System Errors (5xx equivalent)
  @system_errors ~w[
    database_error
    database_connection_error
    cache_error
    cache_unavailable
    timeout
    rate_limit_exceeded
    circuit_breaker_open
    memory_limit_exceeded
    disk_space_error
    configuration_error
    startup_error
    shutdown_error
    process_exit
    runtime_error
    unknown_error
    generic_error
  ]a

  # Business Logic Errors
  @business_errors ~w[
    analysis_failed
    analysis_incomplete
    insufficient_data
    stale_data
    duplicate_entry
    profile_limit_exceeded
    analysis_timeout
    batch_processing_failed
    pipeline_error
    intelligence_engine_error
    correlation_failed
    scoring_failed
    aggregation_failed
    filtering_failed
    transformation_failed
  ]a

  # Security Errors
  @security_errors ~w[
    authentication_required
    authentication_failed
    authorization_failed
    permission_denied
    token_expired
    token_invalid
    session_expired
    access_denied
    security_violation
    rate_limit_exceeded
    suspicious_activity
    account_locked
    ip_blocked
  ]a

  @doc """
  Check if error code is a validation error.
  """
  @spec validation_error?(atom()) :: boolean()
  def validation_error?(code), do: code in @validation_errors

  @doc """
  Check if error code is a resource not found error.
  """
  @spec resource_error?(atom()) :: boolean()
  def resource_error?(code), do: code in @resource_errors

  @doc """
  Check if error code is an external service error.
  """
  @spec external_error?(atom()) :: boolean()
  def external_error?(code), do: code in @external_errors

  @doc """
  Check if error code is a system error.
  """
  @spec system_error?(atom()) :: boolean()
  def system_error?(code), do: code in @system_errors

  @doc """
  Check if error code is a business logic error.
  """
  @spec business_error?(atom()) :: boolean()
  def business_error?(code), do: code in @business_errors

  @doc """
  Check if error code is a security error.
  """
  @spec security_error?(atom()) :: boolean()
  def security_error?(code), do: code in @security_errors

  @doc """
  Get the category for an error code.
  """
  @spec category(atom()) ::
          :validation
          | :not_found
          | :external_service
          | :system
          | :business_logic
          | :security
          | :unknown
  def category(code) do
    cond do
      validation_error?(code) -> :validation
      resource_error?(code) -> :not_found
      external_error?(code) -> :external_service
      system_error?(code) -> :system
      business_error?(code) -> :business_logic
      security_error?(code) -> :security
      true -> :unknown
    end
  end

  @doc """
  Get HTTP status code equivalent for error category.
  """
  @spec http_status(atom()) :: integer()
  def http_status(code) do
    case category(code) do
      :validation -> 400
      :not_found -> 404
      :external_service -> 502
      :system -> 500
      :business_logic -> 422
      :security -> 401
      :unknown -> 500
    end
  end

  @doc """
  Check if error should be retried automatically.
  """
  @spec retryable?(atom()) :: boolean()
  def retryable?(code) do
    case code do
      :timeout -> true
      :rate_limit_exceeded -> true
      :circuit_breaker_open -> true
      :database_connection_error -> true
      :sse_stream_error -> true
      :sse_connection_failed -> true
      :esi_timeout -> true
      :janice_timeout -> true
      :mutamarket_timeout -> true
      :wanderer_connection_error -> true
      :external_service_unavailable -> true
      :cache_unavailable -> true
      _ -> false
    end
  end

  @doc """
  Get retry delay in milliseconds for retryable errors.
  """
  @spec retry_delay(atom()) :: integer()
  def retry_delay(code) do
    case code do
      :rate_limit_exceeded -> 5_000
      :esi_rate_limited -> 10_000
      :circuit_breaker_open -> 30_000
      :database_connection_error -> 1_000
      :sse_connection_failed -> 5_000
      :timeout -> 1_000
      _ -> 1_000
    end
  end

  @doc """
  Get all error codes in a category.
  """
  @spec codes_in_category(
          :validation
          | :not_found
          | :external_service
          | :system
          | :business_logic
          | :security
        ) :: [atom()]
  def codes_in_category(category) do
    case category do
      :validation -> @validation_errors
      :not_found -> @resource_errors
      :external_service -> @external_errors
      :system -> @system_errors
      :business_logic -> @business_errors
      :security -> @security_errors
    end
  end

  @doc """
  Get all error codes.
  """
  @spec all_codes() :: [atom()]
  def all_codes do
    @validation_errors ++
      @resource_errors ++
      @external_errors ++
      @system_errors ++ @business_errors ++ @security_errors
  end

  @doc """
  Get error severity level.
  """
  @spec severity(atom()) :: :low | :medium | :high | :critical
  def severity(code) do
    case category(code) do
      :validation -> :low
      :not_found -> :low
      :external_service -> :medium
      :business_logic -> :medium
      :security -> :high
      :system -> :critical
      :unknown -> :critical
    end
  end
end

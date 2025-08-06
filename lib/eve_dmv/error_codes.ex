defmodule EveDmv.ErrorCodes do
  @moduledoc """
  Error code categorization service for monitoring and error recovery.

  This module provides categorization of error codes to help the monitoring
  system identify the type of service causing issues and take appropriate
  recovery actions.
  """

  @doc """
  Categorizes an error code based on its pattern or source.

  Returns an atom indicating the category of service that generated the error.
  This helps the error recovery system take appropriate action.

  ## Parameters
  - `error_code` - The error code string or atom to categorize

  ## Returns
  - `:external_service` - Errors from external APIs (ESI, wanderer-kills, etc.)
  - `:database` - Database connection, query, or transaction errors
  - `:application` - Internal application logic errors
  - `:unknown` - Unrecognized error codes

  ## Examples
      iex> ErrorCodes.category("esi_timeout")
      :external_service

      iex> ErrorCodes.category("db_connection_failed")
      :database

      iex> ErrorCodes.category(:postgrex_error)
      :database

      iex> ErrorCodes.category("unknown_error")
      :unknown
  """
  def category(error_code) when is_binary(error_code) do
    error_code_lower = String.downcase(error_code)

    cond do
      # External service errors - EVE ESI, wanderer-kills, etc.
      String.contains?(error_code_lower, "esi") -> :external_service
      String.contains?(error_code_lower, "wanderer") -> :external_service
      String.contains?(error_code_lower, "api_timeout") -> :external_service
      String.contains?(error_code_lower, "http_") -> :external_service
      String.contains?(error_code_lower, "request_timeout") -> :external_service
      String.contains?(error_code_lower, "service_unavailable") -> :external_service
      String.contains?(error_code_lower, "rate_limit") -> :external_service
      String.contains?(error_code_lower, "oauth") -> :external_service
      String.contains?(error_code_lower, "sso") -> :external_service
      # Database errors
      String.contains?(error_code_lower, "db_") -> :database
      String.contains?(error_code_lower, "database") -> :database
      String.contains?(error_code_lower, "postgres") -> :database
      String.contains?(error_code_lower, "postgrex") -> :database
      String.contains?(error_code_lower, "ecto") -> :database
      String.contains?(error_code_lower, "connection") -> :database
      String.contains?(error_code_lower, "query") -> :database
      String.contains?(error_code_lower, "transaction") -> :database
      String.contains?(error_code_lower, "constraint") -> :database
      String.contains?(error_code_lower, "migration") -> :database
      # Application logic errors
      String.contains?(error_code_lower, "validation") -> :application
      String.contains?(error_code_lower, "auth") -> :application
      String.contains?(error_code_lower, "permission") -> :application
      String.contains?(error_code_lower, "not_found") -> :application
      String.contains?(error_code_lower, "invalid") -> :application
      # Default to unknown
      true -> :unknown
    end
  end

  def category(error_code) when is_atom(error_code) do
    error_code
    |> Atom.to_string()
    |> category()
  end

  def category(_error_code) do
    :unknown
  end

  @doc """
  Returns a list of all supported error categories.

  ## Returns
  - List of atoms representing all possible error categories

  ## Examples
      iex> ErrorCodes.all_categories()
      [:external_service, :database, :application, :unknown]
  """
  def all_categories do
    [:external_service, :database, :application, :unknown]
  end

  @doc """
  Checks if an error category requires immediate attention.

  Some error categories like database errors typically require more urgent
  response than others.

  ## Parameters
  - `category` - The error category atom

  ## Returns
  - `true` if the category requires immediate attention
  - `false` otherwise

  ## Examples
      iex> ErrorCodes.critical_category?(:database)
      true

      iex> ErrorCodes.critical_category?(:external_service)
      false
  """
  def critical_category?(:database), do: true
  def critical_category?(:application), do: true
  def critical_category?(_), do: false

  @doc """
  Returns a human-readable description of an error category.

  ## Parameters
  - `category` - The error category atom

  ## Returns
  - String description of the category

  ## Examples
      iex> ErrorCodes.category_description(:external_service)
      "External API or service errors"

      iex> ErrorCodes.category_description(:database)
      "Database connection and query errors"
  """
  def category_description(:external_service), do: "External API or service errors"
  def category_description(:database), do: "Database connection and query errors"
  def category_description(:application), do: "Internal application logic errors"
  def category_description(:unknown), do: "Unrecognized error category"
  def category_description(_), do: "Invalid error category"

  @doc """
  Determines if an error code represents a retryable error.

  Some errors are transient and worth retrying, while others are permanent
  failures that should not be retried.

  ## Parameters
  - `error_code` - The error code string or atom

  ## Returns
  - `true` if the error should be retried
  - `false` if the error is permanent

  ## Examples
      iex> ErrorCodes.retryable?("timeout")
      true

      iex> ErrorCodes.retryable?("invalid_credentials")
      false
  """
  def retryable?(error_code) do
    category = category(error_code)
    error_string = to_string(error_code) |> String.downcase()

    case category do
      :external_service ->
        # Most external service errors are retryable except auth failures
        not String.contains?(error_string, "unauthorized") and
          not String.contains?(error_string, "forbidden") and
          not String.contains?(error_string, "invalid_token")

      :database ->
        # Database connection issues are retryable, but constraint violations are not
        String.contains?(error_string, "timeout") or
          String.contains?(error_string, "connection") or
          String.contains?(error_string, "pool")

      :application ->
        # Most application errors are not retryable
        false

      :unknown ->
        # Unknown errors get one retry attempt
        true
    end
  end

  @doc """
  Returns the appropriate retry delay in milliseconds for an error code.

  Different types of errors should have different retry delays to avoid
  overwhelming failing services.

  ## Parameters
  - `error_code` - The error code string or atom

  ## Returns
  - Integer delay in milliseconds

  ## Examples
      iex> ErrorCodes.retry_delay("esi_timeout")
      5000

      iex> ErrorCodes.retry_delay("db_connection_failed")
      1000
  """
  def retry_delay(error_code) do
    case category(error_code) do
      # 5 seconds for external services
      :external_service -> 5000
      # 1 second for database issues
      :database -> 1000
      # 2 seconds for application errors
      :application -> 2000
      # 3 seconds for unknown errors
      :unknown -> 3000
    end
  end

  @doc """
  Returns the severity level of an error code.

  Used for logging and alerting to prioritize error handling.

  ## Parameters
  - `error_code` - The error code string or atom

  ## Returns
  - `:critical` - Requires immediate attention
  - `:warning` - Should be monitored
  - `:info` - Informational only

  ## Examples
      iex> ErrorCodes.severity("db_connection_failed")
      :critical

      iex> ErrorCodes.severity("esi_rate_limit")
      :warning
  """
  def severity(error_code) do
    category = category(error_code)
    error_string = to_string(error_code) |> String.downcase()

    case category do
      :database ->
        if String.contains?(error_string, "connection") or
             String.contains?(error_string, "pool") do
          :critical
        else
          :warning
        end

      :external_service ->
        if String.contains?(error_string, "rate_limit") do
          :info
        else
          :warning
        end

      :application ->
        if String.contains?(error_string, "auth") or
             String.contains?(error_string, "permission") do
          :warning
        else
          :info
        end

      :unknown ->
        :warning
    end
  end

  @doc """
  Returns a list of common error codes for a given category.

  This is useful for monitoring and analysis to understand what types
  of errors are occurring in each category.

  ## Parameters
  - `category` - The error category atom

  ## Returns
  - List of common error code strings for that category

  ## Examples
      iex> EveDmv.ErrorCodes.codes_in_category(:external_service)
      ["esi_timeout", "api_rate_limit", "service_unavailable"]
  """
  def codes_in_category(:external_service) do
    [
      "esi_timeout",
      "esi_rate_limit",
      "wanderer_connection_failed",
      "api_timeout",
      "http_502",
      "http_503",
      "request_timeout",
      "service_unavailable",
      "oauth_expired",
      "sso_error"
    ]
  end

  def codes_in_category(:database) do
    [
      "db_connection_failed",
      "db_timeout",
      "postgres_error",
      "postgrex_error",
      "ecto_query_error",
      "connection_pool_full",
      "query_timeout",
      "transaction_failed",
      "constraint_violation",
      "migration_error"
    ]
  end

  def codes_in_category(:application) do
    [
      "validation_error",
      "auth_failed",
      "permission_denied",
      "not_found",
      "invalid_input",
      "business_logic_error",
      "configuration_error"
    ]
  end

  def codes_in_category(:unknown) do
    [
      "unknown_error",
      "unhandled_exception",
      "generic_error"
    ]
  end

  def codes_in_category(_), do: []
end

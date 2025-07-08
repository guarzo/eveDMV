defmodule EveDmv.ErrorHandler do
        use EveDmv.ErrorHandler
  @moduledoc """
  Behavior and utilities for consistent error handling across modules.

  Provides a standardized approach to error handling with support for:
  - Retry logic for transient failures
  - Fallback values for graceful degradation
  - Error transformation and context addition
  - Telemetry and monitoring integration

  ## Usage

      defmodule MyModule do

        def my_operation(params) do
          with_error_handling fn ->
            # Your operation logic here
            do_something(params)
          end, %{operation: :my_operation, params: params}
        end

        # Custom error handling for this module
        def handle_error(error, context) do
          case error.code do
            :timeout -> {:retry, 1000}
            :not_found -> {:fallback, default_value()}
            _ -> {:propagate, error}
          end
        end
      end
  """

    alias EveDmv.Error
  alias EveDmv.ErrorCodes
  require Logger

  @type error_action ::
          {:retry, delay_ms :: non_neg_integer()}
          | {:fallback, value :: term()}
          | {:propagate, Error.t()}
          | :ignore

  @doc """
  Handle an error and determine the appropriate action.

  Return one of:
  - `{:retry, delay_ms}` - Retry the operation after delay
  - `{:fallback, value}` - Use fallback value and continue
  - `{:propagate, error}` - Propagate the error (possibly modified)
  - `:ignore` - Log the error but continue with nil result
  """
  @callback handle_error(Error.t(), context :: map()) :: error_action()

  @doc """
  Optional callback to configure error handling behavior.

  Return options like:
  - `max_retries` - Maximum number of retry attempts
  - `retry_backoff` - Retry backoff strategy (:linear | :exponential)
  - `enable_telemetry` - Whether to emit telemetry events
  """
  @callback error_config() :: keyword()

  @optional_callbacks [error_config: 0]

  defmacro __using__(opts \\ []) do
    quote location: :keep do
      @behaviour EveDmv.ErrorHandler

      import EveDmv.Result
      require Logger

      # Default configuration
      def error_config do
        [
          max_retries: 3,
          retry_backoff: :exponential,
          enable_telemetry: true,
          emit_error_logs: true
        ]
      end

      @doc """
      Execute operation with standardized error handling.

      Wraps the operation in try-catch and applies the module's error handling strategy.
      """
      def with_error_handling(operation, context \\ %{}) when is_function(operation, 0) do
        config = error_config()
        max_retries = Keyword.get(config, :max_retries, 3)

        do_with_error_handling(operation, context, 0, max_retries, config)
      end

      defp do_with_error_handling(operation, context, attempt, max_retries, config) do
        try do
          case operation.() do
            {:ok, _} = success ->
              success

            {:error, reason} ->
              error = Error.normalize(reason)
              handle_error_result(error, context, attempt, max_retries, config, operation)

            %Error{} = error ->
              handle_error_result(error, context, attempt, max_retries, config, operation)

            other ->
              # Assume non-tuple, non-error returns are success
              {:ok, other}
          end
        rescue
          e in RuntimeError ->
            error =
              Error.new(:runtime_error, Exception.message(e),
                context: context,
                stacktrace: __STACKTRACE__
              )

            handle_error_result(error, context, attempt, max_retries, config, operation)

          e ->
            error =
              Error.new(:exception, Exception.message(e),
                context: context,
                details: %{exception_type: e.__struct__},
                stacktrace: __STACKTRACE__
              )

            handle_error_result(error, context, attempt, max_retries, config, operation)
        catch
          :exit, reason ->
            error = Error.new(:process_exit, inspect(reason), context: context)
            handle_error_result(error, context, attempt, max_retries, config, operation)

          :throw, value ->
            error = Error.new(:thrown_value, inspect(value), context: context)
            handle_error_result(error, context, attempt, max_retries, config, operation)
        end
      end

      defp handle_error_result(error, context, attempt, max_retries, config, operation) do
        # Add attempt information to error context
        error_with_context =
          Error.add_context(error, %{
            attempt: attempt + 1,
            max_retries: max_retries,
            module: __MODULE__
          })

        # Emit telemetry if enabled
        if Keyword.get(config, :enable_telemetry, true) do
          emit_error_telemetry(error_with_context, context)
        end

        # Log error if enabled
        if Keyword.get(config, :emit_error_logs, true) do
          log_error(error_with_context, context)
        end

        case handle_error(error_with_context, context) do
          {:retry, delay_ms} when attempt < max_retries ->
            if delay_ms > 0, do: Process.sleep(delay_ms)
            do_with_error_handling(operation, context, attempt + 1, max_retries, config)

          {:retry, _delay_ms} ->
            # Max retries exceeded
            final_error =
              Error.add_details(error_with_context, %{
                retry_exhausted: true,
                total_attempts: attempt + 1
              })

            {:error, final_error}

          {:fallback, value} ->
            {:ok, value}

          {:propagate, new_error} ->
            {:error, new_error}

          :ignore ->
            Logger.warning("Ignored error in #{__MODULE__}: #{error_with_context.message}")
            {:ok, nil}
        end
      end

      # Default error handling - can be overridden
      def handle_error(error, context) do
        case {error.code, ErrorCodes.category(error.code)} do
          # Retryable errors
          {code, _} when code in [:timeout, :rate_limit_exceeded, :circuit_breaker_open] ->
            delay = ErrorCodes.retry_delay(code)
            {:retry, delay}

          # Database connection issues
          {:database_connection_error, _} ->
            {:retry, 1000}

          # External service issues
          {_, :external_service} when error.code in [:esi_timeout, :janice_timeout] ->
            {:retry, 2000}

          # Not found errors - usually not retryable
          {_, :not_found} ->
            {:propagate, error}

          # Validation errors - not retryable
          {_, :validation} ->
            {:propagate, error}

          # Security errors - not retryable
          {_, :security} ->
            {:propagate, error}

          # System errors - may be retryable
          {_, :system} ->
            if ErrorCodes.retryable?(error.code) do
              {:retry, 1000}
            else
              {:propagate, error}
            end

          # Unknown errors - propagate
          _ ->
            {:propagate, error}
        end
      end

      defp emit_error_telemetry(error, context) do
        :telemetry.execute(
          [:eve_dmv, :error, ErrorCodes.category(error.code)],
          %{count: 1},
          Map.merge(context, %{
            error_code: error.code,
            error_message: error.message,
            module: __MODULE__
          })
        )
      end

      defp log_error(error, context) do
        severity = ErrorCodes.severity(error.code)
        log_message = "Error in #{__MODULE__}: #{error.message}"

        log_metadata = [
          error_code: error.code,
          error_category: ErrorCodes.category(error.code),
          context: context,
          details: error.details
        ]

        case severity do
          :low -> Logger.info(log_message, log_metadata)
          :medium -> Logger.warning(log_message, log_metadata)
          :high -> Logger.error(log_message, log_metadata)
          :critical -> Logger.critical(log_message, log_metadata)
        end
      end

      # Allow overriding the default error handling
      defoverridable handle_error: 2, error_config: 0

      # Convenience functions for common error operations

      @doc """
      Create and return a standardized error result.
      """
      def error_result(code, message, opts \\ []) do
        context = Keyword.get(opts, :context, %{module: __MODULE__})
        details = Keyword.get(opts, :details, %{})

        error = Error.new(code, message, context: context, details: details)
        {:error, error}
      end

      @doc """
      Add module context to an error.
      """
      def add_module_context(error, additional_context \\ %{}) do
        context = Map.merge(%{module: __MODULE__}, additional_context)
        Error.add_context(error, context)
      end

      unquote(opts)
    end
  end

  @doc """
  Global error handler for uncaught errors.

  Can be used as a fallback when no specific error handling is available.
  """
  def handle_global_error(error, context \\ %{}) do
    normalized = Error.normalize(error)

    # Always emit telemetry for global errors
    :telemetry.execute(
      [:eve_dmv, :error, :global],
      %{count: 1},
      Map.merge(context, %{
        error_code: normalized.code,
        error_message: normalized.message
      })
    )

    # Log critical errors
    Logger.critical(
      "Unhandled error: #{normalized.message} - code: #{normalized.code}, context: #{inspect(context)}, details: #{inspect(normalized.details)}"
    )

    {:error, normalized}
  end

  @doc """
  Attach global error telemetry handlers.

  Should be called during application startup.
  """
  def attach_telemetry_handlers do
    handlers = [
      {
        "eve-dmv-validation-errors",
        [:eve_dmv, :error, :validation],
        &handle_validation_error_telemetry/4,
        nil
      },
      {
        "eve-dmv-external-errors",
        [:eve_dmv, :error, :external_service],
        &handle_external_error_telemetry/4,
        nil
      },
      {
        "eve-dmv-system-errors",
        [:eve_dmv, :error, :system],
        &handle_system_error_telemetry/4,
        nil
      },
      {
        "eve-dmv-security-errors",
        [:eve_dmv, :error, :security],
        &handle_security_error_telemetry/4,
        nil
      }
    ]

    Enum.each(handlers, fn {id, event, handler, config} ->
      :telemetry.attach(id, event, handler, config)
    end)
  end

  # Telemetry handlers
  defp handle_validation_error_telemetry(_event, measurements, metadata, _config) do
    Logger.debug(
      "Validation error: #{metadata.error_code}, module: #{metadata[:module]}, measurements: #{inspect(measurements)}"
    )
  end

  defp handle_external_error_telemetry(_event, measurements, metadata, _config) do
    Logger.warning(
      "External service error: #{metadata.error_code}, module: #{metadata[:module]}, measurements: #{inspect(measurements)}"
    )
  end

  defp handle_system_error_telemetry(_event, measurements, metadata, _config) do
    Logger.error(
      "System error: #{metadata.error_code}, module: #{metadata[:module]}, measurements: #{inspect(measurements)}"
    )

    # Could trigger alerts here for critical system errors
  end

  defp handle_security_error_telemetry(_event, measurements, metadata, _config) do
    Logger.critical(
      "Security error: #{metadata.error_code}, module: #{metadata[:module]}, measurements: #{inspect(measurements)}"
    )

    # Could trigger security alerts here
  end
end

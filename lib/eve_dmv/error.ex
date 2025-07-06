defmodule EveDmv.Error do
  @moduledoc """
  Unified error handling for EVE DMV.

  All errors in the system should use this structure for consistency.
  Provides standardized error format with context and debugging information.

  ## Usage

      # Create a new error
      EveDmv.Error.new(:invalid_input, "Character ID must be positive")

      # Create with context
      EveDmv.Error.new(:database_error, "Connection failed",
        context: %{operation: :select, table: :characters})

      # Normalize different error formats
      EveDmv.Error.normalize({:error, "Some error"})
      EveDmv.Error.normalize({:error, :timeout})
  """

  @type t :: %__MODULE__{
          code: atom(),
          message: String.t(),
          details: map(),
          context: map(),
          stacktrace: list() | nil
        }

  defstruct [:code, :message, :details, :context, :stacktrace]

  @doc """
  Create a new error with consistent structure.

  ## Parameters

  - `code` - Atom identifying the error type (see EveDmv.ErrorCodes)
  - `message` - Human-readable error message
  - `opts` - Optional keyword list with :details, :context, :stacktrace
  """
  @spec new(atom(), String.t(), keyword()) :: t()
  def new(code, message, opts \\ []) do
    %__MODULE__{
      code: code,
      message: message,
      details: Keyword.get(opts, :details, %{}),
      context: Keyword.get(opts, :context, %{}),
      stacktrace: Keyword.get(opts, :stacktrace)
    }
  end

  @doc """
  Convert various error formats to unified structure.

  Handles legacy error formats and normalizes them to the standard format.
  """
  @spec normalize(term()) :: t()
  def normalize(error) do
    case error do
      %__MODULE__{} = err ->
        err

      {:error, %__MODULE__{} = err} ->
        err

      {:error, reason} when is_binary(reason) ->
        new(:generic_error, reason)

      {:error, reason} when is_atom(reason) ->
        new(reason, humanize(reason))

      {:error, reason, details} when is_map(details) ->
        new(:generic_error, inspect(reason), details: details)

      {:error, reason, details} ->
        new(:generic_error, inspect(reason), details: %{raw_details: details})

      %{message: msg} when is_binary(msg) ->
        new(:generic_error, msg, details: Map.delete(error, :message))

      %{__exception__: true} = exception ->
        new(:exception, Exception.message(exception),
          details: %{exception_type: exception.__struct__}
        )

      other ->
        new(:unknown_error, inspect(other), details: %{raw_error: other})
    end
  end

  @doc """
  Convert error to a tuple format for backwards compatibility.
  """
  @spec to_tuple(t()) :: {:error, t()}
  def to_tuple(%__MODULE__{} = error), do: {:error, error}

  @doc """
  Get user-friendly error message based on error code.
  """
  @spec user_message(t()) :: String.t()
  def user_message(%__MODULE__{} = error) do
    case EveDmv.ErrorCodes.category(error.code) do
      :validation -> "Invalid request: #{error.message}"
      :not_found -> "Requested data not found"
      :external_service -> "External service temporarily unavailable"
      :system -> "System error occurred. Please try again."
      :business_logic -> error.message
      _ -> "An error occurred: #{error.message}"
    end
  end

  @doc """
  Check if error is retryable based on error code.
  """
  @spec retryable?(t()) :: boolean()
  def retryable?(%__MODULE__{code: code}) do
    case code do
      :timeout -> true
      :rate_limit_exceeded -> true
      :circuit_breaker_open -> true
      :database_connection_error -> true
      :sse_stream_error -> true
      _ -> false
    end
  end

  @doc """
  Add context to an existing error.
  """
  @spec add_context(t(), map()) :: t()
  def add_context(%__MODULE__{context: existing_context} = error, new_context) do
    %{error | context: Map.merge(existing_context, new_context)}
  end

  @doc """
  Add details to an existing error.
  """
  @spec add_details(t(), map()) :: t()
  def add_details(%__MODULE__{details: existing_details} = error, new_details) do
    %{error | details: Map.merge(existing_details, new_details)}
  end

  # Private helper functions

  defp humanize(atom) when is_atom(atom) do
    atom
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  defp humanize(other), do: inspect(other)
end

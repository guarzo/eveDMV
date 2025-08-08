defmodule EveDmv.Error do
  @moduledoc """
  Standard error structure for EVE DMV application.

  Provides consistent error handling across the application with
  structured error information including codes, messages, and metadata.
  """

  defstruct [:code, :message, details: %{}, stacktrace: nil]

  @type t :: %__MODULE__{
          code: atom(),
          message: String.t(),
          details: map(),
          stacktrace: list() | nil
        }

  @doc """
  Create a new error.
  """
  def new(code, message, opts \\ []) do
    %__MODULE__{
      code: code,
      message: message,
      details: Keyword.get(opts, :details, %{}),
      stacktrace: Keyword.get(opts, :stacktrace)
    }
  end

  @doc """
  Normalize various error formats into EveDmv.Error.
  """
  def normalize(%__MODULE__{} = error), do: error

  def normalize({:error, %__MODULE__{} = error}), do: error

  def normalize({:error, message}) when is_binary(message) do
    new(:generic_error, message)
  end

  def normalize({:error, code}) when is_atom(code) do
    new(code, Atom.to_string(code))
  end

  def normalize(other) do
    new(:unknown_error, inspect(other))
  end

  @doc """
  Add details to an existing error.
  """
  def add_details(%__MODULE__{} = error, details) when is_map(details) do
    %{error | details: Map.merge(error.details, details)}
  end

  @doc """
  Add context information to error message.
  """
  def add_context(%__MODULE__{} = error, context) when is_binary(context) do
    %{error | message: "#{error.message} (#{context})"}
  end

  @doc """
  Check if an error is retryable.
  """
  def retryable?(%__MODULE__{code: code})
      when code in [:timeout, :connection_error, :temporary_failure],
      do: true

  def retryable?(_), do: false
end

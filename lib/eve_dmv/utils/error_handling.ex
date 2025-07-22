defmodule EveDmv.Utils.ErrorHandling do
  @moduledoc """
  Standardized error handling patterns to reduce duplication.

  Part of Sprint 22 Quality Standards - Code Duplication Elimination.
  """

  require Logger

  @doc """
  Standard error logging with context.
  """
  def log_error(message, error, context \\ %{}) do
    Logger.error("""
    #{message}
    Error: #{inspect(error)}
    Context: #{inspect(context)}
    """)
  end

  @doc """
  Standard API error response format.
  """
  def api_error_response(error_type, message, details \\ %{}) do
    %{
      error: error_type,
      message: message,
      details: details,
      timestamp: DateTime.utc_now()
    }
  end

  @doc """
  Standardized with pattern error handling.
  """
  def handle_with_error({:error, :not_found}, resource_type) do
    {:error, "#{resource_type} not found"}
  end

  def handle_with_error({:error, :unauthorized}, _) do
    {:error, "Unauthorized access"}
  end

  def handle_with_error({:error, :timeout}, operation) do
    {:error, "#{operation} timed out"}
  end

  def handle_with_error({:error, %Ecto.Changeset{} = changeset}, _) do
    {:error, "Validation failed: #{format_changeset_errors(changeset)}"}
  end

  def handle_with_error({:error, reason}, operation) do
    {:error, "#{operation} failed: #{inspect(reason)}"}
  end

  @doc """
  Format Ecto changeset errors for display.
  """
  def format_changeset_errors(%Ecto.Changeset{errors: errors}) do
    errors
    Enum.map(fn {field, {message, _}} -> "#{field}: #{message}" end)
    Enum.join(", ")
  end

  @doc """
  Safe operation execution with error logging.
  """
  def safe_execute(operation_name, fun, context \\ %{}) when is_function(fun, 0) do
    try do
      fun.()
    rescue
      error ->
        log_error("#{operation_name} failed", error, context)
        {:error, "#{operation_name} encountered an error"}
    catch
      :exit, reason ->
        log_error("#{operation_name} exited", reason, context)
        {:error, "#{operation_name} was terminated"}
    end
  end

  @doc """
  Standard GenServer error handling.
  """
  def handle_genserver_error(operation, error, state) do
    log_error("GenServer operation failed", error, %{
      operation: operation,
      state: inspect(state, limit: :infinity, printable_limit: 500)
    })

    {:reply, {:error, "Service unavailable"}, state}
  end
end

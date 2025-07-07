defmodule EveDmv.Shared.ErrorFormatter do
  @moduledoc """
  Consistent error response formatting across the application.
  """

  @doc """
  Formats various error types into a consistent error response format.
  """
  def format_error({:error, %Ecto.Changeset{} = changeset}) do
    {:error, format_changeset_errors(changeset)}
  end

  def format_error({:error, reason}) when is_binary(reason) do
    {:error, reason}
  end

  def format_error({:error, %{message: message}}) do
    {:error, message}
  end

  def format_error({:error, reason}) do
    {:error, inspect(reason)}
  end

  def format_error(_) do
    {:error, "An unexpected error occurred"}
  end

  @doc """
  Formats Ecto changeset errors into a human-readable string.
  """
  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map(fn {field, errors} ->
      "#{field}: #{Enum.join(errors, ", ")}"
    end)
    |> Enum.join("; ")
  end
end
defmodule EveDmv.Utils.ValidationUtils do
  @moduledoc """
  Shared validation utilities for the EveDmv application.
  """

  @doc """
  Validates that all required fields are present in the provided data.

  Returns `:ok` if all required fields are present and not nil.
  Returns `{:error, {:missing_fields, missing_fields}}` if any required fields are missing or nil.
  """
  @spec validate_required_fields(map(), list()) :: :ok | {:error, {:missing_fields, list()}}
  def validate_required_fields(data, required_fields) do
    missing_fields =
      Enum.filter(required_fields, fn field ->
        not Map.has_key?(data, field) or is_nil(data[field])
      end)

    case missing_fields do
      [] -> :ok
      fields -> {:error, {:missing_fields, fields}}
    end
  end
end

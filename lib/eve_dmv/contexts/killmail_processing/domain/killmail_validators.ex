defmodule EveDmv.Contexts.KillmailProcessing.Domain.KillmailValidators do
  @moduledoc """
  Validation functions for killmail processing operations.

  Provides reusable validators for killmail data, options, and identifiers.
  Extracted from the API module to follow single-responsibility principle.
  """

  import EveDmv.Core.Validation.Validators

  alias EveDmv.SharedKernel.ValueObjects.TimeRange

  @typedoc "Error types for killmail options validation"
  @type killmail_options_error ::
          :invalid_options_format
          | :invalid_limit
          | :invalid_offset
          | :invalid_value_range
          | :invalid_time_range

  @typedoc "Error types for character IDs validation"
  @type character_ids_error :: :invalid_character_ids | :invalid_character_ids_format

  @doc """
  Validates a raw killmail has required structure and fields.

  ## Required Fields
  - `:killmail_id` - Unique identifier
  - `:killmail_time` - When the killmail occurred
  - `:victim` - Victim information
  - `:attackers` - List of attackers

  ## Examples

      iex> validate_raw_killmail(%{killmail_id: 123, killmail_time: ~U[...], victim: %{}, attackers: []})
      :ok

      iex> validate_raw_killmail(%{killmail_id: 123})
      {:error, {:missing_field, :killmail_time}}

      iex> validate_raw_killmail("not a map")
      {:error, :invalid_killmail_format}
  """
  @spec validate_raw_killmail(any()) :: :ok | {:error, atom() | {atom(), atom()}}
  def validate_raw_killmail(killmail) do
    case validate_map(:killmail, killmail) do
      :ok ->
        required_fields = [:killmail_id, :killmail_time, :victim, :attackers]

        case validate_required_keys(:killmail, killmail, required_fields) do
          :ok -> :ok
          {:error, {:killmail, {:missing_keys, [field | _]}}} -> {:error, {:missing_field, field}}
        end

      {:error, _} ->
        {:error, :invalid_killmail_format}
    end
  end

  @doc """
  Validates killmail query options.

  ## Supported Options
  - `:limit` - Number of results (1-500)
  - `:offset` - Skip N results (non-negative)
  - `:min_value` - Minimum ISK value filter
  - `:max_value` - Maximum ISK value filter
  - `:time_range` - TimeRange value object

  ## Examples

      iex> validate_killmail_options(limit: 50, offset: 0)
      :ok

      iex> validate_killmail_options(limit: 1000)
      {:error, :invalid_limit}

      iex> validate_killmail_options("not a list")
      {:error, :invalid_options_format}
  """
  @spec validate_killmail_options(any()) :: :ok | {:error, killmail_options_error()}
  def validate_killmail_options(opts) when is_list(opts) do
    with :ok <- do_validate_limit(Keyword.get(opts, :limit)),
         :ok <- do_validate_offset(Keyword.get(opts, :offset)),
         :ok <-
           do_validate_value_range(Keyword.get(opts, :min_value), Keyword.get(opts, :max_value)),
         :ok <- do_validate_time_range(Keyword.get(opts, :time_range)) do
      :ok
    end
  end

  def validate_killmail_options(_), do: {:error, :invalid_options_format}

  @doc """
  Validates a list of character IDs.

  ## Examples

      iex> validate_character_ids([123, 456, 789])
      :ok

      iex> validate_character_ids([])
      {:error, :invalid_character_ids}

      iex> validate_character_ids("not a list")
      {:error, :invalid_character_ids_format}
  """
  @spec validate_character_ids(any()) :: :ok | {:error, character_ids_error()}
  def validate_character_ids(character_ids) do
    case validate_integer_list(:character_ids, character_ids, min: 1) do
      :ok -> :ok
      {:error, {:character_ids, :invalid_type}} -> {:error, :invalid_character_ids_format}
      {:error, {:character_ids, :required}} -> {:error, :invalid_character_ids_format}
      {:error, {:character_ids, :too_few_items}} -> {:error, :invalid_character_ids}
      {:error, {:character_ids, :invalid_items}} -> {:error, :invalid_character_ids}
    end
  end

  # Private validation helpers

  defp do_validate_limit(nil), do: :ok

  defp do_validate_limit(limit) do
    case validate_in_range(:limit, limit, min: 1, max: 500) do
      :ok -> :ok
      {:error, _} -> {:error, :invalid_limit}
    end
  end

  defp do_validate_offset(nil), do: :ok

  defp do_validate_offset(offset) do
    case validate_non_negative_integer(:offset, offset) do
      :ok -> :ok
      {:error, _} -> {:error, :invalid_offset}
    end
  end

  defp do_validate_value_range(nil, nil), do: :ok

  defp do_validate_value_range(min, nil) do
    case validate_non_negative_integer(:min_value, min) do
      :ok -> :ok
      {:error, _} -> {:error, :invalid_value_range}
    end
  end

  defp do_validate_value_range(nil, max) do
    case validate_non_negative_integer(:max_value, max) do
      :ok -> :ok
      {:error, _} -> {:error, :invalid_value_range}
    end
  end

  defp do_validate_value_range(min, max) do
    with :ok <- validate_non_negative_integer(:min_value, min),
         :ok <- validate_non_negative_integer(:max_value, max) do
      if min <= max, do: :ok, else: {:error, :invalid_value_range}
    else
      {:error, _} -> {:error, :invalid_value_range}
    end
  end

  defp do_validate_time_range(nil), do: :ok
  defp do_validate_time_range(%TimeRange{}), do: :ok
  defp do_validate_time_range(_), do: {:error, :invalid_time_range}
end

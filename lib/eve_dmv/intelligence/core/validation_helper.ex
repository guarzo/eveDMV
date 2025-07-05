defmodule EveDmv.Intelligence.Core.ValidationHelper do
  @moduledoc """
  Parameter validation utilities for intelligence analyzers.

  Provides standardized validation functions for common parameter types
  and analysis options used across intelligence modules.
  """

  @type validation_result :: :ok | {:error, String.t()}
  @type entity_id :: integer()
  @type analysis_options :: map()

  @doc """
  Validate basic entity ID requirements.

  Ensures entity ID is a positive integer suitable for EVE Online character/corporation IDs.
  """
  @spec validate_entity_id(entity_id()) :: validation_result()
  def validate_entity_id(entity_id) when is_integer(entity_id) and entity_id > 0 do
    cond do
      entity_id < 1_000_000 ->
        {:error, "Entity ID too small: EVE Online IDs are typically 8+ digits"}

      entity_id > 999_999_999_999 ->
        {:error, "Entity ID too large: exceeds EVE Online ID range"}

      true ->
        :ok
    end
  end

  def validate_entity_id(entity_id) when is_binary(entity_id) do
    case Integer.parse(entity_id) do
      {parsed_id, ""} -> validate_entity_id(parsed_id)
      _ -> {:error, "Invalid entity ID format: must be integer or numeric string"}
    end
  end

  def validate_entity_id(_entity_id) do
    {:error, "Invalid entity ID: must be positive integer"}
  end

  @doc """
  Validate analysis options map structure and common parameters.
  """
  @spec validate_analysis_options(analysis_options()) :: validation_result()
  def validate_analysis_options(opts) when is_map(opts) do
    with :ok <- validate_days_back(opts),
         :ok <- validate_limit(opts),
         :ok <- validate_include_options(opts),
         :ok <- validate_timeout_options(opts) do
      :ok
    end
  end

  def validate_analysis_options(_opts) do
    {:error, "Analysis options must be a map"}
  end

  @doc """
  Validate character-specific analysis parameters.
  """
  @spec validate_character_analysis(entity_id(), analysis_options()) :: validation_result()
  def validate_character_analysis(character_id, opts) do
    with :ok <- validate_entity_id(character_id),
         :ok <- validate_analysis_options(opts),
         :ok <- validate_character_specific_options(opts) do
      :ok
    end
  end

  @doc """
  Validate corporation-specific analysis parameters.
  """
  @spec validate_corporation_analysis(entity_id(), analysis_options()) :: validation_result()
  def validate_corporation_analysis(corporation_id, opts) do
    with :ok <- validate_entity_id(corporation_id),
         :ok <- validate_analysis_options(opts),
         :ok <- validate_corporation_specific_options(opts) do
      :ok
    end
  end

  @doc """
  Validate alliance-specific analysis parameters.
  """
  @spec validate_alliance_analysis(entity_id(), analysis_options()) :: validation_result()
  def validate_alliance_analysis(alliance_id, opts) do
    with :ok <- validate_entity_id(alliance_id),
         :ok <- validate_analysis_options(opts),
         :ok <- validate_alliance_specific_options(opts) do
      :ok
    end
  end

  @doc """
  Validate batch analysis parameters.
  """
  @spec validate_batch_analysis([entity_id()], analysis_options()) :: validation_result()
  def validate_batch_analysis(entity_ids, opts) when is_list(entity_ids) do
    cond do
      length(entity_ids) == 0 ->
        {:error, "Entity ID list cannot be empty"}

      length(entity_ids) > 100 ->
        {:error, "Batch size too large: maximum 100 entities per batch"}

      true ->
        with :ok <- validate_all_entity_ids(entity_ids),
             :ok <- validate_analysis_options(opts),
             :ok <- validate_batch_specific_options(opts) do
          :ok
        end
    end
  end

  def validate_batch_analysis(_entity_ids, _opts) do
    {:error, "Entity IDs must be provided as a list"}
  end

  @doc """
  Validate time range parameters.
  """
  @spec validate_time_range(DateTime.t() | nil, DateTime.t() | nil) :: validation_result()
  def validate_time_range(start_date, end_date) do
    cond do
      is_nil(start_date) and is_nil(end_date) ->
        :ok

      is_nil(start_date) or is_nil(end_date) ->
        {:error, "Both start_date and end_date must be provided if either is specified"}

      DateTime.compare(start_date, end_date) == :gt ->
        {:error, "Start date must be before end date"}

      DateTime.diff(end_date, start_date, :day) > 365 ->
        {:error, "Time range too large: maximum 365 days"}

      DateTime.compare(start_date, DateTime.utc_now()) == :gt ->
        {:error, "Start date cannot be in the future"}

      true ->
        :ok
    end
  end

  # Private validation functions

  defp validate_days_back(%{days_back: days}) when is_integer(days) do
    cond do
      days < 1 -> {:error, "days_back must be at least 1"}
      days > 365 -> {:error, "days_back cannot exceed 365 days"}
      true -> :ok
    end
  end

  defp validate_days_back(%{days_back: _}) do
    {:error, "days_back must be an integer"}
  end

  defp validate_days_back(_opts), do: :ok

  defp validate_limit(%{limit: limit}) when is_integer(limit) do
    cond do
      limit < 1 -> {:error, "limit must be at least 1"}
      limit > 10_000 -> {:error, "limit cannot exceed 10,000"}
      true -> :ok
    end
  end

  defp validate_limit(%{limit: _}) do
    {:error, "limit must be an integer"}
  end

  defp validate_limit(_opts), do: :ok

  defp validate_include_options(%{include: include}) when is_list(include) do
    valid_includes = [:killmails, :corporations, :alliances, :ships, :systems, :statistics]

    invalid_includes = include -- valid_includes

    if length(invalid_includes) > 0 do
      {:error, "Invalid include options: #{inspect(invalid_includes)}"}
    else
      :ok
    end
  end

  defp validate_include_options(%{include: _}) do
    {:error, "include must be a list of atoms"}
  end

  defp validate_include_options(_opts), do: :ok

  defp validate_timeout_options(%{timeout: timeout}) when is_integer(timeout) do
    cond do
      timeout < 1_000 -> {:error, "timeout must be at least 1,000ms"}
      timeout > 300_000 -> {:error, "timeout cannot exceed 300,000ms (5 minutes)"}
      true -> :ok
    end
  end

  defp validate_timeout_options(%{timeout: _}) do
    {:error, "timeout must be an integer (milliseconds)"}
  end

  defp validate_timeout_options(_opts), do: :ok

  defp validate_character_specific_options(%{include_inactive: include}) when is_boolean(include),
    do: :ok

  defp validate_character_specific_options(%{include_inactive: _}),
    do: {:error, "include_inactive must be boolean"}

  defp validate_character_specific_options(_opts), do: :ok

  defp validate_corporation_specific_options(%{include_members: include})
       when is_boolean(include),
       do: :ok

  defp validate_corporation_specific_options(%{include_members: _}),
    do: {:error, "include_members must be boolean"}

  defp validate_corporation_specific_options(_opts), do: :ok

  defp validate_alliance_specific_options(%{include_corporations: include})
       when is_boolean(include),
       do: :ok

  defp validate_alliance_specific_options(%{include_corporations: _}),
    do: {:error, "include_corporations must be boolean"}

  defp validate_alliance_specific_options(_opts), do: :ok

  defp validate_batch_specific_options(%{parallel: parallel}) when is_boolean(parallel), do: :ok
  defp validate_batch_specific_options(%{parallel: _}), do: {:error, "parallel must be boolean"}
  defp validate_batch_specific_options(_opts), do: :ok

  defp validate_all_entity_ids(entity_ids) do
    invalid_ids =
      entity_ids
      |> Enum.with_index()
      |> Enum.filter(fn {id, _index} ->
        case validate_entity_id(id) do
          :ok -> false
          {:error, _} -> true
        end
      end)

    if length(invalid_ids) > 0 do
      indices = Enum.map(invalid_ids, fn {_id, index} -> index end)
      {:error, "Invalid entity IDs at indices: #{inspect(indices)}"}
    else
      :ok
    end
  end
end

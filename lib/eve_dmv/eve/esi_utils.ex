defmodule EveDmv.Eve.EsiUtils do
  @moduledoc """
  Common utilities for ESI client error handling and data fetching patterns.

  This module consolidates repeated ESI error handling patterns found across
  intelligence modules to provide consistent error handling, logging, and
  fallback strategies.
  """

  alias EveDmv.Eve.EsiClient

  require Logger

  @doc """
  Safely execute an ESI call with standardized error handling.

  ## Examples

      iex> safe_esi_call("character", fn -> EsiClient.get_character(12_345) end)
      {:ok, %{name: "Test Character"}}

      iex> safe_esi_call("character", fn -> {:error, :not_found} end)
      {:error, :service_unavailable}
  """
  def safe_esi_call(service_name, call_fn) when is_function(call_fn, 0) do
    call_fn.()
  rescue
    error ->
      Logger.error("ESI #{service_name} failed: #{inspect(error)}")
      {:error, :service_unavailable}
  end

  @doc """
  Handle ESI result with success and fallback functions.

  ## Examples

      iex> handle_esi_result({:ok, data}, &process_data/1, fn -> fallback_data() end)
      {:ok, processed_data}

      iex> handle_esi_result({:error, :timeout}, &process_data/1, fn -> fallback_data() end)
      {:ok, fallback_data}
  """
  def handle_esi_result({:ok, data}, success_fn, _fallback_fn) when is_function(success_fn, 1) do
    success_fn.(data)
  end

  def handle_esi_result({:error, reason}, _success_fn, fallback_fn)
      when is_function(fallback_fn, 0) do
    Logger.warning("ESI call failed: #{inspect(reason)}")
    fallback_fn.()
  end

  @doc """
  Fetch character info with fallback to placeholder data.

  Returns character name, corporation_id, and other basic info.
  Falls back to cached data or placeholder if ESI fails.
  """
  def fetch_character_with_fallback(character_id, fallback_name \\ "Unknown Character") do
    handle_esi_result(
      safe_esi_call("character", fn ->
        EsiClient.get_character(character_id)
      end),
      fn char_data ->
        {:ok,
         %{
           character_name: char_data.name,
           corporation_id: char_data.corporation_id
         }}
      end,
      fn ->
        Logger.warning("Failed to fetch character info for #{character_id}, using fallback")

        {:ok,
         %{
           character_name: fallback_name,
           corporation_id: nil
         }}
      end
    )
  end

  @doc """
  Fetch corporation info with alliance data if available.

  This consolidates the common pattern of fetching corporation data
  and then conditionally fetching alliance data based on alliance_id.
  """
  def fetch_corporation_with_alliance(corporation_id) do
    result =
      safe_esi_call("corporation", fn ->
        EsiClient.get_corporation(corporation_id)
      end)

    case result do
      {:ok, corp_data} ->
        alliance_info = fetch_alliance_info(corp_data.alliance_id)

        {:ok,
         %{
           corporation_id: corporation_id,
           corporation_name: corp_data.name,
           alliance_id: corp_data.alliance_id,
           alliance_name: alliance_info.alliance_name
         }}

      {:error, reason} ->
        Logger.warning(
          "Failed to fetch corporation info for #{corporation_id}: #{inspect(reason)}"
        )

        {:ok,
         %{
           corporation_id: corporation_id,
           corporation_name: "Unknown Corporation",
           alliance_id: nil,
           alliance_name: nil
         }}
    end
  end

  @doc """
  Fetch character, corporation, and alliance data in one call.

  This combines character and corporation+alliance fetching into a single
  operation with consistent fallback handling.
  """
  def fetch_character_corporation_alliance(character_id) do
    with {:ok, char_data} <- fetch_character_with_fallback(character_id),
         {:ok, corp_data} <- fetch_corporation_with_alliance(char_data.corporation_id) do
      {:ok, Map.merge(char_data, corp_data)}
    else
      {:error, reason} ->
        Logger.warning(
          "Failed to fetch character corporation alliance for #{character_id}: #{inspect(reason)}"
        )

        {:ok,
         %{
           character_name: "Unknown Character",
           corporation_id: nil,
           corporation_name: "Unknown Corporation",
           alliance_id: nil,
           alliance_name: nil
         }}
    end
  end

  @doc """
  Fetch employment history with fallback to placeholder data.

  Returns employment history data with fallback structure when ESI fails.
  """
  def fetch_employment_history_with_fallback(character_id) do
    result =
      safe_esi_call("employment_history", fn ->
        EsiClient.get_character_employment_history(character_id)
      end)

    handle_esi_result(
      result,
      fn history_data ->
        {:ok, process_employment_history(history_data)}
      end,
      fn ->
        Logger.warning(
          "Could not fetch employment history for character #{character_id}, using fallback"
        )

        {:ok,
         %{
           "corp_changes" => 0,
           "avg_tenure_days" => 0,
           "suspicious_patterns" => ["Unable to verify employment history"],
           "history" => []
         }}
      end
    )
  end

  @doc """
  Safely fetch corporation assets with error handling.

  Returns empty list if fetching fails rather than propagating errors.
  """
  def fetch_assets_safe(corporation_id, auth_token) do
    result =
      safe_esi_call("corporation_assets", fn ->
        EsiClient.get_corporation_assets(corporation_id, auth_token)
      end)

    handle_esi_result(
      result,
      fn assets -> {:ok, assets} end,
      fn ->
        Logger.warning(
          "Failed to fetch assets for corporation #{corporation_id}, returning empty list"
        )

        {:ok, []}
      end
    )
  end

  @doc """
  Fetch multiple characters with partial failure handling.

  Returns successfully fetched character data even if some characters fail.
  """
  def fetch_characters_bulk(character_ids) when is_list(character_ids) do
    result =
      safe_esi_call("characters_bulk", fn ->
        EsiClient.get_characters(character_ids)
      end)

    handle_esi_result(
      result,
      fn character_data -> {:ok, character_data} end,
      fn ->
        Logger.warning(
          "Failed to fetch bulk character data for #{length(character_ids)} characters"
        )

        {:ok, []}
      end
    )
  end

  # Private helper functions

  defp fetch_alliance_info(nil), do: %{alliance_name: nil}

  defp fetch_alliance_info(alliance_id) do
    result =
      safe_esi_call("alliance", fn ->
        EsiClient.get_alliance(alliance_id)
      end)

    case result do
      {:ok, alliance_data} ->
        %{alliance_name: alliance_data.name}

      {:error, _reason} ->
        Logger.warning("Failed to fetch alliance info for #{alliance_id}")
        %{alliance_name: nil}
    end
  end

  defp process_employment_history(history_data) when is_list(history_data) do
    history_length = length(history_data)
    corp_changes = history_length - 1

    avg_tenure_days =
      if corp_changes > 0 do
        total_days = calculate_total_tenure_days(history_data)
        round(total_days / history_length)
      else
        0
      end

    suspicious_patterns = identify_suspicious_patterns(history_data, history_length)

    %{
      "corp_changes" => corp_changes,
      "avg_tenure_days" => avg_tenure_days,
      "suspicious_patterns" => suspicious_patterns,
      "history" => history_data
    }
  end

  defp process_employment_history(_),
    do: %{
      "corp_changes" => 0,
      "avg_tenure_days" => 0,
      "suspicious_patterns" => ["Invalid employment history data"],
      "history" => []
    }

  defp calculate_total_tenure_days(history) when is_list(history) do
    # Calculate real tenure based on start_date and end_date fields
    try do
      # Sort history by start_date to process chronologically
      sorted_history =
        Enum.sort_by(history, fn record ->
          case Map.get(record, "start_date") do
            date when is_binary(date) -> Date.from_iso8601!(date)
            %Date{} = date -> date
            # EVE launch date as fallback
            _ -> ~D[2003-05-06]
          end
        end)

      total_days = calculate_tenure_from_records(sorted_history)
      max(0, total_days)
    rescue
      _error ->
        # Fallback to simple calculation if date parsing fails
        length(history) * 90
    end
  end

  defp calculate_tenure_from_records([]), do: 0

  defp calculate_tenure_from_records(records) do
    today = Date.utc_today()

    records
    |> Enum.with_index()
    |> Enum.reduce(0, fn {record, index}, acc ->
      start_date = parse_employment_date(Map.get(record, "start_date"))

      # Determine end date
      end_date =
        if index == 0 do
          # Current/most recent employment goes to today
          today
        else
          # Previous employment ends when next one starts
          next_record = Enum.at(records, index - 1)
          parse_employment_date(Map.get(next_record, "start_date"))
        end

      # Calculate days for this employment period
      if start_date && end_date && Date.compare(start_date, end_date) != :gt do
        days = Date.diff(end_date, start_date)
        acc + days
      else
        acc
      end
    end)
  end

  defp parse_employment_date(date_string) when is_binary(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} -> date
      {:error, _} -> nil
    end
  end

  defp parse_employment_date(%Date{} = date), do: date
  defp parse_employment_date(_), do: nil

  defp identify_suspicious_patterns(_history, history_length) when history_length > 10 do
    ["High corp turnover (#{history_length} corporations)"]
  end

  defp identify_suspicious_patterns(_history, _history_length), do: []
end

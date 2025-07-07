defmodule EveDmv.PlayerProfile.DataLoader do
  @moduledoc """
  Data loading service for player profiles.

  Handles ESI integration, character data fetching, corporation and alliance
  information retrieval, and historical killmail loading with proper error
  handling and timeout management.
  """

  alias EveDmv.Eve.EsiClient
  alias EveDmv.Killmails.HistoricalKillmailFetcher
  require Logger

  @doc """
  Load complete character data including ESI info and historical killmails.

  Fetches character, corporation, alliance data and historical killmails
  in a background task with proper error handling.
  """
  def load_character_data(character_id, callback_pid) do
    Task.Supervisor.start_child(EveDmv.TaskSupervisor, fn ->
      # Fetch character info from ESI with timeout
      character_result =
        case Task.yield(Task.async(fn -> EsiClient.get_character(character_id) end), 10_000) do
          {:ok, result} -> result
          nil -> {:error, :timeout}
        end

      with {:ok, character_info} <- character_result,
           {:ok, corp_info} <- fetch_corporation_info(character_info.corporation_id),
           {:ok, alliance_info} <- fetch_alliance_info(character_info.alliance_id) do
        # Enrich character info
        enriched_info =
          character_info
          |> Map.put(:corporation_name, corp_info.name)
          |> Map.put(:corporation_ticker, corp_info.ticker)
          |> Map.put(:alliance_name, alliance_info[:name])
          |> Map.put(:alliance_ticker, alliance_info[:ticker])

        # Fetch historical killmails
        Logger.info("Fetching historical killmails for character #{character_id}")

        case HistoricalKillmailFetcher.fetch_character_history(character_id) do
          {:ok, killmail_count} ->
            Logger.info(
              "Fetched #{killmail_count} historical killmails for character #{character_id}"
            )

            send(callback_pid, {:character_esi_loaded, enriched_info, killmail_count})

          {:error, reason} ->
            Logger.warning("Failed to fetch historical killmails: #{inspect(reason)}")
            # Still show character info even if killmail fetch fails
            send(callback_pid, {:character_esi_loaded, enriched_info, 0})
        end
      else
        {:error, :not_found} ->
          send(callback_pid, {:character_load_failed, :character_not_found})

        {:error, :timeout} ->
          send(callback_pid, {:character_load_failed, :esi_timeout})

        {:error, _reason} ->
          send(callback_pid, {:character_load_failed, :esi_unavailable})
      end
    end)
  end

  @doc """
  Fetch corporation information with timeout and error handling.
  """
  def fetch_corporation_info(nil), do: {:ok, %{name: nil, ticker: nil}}

  def fetch_corporation_info(corp_id) do
    task = Task.async(fn -> EsiClient.get_corporation(corp_id) end)

    case Task.yield(task, 10_000) || Task.shutdown(task) do
      {:ok, {:ok, corp}} -> {:ok, corp}
      {:ok, {:error, _}} -> {:ok, %{name: "Unknown Corporation", ticker: "???"}}
      nil -> {:ok, %{name: "Unknown Corporation", ticker: "???"}}
    end
  rescue
    _ -> {:ok, %{name: "Unknown Corporation", ticker: "???"}}
  end

  @doc """
  Fetch alliance information with timeout and error handling.
  """
  def fetch_alliance_info(nil), do: {:ok, %{name: nil, ticker: nil}}

  def fetch_alliance_info(alliance_id) do
    task = Task.async(fn -> EsiClient.get_alliance(alliance_id) end)

    case Task.yield(task, 10_000) || Task.shutdown(task) do
      {:ok, {:ok, alliance}} -> {:ok, alliance}
      {:ok, {:error, _}} -> {:ok, %{name: "Unknown Alliance", ticker: "???"}}
      nil -> {:ok, %{name: "Unknown Alliance", ticker: "???"}}
    end
  rescue
    _ -> {:ok, %{name: "Unknown Alliance", ticker: "???"}}
  end
end

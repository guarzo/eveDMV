defmodule EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysis.DataCollectors.BattleDataCollector do
  @moduledoc """
  Handles data collection and fetching for battle analysis.

  Responsible for:
  - Fetching killmails related to specific battles
  - Retrieving recent system activity
  - Optimizing data collection strategies based on dataset size
  - Handling streaming vs standard fetch decisions
  """

  require Logger

  alias EveDmv.Contexts.CombatIntelligence.Domain.Shared.KillmailMapper
  alias EveDmv.Contexts.CombatIntelligence.Domain.StreamingBattleAnalyzer

  @doc """
  Fetch killmails related to a specific battle.

  Battle ID format: "system_{system_id}_{unix_timestamp}"
  """
  def fetch_battle_killmails(battle_id) do
    Logger.debug("Fetching killmails for battle #{battle_id}")

    case String.split(battle_id, "_") do
      ["system", system_id_str, timestamp_str] ->
        with {system_id, ""} <- Integer.parse(system_id_str),
             {timestamp, ""} <- Integer.parse(timestamp_str) do
          battle_time = DateTime.from_unix!(timestamp)
          {start_time, end_time} = calculate_optimal_battle_window(system_id, battle_time)

          query = """
          SELECT
            killmail_id,
            killmail_time,
            killmail_hash,
            solar_system_id,
            victim_character_id,
            victim_corporation_id,
            victim_alliance_id,
            victim_ship_type_id,
            attacker_count,
            raw_data,
            source
          FROM killmails_raw
          WHERE solar_system_id = $1
            AND killmail_time >= $2
            AND killmail_time <= $3
          ORDER BY killmail_time ASC
          """

          case Ecto.Adapters.SQL.query(EveDmv.Repo, query, [system_id, start_time, end_time]) do
            {:ok, %{rows: rows}} ->
              killmails = Enum.map(rows, &KillmailMapper.map_killmail_row/1)
              Logger.debug("Found #{length(killmails)} killmails for battle #{battle_id}")
              {:ok, killmails}

            {:error, error} ->
              Logger.error("Database error fetching battle killmails: #{inspect(error)}")
              {:error, :database_error}
          end
        else
          _ ->
            Logger.warning("Invalid battle_id format: #{battle_id}")
            {:error, :invalid_battle_id}
        end

      _ ->
        Logger.warning("Invalid battle_id format: #{battle_id}")
        {:error, :invalid_battle_id}
    end
  rescue
    error ->
      Logger.error("Exception fetching battle killmails: #{inspect(error)}")
      {:error, :fetch_failed}
  end

  @doc """
  Fetch recent kills in a specific system.

  Automatically chooses between streaming and standard fetch based on time window size.
  """
  def fetch_recent_system_kills(system_id, seconds_back) do
    Logger.debug("Fetching kills in system #{system_id} from last #{seconds_back} seconds")

    cutoff_time = DateTime.add(DateTime.utc_now(), -seconds_back, :second)

    # Use streaming for large time windows (> 4 hours) or when expecting > 1000 kills
    if seconds_back > 14400 do
      use_streaming_fetch(system_id, cutoff_time)
    else
      use_standard_fetch(system_id, cutoff_time)
    end
  end

  @doc """
  Standard fetch implementation for smaller datasets.
  """
  def use_standard_fetch(system_id, cutoff_time) do
    seconds_back_calculated = DateTime.diff(DateTime.utc_now(), cutoff_time, :second)

    query = """
    SELECT
      killmail_id,
      killmail_time,
      killmail_hash,
      solar_system_id,
      victim_character_id,
      victim_corporation_id,
      victim_alliance_id,
      victim_ship_type_id,
      attacker_count,
      raw_data,
      source
    FROM killmails_raw
    WHERE solar_system_id = $1
      AND killmail_time >= $2
    ORDER BY killmail_time DESC
    LIMIT 1000
    """

    case Ecto.Adapters.SQL.query(EveDmv.Repo, query, [system_id, cutoff_time]) do
      {:ok, %{rows: rows}} ->
        killmails = Enum.map(rows, &map_killmail_row_with_analysis_data/1)

        Logger.debug(
          "Found #{length(killmails)} killmails in system #{system_id} from last #{seconds_back_calculated} seconds"
        )

        {:ok, killmails}

      {:error, error} ->
        Logger.error("Database error fetching recent system kills: #{inspect(error)}")
        {:error, :database_error}
    end
  rescue
    error ->
      Logger.error("Exception fetching recent system kills: #{inspect(error)}")
      {:error, :fetch_failed}
  end

  @doc """
  Streaming fetch implementation for larger datasets.
  """
  def use_streaming_fetch(system_id, cutoff_time) do
    Logger.info("Using streaming fetch for large dataset: system #{system_id}")

    params = %{
      system_id: system_id,
      start_time: cutoff_time,
      end_time: DateTime.utc_now()
    }

    opts = [
      batch_size: 1000,
      analysis_types: [:basic_metrics],
      stream_timeout: 60_000
    ]

    try do
      case StreamingBattleAnalyzer.stream_killmail_processing(
             params,
             fn batch -> batch end,
             opts
           ) do
        {:ok, stream} ->
          killmails =
            stream
            |> Enum.take(10)
            |> List.flatten()
            |> Enum.sort_by(& &1.killmail_time, {:desc, DateTime})
            |> Enum.take(2000)

          Logger.info("Streaming fetch completed: #{length(killmails)} killmails")
          {:ok, killmails}

        {:error, reason} ->
          Logger.error("Streaming fetch failed: #{inspect(reason)}")
          smaller_cutoff = DateTime.add(DateTime.utc_now(), -3600, :second)
          use_standard_fetch(system_id, smaller_cutoff)
      end
    rescue
      error ->
        Logger.error("Exception in streaming fetch: #{inspect(error)}")
        smaller_cutoff = DateTime.add(DateTime.utc_now(), -3600, :second)
        use_standard_fetch(system_id, smaller_cutoff)
    end
  end

  # Private helper functions

  defp map_killmail_row_with_analysis_data([
         killmail_id,
         killmail_time,
         killmail_hash,
         solar_system_id,
         victim_character_id,
         victim_corporation_id,
         victim_alliance_id,
         victim_ship_type_id,
         attacker_count,
         raw_data,
         source
       ]) do
    %{
      killmail_id: killmail_id,
      killmail_time: killmail_time,
      killmail_hash: killmail_hash,
      solar_system_id: solar_system_id,
      victim_character_id: victim_character_id,
      victim_corporation_id: victim_corporation_id,
      victim_alliance_id: victim_alliance_id,
      victim_ship_type_id: victim_ship_type_id,
      attacker_count: attacker_count,
      raw_data: raw_data,
      source: source,
      # Extract additional fields from raw_data for analysis
      total_value: get_in(raw_data, ["zkb", "totalValue"]) || 0,
      attackers: raw_data["attackers"] || [],
      victim: raw_data["victim"] || %{}
    }
  end

  defp calculate_optimal_battle_window(_system_id, battle_time) do
    # Create intelligent time window around the battle based on activity patterns
    # For now, use a standard 2-hour window around the battle time
    start_time = DateTime.add(battle_time, -3600, :second)
    end_time = DateTime.add(battle_time, 3600, :second)

    {start_time, end_time}
  end
end

defmodule EveDmv.Analytics.PlayerStatsEngine do
  @moduledoc """
  Engine for calculating player performance statistics.
  """

  alias EveDmv.Analytics.PlayerStats
  alias EveDmv.Api
  alias EveDmv.Constants.Isk
  alias EveDmv.Core.Utils.DateTimeUtils

  require Logger

  @default_days 90
  @default_batch_size 100
  @default_min_activity 5

  @doc """
  Calculate and update player statistics for all active characters.

  ## Options

    * `:days`         - days to look back (default: #{@default_days})
    * `:batch_size`   - characters per batch (default: #{@default_batch_size})
    * `:min_activity` - minimum killmail count (default: #{@default_min_activity})
  """
  def calculate_player_stats(opts \\ []) do
    days = Keyword.get(opts, :days, @default_days)
    batch_size = Keyword.get(opts, :batch_size, @default_batch_size)
    min_activity = Keyword.get(opts, :min_activity, @default_min_activity)
    now = DateTime.utc_now()
    start_date = DateTimeUtils.add(now, -days * 86_400, :second)

    _ = Logger.info("Starting player statistics for last #{days} days")

    case participants_ids(:character_id, min_activity, start_date) do
      {:error, reason} ->
        Logger.error("Failed to calculate player stats: #{inspect(reason)}")
        {:error, reason}

      {:ok, ids} ->
        chunk_and_process(ids, batch_size, &process_character(&1, start_date, now), "player")
        Logger.info("Player statistics calculation completed")
        :ok
    end
  end

  # Fetch up to `limit` unique non-nil character IDs from recent participants
  # Uses time range filter on killmail_time for efficient index usage
  defp participants_ids(field, limit, start_date) do
    query = """
    SELECT DISTINCT #{field}
    FROM participants
    WHERE #{field} IS NOT NULL
      AND killmail_time >= $1
    LIMIT $2
    """

    case EveDmv.Repo.query(query, [start_date, limit]) do
      {:ok, %{rows: rows}} ->
        ids = Enum.map(rows, fn [id] -> id end)
        {:ok, ids}

      {:error, reason} ->
        Logger.error("Failed to fetch participants: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Split a list into batches and run `fun` on each batch in parallel
  defp chunk_and_process(items, batch_size, fun, type) do
    batches =
      items
      |> Enum.chunk_every(batch_size)
      |> Enum.with_index(1)

    result_stream =
      Task.async_stream(
        batches,
        fn {batch, idx} ->
          Logger.debug("Processing #{type} batch #{idx}")
          Enum.each(batch, fun)
        end,
        max_concurrency: System.schedulers_online(),
        ordered: false
      )

    Stream.run(result_stream)
  end

  # Process one character's metrics and upsert into Ash
  defp process_character(character_id, start_date, end_date) do
    case calculate_character_metrics(character_id, start_date, end_date) do
      {:ok, %{character_name: name} = metrics} when is_binary(name) ->
        attrs =
          metrics
          |> Map.put(:character_id, character_id)
          |> Map.put(:stats_period_start, start_date)
          |> Map.put(:stats_period_end, end_date)

        upsert(PlayerStats, [character_id: character_id], attrs)

      {:error, reason} ->
        Logger.warning("Failed to process character #{character_id}: #{inspect(reason)}")
        {:error, reason}
    end
  rescue
    error ->
      Logger.error("Error processing character #{character_id}: #{inspect(error)}")
      {:error, error}
  end

  # Generic upsert helper (create or update based on filters)
  defp upsert(schema, filters, attrs) do
    case Ash.get(schema, filters, domain: Api) do
      {:ok, existing} -> Ash.update(existing, attrs, domain: Api)
      _ -> Ash.create(schema, attrs, domain: Api)
    end
  end

  # Calculate character metrics from participant data
  # Uses time range filter on killmail_time for efficient index usage
  defp calculate_character_metrics(character_id, start_date, end_date) do
    query = """
    SELECT
      id, killmail_id, killmail_time, character_id, character_name,
      corporation_id, corporation_name, alliance_id, alliance_name,
      ship_type_id, ship_name, weapon_type_id, weapon_name,
      damage_done, is_victim, final_blow, is_npc, solar_system_id
    FROM participants
    WHERE character_id = $1
      AND killmail_time >= $2
      AND killmail_time <= $3
    ORDER BY killmail_time DESC
    LIMIT 1000
    """

    case EveDmv.Repo.query(query, [character_id, start_date, end_date]) do
      {:ok, %{rows: rows, columns: columns}} when rows != [] ->
        parts = Enum.map(rows, fn row -> row_to_participant_map(columns, row) end)
        enriched_parts = enrich_participants_with_gang_size(parts)
        {:ok, build_character_metrics(enriched_parts)}

      {:ok, %{rows: []}} ->
        {:error, "No participants found for character #{character_id}"}

      {:error, reason} ->
        Logger.error("Failed to fetch character metrics: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Convert a database row to a participant map
  # Column names are known at compile time, so String.to_existing_atom is safe
  defp row_to_participant_map(columns, row) do
    columns
    |> Enum.zip(row)
    |> Enum.map(fn {col, val} -> {String.to_existing_atom(col), val} end)
    |> Map.new()
  end

  # Enrich participants with gang_size information from killmail data
  defp enrich_participants_with_gang_size(participants) do
    # Group participants by killmail to batch lookup attacker counts
    killmail_groups = Enum.group_by(participants, &{&1.killmail_id, &1.killmail_time})

    # Get attacker counts for each unique killmail
    attacker_counts = get_attacker_counts_for_killmails(Map.keys(killmail_groups))

    # Add gang_size to each participant based on their killmail's attacker count
    Enum.flat_map(killmail_groups, fn {killmail_key, parts} ->
      gang_size = Map.get(attacker_counts, killmail_key, 1)
      Enum.map(parts, &Map.put(&1, :gang_size, gang_size))
    end)
  end

  # Get attacker counts for a list of killmails (excluding victims)
  # Uses a single bulk query instead of N queries to avoid N+1 performance issues
  defp get_attacker_counts_for_killmails([]), do: %{}

  defp get_attacker_counts_for_killmails(killmail_keys) do
    # Extract killmail_ids and time range for partition pruning
    # Filter out nil times to avoid Enum.min/max failures
    killmail_ids = Enum.map(killmail_keys, fn {id, _time} -> id end)

    killmail_times =
      killmail_keys
      |> Enum.map(fn {_id, time} -> time end)
      |> Enum.reject(&is_nil/1)

    if Enum.empty?(killmail_times) do
      log_missing_killmail_times(killmail_keys)
    else
      fetch_attacker_counts(killmail_keys, killmail_ids, killmail_times)
    end
  end

  defp log_missing_killmail_times(killmail_keys) do
    Logger.warning(
      "No valid killmail_times found for #{length(killmail_keys)} killmail keys, " <>
        "falling back to default gang_size of 1"
    )

    default_gang_sizes(killmail_keys)
  end

  defp fetch_attacker_counts(killmail_keys, killmail_ids, killmail_times) do
    min_time = Enum.min(killmail_times, DateTime)
    max_time = Enum.max(killmail_times, DateTime)

    query = """
    SELECT killmail_id, killmail_time, COUNT(*) as attacker_count
    FROM participants
    WHERE killmail_id = ANY($1::bigint[])
      AND killmail_time >= $2
      AND killmail_time <= $3
      AND is_victim = false
    GROUP BY killmail_id, killmail_time
    """

    case EveDmv.Repo.query(query, [killmail_ids, min_time, max_time]) do
      {:ok, %{rows: rows}} ->
        parse_attacker_count_rows(rows)

      {:error, err} ->
        Logger.error(
          "Failed to fetch attacker counts for #{length(killmail_ids)} killmails " <>
            "(time range: #{inspect(min_time)} to #{inspect(max_time)}): #{inspect(err)}"
        )

        default_gang_sizes(killmail_keys)
    end
  end

  defp parse_attacker_count_rows(rows) do
    rows
    |> Enum.map(fn [killmail_id, killmail_time, count] ->
      {{killmail_id, killmail_time}, count}
    end)
    |> Map.new()
  end

  defp default_gang_sizes(killmail_keys) do
    killmail_keys
    |> Enum.map(fn key -> {key, 1} end)
    |> Map.new()
  end

  # Build character-level metrics map
  defp build_character_metrics(ps) do
    if Enum.empty?(ps) do
      %{character_name: "Unknown"}
    else
      character_name =
        case List.first(ps) do
          %{character_name: name} when is_binary(name) -> name
          _ -> "Unknown"
        end

      {kills, losses} = split_kills_losses(ps)
      {solo_kills, gang_kills, solo_losses, gang_losses} = split_solo_gang(kills, losses)

      basic_stats = calculate_basic_stats(kills, losses)
      ship_stats = calculate_participant_ship_stats(ps)
      gang_stats = calculate_gang_stats(ps, basic_stats.total_kills, basic_stats.total_losses)
      time_stats = calculate_time_stats(ps)

      Map.merge(basic_stats, %{
        character_name: character_name,
        solo_kills: length(solo_kills),
        solo_losses: length(solo_losses),
        gang_kills: length(gang_kills),
        gang_losses: length(gang_losses),
        ship_types_used: ship_stats.diversity,
        favorite_ship_type_id: ship_stats.fav_id,
        favorite_ship_name: ship_stats.fav_name,
        avg_gang_size: Decimal.from_float(gang_stats.avg_size),
        preferred_gang_size: gang_stats.preferred_size,
        first_kill_date: time_stats.first_kill,
        last_kill_date: time_stats.last_kill,
        active_days: time_stats.active_days,
        avg_kills_per_week: Decimal.from_float(time_stats.avg_per_week),
        active_regions: 1,
        danger_rating:
          calculate_character_danger_rating(
            basic_stats.total_kills,
            basic_stats.total_losses,
            basic_stats.total_isk_destroyed,
            ship_stats.diversity
          ),
        primary_activity: classify_character_activity(solo_kills, gang_kills)
      })
    end
  end

  defp split_kills_losses(ps) do
    Enum.split_with(ps, fn p -> p.is_victim == false end)
  end

  defp split_solo_gang(kills, losses) do
    {solo_kills, gang_kills} = Enum.split_with(kills, &((&1.gang_size || 1) == 1))
    {solo_losses, gang_losses} = Enum.split_with(losses, &((&1.gang_size || 1) == 1))
    {solo_kills, gang_kills, solo_losses, gang_losses}
  end

  defp calculate_basic_stats(kills, losses) do
    total_kills = length(kills)
    total_losses = length(losses)

    # Calculate actual ISK values from killmail data
    total_isk_destroyed =
      kills
      |> Enum.map(&(&1.total_value || Decimal.new(0)))
      |> Enum.reduce(Decimal.new(0), &Decimal.add/2)

    total_isk_lost =
      losses
      |> Enum.map(&(&1.total_value || Decimal.new(0)))
      |> Enum.reduce(Decimal.new(0), &Decimal.add/2)

    %{
      total_kills: total_kills,
      total_losses: total_losses,
      total_isk_destroyed: total_isk_destroyed,
      total_isk_lost: total_isk_lost
    }
  end

  defp calculate_participant_ship_stats(participants) do
    if Enum.empty?(participants) do
      %{diversity: 0, fav_id: nil, fav_name: "Unknown"}
    else
      ship_groups = Enum.group_by(participants, & &1.ship_type_id)

      diversity = map_size(ship_groups)

      {fav_id, fav_name} =
        ship_groups
        |> Enum.map(fn {ship_type_id, ship_participants} ->
          {ship_type_id, List.first(ship_participants).ship_name || "Unknown",
           length(ship_participants)}
        end)
        |> Enum.max_by(fn {_id, _name, count} -> count end, fn -> {nil, "Unknown", 0} end)
        |> then(fn {id, name, _count} -> {id, name} end)

      %{diversity: diversity, fav_id: fav_id, fav_name: fav_name}
    end
  end

  defp calculate_gang_stats(ps, total_kills, total_losses) do
    if Enum.empty?(ps) or total_kills + total_losses == 0 do
      %{avg_size: 1.0, preferred_size: :solo}
    else
      gang_sizes = Enum.map(ps, &(&1.gang_size || 1))

      avg_size =
        if total_kills + total_losses > 0 do
          Enum.sum(gang_sizes) / (total_kills + total_losses)
        else
          1.0
        end

      preferred_size = determine_preferred_gang_size(avg_size)

      %{avg_size: avg_size, preferred_size: preferred_size}
    end
  end

  defp determine_preferred_gang_size(avg_gang_size) do
    cond do
      avg_gang_size <= 1.2 -> :solo
      avg_gang_size <= 5 -> :small_gang
      avg_gang_size <= 15 -> :medium_gang
      true -> :fleet
    end
  end

  defp calculate_time_stats(participants) do
    now = DateTime.utc_now()

    if Enum.empty?(participants) do
      %{
        first_kill: now,
        last_kill: now,
        active_days: 0,
        avg_per_week: 0
      }
    else
      kill_participants = Enum.filter(participants, fn p -> p.is_victim == false end)
      total_kills = length(kill_participants)

      weeks = 12
      avg_per_week = if weeks > 0, do: total_kills / weeks, else: 0

      %{
        first_kill: DateTimeUtils.add(now, -30 * 86_400, :second),
        last_kill: now,
        active_days: 30,
        avg_per_week: avg_per_week
      }
    end
  end

  defp calculate_character_danger_rating(kills, losses, isk_destroyed, diversity) do
    kd_ratio = if losses > 0, do: kills / losses, else: kills * 1.0
    # Calculate ISK efficiency in billions using centralized constant
    isk_efficiency = Isk.to_billions(isk_destroyed)

    base_rating = 50
    kd_modifier = min(20, kd_ratio * 5)
    isk_modifier = min(20, isk_efficiency * 2)
    diversity_modifier = min(10, diversity * 2)

    rating = base_rating + kd_modifier + isk_modifier + diversity_modifier

    cond do
      rating >= 90 -> :extremely_dangerous
      rating >= 75 -> :very_dangerous
      rating >= 60 -> :dangerous
      rating >= 40 -> :moderate
      true -> :low
    end
  end

  defp classify_character_activity(solo_kills, gang_kills) do
    solo_count = length(solo_kills)
    gang_count = length(gang_kills)
    total = solo_count + gang_count

    cond do
      total == 0 -> :inactive
      solo_count > gang_count * 2 -> :solo_hunter
      gang_count > solo_count * 2 -> :fleet_pilot
      true -> :mixed
    end
  end
end

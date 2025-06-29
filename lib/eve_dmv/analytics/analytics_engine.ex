defmodule EveDmv.Analytics.AnalyticsEngine do
  @moduledoc """
  Analytics engine for calculating player and ship performance statistics.
  """

  require Logger
  alias EveDmv.Api
  alias EveDmv.Analytics.{PlayerStats, ShipStats}
  alias EveDmv.Eve.ItemType
  alias EveDmv.Killmails.Participant

  @default_days 90
  @default_batch_size 100
  @default_min_activity 5
  @default_min_usage 10

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
    start_date = DateTime.add(now, -days * 86_400, :second)

    Logger.info("Starting player statistics for last #{days} days")

    case participants_ids(:character_id, min_activity) do
      {:error, reason} ->
        Logger.error("Failed to calculate player stats: #{inspect(reason)}")
        {:error, reason}
      
      ids ->
        chunk_and_process(ids, batch_size, &process_character(&1, start_date, now), "player")
        Logger.info("Player statistics calculation completed")
        :ok
    end
  end

  @doc """
  Calculate and update ship statistics for all ship types.

  ## Options

    * `:days`      - days to look back (default: #{@default_days})
    * `:min_usage` - minimum activity count (default: #{@default_min_usage})
  """
  def calculate_ship_stats(opts \\ []) do
    days = Keyword.get(opts, :days, @default_days)
    min_usage = Keyword.get(opts, :min_usage, @default_min_usage)
    now = DateTime.utc_now()
    start_date = DateTime.add(now, -days * 86_400, :second)

    Logger.info("Starting ship statistics for last #{days} days")

    case participants_ids(:ship_type_id, min_usage) do
      {:error, reason} ->
        Logger.error("Failed to calculate ship stats: #{inspect(reason)}")
        {:error, reason}
      
      ids ->
        ids
        |> Enum.with_index(1)
        |> Task.async_stream(
          fn {ship_id, idx} ->
            if rem(idx, 50) == 1, do: Logger.debug("Processing ship #{idx}")
            process_ship(ship_id, start_date, now)
          end,
          max_concurrency: System.schedulers_online(),
          ordered: false
        )
        |> Stream.run()

        update_ship_rankings()
        Logger.info("Ship statistics calculation completed")
        :ok
    end
  end

  # Fetch up to `limit` unique non-nil values of `field` from recent participants
  defp participants_ids(field, limit) do
    case Ash.read(Participant, domain: Api) do
      {:ok, parts} ->
        parts
        |> Enum.map(&Map.get(&1, field))
        |> Enum.filter(& &1)
        |> Enum.uniq()
        |> Enum.take(limit)

      {:error, reason} ->
        Logger.error("Failed to fetch participants: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Split a list into batches and run `fun` on each batch in parallel
  defp chunk_and_process(items, batch_size, fun, type) do
    items
    |> Enum.chunk_every(batch_size)
    |> Enum.with_index(1)
    |> Task.async_stream(
      fn {batch, idx} ->
        Logger.debug("Processing #{type} batch #{idx}")
        Enum.each(batch, fun)
      end,
      max_concurrency: System.schedulers_online(),
      ordered: false
    )
    |> Stream.run()
  end

  # Process one character’s metrics and upsert into Ash
  defp process_character(character_id, start_date, end_date) do
    case calculate_character_metrics(character_id, start_date, end_date) do
      %{character_name: name} = metrics when is_binary(name) ->
        attrs =
          metrics
          |> Map.put(:character_id, character_id)
          |> Map.put(:stats_period_start, start_date)
          |> Map.put(:stats_period_end, end_date)

        upsert(PlayerStats, [character_id: character_id], attrs)

      _ ->
        Logger.warning("Insufficient data for character #{character_id}")
    end
  rescue
    error ->
      Logger.error("Error processing character #{character_id}: #{inspect(error)}")
  end

  # Process one ship’s metrics and upsert into Ash
  defp process_ship(ship_type_id, start_date, end_date) do
    with {:ok, ship_type} <-
           Ash.get(ItemType, ship_type_id, domain: Api, load: [:is_capital_ship]),
         metrics when is_map(metrics) <-
           calculate_ship_metrics(ship_type_id, start_date, end_date),
         %{ship_name: _} <- metrics do
      attrs =
        metrics
        |> Map.put(:ship_type_id, ship_type_id)
        |> Map.put(:ship_category, determine_ship_category(ship_type))
        |> Map.put(:tech_level, ship_type.tech_level || 1)
        |> Map.put(:meta_level, ship_type.meta_level || 0)
        |> Map.put(:is_capital, ship_type.is_capital_ship == true)
        |> Map.put(:stats_period_start, start_date)
        |> Map.put(:stats_period_end, end_date)

      upsert(ShipStats, [ship_type_id: ship_type_id], attrs)
    else
      _ -> Logger.warning("Insufficient data for ship #{ship_type_id}")
    end
  rescue
    error ->
      Logger.error("Error processing ship #{ship_type_id}: #{inspect(error)}")
  end

  # Generic upsert helper (create or update based on filters)
  defp upsert(schema, filters, attrs) do
    case Ash.get(schema, filters, domain: Api) do
      {:ok, existing} -> Ash.update(existing, attrs, domain: Api)
      _ -> Ash.create(schema, attrs, domain: Api)
    end
  end

  # --- Metric calculations ---

  defp calculate_character_metrics(character_id, _start_date, _end_date) do
    case Ash.read(Participant, 
      filter: %{character_id: character_id},
      limit: 1_000,
      domain: Api
    ) do
      {:ok, [_ | _] = parts} ->
        build_character_metrics(parts)
      {:ok, []} ->
        %{}
      {:error, reason} ->
        Logger.error("Failed to fetch character metrics: #{inspect(reason)}")
        %{}
    end
  end

  defp calculate_ship_metrics(ship_type_id, _start_date, _end_date) do
    case Ash.read(Participant, 
      filter: %{ship_type_id: ship_type_id},
      limit: 1_000,
      domain: Api
    ) do
      {:ok, [_ | _] = parts} ->
        build_ship_metrics(parts)
      {:ok, []} ->
        %{}
      {:error, reason} ->
        Logger.error("Failed to fetch ship metrics: #{inspect(reason)}")
        %{}
    end
  end

  # Build character-level metrics map
  defp build_character_metrics(ps) do
    character_name = 
      case List.first(ps) do
        %{character_name: name} when is_binary(name) -> name
        _ -> "Unknown"
      end
    {kills, losses} = split_kills_losses(ps)
    {solo_kills, gang_kills, solo_losses, gang_losses} = split_solo_gang(kills, losses)

    basic_stats = calculate_basic_stats(kills, losses)
    ship_stats = calculate_ship_stats(ps)
    gang_stats = calculate_gang_stats(ps, basic_stats.total_kills, basic_stats.total_losses)
    time_stats = calculate_time_stats(basic_stats.total_kills)

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
        calculate_danger_rating(
          basic_stats.total_kills,
          basic_stats.total_losses,
          basic_stats.total_isk_destroyed,
          ship_stats.diversity
        ),
      primary_activity: classify_primary_activity(solo_kills, gang_kills)
    })
  end

  defp split_kills_losses(ps) do
    Enum.split_with(ps, &((&1.damage_dealt || 0) > 0))
  end

  defp split_solo_gang(kills, losses) do
    {solo_kills, gang_kills} = Enum.split_with(kills, &((&1.gang_size || 1) == 1))
    {solo_losses, gang_losses} = Enum.split_with(losses, &((&1.gang_size || 1) == 1))
    {solo_kills, gang_kills, solo_losses, gang_losses}
  end

  defp calculate_basic_stats(kills, losses) do
    total_kills = length(kills)
    total_losses = length(losses)

    # Calculate actual ISK values from participant data instead of hardcoded multipliers
    total_isk_destroyed = 
      ps
      |> Enum.filter(&(not &1.is_victim))
      |> Enum.map(&(&1.ship_value || Decimal.new(0)))
      |> Enum.reduce(Decimal.new(0), &Decimal.add/2)
    
    total_isk_lost = 
      ps
      |> Enum.filter(& &1.is_victim)
      |> Enum.map(&(&1.ship_value || Decimal.new(0)))
      |> Enum.reduce(Decimal.new(0), &Decimal.add/2)
    
    %{
      total_kills: total_kills,
      total_losses: total_losses,
      total_isk_destroyed: total_isk_destroyed,
      total_isk_lost: total_isk_lost
    }
  end

  defp calculate_gang_stats(ps, total_kills, total_losses) do
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

  defp determine_preferred_gang_size(avg_gang_size) do
    cond do
      avg_gang_size <= 1.2 -> :solo
      avg_gang_size <= 5 -> :small_gang
      avg_gang_size <= 15 -> :medium_gang
      true -> :fleet
    end
  end

  defp calculate_time_stats(total_kills) do
    now = DateTime.utc_now()
    weeks = 12
    avg_per_week = if weeks > 0, do: total_kills / weeks, else: 0

    %{
      first_kill: DateTime.add(now, -30 * 86_400, :second),
      last_kill: now,
      active_days: 30,
      avg_per_week: avg_per_week
    }
  end

  # Build ship-level metrics map
  defp build_ship_metrics(ps) do
    ship_name = List.first(ps).ship_name || "Unknown"

    {kills, losses} =
      Enum.split_with(ps, &((&1.damage_dealt || 0) > 0))

    total_kills = length(kills)
    total_losses = length(losses)
    pilots = ps |> Enum.map(& &1.character_id) |> Enum.uniq() |> length()

    # Calculate actual ISK values from participant data instead of hardcoded multipliers
    total_isk_out = 
      kills
      |> Enum.map(&(&1.ship_value || Decimal.new(0)))
      |> Enum.reduce(Decimal.new(0), &Decimal.add/2)
    
    total_isk_in = 
      losses
      |> Enum.map(&(&1.ship_value || Decimal.new(0)))
      |> Enum.reduce(Decimal.new(0), &Decimal.add/2)

    avg_damage_dealt =
      if total_kills > 0,
        do: Enum.sum(Enum.map(kills, &(&1.damage_dealt || 0))) / total_kills,
        else: 0

    avg_gang_kill =
      if total_kills > 0,
        do: Enum.sum(Enum.map(kills, &(&1.gang_size || 1))) / total_kills,
        else: 1.0

    avg_gang_loss =
      if total_losses > 0,
        do: Enum.sum(Enum.map(losses, &(&1.gang_size || 1))) / total_losses,
        else: 1.0

    solo_kills = Enum.count(kills, &((&1.gang_size || 1) == 1))
    solo_pct = if total_kills > 0, do: solo_kills / total_kills * 100, else: 0

    now = DateTime.utc_now()
    first = DateTime.add(now, -30 * 86_400, :second)
    last = now
    peak_utc = 18

    %{
      ship_name: ship_name,
      total_kills: total_kills,
      total_losses: total_losses,
      pilots_flown: pilots,
      total_isk_destroyed: total_isk_out,
      total_isk_lost: total_isk_in,
      avg_damage_dealt: Decimal.from_float(avg_damage_dealt),
      avg_gang_size_when_killing: Decimal.from_float(avg_gang_kill),
      avg_gang_size_when_dying: Decimal.from_float(avg_gang_loss),
      solo_kill_percentage: Decimal.from_float(solo_pct),
      peak_activity_hour: peak_utc,
      first_seen: first,
      last_seen: last
    }
  end

  # Update usage + effectiveness rankings, then assign meta-tiers
  defp update_ship_rankings do
    case Ash.read(ShipStats, domain: Api) do
      {:ok, ships} ->
        usage_ranked =
          ships
          |> Enum.sort_by(&(&1.total_kills + &1.total_losses), :desc)
          |> Enum.with_index(1)

        eff_ranked =
          ships
          |> Enum.filter(&(&1.total_kills + &1.total_losses >= 25))
          |> Enum.sort_by(& &1.kill_death_ratio, :desc)
          |> Enum.with_index(1)

        for {ship, rank} <- usage_ranked, do: Ash.update(ship, %{usage_rank: rank}, domain: Api)

        for {ship, rank} <- eff_ranked,
            do: Ash.update(ship, %{effectiveness_rank: rank}, domain: Api)

        calculate_meta_tiers(eff_ranked)

      {:error, reason} ->
        Logger.error("Failed reading ship stats: #{inspect(reason)}")
    end
  rescue
    error -> Logger.error("Error updating rankings: #{inspect(error)}")
  end

  defp calculate_meta_tiers(ranked) do
    total = length(ranked)

    for {ship, rank} <- ranked do
      tier =
        cond do
          rank <= max(1, div(total, 20)) -> "S"
          rank <= max(1, div(total, 10)) -> "A"
          rank <= max(1, div(total, 5)) -> "B"
          rank <= max(1, div(total, 2)) -> "C"
          true -> "D"
        end

      Ash.update(ship, %{meta_tier: tier}, domain: Api)
    end
  rescue
    error -> Logger.error("Error calculating meta tiers: #{inspect(error)}")
  end

  defp calculate_danger_rating(kills, losses, isk_destroyed, diversity) do
    kd_ratio = if losses > 0, do: kills / losses, else: kills

    base_score =
      cond do
        kd_ratio >= 5.0 -> 4
        kd_ratio >= 2.0 -> 3
        kd_ratio >= 1.0 -> 2
        true -> 1
      end

    bonus_isk = if isk_destroyed > 10_000_000_000, do: 1, else: 0
    bonus_div = if diversity > 10, do: 1, else: 0

    min(5, base_score + bonus_isk + bonus_div)
  end

  defp classify_primary_activity(solo, gang) do
    total = length(solo) + length(gang)

    cond do
      length(solo) > total * 0.7 -> "solo_pvp"
      length(gang) > total * 0.8 -> "small_gang"
      true -> "fleet_pvp"
    end
  end

  @spec determine_ship_category(ItemType.t()) :: String.t()
  defp determine_ship_category(%ItemType{is_capital_ship: is_cap, group_name: group_name}) do
    if is_cap do
      "capital"
    else
      categorize_by_group(group_name || "")
    end
  end

  defp categorize_by_group(group) do
    cond do
      group =~ ~r/battlecruiser/i -> "battlecruiser"
      group =~ ~r/battleship/i -> "battleship"
      group =~ ~r/cruiser/i -> "cruiser"
      group =~ ~r/destroyer/i -> "destroyer"
      group =~ ~r/frigate/i -> "frigate"
      group =~ ~r/industrial/i -> "industrial"
      true -> "special"
    end
  end
end

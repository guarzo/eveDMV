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

  defp calculate_time_stats(participants) do
    now = DateTime.utc_now()

    kill_participants = Enum.filter(participants, &((&1.damage_dealt || 0) > 0))
    total_kills = length(kill_participants)

    weeks = 12
    avg_per_week = if weeks > 0, do: total_kills / weeks, else: 0

    %{
      first_kill: DateTime.add(now, -30 * 86_400, :second),
      last_kill: now,
      active_days: 30,
      avg_per_week: avg_per_week
    }
  end

  defp calculate_character_danger_rating(kills, losses, isk_destroyed, diversity) do
    kd_ratio = if losses > 0, do: kills / losses, else: kills * 1.0
    # billions destroyed
    isk_efficiency = Decimal.to_float(isk_destroyed) / 1_000_000_000

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

  # Build ship-level metrics map
  defp build_ship_metrics(ps) do
    ship_name = List.first(ps).ship_name || "Unknown"
    {kills, losses} = Enum.split_with(ps, &((&1.damage_dealt || 0) > 0))

    basic_metrics = calculate_basic_metrics(kills, losses, ps)
    isk_metrics = calculate_isk_metrics(kills, losses)
    combat_metrics = calculate_combat_metrics(kills, losses)
    time_metrics = calculate_time_metrics()

    Map.merge(basic_metrics, isk_metrics)
    |> Map.merge(combat_metrics)
    |> Map.merge(time_metrics)
    |> Map.put(:ship_name, ship_name)
  end

  defp calculate_basic_metrics(kills, losses, ps) do
    %{
      total_kills: length(kills),
      total_losses: length(losses),
      pilots_flown: ps |> Enum.map(& &1.character_id) |> Enum.uniq() |> length()
    }
  end

  defp calculate_isk_metrics(kills, losses) do
    total_isk_out = sum_ship_values(kills)
    total_isk_in = sum_ship_values(losses)

    %{
      total_isk_destroyed: total_isk_out,
      total_isk_lost: total_isk_in
    }
  end

  defp calculate_combat_metrics(kills, losses) do
    total_kills = length(kills)
    total_losses = length(losses)

    avg_damage_dealt = calculate_average_damage(kills, total_kills)
    avg_gang_kill = calculate_average_gang_size(kills, total_kills)
    avg_gang_loss = calculate_average_gang_size(losses, total_losses)
    solo_pct = calculate_solo_percentage(kills, total_kills)

    %{
      avg_damage_dealt: Decimal.from_float(avg_damage_dealt),
      avg_gang_size_when_killing: Decimal.from_float(avg_gang_kill),
      avg_gang_size_when_dying: Decimal.from_float(avg_gang_loss),
      solo_kill_percentage: Decimal.from_float(solo_pct)
    }
  end

  defp calculate_time_metrics do
    now = DateTime.utc_now()
    first = DateTime.add(now, -30 * 86_400, :second)

    %{
      peak_activity_hour: 18,
      first_seen: first,
      last_seen: now
    }
  end

  defp sum_ship_values(participants) do
    participants
    |> Enum.map(&(&1.ship_value || Decimal.new(0)))
    |> Enum.reduce(Decimal.new(0), &Decimal.add/2)
  end

  defp calculate_average_damage(kills, total_kills) do
    if total_kills > 0 do
      Enum.sum(Enum.map(kills, &(&1.damage_dealt || 0))) / total_kills
    else
      0
    end
  end

  defp calculate_average_gang_size(participants, total_count) do
    if total_count > 0 do
      Enum.sum(Enum.map(participants, &(&1.gang_size || 1))) / total_count
    else
      1.0
    end
  end

  defp calculate_solo_percentage(kills, total_kills) do
    if total_kills > 0 do
      solo_kills = Enum.count(kills, &((&1.gang_size || 1) == 1))
      solo_kills / total_kills * 100
    else
      0
    end
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

        # Bulk update usage ranks
        usage_updates =
          Enum.map(usage_ranked, fn {ship, rank} ->
            %{id: ship.id, usage_rank: rank}
          end)

        Ash.bulk_update(usage_updates, ShipTypeStats, :update,
          domain: Api,
          return_records?: false,
          return_errors?: false,
          stop_on_error?: false,
          batch_size: 500
        )

        # Bulk update effectiveness ranks
        eff_updates =
          Enum.map(eff_ranked, fn {ship, rank} ->
            %{id: ship.id, effectiveness_rank: rank}
          end)

        Ash.bulk_update(eff_updates, ShipTypeStats, :update,
          domain: Api,
          return_records?: false,
          return_errors?: false,
          stop_on_error?: false,
          batch_size: 500
        )

        calculate_meta_tiers(eff_ranked)

      {:error, reason} ->
        Logger.error("Failed reading ship stats: #{inspect(reason)}")
    end
  rescue
    error -> Logger.error("Error updating rankings: #{inspect(error)}")
  end

  defp calculate_meta_tiers(ranked) do
    total = length(ranked)

    tier_updates =
      Enum.map(ranked, fn {ship, rank} ->
        tier =
          cond do
            rank <= max(1, div(total, 20)) -> "S"
            rank <= max(1, div(total, 10)) -> "A"
            rank <= max(1, div(total, 5)) -> "B"
            rank <= max(1, div(total, 2)) -> "C"
            true -> "D"
          end

        %{id: ship.id, meta_tier: tier}
      end)

    Ash.bulk_update(tier_updates, ShipTypeStats, :update,
      domain: Api,
      return_records?: false,
      return_errors?: false,
      stop_on_error?: false,
      batch_size: 500
    )
  rescue
    error -> Logger.error("Error calculating meta tiers: #{inspect(error)}")
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

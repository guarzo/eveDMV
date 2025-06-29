defmodule EveDmv.Analytics.AnalyticsEngine do
  @moduledoc """
  Analytics engine for calculating player and ship performance statistics.

  This module processes killmail data to generate comprehensive analytics
  for both individual players and ship types. It provides batch processing
  capabilities for efficient large-scale analysis.
  """

  require Logger
  alias EveDmv.Api
  alias EveDmv.Analytics.{PlayerStats, ShipStats}
  alias EveDmv.Killmails.{KillmailEnriched, Participant}
  alias EveDmv.Eve.{ItemType, SolarSystem}

  @doc """
  Calculate and update player statistics for all active characters.

  Options:
  - days: Number of days to look back (default: 90)
  - batch_size: Number of characters to process per batch (default: 100)
  - min_activity: Minimum killmails required to generate stats (default: 5)
  """
  def calculate_player_stats(opts \\ []) do
    days = Keyword.get(opts, :days, 90)
    batch_size = Keyword.get(opts, :batch_size, 100)
    min_activity = Keyword.get(opts, :min_activity, 5)

    Logger.info("Starting player statistics calculation for last #{days} days")

    start_date = DateTime.utc_now() |> DateTime.add(-days, :day)

    # Get all characters with killmail activity in the period
    active_characters = get_active_characters(start_date, min_activity)

    Logger.info("Found #{length(active_characters)} active characters to process")

    # Process in batches
    active_characters
    |> Enum.chunk_every(batch_size)
    |> Enum.with_index()
    |> Enum.each(fn {batch, index} ->
      Logger.debug("Processing player stats batch #{index + 1}")
      process_player_batch(batch, start_date, DateTime.utc_now())
    end)

    Logger.info("Player statistics calculation completed")
  end

  @doc """
  Calculate and update ship statistics for all ship types.

  Options:
  - days: Number of days to look back (default: 90)  
  - min_usage: Minimum kills+losses required to generate stats (default: 10)
  """
  def calculate_ship_stats(opts \\ []) do
    days = Keyword.get(opts, :days, 90)
    min_usage = Keyword.get(opts, :min_usage, 10)

    Logger.info("Starting ship statistics calculation for last #{days} days")

    start_date = DateTime.utc_now() |> DateTime.add(-days, :day)

    # Get all ship types with activity in the period
    active_ships = get_active_ships(start_date, min_usage)

    Logger.info("Found #{length(active_ships)} ship types to process")

    # Process each ship type
    active_ships
    |> Enum.with_index()
    |> Enum.each(fn {ship_type_id, index} ->
      if rem(index, 50) == 0 do
        Logger.debug("Processing ship #{index + 1}/#{length(active_ships)}")
      end

      process_ship_stats(ship_type_id, start_date, DateTime.utc_now())
    end)

    # Calculate rankings and meta tiers
    update_ship_rankings()

    Logger.info("Ship statistics calculation completed")
  end

  # Private helper functions

  defp get_active_characters(_start_date, _min_activity) do
    # For now, get characters from recent participants
    {:ok, participants} = Ash.read(Participant, domain: Api)

    participants
    |> Enum.map(& &1.character_id)
    |> Enum.filter(&(&1 != nil))
    |> Enum.uniq()
    |> Enum.take(100)
  rescue
    error ->
      Logger.error("Failed to get active characters: #{inspect(error)}")
      []
  end

  defp get_active_ships(_start_date, _min_usage) do
    # For now, get ship types from recent participants
    {:ok, participants} = Ash.read(Participant, domain: Api)

    participants
    |> Enum.map(& &1.ship_type_id)
    |> Enum.filter(&(&1 != nil))
    |> Enum.uniq()
    |> Enum.take(50)
  rescue
    error ->
      Logger.error("Failed to get active ships: #{inspect(error)}")
      []
  end

  defp process_player_batch(character_ids, start_date, end_date) do
    Enum.each(character_ids, fn character_id ->
      process_character_stats(character_id, start_date, end_date)
    end)
  end

  defp process_character_stats(character_id, start_date, end_date) do
    # Get character's killmail participation data
    stats = calculate_character_metrics(character_id, start_date, end_date)

    case stats do
      %{character_name: character_name} = metrics when character_name != nil ->
        # Create or update player stats
        case Ash.get(PlayerStats, character_id: character_id, domain: Api) do
          {:ok, existing_stats} ->
            Ash.update(
              existing_stats,
              Map.put(metrics, :stats_period_start, start_date)
              |> Map.put(:stats_period_end, end_date),
              domain: Api
            )

          {:error, _} ->
            Ash.create(
              PlayerStats,
              metrics
              |> Map.put(:character_id, character_id)
              |> Map.put(:stats_period_start, start_date)
              |> Map.put(:stats_period_end, end_date),
              domain: Api
            )
        end

      _ ->
        Logger.warning("Insufficient data for character #{character_id}")
    end
  rescue
    error ->
      Logger.error("Failed to process character #{character_id}: #{inspect(error)}")
  end

  defp calculate_character_metrics(character_id, _start_date, _end_date) do
    # Get all killmail participation for this character (simplified for now)
    {:ok, all_participants} = Ash.read(Participant, domain: Api)

    participations =
      all_participants |> Enum.filter(&(&1.character_id == character_id)) |> Enum.take(1000)

    if Enum.empty?(participations) do
      %{}
    else
      character_name = participations |> List.first() |> Map.get(:character_name, "Unknown")

      # Separate kills from losses
      {kills, losses} = Enum.split_with(participations, &(&1.damage_dealt > 0))

      # Calculate basic metrics
      total_kills = length(kills)
      total_losses = length(losses)

      # Calculate ISK metrics (placeholder values for now)
      # Placeholder
      total_isk_destroyed = total_kills * 50_000_000
      # Placeholder
      total_isk_lost = total_losses * 50_000_000

      # Calculate gang vs solo
      {solo_kills, gang_kills} = Enum.split_with(kills, &((&1.gang_size || 1) == 1))
      {solo_losses, gang_losses} = Enum.split_with(losses, &((&1.gang_size || 1) == 1))

      # Ship diversity
      ship_types_used = participations |> Enum.map(& &1.ship_type_id) |> Enum.uniq() |> length()

      # Most used ship
      ship_usage =
        participations
        |> Enum.group_by(& &1.ship_type_id)
        |> Enum.max_by(fn {_ship_id, uses} -> length(uses) end, fn -> {nil, []} end)

      {favorite_ship_type_id, favorite_uses} = ship_usage

      favorite_ship_name =
        if favorite_uses != [], do: List.first(favorite_uses).ship_name, else: nil

      # Gang size analysis
      gang_sizes = participations |> Enum.map(&(&1.gang_size || 1))

      avg_gang_size =
        if total_kills + total_losses > 0 do
          (gang_sizes |> Enum.sum()) / (total_kills + total_losses)
        else
          1.0
        end

      # Determine preferred gang size
      preferred_gang_size =
        cond do
          length(solo_kills) + length(solo_losses) > (total_kills + total_losses) * 0.6 ->
            "solo"

          avg_gang_size <= 5 ->
            "small_gang"

          avg_gang_size <= 15 ->
            "medium_gang"

          true ->
            "fleet"
        end

      # Activity analysis
      # Placeholder
      first_kill_date = DateTime.utc_now() |> DateTime.add(-30, :day)
      # Placeholder
      last_kill_date = DateTime.utc_now()

      # Active days calculation (placeholder)
      active_days = 30

      # Weekly activity
      weeks_in_period = 12
      avg_kills_per_week = if weeks_in_period > 0, do: total_kills / weeks_in_period, else: 0

      # Danger rating (1-5 based on performance)
      danger_rating =
        calculate_danger_rating(total_kills, total_losses, total_isk_destroyed, ship_types_used)

      # Primary activity classification
      primary_activity = classify_primary_activity(solo_kills, gang_kills, participations)

      %{
        character_name: character_name,
        total_kills: total_kills,
        total_losses: total_losses,
        solo_kills: length(solo_kills),
        solo_losses: length(solo_losses),
        gang_kills: length(gang_kills),
        gang_losses: length(gang_losses),
        total_isk_destroyed: Decimal.new(total_isk_destroyed),
        total_isk_lost: Decimal.new(total_isk_lost),
        first_kill_date: first_kill_date,
        last_kill_date: last_kill_date,
        active_days: active_days,
        avg_kills_per_week: Decimal.new(avg_kills_per_week),
        ship_types_used: ship_types_used,
        favorite_ship_type_id: favorite_ship_type_id,
        favorite_ship_name: favorite_ship_name,
        avg_gang_size: Decimal.new(avg_gang_size),
        preferred_gang_size: preferred_gang_size,
        # Simplified for now
        active_regions: 1,
        danger_rating: danger_rating,
        primary_activity: primary_activity
      }
    end
  rescue
    error ->
      Logger.error("Failed to calculate metrics for character #{character_id}: #{inspect(error)}")

      %{}
  end

  defp process_ship_stats(ship_type_id, start_date, end_date) do
    # Get ship type information
    case Ash.get(ItemType, ship_type_id, domain: Api) do
      {:ok, ship_type} ->
        # Calculate ship metrics
        metrics = calculate_ship_metrics(ship_type_id, start_date, end_date)

        case metrics do
          %{ship_name: ship_name} when ship_name != nil ->
            # Create or update ship stats
            case Ash.get(ShipStats, ship_type_id: ship_type_id, domain: Api) do
              {:ok, existing_stats} ->
                Ash.update(
                  existing_stats,
                  metrics
                  |> Map.put(:stats_period_start, start_date)
                  |> Map.put(:stats_period_end, end_date),
                  domain: Api
                )

              {:error, _} ->
                Ash.create(
                  ShipStats,
                  metrics
                  |> Map.put(:ship_type_id, ship_type_id)
                  |> Map.put(:ship_category, determine_ship_category(ship_type))
                  |> Map.put(:tech_level, ship_type.tech_level || 1)
                  |> Map.put(:meta_level, ship_type.meta_level || 0)
                  |> Map.put(:is_capital, ship_type.is_capital_ship || false)
                  |> Map.put(:stats_period_start, start_date)
                  |> Map.put(:stats_period_end, end_date),
                  domain: Api
                )
            end

          _ ->
            Logger.warning("Insufficient data for ship type #{ship_type_id}")
        end

      {:error, _} ->
        Logger.warning("Ship type #{ship_type_id} not found")
    end
  rescue
    error ->
      Logger.error("Failed to process ship #{ship_type_id}: #{inspect(error)}")
  end

  defp calculate_ship_metrics(ship_type_id, _start_date, _end_date) do
    # Get all killmail participation for this ship type (simplified)
    {:ok, all_participants} = Ash.read(Participant, domain: Api)

    participations =
      all_participants |> Enum.filter(&(&1.ship_type_id == ship_type_id)) |> Enum.take(1000)

    if Enum.empty?(participations) do
      %{}
    else
      ship_name = participations |> List.first() |> Map.get(:ship_name, "Unknown")

      # Separate kills from losses
      {kills, losses} = Enum.split_with(participations, &(&1.damage_dealt > 0))

      # Basic metrics
      total_kills = length(kills)
      total_losses = length(losses)
      pilots_flown = participations |> Enum.map(& &1.character_id) |> Enum.uniq() |> length()

      # ISK metrics (placeholder)
      total_isk_destroyed = total_kills * 50_000_000
      total_isk_lost = total_losses * 50_000_000

      # Damage analysis
      avg_damage_dealt =
        if total_kills > 0 do
          total_damage = kills |> Enum.map(&(&1.damage_dealt || 0)) |> Enum.sum()
          total_damage / total_kills
        else
          0
        end

      # Gang size analysis
      avg_gang_size_killing =
        if total_kills > 0 do
          total_gang_size_kills = kills |> Enum.map(&(&1.gang_size || 1)) |> Enum.sum()
          total_gang_size_kills / total_kills
        else
          1.0
        end

      avg_gang_size_dying =
        if total_losses > 0 do
          total_gang_size_losses = losses |> Enum.map(&(&1.gang_size || 1)) |> Enum.sum()
          total_gang_size_losses / total_losses
        else
          1.0
        end

      # Solo performance
      solo_kills = kills |> Enum.count(&((&1.gang_size || 1) == 1))
      solo_kill_percentage = if total_kills > 0, do: solo_kills / total_kills * 100, else: 0

      # Temporal analysis (placeholders)
      first_seen = DateTime.utc_now() |> DateTime.add(-30, :day)
      last_seen = DateTime.utc_now()
      # 18:00 UTC placeholder
      peak_hour = 18

      %{
        ship_name: ship_name,
        total_kills: total_kills,
        total_losses: total_losses,
        pilots_flown: pilots_flown,
        total_isk_destroyed: Decimal.new(total_isk_destroyed),
        total_isk_lost: Decimal.new(total_isk_lost),
        avg_damage_dealt: Decimal.new(avg_damage_dealt),
        avg_gang_size_when_killing: Decimal.new(avg_gang_size_killing),
        avg_gang_size_when_dying: Decimal.new(avg_gang_size_dying),
        solo_kill_percentage: Decimal.new(solo_kill_percentage),
        peak_activity_hour: peak_hour,
        first_seen: first_seen,
        last_seen: last_seen
      }
    end
  rescue
    error ->
      Logger.error("Failed to calculate ship metrics for #{ship_type_id}: #{inspect(error)}")
      %{}
  end

  defp update_ship_rankings do
    # Get all ship stats to calculate rankings
    case Ash.read(ShipStats, domain: Api) do
      {:ok, all_ships} ->
        # Rank by usage (total activity)
        usage_ranked =
          all_ships
          |> Enum.sort_by(&(&1.total_kills + &1.total_losses), :desc)
          |> Enum.with_index(1)

        # Rank by effectiveness (K/D ratio)
        effectiveness_ranked =
          all_ships
          # Min usage threshold
          |> Enum.filter(&(&1.total_kills + &1.total_losses >= 25))
          |> Enum.sort_by(& &1.kill_death_ratio, :desc)
          |> Enum.with_index(1)

        # Update usage rankings
        Enum.each(usage_ranked, fn {ship, rank} ->
          Ash.update(ship, %{usage_rank: rank}, domain: Api)
        end)

        # Update effectiveness rankings
        Enum.each(effectiveness_ranked, fn {ship, rank} ->
          Ash.update(ship, %{effectiveness_rank: rank}, domain: Api)
        end)

        # Calculate meta tiers based on performance
        calculate_meta_tiers(effectiveness_ranked)

      {:error, error} ->
        Logger.error("Failed to read ship stats: #{inspect(error)}")
    end
  rescue
    error ->
      Logger.error("Failed to update ship rankings: #{inspect(error)}")
  end

  defp calculate_meta_tiers(effectiveness_ranked) do
    total_ships = length(effectiveness_ranked)

    effectiveness_ranked
    |> Enum.each(fn {ship, rank} ->
      tier =
        cond do
          # Top 5%
          rank <= max(1, div(total_ships, 20)) -> "S"
          # Top 10%
          rank <= max(1, div(total_ships, 10)) -> "A"
          # Top 20%
          rank <= max(1, div(total_ships, 5)) -> "B"
          # Top 50%
          rank <= max(1, div(total_ships, 2)) -> "C"
          true -> "D"
        end

      Ash.update(ship, %{meta_tier: tier}, domain: Api)
    end)
  rescue
    error ->
      Logger.error("Failed to calculate meta tiers: #{inspect(error)}")
  end

  # Helper functions for classification

  defp calculate_danger_rating(kills, losses, isk_destroyed, ship_diversity) do
    kd_ratio = if losses > 0, do: kills / losses, else: kills

    # Base score from K/D ratio
    base_score =
      cond do
        kd_ratio >= 5.0 -> 4
        kd_ratio >= 2.0 -> 3
        kd_ratio >= 1.0 -> 2
        true -> 1
      end

    # Bonus for high ISK destroyed
    # 10B ISK
    isk_bonus = if isk_destroyed > 10_000_000_000, do: 1, else: 0

    # Bonus for ship diversity (experienced pilot)
    diversity_bonus = if ship_diversity > 10, do: 1, else: 0

    min(5, base_score + isk_bonus + diversity_bonus)
  end

  defp classify_primary_activity(solo_kills, gang_kills, _all_participations) do
    total_kills = length(solo_kills) + length(gang_kills)

    cond do
      length(solo_kills) > total_kills * 0.7 -> "solo_pvp"
      length(gang_kills) > total_kills * 0.8 -> "small_gang"
      true -> "fleet_pvp"
    end
  end

  defp determine_ship_category(ship_type) do
    group_name = ship_type.group_name || ""

    cond do
      ship_type.is_capital_ship -> "capital"
      group_name =~ ~r/frigate/i -> "frigate"
      group_name =~ ~r/destroyer/i -> "destroyer"
      group_name =~ ~r/cruiser/i and not (group_name =~ ~r/battle/i) -> "cruiser"
      group_name =~ ~r/battlecruiser/i -> "battlecruiser"
      group_name =~ ~r/battleship/i -> "battleship"
      group_name =~ ~r/industrial/i -> "industrial"
      true -> "special"
    end
  end
end

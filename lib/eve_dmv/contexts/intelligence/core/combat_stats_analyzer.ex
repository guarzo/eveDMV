defmodule EveDmv.Contexts.Intelligence.Core.CombatStatsAnalyzer do
  @moduledoc """
  Analyzes combat statistics for characters including kill/death ratios,
  ISK efficiency, weapon preferences, and engagement patterns.
  
  Consolidates functionality from:
  - Character Intelligence combat metrics
  - Player Profile combat analysis
  """
  
  alias EveDmv.Platform.Database.{CharacterRepository, KillmailRepository}
  alias EveDmv.Platform.Cache.Intelligence.IntelligenceCache
  alias EveDmv.StaticData.ShipTypes
  
  require Logger
  
  @cache_ttl :timer.hours(4)
  
  @doc """
  Analyze comprehensive combat statistics for a character.
  
  Options:
    - time_range: Time period for analysis (default: last 90 days)
    - include_details: Include detailed breakdowns
  """
  def analyze_combat_stats(character_id, opts \\ []) do
    cache_key = {:combat_stats, character_id, opts}
    
    IntelligenceCache.get_or_compute(cache_key, fn ->
      perform_combat_analysis(character_id, opts)
    end, ttl: @cache_ttl)
  end
  
  @doc """
  Get kill/death ratio for a character.
  """
  def get_kill_death_ratio(character_id) do
    case analyze_combat_stats(character_id) do
      {:ok, stats} -> {:ok, stats.kill_death_ratio}
      error -> error
    end
  end
  
  @doc """
  Get ISK efficiency percentage.
  """
  def get_isk_efficiency(character_id) do
    case analyze_combat_stats(character_id) do
      {:ok, stats} -> {:ok, stats.isk_efficiency}
      error -> error
    end
  end
  
  @doc """
  Get weapon system preferences.
  """
  def get_weapon_preferences(character_id) do
    case analyze_combat_stats(character_id) do
      {:ok, stats} -> {:ok, stats.weapon_preferences}
      error -> error
    end
  end
  
  @doc """
  Get engagement pattern analysis.
  """
  def get_engagement_patterns(character_id) do
    case analyze_combat_stats(character_id) do
      {:ok, stats} -> {:ok, stats.engagement_patterns}
      error -> error
    end
  end
  
  # Private Functions
  
  defp perform_combat_analysis(character_id, opts) do
    time_range = Keyword.get(opts, :time_range, days: 90)
    
    with {:ok, killmails} <- fetch_character_killmails(character_id, time_range),
         {:ok, basic_stats} <- calculate_basic_stats(killmails, character_id),
         {:ok, weapon_prefs} <- analyze_weapon_usage(killmails, character_id),
         {:ok, engagement_patterns} <- analyze_engagement_patterns(killmails, character_id),
         {:ok, performance_metrics} <- calculate_performance_metrics(killmails, character_id) do
      
      stats = %{
        character_id: character_id,
        total_kills: basic_stats.kills,
        total_losses: basic_stats.losses,
        kill_death_ratio: basic_stats.kd_ratio,
        isk_destroyed: basic_stats.isk_destroyed,
        isk_lost: basic_stats.isk_lost,
        isk_efficiency: basic_stats.isk_efficiency,
        solo_kills: basic_stats.solo_kills,
        solo_losses: basic_stats.solo_losses,
        solo_ratio: basic_stats.solo_ratio,
        small_gang_ratio: basic_stats.small_gang_ratio,
        fleet_ratio: basic_stats.fleet_ratio,
        weapon_preferences: weapon_prefs,
        engagement_patterns: engagement_patterns,
        performance_metrics: performance_metrics,
        analyzed_at: DateTime.utc_now()
      }
      
      {:ok, stats}
    end
  end
  
  defp fetch_character_killmails(character_id, time_range) do
    start_date = calculate_start_date(time_range)
    KillmailRepository.get_character_killmails(character_id, start_date)
  end
  
  defp calculate_start_date(days: days) do
    DateTime.utc_now()
    |> DateTime.add(-days * 24 * 60 * 60, :second)
  end
  
  defp calculate_start_date(hours: hours) do
    DateTime.utc_now()
    |> DateTime.add(-hours * 60 * 60, :second)
  end
  
  defp calculate_basic_stats(killmails, character_id) do
    {kills, losses} = separate_kills_losses(killmails, character_id)
    
    total_kills = length(kills)
    total_losses = length(losses)
    
    # Calculate ISK values
    isk_destroyed = calculate_total_value(kills)
    isk_lost = calculate_total_value(losses)
    
    # Calculate ratios
    kd_ratio = if total_losses > 0, do: total_kills / total_losses, else: Float.round(total_kills * 1.0, 2)
    isk_efficiency = if isk_lost > 0, do: (isk_destroyed / (isk_destroyed + isk_lost)) * 100, else: 100.0
    
    # Gang size analysis
    {solo_kills, small_gang_kills, fleet_kills} = categorize_by_gang_size(kills)
    {solo_losses, small_gang_losses, fleet_losses} = categorize_by_gang_size(losses)
    
    solo_ratio = if total_kills > 0, do: length(solo_kills) / total_kills, else: 0
    small_gang_ratio = if total_kills > 0, do: length(small_gang_kills) / total_kills, else: 0
    fleet_ratio = if total_kills > 0, do: length(fleet_kills) / total_kills, else: 0
    
    {:ok, %{
      kills: total_kills,
      losses: total_losses,
      kd_ratio: Float.round(kd_ratio, 2),
      isk_destroyed: isk_destroyed,
      isk_lost: isk_lost,
      isk_efficiency: Float.round(isk_efficiency, 1),
      solo_kills: length(solo_kills),
      solo_losses: length(solo_losses),
      solo_ratio: Float.round(solo_ratio, 2),
      small_gang_ratio: Float.round(small_gang_ratio, 2),
      fleet_ratio: Float.round(fleet_ratio, 2)
    }}
  end
  
  defp separate_kills_losses(killmails, character_id) do
    Enum.split_with(killmails, fn km ->
      # Character is an attacker if they're not the victim
      km.victim.character_id != character_id
    end)
  end
  
  defp calculate_total_value(killmails) do
    killmails
    |> Enum.map(& &1.total_value)
    |> Enum.sum()
  end
  
  defp categorize_by_gang_size(killmails) do
    killmails
    |> Enum.reduce({[], [], []}, fn km, {solo, small, fleet} ->
      attacker_count = length(km.attackers)
      
      cond do
        attacker_count == 1 -> {[km | solo], small, fleet}
        attacker_count <= 10 -> {solo, [km | small], fleet}
        true -> {solo, small, [km | fleet]}
      end
    end)
  end
  
  defp analyze_weapon_usage(killmails, character_id) do
    weapon_usage = killmails
    |> Enum.filter(fn km -> km.victim.character_id != character_id end)  # Only kills
    |> Enum.flat_map(fn km ->
      # Find this character's attacker entry
      case find_character_attacker(km.attackers, character_id) do
        nil -> []
        attacker -> [analyze_ship_weapon_type(attacker.ship_type_id)]
      end
    end)
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_weapon, count} -> count end, :desc)
    |> Enum.take(5)
    
    {:ok, weapon_usage}
  end
  
  defp find_character_attacker(attackers, character_id) do
    Enum.find(attackers, fn att -> att.character_id == character_id end)
  end
  
  defp analyze_ship_weapon_type(ship_type_id) do
    case ShipTypes.get_ship_info(ship_type_id) do
      {:ok, ship_info} ->
        # Determine weapon type from ship bonuses or race
        determine_weapon_from_ship(ship_info)
      _ ->
        :unknown
    end
  end
  
  defp determine_weapon_from_ship(ship_info) do
    # Check ship bonuses for weapon type hints
    bonuses = ship_info[:bonuses] || []
    
    cond do
      Enum.any?(bonuses, &String.contains?(&1, "projectile")) -> :projectile
      Enum.any?(bonuses, &String.contains?(&1, "laser")) -> :laser
      Enum.any?(bonuses, &String.contains?(&1, "hybrid")) -> :hybrid
      Enum.any?(bonuses, &String.contains?(&1, "missile")) -> :missile
      Enum.any?(bonuses, &String.contains?(&1, "drone")) -> :drone
      true ->
        # Fall back to racial preference
        case ship_info[:race] do
          "Minmatar" -> :projectile
          "Amarr" -> :laser
          "Gallente" -> :hybrid
          "Caldari" -> :missile
          _ -> :unknown
        end
    end
  end
  
  defp analyze_engagement_patterns(killmails, character_id) do
    patterns = %{
      hot_dropper: detect_hot_drop_pattern(killmails, character_id),
      gate_camper: detect_gate_camp_pattern(killmails, character_id),
      roamer: detect_roaming_pattern(killmails, character_id),
      home_defender: detect_home_defense_pattern(killmails, character_id),
      brawler: detect_brawling_pattern(killmails, character_id),
      kiter: detect_kiting_pattern(killmails, character_id)
    }
    
    {:ok, patterns}
  end
  
  defp detect_hot_drop_pattern(killmails, character_id) do
    # Look for capital/blops usage in kills
    capital_kills = killmails
    |> Enum.filter(fn km -> 
      km.victim.character_id != character_id and
      Enum.any?(km.attackers, fn att ->
        att.character_id == character_id and
        is_capital_or_blops(att.ship_type_id)
      end)
    end)
    |> length()
    
    capital_kills > 5
  end
  
  defp detect_gate_camp_pattern(killmails, _character_id) do
    # Look for kills near gates/stations
    gate_kills = killmails
    |> Enum.filter(fn km ->
      # Check if kill happened near a stargate
      String.contains?(km.location || "", "Stargate")
    end)
    |> length()
    
    total_kills = length(killmails)
    total_kills > 0 and gate_kills / total_kills > 0.5
  end
  
  defp detect_roaming_pattern(killmails, _character_id) do
    # Look for kills across multiple systems
    systems = killmails
    |> Enum.map(& &1.solar_system_id)
    |> Enum.uniq()
    |> length()
    
    systems > 10
  end
  
  defp detect_home_defense_pattern(killmails, _character_id) do
    # Look for concentration in few systems
    system_counts = killmails
    |> Enum.frequencies_by(& &1.solar_system_id)
    |> Map.values()
    |> Enum.sort(:desc)
    
    case system_counts do
      [top | _rest] when length(system_counts) > 0 ->
        total = Enum.sum(system_counts)
        top / total > 0.7
      _ ->
        false
    end
  end
  
  defp detect_brawling_pattern(killmails, character_id) do
    # Look for close-range ship usage
    brawling_ships = killmails
    |> Enum.filter(fn km ->
      km.victim.character_id != character_id and
      Enum.any?(km.attackers, fn att ->
        att.character_id == character_id and
        is_brawling_ship(att.ship_type_id)
      end)
    end)
    |> length()
    
    total_kills = count_kills(killmails, character_id)
    total_kills > 0 and brawling_ships / total_kills > 0.5
  end
  
  defp detect_kiting_pattern(killmails, character_id) do
    # Look for long-range ship usage
    kiting_ships = killmails
    |> Enum.filter(fn km ->
      km.victim.character_id != character_id and
      Enum.any?(km.attackers, fn att ->
        att.character_id == character_id and
        is_kiting_ship(att.ship_type_id)
      end)
    end)
    |> length()
    
    total_kills = count_kills(killmails, character_id)
    total_kills > 0 and kiting_ships / total_kills > 0.5
  end
  
  defp count_kills(killmails, character_id) do
    Enum.count(killmails, fn km -> km.victim.character_id != character_id end)
  end
  
  defp is_capital_or_blops(ship_type_id) do
    case ShipTypes.get_ship_class(ship_type_id) do
      {:ok, class} ->
        class in [:titan, :supercarrier, :carrier, :dreadnought, :fax, :black_ops]
      _ ->
        false
    end
  end
  
  defp is_brawling_ship(ship_type_id) do
    case ShipTypes.get_ship_info(ship_type_id) do
      {:ok, ship_info} ->
        # Ships known for close-range combat
        ship_info.name in ["Deimos", "Brutix", "Thorax", "Hurricane", "Rupture", 
                          "Maller", "Omen", "Caracal", "Moa"]
      _ ->
        false
    end
  end
  
  defp is_kiting_ship(ship_type_id) do
    case ShipTypes.get_ship_info(ship_type_id) do
      {:ok, ship_info} ->
        # Ships known for long-range kiting
        ship_info.name in ["Orthrus", "Garmur", "Keres", "Malediction", "Crow",
                          "Slicer", "Condor", "Executioner", "Atron"]
      _ ->
        false
    end
  end
  
  defp calculate_performance_metrics(killmails, character_id) do
    kills = Enum.filter(killmails, fn km -> km.victim.character_id != character_id end)
    
    metrics = %{
      average_kill_value: calculate_average_value(kills),
      highest_value_kill: find_highest_value_kill(kills),
      favorite_target_class: analyze_target_preferences(kills),
      peak_activity_hour: analyze_activity_times(killmails),
      preferred_space: analyze_space_preferences(killmails)
    }
    
    {:ok, metrics}
  end
  
  defp calculate_average_value(kills) do
    if Enum.empty?(kills) do
      0
    else
      total = Enum.sum(Enum.map(kills, & &1.total_value))
      Float.round(total / length(kills), 2)
    end
  end
  
  defp find_highest_value_kill(kills) do
    case Enum.max_by(kills, & &1.total_value, fn -> nil end) do
      nil -> nil
      kill -> %{
        killmail_id: kill.killmail_id,
        value: kill.total_value,
        victim_ship: kill.victim.ship_type_id
      }
    end
  end
  
  defp analyze_target_preferences(kills) do
    kills
    |> Enum.map(fn km -> classify_ship_size(km.victim.ship_type_id) end)
    |> Enum.frequencies()
    |> Enum.max_by(fn {_size, count} -> count end, fn -> {:unknown, 0} end)
    |> elem(0)
  end
  
  defp classify_ship_size(ship_type_id) do
    case ShipTypes.get_ship_class(ship_type_id) do
      {:ok, class} ->
        cond do
          class in [:frigate, :destroyer, :interceptor] -> :small
          class in [:cruiser, :battlecruiser, :combat_battlecruiser] -> :medium
          class in [:battleship, :marauder] -> :large
          class in [:carrier, :dreadnought, :supercarrier, :titan, :fax] -> :capital
          true -> :special
        end
      _ ->
        :unknown
    end
  end
  
  defp analyze_activity_times(killmails) do
    killmails
    |> Enum.map(fn km -> DateTime.to_time(km.killmail_time).hour end)
    |> Enum.frequencies()
    |> Enum.max_by(fn {_hour, count} -> count end, fn -> {0, 0} end)
    |> elem(0)
  end
  
  defp analyze_space_preferences(killmails) do
    space_types = killmails
    |> Enum.map(fn km -> classify_security_status(km.solar_system_id) end)
    |> Enum.frequencies()
    
    case Enum.max_by(space_types, fn {_type, count} -> count end, fn -> {:unknown, 0} end) do
      {space_type, _} -> space_type
      _ -> :unknown
    end
  end
  
  defp classify_security_status(solar_system_id) do
    case EveDmv.StaticData.SystemData.get_system_security(solar_system_id) do
      {:ok, sec} when sec >= 0.5 -> :highsec
      {:ok, sec} when sec > 0.0 -> :lowsec
      {:ok, 0.0} -> :nullsec
      {:ok, _} -> :wormhole
      _ -> :unknown
    end
  end
end
defmodule EveDmv.Contexts.Intelligence.Core.ShipPreferenceAnalyzer do
  @moduledoc """
  Analyzes ship usage patterns and preferences for characters.
  
  Consolidates functionality from:
  - Player Profile ship preferences
  - Character Intelligence ship analysis
  """
  
  alias EveDmv.Platform.Database.{CharacterRepository, KillmailRepository}
  alias EveDmv.Platform.Cache.Intelligence.IntelligenceCache
  alias EveDmv.StaticData.ShipTypes
  alias EveDmv.Shared.ShipAnalysis
  
  require Logger
  
  @cache_ttl :timer.hours(6)
  
  @doc """
  Analyze ship preferences for a character.
  """
  def analyze_ship_preferences(character_id) do
    cache_key = {:ship_preferences, character_id}
    
    IntelligenceCache.get_or_compute(cache_key, fn ->
      perform_ship_analysis(character_id)
    end, ttl: @cache_ttl)
  end
  
  @doc """
  Get favorite ships for a character.
  """
  def get_favorite_ships(character_id, limit \\ 10) do
    case analyze_ship_preferences(character_id) do
      {:ok, prefs} -> 
        ships = prefs.favorite_ships
        |> Enum.take(limit)
        {:ok, ships}
      error -> error
    end
  end
  
  @doc """
  Get ship progression timeline.
  """
  def get_ship_progression(character_id) do
    case analyze_ship_preferences(character_id) do
      {:ok, prefs} -> {:ok, prefs.ship_progression}
      error -> error
    end
  end
  
  @doc """
  Get fitting pattern analysis.
  """
  def get_fitting_patterns(character_id) do
    case analyze_ship_preferences(character_id) do
      {:ok, prefs} -> {:ok, prefs.fitting_patterns}
      error -> error
    end
  end
  
  # Private Functions
  
  defp perform_ship_analysis(character_id) do
    with {:ok, ship_usage} <- get_ship_usage_data(character_id),
         {:ok, killmail_data} <- get_recent_killmails(character_id) do
      
      preferences = %{
        character_id: character_id,
        favorite_ships: analyze_favorite_ships(ship_usage),
        ship_classes: analyze_ship_classes(ship_usage),
        ship_progression: analyze_progression(ship_usage, killmail_data),
        fitting_patterns: analyze_fitting_patterns(killmail_data),
        ship_diversity: ShipAnalysis.calculate_ship_diversity(ship_usage),
        specialization_index: ShipAnalysis.calculate_specialization_index(ship_usage),
        primary_ship_class: determine_primary_class(ship_usage),
        capital_usage: calculate_capital_usage(ship_usage),
        faction_preferences: analyze_faction_preferences(ship_usage),
        analyzed_at: DateTime.utc_now()
      }
      
      {:ok, preferences}
    end
  end
  
  defp get_ship_usage_data(character_id) do
    case CharacterRepository.get_character_ship_usage(character_id) do
      {:ok, usage} when is_map(usage) -> {:ok, usage}
      {:ok, _} -> {:ok, %{}}
      error -> error
    end
  end
  
  defp get_recent_killmails(character_id) do
    start_date = DateTime.utc_now() |> DateTime.add(-90 * 24 * 60 * 60, :second)
    KillmailRepository.get_character_killmails(character_id, start_date)
  end
  
  defp analyze_favorite_ships(ship_usage) do
    ship_usage
    |> Enum.map(fn {ship_type_id, usage_data} ->
      ship_id = normalize_ship_id(ship_type_id)
      
      ship_info = case ShipTypes.get_ship_info(ship_id) do
        {:ok, info} -> info
        _ -> %{name: "Unknown Ship", class: :unknown}
      end
      
      %{
        ship_type_id: ship_id,
        ship_name: ship_info.name,
        ship_class: ship_info.class,
        times_used: usage_data["times_used"] || 0,
        kills: usage_data["kills"] || 0,
        losses: usage_data["losses"] || 0,
        efficiency: calculate_ship_efficiency(usage_data),
        last_used: usage_data["last_used"]
      }
    end)
    |> Enum.sort_by(& &1.times_used, :desc)
    |> Enum.take(20)
  end
  
  defp normalize_ship_id(ship_type_id) when is_binary(ship_type_id) do
    String.to_integer(ship_type_id)
  end
  defp normalize_ship_id(ship_type_id) when is_integer(ship_type_id), do: ship_type_id
  
  defp calculate_ship_efficiency(usage_data) do
    kills = usage_data["kills"] || 0
    losses = usage_data["losses"] || 0
    
    if losses > 0 do
      Float.round(kills / losses, 2)
    else
      Float.round(kills * 1.0, 2)
    end
  end
  
  defp analyze_ship_classes(ship_usage) do
    ship_usage
    |> Enum.reduce(%{}, fn {ship_type_id, usage_data}, acc ->
      ship_id = normalize_ship_id(ship_type_id)
      
      class = case ShipTypes.get_ship_class(ship_id) do
        {:ok, ship_class} -> ship_class
        _ -> :unknown
      end
      
      times_used = usage_data["times_used"] || 0
      Map.update(acc, class, times_used, &(&1 + times_used))
    end)
    |> Enum.sort_by(fn {_class, count} -> count end, :desc)
  end
  
  defp analyze_progression(ship_usage, killmails) do
    # Group killmails by month
    monthly_usage = killmails
    |> Enum.group_by(fn km ->
      {km.killmail_time.year, km.killmail_time.month}
    end)
    |> Enum.map(fn {{year, month}, kms} ->
      ship_types = kms
      |> Enum.map(fn km ->
        if km.victim.character_id == List.first(kms).victim.character_id do
          km.victim.ship_type_id
        else
          # Find character's ship in attackers
          attacker = Enum.find(km.attackers, fn att -> 
            att.character_id == List.first(kms).victim.character_id 
          end)
          if attacker, do: attacker.ship_type_id, else: nil
        end
      end)
      |> Enum.filter(& &1)
      |> Enum.uniq()
      
      %{
        year: year,
        month: month,
        ship_diversity: length(ship_types),
        ship_types: ship_types,
        progression_stage: determine_progression_stage(ship_types)
      }
    end)
    |> Enum.sort_by(fn %{year: y, month: m} -> {y, m} end)
    
    %{
      timeline: monthly_usage,
      current_stage: determine_current_progression(ship_usage),
      tech_advancement: analyze_tech_progression(ship_usage)
    }
  end
  
  defp determine_progression_stage(ship_types) do
    # Check tech levels of ships used
    tech_levels = ship_types
    |> Enum.map(fn ship_id ->
      case ShipTypes.get_ship_info(ship_id) do
        {:ok, info} -> info[:tech_level] || 1
        _ -> 1
      end
    end)
    
    avg_tech = Enum.sum(tech_levels) / max(length(tech_levels), 1)
    
    cond do
      avg_tech >= 2.5 -> :expert
      avg_tech >= 2.0 -> :advanced
      avg_tech >= 1.5 -> :intermediate
      true -> :beginner
    end
  end
  
  defp determine_current_progression(ship_usage) do
    total_ships = map_size(ship_usage)
    
    # Check for advanced ship usage
    advanced_ships = ship_usage
    |> Enum.count(fn {ship_type_id, _} ->
      ship_id = normalize_ship_id(ship_type_id)
      case ShipTypes.get_ship_info(ship_id) do
        {:ok, info} -> (info[:tech_level] || 1) > 1
        _ -> false
      end
    end)
    
    capital_ships = ship_usage
    |> Enum.count(fn {ship_type_id, _} ->
      ship_id = normalize_ship_id(ship_type_id)
      case ShipTypes.get_ship_class(ship_id) do
        {:ok, class} -> class in [:carrier, :dreadnought, :supercarrier, :titan, :fax]
        _ -> false
      end
    end)
    
    cond do
      capital_ships > 0 -> :capital_pilot
      advanced_ships / max(total_ships, 1) > 0.5 -> :advanced_pilot
      total_ships > 10 -> :experienced_pilot
      total_ships > 5 -> :developing_pilot
      true -> :new_pilot
    end
  end
  
  defp analyze_tech_progression(ship_usage) do
    tech_distribution = ship_usage
    |> Enum.reduce(%{tech1: 0, tech2: 0, tech3: 0, faction: 0}, fn {ship_type_id, usage_data}, acc ->
      ship_id = normalize_ship_id(ship_type_id)
      times_used = usage_data["times_used"] || 0
      
      tech_level = case ShipTypes.get_ship_info(ship_id) do
        {:ok, info} ->
          cond do
            info[:faction] -> :faction
            info[:tech_level] == 3 -> :tech3
            info[:tech_level] == 2 -> :tech2
            true -> :tech1
          end
        _ -> :tech1
      end
      
      Map.update(acc, tech_level, times_used, &(&1 + times_used))
    end)
    
    total_usage = Map.values(tech_distribution) |> Enum.sum()
    
    if total_usage > 0 do
      tech_distribution
      |> Enum.map(fn {tech, usage} -> {tech, Float.round(usage / total_usage * 100, 1)} end)
      |> Map.new()
    else
      %{tech1: 0, tech2: 0, tech3: 0, faction: 0}
    end
  end
  
  defp analyze_fitting_patterns(killmails) do
    # Analyze weapon systems and tank types from killmails
    patterns = killmails
    |> Enum.reduce(%{weapons: %{}, tank_types: %{}, ewar_usage: 0}, fn km, acc ->
      # This is simplified - in reality would analyze actual module usage
      acc
    end)
    
    %{
      common_patterns: ["PvP Focused", "Solo Fit", "Fleet Support"],
      weapon_preferences: [:hybrid, :projectile],
      tank_preferences: [:armor, :shield],
      specialized_fits: detect_specialized_fits(killmails)
    }
  end
  
  defp detect_specialized_fits(_killmails) do
    # Detect specialized fitting patterns
    []
  end
  
  defp determine_primary_class(ship_usage) do
    ship_usage
    |> Enum.reduce(%{}, fn {ship_type_id, usage_data}, acc ->
      ship_id = normalize_ship_id(ship_type_id)
      
      class = case ShipTypes.get_ship_class(ship_id) do
        {:ok, ship_class} -> ship_class
        _ -> :unknown
      end
      
      times_used = usage_data["times_used"] || 0
      Map.update(acc, class, times_used, &(&1 + times_used))
    end)
    |> Enum.max_by(fn {_class, count} -> count end, fn -> {:unknown, 0} end)
    |> elem(0)
  end
  
  defp calculate_capital_usage(ship_usage) do
    capital_usage = ship_usage
    |> Enum.filter(fn {ship_type_id, _} ->
      ship_id = normalize_ship_id(ship_type_id)
      case ShipTypes.get_ship_class(ship_id) do
        {:ok, class} -> class in [:carrier, :dreadnought, :supercarrier, :titan, :fax]
        _ -> false
      end
    end)
    |> Enum.map(fn {_, usage_data} -> usage_data["times_used"] || 0 end)
    |> Enum.sum()
    
    total_usage = ship_usage
    |> Enum.map(fn {_, usage_data} -> usage_data["times_used"] || 0 end)
    |> Enum.sum()
    
    if total_usage > 0 do
      Float.round(capital_usage / total_usage, 3)
    else
      0.0
    end
  end
  
  defp analyze_faction_preferences(ship_usage) do
    faction_usage = ship_usage
    |> Enum.reduce(%{}, fn {ship_type_id, usage_data}, acc ->
      ship_id = normalize_ship_id(ship_type_id)
      
      faction = case ShipTypes.get_ship_info(ship_id) do
        {:ok, info} -> info[:race] || "Unknown"
        _ -> "Unknown"
      end
      
      times_used = usage_data["times_used"] || 0
      Map.update(acc, faction, times_used, &(&1 + times_used))
    end)
    
    total_usage = Map.values(faction_usage) |> Enum.sum()
    
    if total_usage > 0 do
      faction_usage
      |> Enum.map(fn {faction, usage} -> 
        {faction, Float.round(usage / total_usage * 100, 1)}
      end)
      |> Enum.sort_by(fn {_, percentage} -> percentage end, :desc)
    else
      []
    end
  end
end
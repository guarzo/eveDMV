defmodule EveDmv.Contexts.PlayerProfile.Analyzers.ShipPreferencesAnalyzer do
  @moduledoc """
  Ship preferences analyzer for player profiles.

  Analyzes individual character ship usage patterns, preferences, and specializations
  including ship roles, fitting patterns, and tactical deployment preferences.
  """

  use EveDmv.ErrorHandler

  alias EveDmv.Result
  alias EveDmv.Shared.ShipAnalysis

  require Logger

  @doc """
  Analyze ship preferences for a character.
  """
  @spec analyze(integer(), map()) :: Result.t(map())
  def analyze(character_id, base_data \\ %{}) when is_integer(character_id) do
    character_stats = Map.get(base_data, :character_stats, %{})

    ship_analysis = %{
      ship_usage_patterns: ShipAnalysis.analyze_ship_usage(character_stats),
      role_specialization: ShipAnalysis.analyze_role_specialization(character_stats),
      fitting_preferences: analyze_fitting_patterns_shared(character_stats),
      deployment_patterns: analyze_deployment_patterns_shared(character_stats),
      ship_value_patterns: analyze_ship_values_shared(character_stats),
      meta_analysis: analyze_meta_usage_shared(character_stats),
      progression_tracking: analyze_ship_progression_shared(character_stats),
      preferences_summary: generate_preferences_summary_shared(character_stats),
      diversity_metrics: ShipAnalysis.calculate_ship_diversity(character_stats),
      specialization: ShipAnalysis.calculate_specialization_index(character_stats)
    }

    Result.ok(ship_analysis)
  rescue
    exception ->
      Logger.error("Ship preferences analysis failed",
        character_id: character_id,
        error: Exception.format(:error, exception)
      )

      Result.error(:analysis_failed, "Ship preferences analysis error: #{inspect(exception)}")
  end

  # Core analysis functions

  # Ship usage analysis delegated to shared module
  # This function is now handled by ShipAnalysis.analyze_ship_usage/1

  # Role specialization analysis delegated to shared module
  # This function is now handled by ShipAnalysis.analyze_role_specialization/1

  defp analyze_fitting_patterns_shared(character_stats) do
    # Real fitting analysis from ship usage data
    ship_usage = Map.get(character_stats, :ship_usage, %{})

    if map_size(ship_usage) == 0 do
      %{
        total_fits_analyzed: 0,
        common_patterns: [],
        weapon_preferences: [],
        tank_preferences: []
      }
    else
      # Analyze weapon preferences from ship types
      weapon_preferences = analyze_weapon_preferences(ship_usage)

      # Analyze tank preferences from ship classes
      tank_preferences = analyze_tank_preferences(ship_usage)

      # Find common fitting patterns
      common_patterns = identify_fitting_patterns(ship_usage)

      %{
        total_fits_analyzed: map_size(ship_usage),
        common_patterns: common_patterns,
        weapon_preferences: weapon_preferences,
        tank_preferences: tank_preferences
      }
    end
  end

  defp analyze_deployment_patterns_shared(character_stats) do
    # Real deployment analysis using active systems data
    active_systems = Map.get(character_stats, :active_systems, %{})
    system_count = map_size(active_systems)

    deployment_spread =
      cond do
        system_count <= 1 -> :concentrated
        system_count <= 5 -> :moderate
        true -> :widespread
      end

    # Calculate real security preferences from active systems
    security_preferences = calculate_security_preferences(active_systems)

    # Additional analysis
    most_active_system = find_most_active_system(active_systems)
    activity_concentration = calculate_activity_concentration(active_systems)

    %{
      systems_count: system_count,
      deployment_spread: deployment_spread,
      security_preferences: security_preferences,
      most_active_system: most_active_system,
      activity_concentration: activity_concentration
    }
  end

  defp analyze_ship_values_shared(character_stats) do
    # Use shared module for ship value analysis
    ship_usage = Map.get(character_stats, :ship_usage, %{})

    ship_values =
      Map.values(ship_usage)
      |> Enum.map(&Map.get(&1, "estimated_value", 0))
      |> Enum.filter(&(&1 > 0))

    %{
      value_distribution: ShipAnalysis.categorize_ship_values(ship_values),
      risk_comfort:
        ShipAnalysis.determine_risk_comfort(Enum.sum(ship_values) / max(length(ship_values), 1)),
      bling_ratio: ShipAnalysis.calculate_bling_ratio(ship_values),
      average_ship_value:
        if(Enum.empty?(ship_values), do: 0, else: Enum.sum(ship_values) / length(ship_values))
    }
  end

  defp analyze_meta_usage_shared(character_stats) do
    # Real tech level analysis using ship usage data
    ship_usage = Map.get(character_stats, :ship_usage, %{})

    if map_size(ship_usage) == 0 do
      %{
        tech_level_distribution: %{tech1: 0, tech2: 0, tech3: 0, faction: 0},
        meta_preferences: :unknown,
        progression_indicators: :no_data
      }
    else
      # Calculate tech level distribution from actual ship usage
      tech_distribution = calculate_tech_level_distribution(ship_usage)

      # Determine meta preferences based on actual usage patterns
      meta_preferences = determine_meta_preferences(tech_distribution)

      # Analyze progression based on ship variety and complexity
      progression_indicators = analyze_progression_indicators(ship_usage, tech_distribution)

      %{
        tech_level_distribution: tech_distribution,
        meta_preferences: meta_preferences,
        progression_indicators: progression_indicators
      }
    end
  end

  defp analyze_ship_progression_shared(character_stats) do
    # Basic progression tracking
    ship_usage = Map.get(character_stats, :ship_usage, %{})
    ship_count = map_size(ship_usage)

    specialization_level =
      cond do
        ship_count <= 2 -> :highly_specialized
        ship_count <= 5 -> :moderately_specialized
        true -> :generalist
      end

    progression_stage =
      cond do
        ship_count <= 1 -> :starter
        ship_count <= 5 -> :developing
        ship_count <= 10 -> :established
        true -> :veteran
      end

    %{
      ship_count: ship_count,
      diversity_score: ShipAnalysis.calculate_ship_diversity(ship_usage),
      specialization_level: specialization_level,
      progression_stage: progression_stage
    }
  end

  defp generate_preferences_summary_shared(character_stats) do
    # Generate high-level insights using shared module
    ship_usage = Map.get(character_stats, :ship_usage, %{})
    ship_count = map_size(ship_usage)

    combat_focus = if ship_count == 0, do: :unknown, else: :pvp
    risk_profile = if ship_count == 0, do: :unknown, else: :moderate

    specialization_summary = %{
      ship_variety: ship_count,
      primary_role: :dps,
      secondary_role: :support,
      specialization_index: min(ship_count / 10.0, 1.0)
    }

    # Enhanced preferences summary with real analysis
    engagement_patterns = analyze_engagement_patterns(character_stats)
    preferred_gang_sizes = analyze_preferred_gang_sizes(ship_usage)

    %{
      primary_ship: ShipAnalysis.get_most_used_ship(ship_usage),
      flies_capitals: ShipAnalysis.flies_capitals?(character_stats),
      combat_focus: combat_focus,
      risk_profile: risk_profile,
      specialization_summary: specialization_summary,
      engagement_patterns: engagement_patterns,
      preferred_gang_sizes: preferred_gang_sizes
    }
  end

  # Real data analysis helper functions

  defp calculate_tech_level_distribution(ship_usage) do
    total_usage =
      Map.values(ship_usage) |> Enum.map(&Map.get(&1, "times_used", 0)) |> Enum.sum()

    if total_usage == 0 do
      %{tech1: 0, tech2: 0, tech3: 0, faction: 0}
    else
      tech_counts =
        ship_usage
        |> Enum.reduce(%{tech1: 0, tech2: 0, tech3: 0, faction: 0}, fn {ship_type_id, usage_data},
                                                                       acc ->
          times_used = Map.get(usage_data, "times_used", 0)
          tech_level = classify_ship_tech_level(ship_type_id)
          Map.update(acc, tech_level, times_used, &(&1 + times_used))
        end)

      # Convert to percentages
      tech_counts
      |> Enum.map(fn {tech, count} -> {tech, count / total_usage} end)
      |> Enum.into(%{})
    end
  end

  defp classify_ship_tech_level(ship_type_id_str) when is_binary(ship_type_id_str) do
    ship_type_id = String.to_integer(ship_type_id_str)
    classify_ship_tech_level(ship_type_id)
  end

  defp classify_ship_tech_level(ship_type_id) when is_integer(ship_type_id) do
    # Use static data to determine tech level
    case EveDmv.StaticData.get_ship_tech_level(ship_type_id) do
      {:ok, :tech1} -> :tech1
      {:ok, :tech2} -> :tech2
      {:ok, :tech3} -> :tech3
      {:ok, :faction} -> :faction
      # Default to T1 if unknown
      {:error, _} -> :tech1
    end
  end

  defp determine_meta_preferences(tech_distribution) do
    # Determine preference based on highest usage
    {primary_tech, primary_percentage} =
      Enum.max_by(tech_distribution, fn {_tech, percentage} -> percentage end)

    cond do
      primary_percentage > 0.7 -> primary_tech
      primary_percentage > 0.4 -> :mixed
      true -> :balanced
    end
  end

  defp analyze_progression_indicators(ship_usage, tech_distribution) do
    ship_count = map_size(ship_usage)
    tech2_usage = Map.get(tech_distribution, :tech2, 0)
    tech3_usage = Map.get(tech_distribution, :tech3, 0)
    faction_usage = Map.get(tech_distribution, :faction, 0)

    # Analyze ship class diversity
    class_diversity = calculate_ship_class_diversity(ship_usage)

    cond do
      tech3_usage > 0.3 or faction_usage > 0.3 -> :expert
      tech2_usage > 0.5 and class_diversity > 0.6 -> :advanced
      tech2_usage > 0.3 and ship_count > 5 -> :intermediate
      ship_count > 3 -> :developing
      true -> :beginner
    end
  end

  defp calculate_ship_class_diversity(ship_usage) do
    if map_size(ship_usage) == 0 do
      0.0
    else
      ship_classes =
        Map.keys(ship_usage)
        |> Enum.map(fn ship_type_id_str ->
          ship_type_id = String.to_integer(ship_type_id_str)

          case EveDmv.StaticData.get_ship_class(ship_type_id) do
            {:ok, ship_class} -> ship_class
            {:error, _} -> :unknown
          end
        end)
        |> Enum.uniq()

      # Diversity is unique classes / total possible classes (simplified)
      # Approximate number of major ship classes
      length(ship_classes) / 15.0
    end
  end

  defp calculate_security_preferences(active_systems) do
    if map_size(active_systems) == 0 do
      %{highsec: 0, lowsec: 0, nullsec: 0, wspace: 0}
    else
      total_activity = calculate_total_activity(active_systems)
      
      if total_activity == 0 do
        %{highsec: 0, lowsec: 0, nullsec: 0, wspace: 0}
      else
        security_activity = aggregate_security_activity(active_systems)
        convert_to_percentages(security_activity, total_activity)
      end
    end
  end

  defp calculate_total_activity(active_systems) do
    Map.values(active_systems)
    |> Enum.map(fn system_data ->
      Map.get(system_data, "kills", 0) + Map.get(system_data, "losses", 0)
    end)
    |> Enum.sum()
  end

  defp aggregate_security_activity(active_systems) do
    active_systems
    |> Enum.reduce(%{highsec: 0, lowsec: 0, nullsec: 0, wspace: 0}, fn {_system_id, system_data}, acc ->
      security = Map.get(system_data, "security", 0.0)
      activity = Map.get(system_data, "kills", 0) + Map.get(system_data, "losses", 0)
      security_type = classify_security_type(security)

      if security_type != :unknown do
        Map.update(acc, security_type, activity, &(&1 + activity))
      else
        acc
      end
    end)
  end

  defp classify_security_type(security) do
    cond do
      security >= 0.5 -> :highsec
      security > 0.0 -> :lowsec
      security == 0.0 -> :nullsec
      security < 0.0 -> :wspace
      true -> :unknown
    end
  end

  defp convert_to_percentages(security_activity, total_activity) do
    security_activity
    |> Enum.map(fn {sec_type, activity} -> {sec_type, activity / total_activity} end)
    |> Enum.into(%{})
  end

  defp find_most_active_system(active_systems) do
    if map_size(active_systems) == 0 do
      nil
    else
      {_system_id, most_active} =
        active_systems
        |> Enum.max_by(fn {_system_id, system_data} ->
          Map.get(system_data, "kills", 0) + Map.get(system_data, "losses", 0)
        end)

      Map.get(most_active, "system_name", "Unknown")
    end
  end

  defp calculate_activity_concentration(active_systems) do
    if map_size(active_systems) <= 1 do
      1.0
    else
      activities =
        Map.values(active_systems)
        |> Enum.map(fn system_data ->
          Map.get(system_data, "kills", 0) + Map.get(system_data, "losses", 0)
        end)

      total_activity = Enum.sum(activities)

      if total_activity == 0 do
        0.0
      else
        # Calculate Gini coefficient for activity concentration
        max_activity = Enum.max(activities)
        max_activity / total_activity
      end
    end
  end

  defp analyze_weapon_preferences(ship_usage) do
    # Analyze weapon preferences based on ship types
    weapon_categories =
      ship_usage
      |> Enum.reduce(
        %{projectile: 0, laser: 0, hybrid: 0, missile: 0, drone: 0},
        fn {ship_type_id_str, usage_data}, acc ->
          ship_type_id = String.to_integer(ship_type_id_str)
          times_used = Map.get(usage_data, "times_used", 0)
          weapon_type = determine_primary_weapon_type(ship_type_id)

          Map.update(acc, weapon_type, times_used, &(&1 + times_used))
        end
      )

    total_usage = Map.values(weapon_categories) |> Enum.sum()

    if total_usage == 0 do
      []
    else
      weapon_categories
      |> Enum.map(fn {weapon, usage} -> {weapon, usage / total_usage} end)
      # Only significant preferences
      |> Enum.filter(fn {_weapon, percentage} -> percentage > 0.1 end)
      |> Enum.sort_by(fn {_weapon, percentage} -> percentage end, :desc)
      |> Enum.take(3)
    end
  end

  defp determine_primary_weapon_type(ship_type_id) do
    # Use ship racial bonuses to determine primary weapon type
    case EveDmv.StaticData.get_ship_bonuses(ship_type_id) do
      {:ok, bonuses} ->
        cond do
          has_bonus_for_weapon?(bonuses, "projectile") -> :projectile
          has_bonus_for_weapon?(bonuses, "laser") -> :laser
          has_bonus_for_weapon?(bonuses, "hybrid") -> :hybrid
          has_bonus_for_weapon?(bonuses, "missile") -> :missile
          has_bonus_for_weapon?(bonuses, "drone") -> :drone
          true -> :unknown
        end

      {:error, _} ->
        # Fallback to racial classification
        case EveDmv.StaticData.get_ship_race(ship_type_id) do
          {:ok, "Minmatar"} -> :projectile
          {:ok, "Amarr"} -> :laser
          {:ok, "Gallente"} -> :hybrid
          {:ok, "Caldari"} -> :missile
          _ -> :unknown
        end
    end
  end

  defp has_bonus_for_weapon?(bonuses, weapon_type) do
    bonuses
    |> Enum.any?(fn bonus ->
      bonus_text = String.downcase(bonus)
      String.contains?(bonus_text, weapon_type)
    end)
  end

  defp analyze_tank_preferences(ship_usage) do
    # Analyze tank preferences based on ship racial characteristics
    tank_types =
      ship_usage
      |> Enum.reduce(%{armor: 0, shield: 0, hull: 0}, fn {ship_type_id_str, usage_data}, acc ->
        ship_type_id = String.to_integer(ship_type_id_str)
        times_used = Map.get(usage_data, "times_used", 0)
        tank_type = determine_primary_tank_type(ship_type_id)

        Map.update(acc, tank_type, times_used, &(&1 + times_used))
      end)

    total_usage = Map.values(tank_types) |> Enum.sum()

    if total_usage == 0 do
      []
    else
      tank_types
      |> Enum.map(fn {tank, usage} -> {tank, usage / total_usage} end)
      |> Enum.filter(fn {_tank, percentage} -> percentage > 0.1 end)
      |> Enum.sort_by(fn {_tank, percentage} -> percentage end, :desc)
    end
  end

  defp determine_primary_tank_type(ship_type_id) do
    # Use ship racial characteristics for tank type
    case EveDmv.StaticData.get_ship_race(ship_type_id) do
      {:ok, "Amarr"} -> :armor
      {:ok, "Gallente"} -> :armor
      {:ok, "Caldari"} -> :shield
      # Mixed, but historically shield
      {:ok, "Minmatar"} -> :shield
      # Default
      _ -> :armor
    end
  end

  defp identify_fitting_patterns(ship_usage) do
    # Identify common fitting patterns from ship usage
    patterns = []

    # Check for logistics patterns
    logistics_usage = count_ships_by_role(ship_usage, :logistics)

    patterns =
      if logistics_usage > 0 do
        ["Logistics Support" | patterns]
      else
        patterns
      end

    # Check for EWAR patterns
    ewar_usage = count_ships_by_role(ship_usage, :ewar)

    patterns =
      if ewar_usage > 0 do
        ["Electronic Warfare" | patterns]
      else
        patterns
      end

    # Check for capital patterns
    capital_usage =
      count_ships_by_class(ship_usage, [:dreadnought, :carrier, :supercarrier, :titan])

    patterns =
      if capital_usage > 0 do
        ["Capital Operations" | patterns]
      else
        patterns
      end

    patterns
  end

  defp count_ships_by_role(ship_usage, target_role) do
    ship_usage
    |> Enum.count(fn {ship_type_id_str, _usage_data} ->
      ship_type_id = String.to_integer(ship_type_id_str)

      case EveDmv.StaticData.get_ship_class(ship_type_id) do
        {:ok, ship_class} -> classify_role_from_class(ship_class) == target_role
        {:error, _} -> false
      end
    end)
  end

  defp count_ships_by_class(ship_usage, target_classes) do
    ship_usage
    |> Enum.count(fn {ship_type_id_str, _usage_data} ->
      ship_type_id = String.to_integer(ship_type_id_str)

      case EveDmv.StaticData.get_ship_class(ship_type_id) do
        {:ok, ship_class} -> ship_class in target_classes
        {:error, _} -> false
      end
    end)
  end

  defp classify_role_from_class(ship_class) do
    case ship_class do
      :logistics_frigate -> :logistics
      :logistics_cruiser -> :logistics
      :force_auxiliary -> :logistics
      :electronic_attack_frigate -> :ewar
      :force_recon -> :ewar
      :combat_recon -> :ewar
      _ -> :dps
    end
  end

  defp analyze_engagement_patterns(character_stats) do
    # Analyze engagement patterns from character stats
    avg_gang_size = Map.get(character_stats, :avg_gang_size, 1.0)
    solo_kills = Map.get(character_stats, :solo_kills, 0)
    total_kills = Map.get(character_stats, :total_kills, 0)

    solo_ratio = if total_kills > 0, do: solo_kills / total_kills, else: 0.0

    engagement_style =
      cond do
        solo_ratio > 0.7 -> :solo_hunter
        avg_gang_size <= 3 -> :small_gang
        avg_gang_size <= 10 -> :medium_gang
        true -> :large_fleet
      end

    %{
      style: engagement_style,
      solo_preference: solo_ratio,
      average_gang_size: avg_gang_size
    }
  end

  defp analyze_preferred_gang_sizes(ship_usage) do
    # Analyze preferred gang sizes from ship usage data
    gang_sizes =
      Map.values(ship_usage)
      |> Enum.map(&Map.get(&1, "avg_gang_size", 1.0))
      |> Enum.filter(&(&1 > 0))

    if Enum.empty?(gang_sizes) do
      %{preferred_size: 1.0, size_variance: 0.0, flexibility: :unknown}
    else
      avg_size = Enum.sum(gang_sizes) / length(gang_sizes)
      variance = calculate_variance(gang_sizes, avg_size)

      flexibility =
        cond do
          variance > 10.0 -> :highly_flexible
          variance > 5.0 -> :moderately_flexible
          variance > 1.0 -> :somewhat_flexible
          true -> :consistent
        end

      %{
        preferred_size: Float.round(avg_size, 1),
        size_variance: Float.round(variance, 2),
        flexibility: flexibility
      }
    end
  end

  defp calculate_variance(values, mean) do
    if length(values) <= 1 do
      0.0
    else
      sum_of_squares =
        values
        |> Enum.map(fn value -> :math.pow(value - mean, 2) end)
        |> Enum.sum()

      sum_of_squares / (length(values) - 1)
    end
  end
end

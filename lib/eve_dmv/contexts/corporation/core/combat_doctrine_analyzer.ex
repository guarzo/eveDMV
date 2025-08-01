defmodule EveDmv.Contexts.Corporation.Core.CombatDoctrineAnalyzer do
  @moduledoc """
  Analyzes corporation combat doctrines, fleet compositions, and ship usage patterns.

  Consolidates functionality from:
  - Corporation Analysis doctrine analysis
  - Corporation Intelligence fleet composition tracking
  """

  alias EveDmv.Platform.Database.CorporationRepository
  alias EveDmv.Database.CharacterRepository
  alias EveDmv.Platform.Cache.Corporation.CorporationCache
  alias EveDmv.StaticData.ShipTypes

  require Logger

  @cache_ttl :timer.hours(6)

  @doc """
  Analyze combat doctrine for a corporation.
  """
  def analyze_combat_doctrine(corporation_id) do
    cache_key = {:combat_doctrine, corporation_id}

    case CorporationCache.get(cache_key) do
      nil ->
        result = perform_combat_doctrine_analysis(corporation_id)

        if match?({:ok, _}, result) do
          {:ok, analysis} = result
          CorporationCache.put(cache_key, analysis, ttl: @cache_ttl)
        end

        result

      cached_result ->
        {:ok, cached_result}
    end
  end

  @doc """
  Get fleet compositions used by corporation.
  """
  def get_fleet_compositions(corporation_id) do
    case analyze_combat_doctrine(corporation_id) do
      {:ok, analysis} -> {:ok, analysis.fleet_compositions}
      error -> error
    end
  end

  @doc """
  Analyze ship usage patterns.
  """
  def analyze_ship_usage_patterns(corporation_id) do
    case analyze_combat_doctrine(corporation_id) do
      {:ok, analysis} -> {:ok, analysis.ship_usage_patterns}
      error -> error
    end
  end

  @doc """
  Assess doctrine compliance across corporation members.
  """
  def assess_doctrine_compliance(corporation_id) do
    case analyze_combat_doctrine(corporation_id) do
      {:ok, analysis} -> {:ok, analysis.doctrine_compliance}
      error -> error
    end
  end

  # Private Functions

  defp perform_combat_doctrine_analysis(corporation_id) do
    Logger.info("Analyzing combat doctrine for corporation #{corporation_id}")

    with {:ok, members} <- CorporationRepository.get_corporation_members(corporation_id),
         {:ok, combat_data} <- gather_combat_data(members),
         {:ok, ship_usage} <- analyze_ship_usage(combat_data),
         {:ok, fleet_comps} <- analyze_fleet_compositions(combat_data),
         {:ok, doctrines} <- identify_combat_doctrines(ship_usage, fleet_comps) do
      analysis = %{
        corporation_id: corporation_id,
        total_members: length(members),
        combat_doctrine: doctrines,
        ship_usage_patterns: ship_usage,
        fleet_compositions: fleet_comps,
        doctrine_compliance: assess_compliance(doctrines, ship_usage),
        tactical_preferences: analyze_tactical_preferences(combat_data),
        capability_assessment: assess_combat_capabilities(doctrines, ship_usage),
        recommendations: generate_doctrine_recommendations(doctrines, ship_usage),
        analyzed_at: DateTime.utc_now()
      }

      {:ok, analysis}
    end
  end

  defp gather_combat_data(members) do
    # Gather combat data for the last 90 days
    start_date = DateTime.utc_now() |> DateTime.add(-90, :day)

    combat_data =
      members
      |> Task.async_stream(
        fn member ->
          {member.character_id, collect_member_combat_data(member, start_date)}
        end,
        max_concurrency: 20,
        timeout: 15_000
      )
      |> Enum.reduce(%{}, fn
        {:ok, {char_id, {:ok, data}}}, acc ->
          Map.put(acc, char_id, data)

        {:ok, {char_id, {:error, reason}}}, acc ->
          Logger.warning("Failed to get combat data for character #{char_id}: #{inspect(reason)}")
          acc

        {:exit, reason}, acc ->
          Logger.error("Combat data collection task failed: #{inspect(reason)}")
          acc
      end)

    {:ok, combat_data}
  end

  defp collect_member_combat_data(member, start_date) do
    with {:ok, killmails} <-
           CharacterRepository.get_character_killmails_since(member.character_id, start_date) do
      combat_data = %{
        character_id: member.character_id,
        character_name: member.character_name,
        total_engagements: length(killmails),
        ships_used: extract_ships_used(killmails, member.character_id),
        fleet_engagements: analyze_fleet_engagements(killmails),
        combat_roles: identify_combat_roles(killmails, member.character_id),
        engagement_types: categorize_engagement_types(killmails),
        weapon_systems: analyze_weapon_usage(killmails, member.character_id),
        operational_areas: identify_operational_areas(killmails)
      }

      {:ok, combat_data}
    end
  end

  defp extract_ships_used(killmails, character_id) do
    ships =
      killmails
      |> Enum.flat_map(fn km ->
        # Get ships used by this character
        if km.victim.character_id == character_id do
          [km.victim.ship_type_id]
        else
          case Enum.find(km.attackers, fn att -> att.character_id == character_id end) do
            nil -> []
            attacker -> [attacker.ship_type_id]
          end
        end
      end)
      |> Enum.frequencies()
      |> Enum.sort_by(fn {_ship, count} -> count end, :desc)

    # Enrich with ship type information
    Enum.map(ships, fn {ship_type_id, count} ->
      ship_info = get_ship_info(ship_type_id)

      %{
        ship_type_id: ship_type_id,
        ship_name: ship_info.type_name,
        ship_class: categorize_ship_class(ship_info),
        usage_count: count,
        usage_percentage: Float.round(count / length(killmails) * 100, 1)
      }
    end)
  end

  defp get_ship_info(ship_type_id) do
    case ShipTypes.get_ship_type(ship_type_id) do
      {:ok, ship_info} ->
        ship_info

      {:error, _} ->
        %{type_name: "Unknown Ship", group_id: 0, category_id: 0}
    end
  end

  defp categorize_ship_class(ship_info) do
    # Categorize ships by class based on group_id
    # This is simplified - real implementation would use proper ship classification
    cond do
      ship_info.group_id in [25, 26, 27, 28, 29, 30, 31] -> :frigate
      ship_info.group_id in [324, 358, 380, 381, 382, 419] -> :destroyer
      ship_info.group_id in [832, 833, 834, 835, 863] -> :cruiser
      ship_info.group_id in [906, 963, 1201, 1202, 1283] -> :battlecruiser
      ship_info.group_id in [27, 898, 900, 941] -> :battleship
      ship_info.group_id in [547, 659, 1538] -> :carrier
      ship_info.group_id in [485, 513, 540, 541, 543] -> :dreadnought
      ship_info.group_id in [30, 893, 894, 906] -> :industrial
      true -> :other
    end
  end

  defp analyze_fleet_engagements(killmails) do
    fleet_activities =
      killmails
      |> Enum.filter(fn km -> length(km.attackers) >= 5 end)
      |> Enum.map(fn km ->
        %{
          fleet_size: length(km.attackers),
          fleet_composition: analyze_km_fleet_composition(km),
          engagement_type: categorize_fleet_engagement(km),
          isk_efficiency: calculate_km_isk_efficiency(km)
        }
      end)

    %{
      total_fleet_engagements: length(fleet_activities),
      avg_fleet_size: calculate_avg_fleet_size(fleet_activities),
      fleet_size_distribution: analyze_fleet_size_distribution(fleet_activities),
      fleet_composition_patterns: identify_composition_patterns(fleet_activities)
    }
  end

  defp analyze_km_fleet_composition(km) do
    ship_classes =
      km.attackers
      |> Enum.map(fn attacker ->
        ship_info = get_ship_info(attacker.ship_type_id)
        categorize_ship_class(ship_info)
      end)
      |> Enum.frequencies()

    ship_classes
  end

  defp categorize_fleet_engagement(km) do
    fleet_size = length(km.attackers)
    victim_value = km.total_value || 0

    cond do
      # 10B+ ISK
      victim_value > 10_000_000_000 -> :capital_engagement
      fleet_size >= 50 -> :large_fleet_op
      fleet_size >= 20 -> :medium_fleet_op
      fleet_size >= 10 -> :small_fleet_op
      true -> :gang_warfare
    end
  end

  defp calculate_km_isk_efficiency(km) do
    # Simplified ISK efficiency calculation
    victim_value = km.total_value || 0

    # Estimate fleet losses (simplified)
    # Assume 10% losses
    estimated_losses = victim_value * 0.1

    if estimated_losses > 0 do
      Float.round(victim_value / estimated_losses, 2)
    else
      # Fallback
      Float.round(victim_value / 1_000_000, 2)
    end
  end

  defp calculate_avg_fleet_size(fleet_activities) do
    if Enum.empty?(fleet_activities) do
      0
    else
      total_size =
        fleet_activities
        |> Enum.map(& &1.fleet_size)
        |> Enum.sum()

      Float.round(total_size / length(fleet_activities), 1)
    end
  end

  defp analyze_fleet_size_distribution(fleet_activities) do
    fleet_activities
    |> Enum.map(& &1.fleet_size)
    |> Enum.map(fn size ->
      cond do
        size >= 100 -> "100+"
        size >= 50 -> "50-99"
        size >= 20 -> "20-49"
        size >= 10 -> "10-19"
        true -> "5-9"
      end
    end)
    |> Enum.frequencies()
  end

  defp identify_composition_patterns(fleet_activities) do
    # Identify common fleet composition patterns
    compositions =
      fleet_activities
      |> Enum.map(& &1.fleet_composition)

    # Group similar compositions
    pattern_analysis = %{
      common_patterns: identify_common_patterns(compositions),
      doctrine_indicators: identify_doctrine_indicators(compositions),
      role_distribution: analyze_role_distribution(compositions)
    }

    pattern_analysis
  end

  defp identify_common_patterns(compositions) do
    # Analyze compositions to find common patterns
    # Simplified implementation
    total_comps = length(compositions)

    if total_comps == 0 do
      []
    else
      # Calculate average composition
      all_classes =
        compositions
        |> Enum.flat_map(&Map.keys/1)
        |> Enum.uniq()

      patterns =
        all_classes
        |> Enum.map(fn ship_class ->
          total_usage =
            compositions
            |> Enum.map(fn comp -> Map.get(comp, ship_class, 0) end)
            |> Enum.sum()

          avg_usage = total_usage / total_comps

          usage_frequency =
            compositions
            |> Enum.count(fn comp -> Map.get(comp, ship_class, 0) > 0 end)
            |> Kernel./(total_comps)

          %{
            ship_class: ship_class,
            avg_count: Float.round(avg_usage, 1),
            usage_frequency: Float.round(usage_frequency * 100, 1)
          }
        end)
        # Used in 20%+ of fleets
        |> Enum.filter(fn pattern -> pattern.usage_frequency > 20 end)
        |> Enum.sort_by(& &1.usage_frequency, :desc)

      patterns
    end
  end

  defp identify_doctrine_indicators(compositions) do
    # Look for indicators of organized doctrines
    indicators = []

    # High consistency in ship classes
    class_consistency = calculate_composition_consistency(compositions)

    indicators =
      if class_consistency > 0.7 do
        ["High ship class consistency (#{Float.round(class_consistency * 100, 1)}%)" | indicators]
      else
        indicators
      end

    # Specific role compositions
    indicators =
      if has_balanced_composition(compositions) do
        ["Balanced fleet compositions detected" | indicators]
      else
        indicators
      end

    Enum.reverse(indicators)
  end

  defp calculate_composition_consistency(compositions) do
    if length(compositions) < 2 do
      0
    else
      # Calculate actual variance in ship role distributions
      role_percentages = Enum.map(compositions, &calculate_role_percentages/1)
      calculate_consistency_from_role_percentages(role_percentages)
    end
  end

  defp has_balanced_composition(compositions) do
    # Check if compositions show balance between roles
    # Simplified implementation
    balanced_count =
      compositions
      |> Enum.count(fn comp ->
        dps_ships =
          Map.get(comp, :frigate, 0) + Map.get(comp, :cruiser, 0) + Map.get(comp, :battleship, 0)

        support_ships = Map.get(comp, :destroyer, 0) + Map.get(comp, :industrial, 0)

        total_ships = dps_ships + support_ships

        if total_ships > 0 do
          support_ratio = support_ships / total_ships
          # 10-40% support ships
          support_ratio > 0.1 and support_ratio < 0.4
        else
          false
        end
      end)

    # 30% of compositions are balanced
    balanced_count > length(compositions) * 0.3
  end

  defp analyze_role_distribution(compositions) do
    if Enum.empty?(compositions) do
      %{}
    else
      # Aggregate role distribution across all compositions
      total_ships =
        compositions
        |> Enum.flat_map(fn comp ->
          Map.to_list(comp)
        end)
        |> Enum.reduce(%{}, fn {role, count}, acc ->
          Map.update(acc, role, count, &(&1 + count))
        end)

      total_count = total_ships |> Map.values() |> Enum.sum()

      if total_count > 0 do
        total_ships
        |> Enum.map(fn {role, count} ->
          {role, Float.round(count / total_count * 100, 1)}
        end)
        |> Map.new()
      else
        %{}
      end
    end
  end

  defp identify_combat_roles(killmails, character_id) do
    # Analyze combat roles based on ship types and engagement patterns
    ships_used = extract_ships_used(killmails, character_id)

    # Determine primary roles
    roles =
      ships_used
      |> Enum.map(fn ship_usage ->
        role = determine_ship_role(ship_usage.ship_class)
        {role, ship_usage.usage_count}
      end)
      |> Enum.reduce(%{}, fn {role, count}, acc ->
        Map.update(acc, role, count, &(&1 + count))
      end)

    # Find primary and secondary roles
    sorted_roles =
      roles
      |> Enum.sort_by(fn {_role, count} -> count end, :desc)

    primary_role =
      case List.first(sorted_roles) do
        {role, _count} -> role
        nil -> :unknown
      end

    %{
      primary_role: primary_role,
      role_distribution: roles,
      role_versatility: calculate_role_versatility(roles)
    }
  end

  defp determine_ship_role(ship_class) do
    case ship_class do
      :frigate -> :fast_tackle
      :destroyer -> :anti_frigate
      :cruiser -> :dps
      :battlecruiser -> :heavy_dps
      :battleship -> :heavy_dps
      :carrier -> :capital_support
      :dreadnought -> :capital_dps
      :industrial -> :logistics
      _ -> :utility
    end
  end

  defp calculate_role_versatility(roles) do
    role_count = map_size(roles)

    cond do
      role_count >= 4 -> :highly_versatile
      role_count >= 3 -> :versatile
      role_count >= 2 -> :somewhat_versatile
      true -> :specialized
    end
  end

  defp categorize_engagement_types(killmails) do
    engagement_types =
      killmails
      |> Enum.map(fn km ->
        fleet_size = length(km.attackers)
        victim_value = km.total_value || 0

        cond do
          # 5B+ ISK targets
          victim_value > 5_000_000_000 -> :capital_hunting
          fleet_size >= 30 -> :large_fleet_warfare
          fleet_size >= 10 -> :small_fleet_warfare
          fleet_size >= 3 -> :gang_warfare
          true -> :solo_pvp
        end
      end)
      |> Enum.frequencies()

    # Convert to percentages
    total_engagements = length(killmails)

    if total_engagements > 0 do
      engagement_types
      |> Enum.map(fn {type, count} ->
        {type, Float.round(count / total_engagements * 100, 1)}
      end)
      |> Map.new()
    else
      %{}
    end
  end

  defp analyze_weapon_usage(_killmails, _character_id) do
    # Extract weapon system information from killmails
    # This would require detailed fitting analysis from killmail data
    # Simplified implementation

    %{
      primary_weapon_systems: ["Energy Weapons", "Projectile Weapons"],
      weapon_range_preference: :medium_range,
      damage_types: %{
        thermal: 40,
        kinetic: 30,
        explosive: 20,
        em: 10
      }
    }
  end

  defp identify_operational_areas(killmails) do
    # Analyze where combat operations typically occur
    systems =
      killmails
      |> Enum.map(& &1.solar_system_id)
      |> Enum.frequencies()
      |> Enum.sort_by(fn {_system, count} -> count end, :desc)
      |> Enum.take(10)

    # Categorize by security status (would need system data)
    %{
      primary_systems: systems,
      operational_scope: determine_operational_scope(systems),
      security_preference: analyze_security_preference(systems)
    }
  end

  defp determine_operational_scope(systems) do
    system_count = length(systems)

    cond do
      system_count >= 20 -> :wide_ranging
      system_count >= 10 -> :regional
      system_count >= 5 -> :local
      true -> :very_local
    end
  end

  defp analyze_security_preference(_systems) do
    # Would analyze actual security status of systems
    # Simplified implementation
    %{
      high_sec: 10,
      low_sec: 30,
      null_sec: 50,
      wormhole: 10
    }
  end

  defp analyze_ship_usage(combat_data) do
    # Aggregate ship usage across all members
    all_ships =
      combat_data
      |> Map.values()
      |> Enum.flat_map(& &1.ships_used)

    # Group by ship type
    ship_usage =
      all_ships
      |> Enum.reduce(%{}, fn ship, acc ->
        key = ship.ship_type_id

        Map.update(acc, key, ship, fn existing ->
          %{existing | usage_count: existing.usage_count + ship.usage_count}
        end)
      end)
      |> Map.values()
      |> Enum.sort_by(& &1.usage_count, :desc)

    # Analyze patterns
    %{
      top_ships: Enum.take(ship_usage, 20),
      ship_class_distribution: analyze_ship_class_distribution(ship_usage),
      doctrine_ships: identify_doctrine_ships(ship_usage),
      specialization_index: calculate_ship_specialization(ship_usage)
    }
  end

  defp analyze_ship_class_distribution(ship_usage) do
    ship_usage
    |> Enum.map(& &1.ship_class)
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_class, count} -> count end, :desc)
  end

  defp identify_doctrine_ships(ship_usage) do
    # Ships that are heavily used likely indicate doctrine ships
    total_usage = ship_usage |> Enum.map(& &1.usage_count) |> Enum.sum()

    if total_usage > 0 do
      ship_usage
      |> Enum.filter(fn ship ->
        usage_percentage = ship.usage_count / total_usage
        # Ships representing 5%+ of usage
        usage_percentage > 0.05
      end)
      |> Enum.take(10)
    else
      []
    end
  end

  defp calculate_ship_specialization(ship_usage) do
    if Enum.empty?(ship_usage) do
      0
    else
      # Calculate Herfindahl index for ship usage concentration
      total_usage = ship_usage |> Enum.map(& &1.usage_count) |> Enum.sum()

      if total_usage > 0 do
        herfindahl =
          ship_usage
          |> Enum.map(fn ship ->
            share = ship.usage_count / total_usage
            share * share
          end)
          |> Enum.sum()

        # Convert to 0-100 scale (higher = more specialized)
        Float.round(herfindahl * 100, 1)
      else
        0
      end
    end
  end

  defp analyze_fleet_compositions(combat_data) do
    # Analyze fleet compositions from member data
    fleet_data =
      combat_data
      |> Map.values()
      |> Enum.map(& &1.fleet_engagements)

    if Enum.empty?(fleet_data) do
      %{
        compositions: [],
        patterns: %{},
        doctrine_strength: 0
      }
    else
      # Aggregate fleet composition data
      _all_patterns =
        fleet_data
        |> Enum.flat_map(& &1.fleet_composition_patterns.common_patterns)

      %{
        avg_fleet_size: calculate_corp_avg_fleet_size(fleet_data),
        size_distribution: aggregate_size_distributions(fleet_data),
        common_compositions: aggregate_composition_patterns(fleet_data),
        tactical_preferences: identify_tactical_preferences(fleet_data)
      }
    end
  end

  defp calculate_corp_avg_fleet_size(fleet_data) do
    sizes =
      fleet_data
      |> Enum.map(& &1.avg_fleet_size)
      |> Enum.filter(&(&1 > 0))

    if Enum.empty?(sizes) do
      0
    else
      Float.round(Enum.sum(sizes) / length(sizes), 1)
    end
  end

  defp aggregate_size_distributions(fleet_data) do
    # Aggregate fleet size distributions
    all_distributions =
      fleet_data
      |> Enum.map(& &1.fleet_size_distribution)
      |> Enum.reduce(%{}, fn dist, acc ->
        Enum.reduce(dist, acc, fn {size_range, count}, inner_acc ->
          Map.update(inner_acc, size_range, count, &(&1 + count))
        end)
      end)

    # Convert to percentages
    total_fleets = all_distributions |> Map.values() |> Enum.sum()

    if total_fleets > 0 do
      all_distributions
      |> Enum.map(fn {size_range, count} ->
        {size_range, Float.round(count / total_fleets * 100, 1)}
      end)
      |> Map.new()
    else
      %{}
    end
  end

  defp aggregate_composition_patterns(fleet_data) do
    # Aggregate common composition patterns across all members
    all_patterns =
      fleet_data
      |> Enum.flat_map(& &1.fleet_composition_patterns.common_patterns)

    # Group patterns by ship class and average usage
    all_patterns
    |> Enum.group_by(& &1.ship_class)
    |> Enum.map(fn {ship_class, patterns} ->
      avg_count =
        patterns
        |> Enum.map(& &1.avg_count)
        |> then(fn counts ->
          if Enum.empty?(counts), do: 0, else: Enum.sum(counts) / length(counts)
        end)

      avg_frequency =
        patterns
        |> Enum.map(& &1.usage_frequency)
        |> then(fn freqs ->
          if Enum.empty?(freqs), do: 0, else: Enum.sum(freqs) / length(freqs)
        end)

      %{
        ship_class: ship_class,
        avg_count: Float.round(avg_count, 1),
        usage_frequency: Float.round(avg_frequency, 1)
      }
    end)
    # Filter out rarely used classes
    |> Enum.filter(&(&1.usage_frequency > 10))
    |> Enum.sort_by(& &1.usage_frequency, :desc)
  end

  defp identify_tactical_preferences(fleet_data) do
    # Analyze tactical preferences from fleet data
    _engagement_types =
      fleet_data
      |> Enum.flat_map(fn _member_data ->
        # Would extract engagement type data if available
        []
      end)

    %{
      preferred_engagement_size: :medium_fleet,
      tactical_style: :balanced,
      risk_tolerance: :moderate
    }
  end

  defp identify_combat_doctrines(ship_usage, fleet_compositions) do
    # Identify likely combat doctrines based on ship usage and fleet patterns
    primary_doctrine = determine_primary_doctrine(ship_usage, fleet_compositions)
    secondary_doctrines = identify_secondary_doctrines(ship_usage)

    %{
      primary_doctrine: primary_doctrine,
      secondary_doctrines: secondary_doctrines,
      doctrine_strength: assess_doctrine_strength(ship_usage),
      doctrine_evolution: analyze_doctrine_evolution(ship_usage)
    }
  end

  defp determine_primary_doctrine(ship_usage, _fleet_compositions) do
    # Determine primary doctrine from most used ship classes
    if Enum.empty?(ship_usage.ship_class_distribution) do
      %{name: :unknown, characteristics: []}
    else
      {primary_class, _count} = List.first(ship_usage.ship_class_distribution)

      doctrine_name =
        case primary_class do
          :frigate -> :fast_tackle_doctrine
          :destroyer -> :anti_frigate_doctrine
          :cruiser -> :cruiser_doctrine
          :battlecruiser -> :heavy_assault_doctrine
          :battleship -> :battleship_doctrine
          :carrier -> :capital_doctrine
          _ -> :mixed_doctrine
        end

      %{
        name: doctrine_name,
        primary_ship_class: primary_class,
        characteristics: get_doctrine_characteristics(doctrine_name),
        strength: calculate_doctrine_adherence(ship_usage, primary_class)
      }
    end
  end

  defp get_doctrine_characteristics(doctrine_name) do
    case doctrine_name do
      :fast_tackle_doctrine ->
        ["High mobility", "Fast engagement", "Point/scram focused"]

      :cruiser_doctrine ->
        ["Balanced approach", "Medium range", "Cost effective"]

      :battleship_doctrine ->
        ["High alpha damage", "Armor tanked", "Slow but powerful"]

      :capital_doctrine ->
        ["Force projection", "High ISK commitment", "Strategic warfare"]

      _ ->
        ["Flexible composition", "Adaptable tactics"]
    end
  end

  defp calculate_doctrine_adherence(ship_usage, primary_class) do
    primary_usage =
      ship_usage.ship_class_distribution
      |> Enum.find(fn {class, _count} -> class == primary_class end)
      |> case do
        {_class, count} -> count
        nil -> 0
      end

    total_usage =
      ship_usage.ship_class_distribution
      |> Enum.map(fn {_class, count} -> count end)
      |> Enum.sum()

    if total_usage > 0 do
      adherence = primary_usage / total_usage
      Float.round(adherence * 100, 1)
    else
      0
    end
  end

  defp identify_secondary_doctrines(ship_usage) do
    # Identify secondary doctrines from remaining ship usage
    ship_usage.ship_class_distribution
    # Skip primary
    |> Enum.drop(1)
    # Take next 2 most common
    |> Enum.take(2)
    |> Enum.map(fn {ship_class, count} ->
      %{
        ship_class: ship_class,
        usage_count: count,
        doctrine_type: map_class_to_doctrine(ship_class)
      }
    end)
  end

  defp map_class_to_doctrine(ship_class) do
    case ship_class do
      :frigate -> :tackle_support
      :destroyer -> :anti_support
      :cruiser -> :line_ship
      :battlecruiser -> :heavy_line
      :battleship -> :anchor_ship
      _ -> :utility
    end
  end

  defp assess_doctrine_strength(ship_usage) do
    # Higher specialization index indicates stronger doctrine adherence
    specialization = ship_usage.specialization_index

    cond do
      specialization >= 30 -> :strong_doctrine
      specialization >= 20 -> :moderate_doctrine
      specialization >= 10 -> :weak_doctrine
      true -> :no_clear_doctrine
    end
  end

  defp analyze_doctrine_evolution(_ship_usage) do
    # Would analyze changes in ship usage over time
    # Simplified implementation
    %{
      trend: :stable,
      recent_changes: [],
      evolution_speed: :slow
    }
  end

  defp assess_compliance(doctrines, ship_usage) do
    # Assess how well corporation members follow identified doctrines
    primary_doctrine = doctrines.primary_doctrine

    compliance_score =
      if primary_doctrine.name != :unknown do
        primary_doctrine.strength
      else
        0
      end

    %{
      overall_compliance: compliance_score,
      compliance_level: categorize_compliance(compliance_score),
      non_compliant_ships: identify_non_compliant_usage(ship_usage, primary_doctrine),
      compliance_trends: analyze_compliance_trends()
    }
  end

  defp categorize_compliance(score) do
    cond do
      score >= 70 -> :high_compliance
      score >= 50 -> :moderate_compliance
      score >= 30 -> :low_compliance
      true -> :poor_compliance
    end
  end

  defp identify_non_compliant_usage(ship_usage, primary_doctrine) do
    if primary_doctrine.name == :unknown do
      []
    else
      # Ships that don't fit the primary doctrine
      primary_class = Map.get(primary_doctrine, :primary_ship_class, :unknown)

      ship_usage.top_ships
      |> Enum.filter(fn ship -> ship.ship_class != primary_class end)
      |> Enum.take(5)
      |> Enum.map(fn ship ->
        %{
          ship_name: ship.ship_name,
          ship_class: ship.ship_class,
          usage_count: ship.usage_count,
          compliance_issue: determine_compliance_issue(ship.ship_class, primary_class)
        }
      end)
    end
  end

  defp determine_compliance_issue(actual_class, expected_class) do
    case {actual_class, expected_class} do
      {:battleship, :cruiser} -> "Ship class too heavy for doctrine"
      {:frigate, :battleship} -> "Ship class too light for doctrine"
      {actual, expected} when actual != expected -> "Ship class mismatch"
      _ -> "Usage pattern deviation"
    end
  end

  defp analyze_compliance_trends do
    # Would analyze compliance changes over time
    %{
      trend: :stable,
      improvement_rate: 0,
      concerning_patterns: []
    }
  end

  defp analyze_tactical_preferences(combat_data) do
    # Analyze tactical preferences from combat data
    all_engagement_types =
      combat_data
      |> Map.values()
      |> Enum.flat_map(&Map.to_list(&1.engagement_types))
      |> Enum.reduce(%{}, fn {type, percentage}, acc ->
        Map.update(acc, type, percentage, &(&1 + percentage))
      end)

    # Normalize percentages
    total_percentage = all_engagement_types |> Map.values() |> Enum.sum()

    tactical_preferences =
      if total_percentage > 0 do
        all_engagement_types
        |> Enum.map(fn {type, total} ->
          {type, Float.round(total / map_size(combat_data), 1)}
        end)
        |> Map.new()
      else
        %{}
      end

    %{
      engagement_preferences: tactical_preferences,
      preferred_fleet_size: determine_preferred_fleet_size(tactical_preferences),
      risk_profile: assess_tactical_risk_profile(tactical_preferences),
      combat_style: determine_combat_style(tactical_preferences)
    }
  end

  defp determine_preferred_fleet_size(preferences) do
    max_engagement =
      preferences
      |> Enum.max_by(fn {_type, percentage} -> percentage end, fn -> {:solo_pvp, 0} end)

    case elem(max_engagement, 0) do
      :large_fleet_warfare -> :large_fleet
      :small_fleet_warfare -> :small_fleet
      :gang_warfare -> :gang
      :solo_pvp -> :solo
      _ -> :mixed
    end
  end

  defp assess_tactical_risk_profile(preferences) do
    high_risk_percentage =
      Map.get(preferences, :capital_hunting, 0) +
        Map.get(preferences, :large_fleet_warfare, 0)

    cond do
      high_risk_percentage > 40 -> :high_risk
      high_risk_percentage > 20 -> :moderate_risk
      true -> :low_risk
    end
  end

  defp determine_combat_style(preferences) do
    solo_percentage = Map.get(preferences, :solo_pvp, 0)

    fleet_percentage =
      Map.get(preferences, :large_fleet_warfare, 0) +
        Map.get(preferences, :small_fleet_warfare, 0)

    cond do
      solo_percentage > 50 -> :individual_focused
      fleet_percentage > 60 -> :fleet_focused
      true -> :balanced
    end
  end

  defp assess_combat_capabilities(doctrines, ship_usage) do
    primary_doctrine = doctrines.primary_doctrine

    %{
      doctrine_maturity: assess_doctrine_maturity(primary_doctrine),
      fleet_versatility: assess_fleet_versatility(ship_usage),
      combat_readiness: assess_combat_readiness_level(doctrines, ship_usage),
      strategic_capability: assess_strategic_capability(ship_usage)
    }
  end

  defp assess_doctrine_maturity(primary_doctrine) do
    case primary_doctrine.name do
      :unknown ->
        :no_doctrine

      _ ->
        strength = primary_doctrine[:strength] || 0

        cond do
          strength >= 70 -> :mature_doctrine
          strength >= 50 -> :developing_doctrine
          strength >= 30 -> :emerging_doctrine
          true -> :weak_doctrine
        end
    end
  end

  defp assess_fleet_versatility(ship_usage) do
    class_count = length(ship_usage.ship_class_distribution)
    specialization = ship_usage.specialization_index

    # High versatility = many ship classes, low specialization
    cond do
      class_count >= 6 and specialization < 20 -> :highly_versatile
      class_count >= 4 and specialization < 30 -> :versatile
      class_count >= 3 -> :moderately_versatile
      true -> :specialized
    end
  end

  defp assess_combat_readiness_level(doctrines, ship_usage) do
    doctrine_strength =
      case doctrines.doctrine_strength do
        :strong_doctrine -> 40
        :moderate_doctrine -> 30
        :weak_doctrine -> 20
        _ -> 10
      end

    ship_diversity = min(length(ship_usage.ship_class_distribution) * 5, 30)
    activity_level = min(length(ship_usage.top_ships), 30)

    total_readiness = doctrine_strength + ship_diversity + activity_level

    cond do
      total_readiness >= 80 -> :combat_ready
      total_readiness >= 60 -> :moderately_ready
      total_readiness >= 40 -> :limited_readiness
      true -> :poor_readiness
    end
  end

  defp assess_strategic_capability(ship_usage) do
    # Look for capital ships and strategic assets
    has_capitals =
      ship_usage.ship_class_distribution
      |> Enum.any?(fn {class, _count} ->
        class in [:carrier, :dreadnought, :supercarrier, :titan]
      end)

    if has_capitals do
      :strategic_capability
    else
      :tactical_capability
    end
  end

  defp generate_doctrine_recommendations(doctrines, ship_usage) do
    recommendations = []

    # Doctrine strength recommendations
    recommendations =
      case doctrines.doctrine_strength do
        :no_clear_doctrine ->
          ["Establish clear combat doctrine and ship requirements" | recommendations]

        :weak_doctrine ->
          ["Strengthen doctrine adherence through training and ship programs" | recommendations]

        _ ->
          recommendations
      end

    # Ship diversity recommendations
    class_count = length(ship_usage.ship_class_distribution)

    recommendations =
      if class_count < 3 do
        ["Increase ship class diversity for tactical flexibility" | recommendations]
      else
        recommendations
      end

    # Specialization recommendations
    recommendations =
      if ship_usage.specialization_index > 50 do
        ["Consider broadening ship usage to reduce over-specialization" | recommendations]
      else
        recommendations
      end

    Enum.reverse(recommendations)
  end

  defp calculate_role_percentages(composition) do
    total_ships =
      composition
      |> Map.values()
      |> Enum.sum()

    if total_ships == 0 do
      %{}
    else
      composition
      |> Enum.map(fn {role, count} ->
        {role, count / total_ships * 100}
      end)
      |> Map.new()
    end
  end

  defp calculate_consistency_from_role_percentages(role_percentages_list) do
    if length(role_percentages_list) < 2 do
      0
    else
      # Get all unique roles across all compositions
      all_roles =
        role_percentages_list
        |> Enum.flat_map(&Map.keys/1)
        |> Enum.uniq()

      # Calculate variance for each role across compositions
      role_variances =
        Enum.map(all_roles, fn role ->
          percentages =
            Enum.map(role_percentages_list, fn rp ->
              Map.get(rp, role, 0)
            end)

          calculate_variance(percentages)
        end)

      # Average variance across all roles
      avg_variance = Enum.sum(role_variances) / length(role_variances)

      # Convert to consistency score (lower variance = higher consistency)
      consistency = max(0, 1.0 - avg_variance / 100)
      Float.round(consistency, 2)
    end
  end

  defp calculate_variance(values) do
    if length(values) < 2 do
      0
    else
      mean = Enum.sum(values) / length(values)

      variance =
        values
        |> Enum.map(fn x -> :math.pow(x - mean, 2) end)
        |> Enum.sum()
        |> Kernel./(length(values))

      variance
    end
  end
end

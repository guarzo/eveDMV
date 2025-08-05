defmodule EveDmv.Contexts.CombatIntelligence.Domain.AdvancedFleetAnalyzer do
  @compile {:nowarn_unused_function}
  @moduledoc """
  Advanced fleet composition analysis with deep tactical insights.

  Integrates multiple analysis systems to provide comprehensive fleet assessment:
  - Ship stats calculations (DPS/EHP)
  - EWAR detection and analysis
  - Role balance optimization
  - Doctrine compliance checking
  - Counter-fleet recommendations
  - Engagement envelope analysis

  Provides actionable intelligence for fleet commanders and strategic planners.
  """

  alias EveDmv.Contexts.CombatIntelligence.Domain.EwarAnalyzer
  alias EveDmv.Contexts.CombatIntelligence.Domain.ShipStatsCalculator

  require Logger

  # Ideal fleet composition ratios
  @ideal_composition %{
    # Core roles
    dps: %{min: 0.50, max: 0.70, critical: true},
    logistics: %{min: 0.10, max: 0.25, critical: true},
    tackle: %{min: 0.05, max: 0.15, critical: true},
    ewar: %{min: 0.05, max: 0.15, critical: false},
    command: %{min: 0.02, max: 0.05, critical: false},

    # Support roles
    scouts: %{min: 0.02, max: 0.05, critical: false},
    anti_support: %{min: 0.02, max: 0.10, critical: false}
  }

  # Common fleet doctrines
  @fleet_doctrines %{
    armor_brawl: %{
      primary_tank: :armor,
      engagement_range: :close,
      mobility: :low,
      ships: ["Megathron", "Dominix", "Guardian", "Oneiros", "Brutix", "Myrmidon"],
      support: ["Lachesis", "Arazu", "Devoter"]
    },
    shield_kite: %{
      primary_tank: :shield,
      engagement_range: :long,
      mobility: :high,
      ships: ["Cerberus", "Eagle", "Tengu", "Scimitar", "Basilisk", "Osprey Navy Issue"],
      support: ["Huginn", "Raptor", "Stiletto"]
    },
    alpha_fleet: %{
      primary_tank: :shield,
      engagement_range: :long,
      mobility: :medium,
      ships: ["Maelstrom", "Rokh", "Basilisk", "Scimitar", "Muninn", "Hurricane Fleet Issue"],
      support: ["Sabre", "Lachesis", "Huginn"]
    },
    nano_gang: %{
      primary_tank: :shield,
      engagement_range: :variable,
      mobility: :very_high,
      ships: ["Orthrus", "Osprey Navy Issue", "Cynabal", "Vagabond", "Gila"],
      support: ["Keres", "Lachesis", "Raptor"]
    }
  }

  @doc """
  Perform comprehensive fleet analysis with advanced metrics.

  ## Parameters
  - fleet_ships: List of ships with type_id or name
  - options:
    - :include_counters - Generate counter-fleet recommendations
    - :check_doctrine - Check against known doctrines
    - :simulate_engagement - Run engagement simulations

  ## Returns
  Comprehensive fleet analysis with tactical recommendations
  """
  def analyze_fleet(fleet_ships, options \\ []) when is_list(fleet_ships) do
    with {:ok, ship_analyses} <- analyze_individual_ships(fleet_ships),
         {:ok, composition} <- analyze_composition(ship_analyses),
         {:ok, capabilities} <- analyze_capabilities(ship_analyses),
         {:ok, vulnerabilities} <- analyze_vulnerabilities(ship_analyses, composition) do
      # Generate recommendations directly since it doesn't return a tuple
      recommendations = generate_recommendations(composition, capabilities, vulnerabilities)

      base_analysis = %{
        fleet_summary: %{ship_count: length(ship_analyses)},
        composition: composition,
        capabilities: capabilities,
        vulnerabilities: vulnerabilities,
        recommendations: recommendations,
        engagement_profile: %{},
        counter_fleet_options: maybe_generate_counters(composition, options)
      }

      # Add doctrine check if requested
      final_analysis =
        if Keyword.get(options, :check_doctrine, false) do
          Map.put(base_analysis, :doctrine_analysis, check_doctrine_compliance(ship_analyses))
        else
          base_analysis
        end

      {:ok, final_analysis}
    end
  end

  @doc """
  Analyze a fleet's ability to counter another fleet composition.
  """
  def analyze_matchup(fleet_a, fleet_b) do
    with {:ok, analysis_a} <- analyze_fleet(fleet_a, []),
         {:ok, analysis_b} <- analyze_fleet(fleet_b, []) do
      matchup = %{
        fleet_a: summarize_fleet(analysis_a),
        fleet_b: summarize_fleet(analysis_b),
        advantages: analyze_advantages(analysis_a, analysis_b),
        engagement_recommendations: recommend_engagement(analysis_a, analysis_b),
        predicted_outcome: %{winner: :unknown, confidence: 0.5}
      }

      {:ok, matchup}
    else
      {:error, reason} -> {:error, reason}
      _ -> {:error, :analysis_failed}
    end
  end

  # Individual ship analysis

  defp analyze_individual_ships(fleet_ships) do
    ship_analyses =
      fleet_ships
      |> Enum.map(&analyze_single_ship/1)
      |> Enum.reject(&is_nil/1)

    if Enum.empty?(ship_analyses) do
      {:error, :no_valid_ships}
    else
      {:ok, ship_analyses}
    end
  end

  defp analyze_single_ship(ship) do
    ship_id = extract_ship_id(ship)

    case ship_id do
      nil ->
        nil

      id ->
        # Get ship stats
        stats =
          case ShipStatsCalculator.calculate_ship_stats(id) do
            {:ok, stats} -> stats
            _ -> nil
          end

        # Check for EWAR
        ewar =
          case EwarAnalyzer.analyze_ewar_ship(id) do
            {:ok, ewar_analysis} -> ewar_analysis
            _ -> %{is_ewar: false}
          end

        # Determine role
        role = determine_ship_role(stats, ewar, id)

        # Get pilot info if available
        pilot_info = extract_pilot_info(ship)

        %{
          ship_id: id,
          ship_name: stats && stats.ship_name,
          pilot: pilot_info,
          stats: stats,
          ewar: ewar,
          role: role,
          value: 0.0
        }
    end
  end

  defp extract_ship_id(ship) do
    case ship do
      %{ship_type_id: id} -> id
      %{ship_id: id} -> id
      %{"ship_type_id" => id} -> id
      id when is_integer(id) -> id
      _ -> nil
    end
  end

  defp extract_pilot_info(ship) do
    case ship do
      %{character_name: name, character_id: id} ->
        %{name: name, id: id}

      %{pilot_name: name} ->
        %{name: name, id: nil}

      _ ->
        nil
    end
  end

  defp determine_ship_role(stats, ewar, _ship_id) do
    cond do
      # EWAR takes precedence
      ewar.is_ewar ->
        :ewar

      # Check ship name for specialized roles
      stats && logistics_ship?(stats.ship_name) ->
        :logistics

      stats && command_ship?(stats.ship_name) ->
        :command

      stats && tackle_ship?(stats.ship_name) ->
        :tackle

      # Use common roles from stats
      stats && Enum.member?(stats.meta_info.common_roles, "Logistics") ->
        :logistics

      stats && Enum.member?(stats.meta_info.common_roles, "Tackle") ->
        :tackle

      # Default to DPS
      true ->
        :dps
    end
  end

  defp logistics_ship?(name) do
    String.contains?(String.downcase(name), [
      "guardian",
      "basilisk",
      "oneiros",
      "scimitar",
      "deacon",
      "kirin",
      "thalia",
      "scalpel",
      "apostle",
      "minokawa",
      "lif",
      "ninazu"
    ])
  end

  defp command_ship?(name) do
    String.contains?(String.downcase(name), [
      "claymore",
      "vulture",
      "damnation",
      "eos",
      "absolution",
      "astarte",
      "nighthawk",
      "sleipnir",
      "bifrost",
      "magus",
      "pontifex",
      "stork"
    ])
  end

  defp tackle_ship?(name) do
    String.contains?(String.downcase(name), [
      "sabre",
      "flycatcher",
      "eris",
      "heretic",
      "broadsword",
      "onyx",
      "devoter",
      "phobos",
      "stiletto",
      "raptor",
      "ares",
      "malediction"
    ])
  end

  # Composition analysis

  defp analyze_composition(ship_analyses) do
    total_ships = length(ship_analyses)

    # Group by role
    role_distribution =
      ship_analyses
      |> Enum.group_by(& &1.role)
      |> Enum.map(fn {role, ships} ->
        {role,
         %{
           count: length(ships),
           percentage: length(ships) / total_ships,
           ships: Enum.map(ships, & &1.ship_name)
         }}
      end)
      |> Map.new()

    # Analyze ship classes
    ship_classes =
      ship_analyses
      |> Enum.group_by(fn ship ->
        (ship.stats && ship.stats.ship_class) || :unknown
      end)
      |> Enum.map(fn {class, ships} ->
        {class, length(ships)}
      end)
      |> Map.new()

    # Analyze tank types
    tank_distribution = analyze_tank_distribution(ship_analyses)

    # Calculate diversity metrics
    diversity = calculate_diversity_metrics(ship_analyses)

    # Assess balance
    balance_score = assess_role_balance(role_distribution, total_ships)

    composition = %{
      total_ships: total_ships,
      role_distribution: role_distribution,
      ship_classes: ship_classes,
      tank_distribution: tank_distribution,
      diversity: diversity,
      balance_score: balance_score,
      composition_type: determine_composition_type(role_distribution, ship_classes),
      missing_roles: identify_missing_roles(role_distribution, total_ships)
    }

    {:ok, composition}
  end

  defp analyze_tank_distribution(ship_analyses) do
    ship_analyses
    |> Enum.group_by(fn ship ->
      (ship.stats && ship.stats.meta_info.tank_type) || :unknown
    end)
    |> Enum.map(fn {tank_type, ships} ->
      {tank_type,
       %{
         count: length(ships),
         percentage: length(ships) / length(ship_analyses)
       }}
    end)
    |> Map.new()
  end

  defp calculate_diversity_metrics(ship_analyses) do
    unique_ships =
      ship_analyses
      |> Enum.map(& &1.ship_name)
      |> Enum.uniq()
      |> length()

    total_ships = length(ship_analyses)

    %{
      unique_ship_types: unique_ships,
      diversity_index: unique_ships / max(total_ships, 1),
      homogeneity: 1 - unique_ships / max(total_ships, 1)
    }
  end

  defp assess_role_balance(role_distribution, total_ships) do
    if total_ships == 0 do
      0.0
    else
      # Check each ideal role
      scores =
        @ideal_composition
        |> Enum.map(fn {role, ideal} ->
          actual = Map.get(role_distribution, role, %{percentage: 0}).percentage

          # Calculate deviation from ideal range
          score =
            cond do
              actual < ideal.min ->
                # Under minimum - bad
                max(0, 1 - (ideal.min - actual) * 5)

              actual > ideal.max ->
                # Over maximum - less bad
                max(0, 1 - (actual - ideal.max) * 3)

              true ->
                # Within range - perfect
                1.0
            end

          # Weight critical roles more heavily
          weight = if ideal.critical, do: 2.0, else: 1.0

          {score * weight, weight}
        end)

      # Calculate weighted average
      {total_score, total_weight} =
        Enum.reduce(scores, {0, 0}, fn {score, weight}, {s, w} ->
          {s + score, w + weight}
        end)

      total_score / total_weight * 100
    end
  end

  defp determine_composition_type(role_distribution, ship_classes) do
    dps_ratio = Map.get(role_distribution, :dps, %{percentage: 0}).percentage
    logi_ratio = Map.get(role_distribution, :logistics, %{percentage: 0}).percentage

    # Check ship classes
    has_capitals =
      Enum.any?(ship_classes, fn {class, _count} ->
        class in [:dreadnought, :carrier, :titan, :supercarrier]
      end)

    cond do
      has_capitals ->
        :capital_fleet

      dps_ratio > 0.8 ->
        :dps_heavy

      logi_ratio > 0.25 ->
        :turtle_fleet

      Map.has_key?(role_distribution, :ewar) and role_distribution.ewar.percentage > 0.2 ->
        :ewar_fleet

      true ->
        :balanced_fleet
    end
  end

  defp identify_missing_roles(role_distribution, total_ships) do
    @ideal_composition
    |> Enum.filter(fn {role, ideal} ->
      actual = Map.get(role_distribution, role, %{percentage: 0}).percentage
      ideal.critical and actual < ideal.min and total_ships >= 5
    end)
    |> Enum.map(fn {role, ideal} ->
      actual = Map.get(role_distribution, role, %{percentage: 0}).percentage
      needed = round((ideal.min - actual) * total_ships)

      %{
        role: role,
        severity: :critical,
        ships_needed: max(needed, 1),
        recommendation: recommend_ships_for_role(role)
      }
    end)
  end

  defp recommend_ships_for_role(role) do
    case role do
      :logistics -> ["Guardian", "Oneiros", "Scimitar", "Basilisk"]
      :tackle -> ["Sabre", "Stiletto", "Lachesis", "Huginn"]
      :ewar -> ["Blackbird", "Celestis", "Arbitrator", "Vigil"]
      :command -> ["Claymore", "Vulture", "Damnation", "Eos"]
      :dps -> ["Muninn", "Cerberus", "Eagle", "Ferox"]
      _ -> []
    end
  end

  # Capabilities analysis

  defp analyze_capabilities(ship_analyses) do
    # Aggregate stats
    total_dps =
      ship_analyses
      |> Enum.map(fn ship -> (ship.stats && ship.stats.dps.total) || 0 end)
      |> Enum.sum()

    total_ehp =
      ship_analyses
      |> Enum.map(fn ship -> (ship.stats && ship.stats.ehp.total) || 0 end)
      |> Enum.sum()

    # Logistics capabilities
    logi_power = calculate_logistics_power(ship_analyses)

    # EWAR capabilities
    ewar_analysis = analyze_ewar_capabilities(ship_analyses)

    # Mobility analysis
    mobility = analyze_fleet_mobility(ship_analyses)

    # Engagement envelope
    engagement_range = analyze_engagement_range(ship_analyses)

    capabilities = %{
      firepower: %{
        total_dps: total_dps,
        dps_per_ship: total_dps / max(length(ship_analyses), 1),
        alpha_strike: calculate_alpha_strike(ship_analyses),
        damage_types: analyze_damage_types(ship_analyses)
      },
      defense: %{
        total_ehp: total_ehp,
        ehp_per_ship: total_ehp / max(length(ship_analyses), 1),
        logistics_power: logi_power,
        tank_efficiency: calculate_tank_efficiency(ship_analyses)
      },
      ewar: ewar_analysis,
      mobility: mobility,
      engagement_range: engagement_range,
      tactical_flexibility: assess_tactical_flexibility(ship_analyses)
    }

    {:ok, capabilities}
  end

  defp calculate_logistics_power(ship_analyses) do
    logi_ships = Enum.filter(ship_analyses, &(&1.role == :logistics))

    # Estimate rep power per logi ship type
    total_rep_power =
      logi_ships
      |> Enum.map(fn ship ->
        name = String.downcase(ship.ship_name || "")

        cond do
          String.contains?(name, "guardian") -> 800
          String.contains?(name, "oneiros") -> 750
          String.contains?(name, "scimitar") -> 700
          String.contains?(name, "basilisk") -> 850
          String.contains?(name, "deacon") -> 400
          String.contains?(name, "thalia") -> 380
          String.contains?(name, "kirin") -> 350
          String.contains?(name, "scalpel") -> 320
          true -> 500
        end
      end)
      |> Enum.sum()

    %{
      logi_count: length(logi_ships),
      total_rep_power: total_rep_power,
      rep_per_logi:
        if(Enum.empty?(logi_ships), do: 0, else: total_rep_power / length(logi_ships)),
      sustainability_rating:
        rate_logistics_sustainability(length(logi_ships), length(ship_analyses))
    }
  end

  defp rate_logistics_sustainability(logi_count, total_ships) do
    ratio = logi_count / max(total_ships, 1)

    cond do
      ratio >= 0.20 -> :excellent
      ratio >= 0.15 -> :good
      ratio >= 0.10 -> :adequate
      ratio >= 0.05 -> :poor
      true -> :critical
    end
  end

  defp analyze_ewar_capabilities(ship_analyses) do
    ewar_ships = Enum.filter(ship_analyses, & &1.ewar.is_ewar)

    # Group by EWAR type
    ewar_breakdown =
      ewar_ships
      |> Enum.flat_map(fn ship ->
        Enum.map(ship.ewar[:ewar_types] || [], fn type -> {type, ship} end)
      end)
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
      |> Enum.map(fn {type, ships} ->
        {type,
         %{
           count: length(ships),
           ships: Enum.map(ships, & &1.ship_name),
           effectiveness: calculate_ewar_effectiveness(type, ships)
         }}
      end)
      |> Map.new()

    %{
      has_ewar: not Enum.empty?(ewar_ships),
      ewar_ship_count: length(ewar_ships),
      ewar_percentage: length(ewar_ships) / max(length(ship_analyses), 1) * 100,
      ewar_types: Map.keys(ewar_breakdown),
      ewar_breakdown: ewar_breakdown,
      ewar_strength: assess_ewar_strength(ewar_breakdown)
    }
  end

  defp calculate_ewar_effectiveness(type, ships) do
    base_effectiveness =
      case type do
        :ecm -> 70
        :damps -> 80
        :tracking_disruptors -> 75
        :neuts -> 85
        :tackle -> 90
        _ -> 50
      end

    # Add bonus for multiple ships
    ship_bonus = min(length(ships) * 10, 30)

    min(base_effectiveness + ship_bonus, 100)
  end

  defp assess_ewar_strength(ewar_breakdown) do
    if map_size(ewar_breakdown) == 0 do
      :none
    else
      total_effectiveness =
        Map.values(ewar_breakdown)
        |> Enum.map(& &1.effectiveness)
        |> Enum.sum()

      avg_effectiveness = total_effectiveness / map_size(ewar_breakdown)

      cond do
        avg_effectiveness >= 80 -> :strong
        avg_effectiveness >= 60 -> :moderate
        avg_effectiveness >= 40 -> :weak
        true -> :minimal
      end
    end
  end

  defp analyze_fleet_mobility(ship_analyses) do
    speeds =
      ship_analyses
      |> Enum.map(fn ship -> (ship.stats && ship.stats.mobility.max_velocity) || 0 end)
      |> Enum.reject(&(&1 == 0))

    if Enum.empty?(speeds) do
      %{average_speed: 0, mobility_rating: :unknown}
    else
      avg_speed = Enum.sum(speeds) / length(speeds)
      min_speed = Enum.min(speeds)
      max_speed = Enum.max(speeds)

      %{
        average_speed: round(avg_speed),
        min_speed: min_speed,
        max_speed: max_speed,
        speed_variance: max_speed - min_speed,
        mobility_rating: rate_mobility(avg_speed),
        bottleneck_ships: identify_mobility_bottlenecks(ship_analyses, avg_speed)
      }
    end
  end

  defp rate_mobility(avg_speed) do
    cond do
      avg_speed >= 2000 -> :very_high
      avg_speed >= 1500 -> :high
      avg_speed >= 1000 -> :medium
      avg_speed >= 500 -> :low
      true -> :very_low
    end
  end

  defp identify_mobility_bottlenecks(ship_analyses, avg_speed) do
    threshold = avg_speed * 0.6

    ship_analyses
    |> Enum.filter(fn ship ->
      speed = (ship.stats && ship.stats.mobility.max_velocity) || 0
      speed > 0 and speed < threshold
    end)
    |> Enum.map(& &1.ship_name)
  end

  defp analyze_engagement_range(ship_analyses) do
    # Group ships by optimal range
    range_groups =
      ship_analyses
      |> Enum.group_by(fn ship ->
        if ship.stats do
          case ship.stats.dps.breakdown.optimal_range do
            "0-10km" -> :brawl
            "10-30km" -> :short
            "20-50km" -> :medium
            "30-80km" -> :long
            _ -> :variable
          end
        else
          :unknown
        end
      end)

    dominant_range =
      range_groups
      |> Enum.max_by(fn {_range, ships} -> length(ships) end, fn -> {:unknown, []} end)
      |> elem(0)

    %{
      dominant_range: dominant_range,
      range_distribution:
        Enum.map(range_groups, fn {range, ships} ->
          {range, length(ships)}
        end)
        |> Map.new(),
      engagement_flexibility: assess_range_flexibility(range_groups),
      recommended_engagement_range: recommend_engagement_range(dominant_range)
    }
  end

  defp assess_range_flexibility(range_groups) do
    active_ranges = Enum.count(range_groups, fn {_range, ships} -> not Enum.empty?(ships) end)

    cond do
      active_ranges >= 4 -> :very_flexible
      active_ranges >= 3 -> :flexible
      active_ranges >= 2 -> :moderate
      true -> :inflexible
    end
  end

  defp recommend_engagement_range(dominant_range) do
    case dominant_range do
      :brawl -> "0-15km - Close range brawling"
      :short -> "15-30km - Short range skirmish"
      :medium -> "30-60km - Medium range kiting"
      :long -> "60-100km - Long range sniping"
      _ -> "Varies - Adapt to situation"
    end
  end

  defp analyze_damage_types(ship_analyses) do
    damage_profiles =
      ship_analyses
      |> Enum.map(fn ship ->
        ship.stats && ship.stats.dps.breakdown.damage_profile
      end)
      |> Enum.reject(&is_nil/1)

    if Enum.empty?(damage_profiles) do
      %{primary: :unknown, secondary: :unknown}
    else
      # Aggregate damage types
      aggregated =
        Enum.reduce(damage_profiles, %{}, fn profile, acc ->
          Enum.reduce(profile, acc, fn {damage_type, weight}, acc2 ->
            Map.update(acc2, damage_type, weight, &(&1 + weight))
          end)
        end)

      # Sort by total weight
      sorted =
        aggregated
        |> Enum.sort_by(&elem(&1, 1), :desc)
        |> Enum.map(&elem(&1, 0))

      %{
        primary: List.first(sorted) || :unknown,
        secondary: Enum.at(sorted, 1) || :none,
        distribution: aggregated
      }
    end
  end

  defp calculate_alpha_strike(ship_analyses) do
    # Estimate alpha based on ship types
    ship_analyses
    |> Enum.map(fn ship ->
      if ship.stats do
        multiplier =
          case ship.stats.ship_class do
            :battleship -> 3.0
            :battlecruiser -> 2.0
            :cruiser -> 1.5
            _ -> 1.0
          end

        ship.stats.dps.total * multiplier
      else
        0
      end
    end)
    |> Enum.sum()
    |> round()
  end

  defp calculate_tank_efficiency(ship_analyses) do
    # Analyze how well the tank types work together
    tank_types_list =
      ship_analyses
      |> Enum.map(fn ship -> ship.stats && ship.stats.meta_info.tank_type end)
      |> Enum.reject(&is_nil/1)

    tank_types_freq = Enum.frequencies(tank_types_list)

    # Homogeneous tank is more efficient
    dominant_tank_percentage =
      if map_size(tank_types_freq) > 0 do
        {_tank, count} = Enum.max_by(tank_types_freq, &elem(&1, 1))
        count / length(tank_types_list)
      else
        0
      end

    Float.round(dominant_tank_percentage, 2)
  end

  defp assess_tactical_flexibility(ship_analyses) do
    # Check for various tactical options
    has_tackle = Enum.any?(ship_analyses, &(&1.role == :tackle))
    has_ewar = Enum.any?(ship_analyses, & &1.ewar.is_ewar)
    has_logi = Enum.any?(ship_analyses, &(&1.role == :logistics))
    has_command = Enum.any?(ship_analyses, &(&1.role == :command))

    flexibility_score =
      [has_tackle, has_ewar, has_logi, has_command]
      |> Enum.count(& &1)

    case flexibility_score do
      4 -> :excellent
      3 -> :good
      2 -> :moderate
      1 -> :limited
      0 -> :poor
    end
  end

  # Vulnerability analysis

  defp analyze_vulnerabilities(ship_analyses, composition) do
    base_vulnerabilities = []

    # Get all vulnerability types
    role_vulns = check_role_vulnerabilities(composition)
    tank_vulns = check_tank_vulnerabilities(ship_analyses)

    # Build vulnerability list with conditions
    all_vulnerabilities =
      base_vulnerabilities
      |> add_vulnerability_if(vulnerable_to_bombers?(ship_analyses), %{
        type: :bomber_vulnerable,
        severity: :high,
        description: "Large signature battleships without sufficient anti-frigate support",
        mitigation: "Add destroyers or light missile cruisers for anti-bomber screen"
      })
      |> add_vulnerability_if(vulnerable_to_kiting?(ship_analyses), %{
        type: :kiting_vulnerable,
        severity: :medium,
        description: "Short range composition with limited tackle",
        mitigation: "Add long-range tackle (Lachesis, Arazu, Huginn)"
      })
      |> Kernel.++(role_vulns)
      |> Kernel.++(tank_vulns)

    vulnerability_analysis = %{
      vulnerabilities: all_vulnerabilities,
      overall_vulnerability: assess_overall_vulnerability(all_vulnerabilities),
      priority_threats: identify_priority_threats(all_vulnerabilities)
    }

    {:ok, vulnerability_analysis}
  end

  defp add_vulnerability_if(vulnerabilities, condition, vulnerability) do
    if condition, do: [vulnerability | vulnerabilities], else: vulnerabilities
  end

  defp vulnerable_to_bombers?(ship_analyses) do
    battleship_count =
      Enum.count(ship_analyses, fn ship ->
        ship.stats && ship.stats.ship_class == :battleship
      end)

    anti_frigate_count =
      Enum.count(ship_analyses, fn ship ->
        ship.stats && ship.stats.ship_class in [:destroyer, :assault_frigate]
      end)

    battleship_count > 5 and anti_frigate_count < 3
  end

  defp vulnerable_to_kiting?(ship_analyses) do
    short_range_ratio =
      Enum.count(ship_analyses, fn ship ->
        ship.stats && ship.stats.dps.breakdown.optimal_range in ["0-10km", "10-30km"]
      end) / max(length(ship_analyses), 1)

    long_tackle_count =
      Enum.count(ship_analyses, fn ship ->
        ship.role == :tackle and ship.ship_name =~ ~r/Lachesis|Arazu|Huginn/i
      end)

    short_range_ratio > 0.7 and long_tackle_count < 2
  end

  defp check_role_vulnerabilities(composition) do
    base_vulnerabilities = []
    tackle_ratio = Map.get(composition.role_distribution, :tackle, %{percentage: 0}).percentage
    has_logistics = Map.get(composition.role_distribution, :logistics, %{count: 0}).count > 0

    base_vulnerabilities
    |> add_vulnerability_if(not has_logistics, %{
      type: :no_logistics,
      severity: :critical,
      description: "No logistics support - vulnerable to attrition",
      mitigation: "Add 2-4 logistics ships immediately"
    })
    |> add_vulnerability_if(tackle_ratio < 0.05 and composition.total_ships > 10, %{
      type: :insufficient_tackle,
      severity: :high,
      description: "Insufficient tackle - enemies can disengage",
      mitigation: "Add fast tackle ships (interceptors, interdictors)"
    })
  end

  defp check_tank_vulnerabilities(ship_analyses) do
    # Get resist profiles
    resist_holes =
      ship_analyses
      |> Enum.map(fn ship ->
        ship.stats && ship.stats.ehp.resist_profile
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.group_by(& &1.damage_type)
      |> Enum.map(fn {damage_type, profiles} ->
        avg_resist = Enum.sum(Enum.map(profiles, & &1.resistance)) / length(profiles)
        {damage_type, avg_resist}
      end)
      |> Enum.min_by(&elem(&1, 1), fn -> {:unknown, 0.5} end)

    case resist_holes do
      {damage_type, avg_resist} when avg_resist < 0.5 ->
        [
          %{
            type: :resist_hole,
            severity: :medium,
            description:
              "Weak #{damage_type} resistance across fleet (#{round(avg_resist * 100)}%)",
            mitigation: "Adjust hardeners or add #{damage_type} resistance rigs"
          }
        ]

      _ ->
        []
    end
  end

  defp assess_overall_vulnerability(vulnerabilities) do
    critical_count = Enum.count(vulnerabilities, &(&1.severity == :critical))
    high_count = Enum.count(vulnerabilities, &(&1.severity == :high))

    cond do
      critical_count > 0 -> :critical
      high_count > 2 -> :high
      high_count > 0 -> :medium
      length(vulnerabilities) > 2 -> :low
      true -> :minimal
    end
  end

  defp identify_priority_threats(vulnerabilities) do
    vulnerabilities
    |> Enum.filter(&(&1.severity in [:critical, :high]))
    |> Enum.map(& &1.type)
  end

  # Recommendations

  defp generate_recommendations(composition, capabilities, vulnerabilities) do
    initial_recommendations = []

    # Role-based recommendations
    role_recs = generate_role_recommendations(composition)
    role_recommendations = initial_recommendations ++ role_recs

    # Capability-based recommendations
    cap_recs = generate_capability_recommendations(capabilities)
    capability_recommendations = role_recommendations ++ cap_recs

    # Vulnerability-based recommendations
    vuln_recs =
      vulnerabilities.vulnerabilities
      |> Enum.map(& &1.mitigation)

    final_recommendations = capability_recommendations ++ vuln_recs

    # Prioritize and deduplicate
    final_recommendations
    |> Enum.uniq()
    |> Enum.take(10)
  end

  defp generate_role_recommendations(composition) do
    composition.missing_roles
    |> Enum.map(fn missing ->
      "Add #{missing.ships_needed} #{missing.role} ships: #{Enum.join(missing.recommendation, ", ")}"
    end)
  end

  defp generate_capability_recommendations(capabilities) do
    base_recs = []

    base_recs
    |> add_recommendation_if(
      capabilities.mobility.mobility_rating in [:low, :very_low],
      "Consider adding faster ships or using mobility implants/drugs"
    )
    |> add_recommendation_if(
      capabilities.ewar.ewar_strength in [:none, :minimal],
      "Add EWAR support for tactical flexibility"
    )
    |> add_recommendation_if(
      capabilities.defense.tank_efficiency < 0.7,
      "Standardize tank type across fleet for better logistics efficiency"
    )
  end

  # Summary and engagement profile

  # Counter-fleet generation

  @dialyzer {:nowarn_function, maybe_generate_counters: 2}
  defp maybe_generate_counters(composition, options) do
    if options[:generate_counters] do
      generate_counter_fleet(composition)
    else
      nil
    end
  end

  @dialyzer {:nowarn_function, generate_counter_fleet: 1}
  defp generate_counter_fleet(composition) do
    # Analyze the fleet type and suggest counters
    case composition.composition_type do
      :dps_heavy ->
        %{
          strategy: "EWAR and kiting",
          suggested_ships: ["Blackbird", "Celestis", "Osprey Navy Issue", "Orthrus"],
          key_tactics: [
            "Use damps to reduce range",
            "Kite at edge of optimal",
            "Avoid direct engagement"
          ]
        }

      :turtle_fleet ->
        %{
          strategy: "Alpha strike or bomber run",
          suggested_ships: ["Tornado", "Oracle", "Naga", "Talos", "Hound", "Nemesis"],
          key_tactics: [
            "Coordinate alpha strikes",
            "Use void bombs on logistics",
            "Hit and run tactics"
          ]
        }

      :ewar_fleet ->
        %{
          strategy: "Sensor boosted snipers",
          suggested_ships: ["Ferox", "Eagle", "Muninn", "Harbinger Navy Issue"],
          key_tactics: [
            "Fit ECCM/Sensor boosters",
            "Engage at maximum range",
            "Primary EWAR ships"
          ]
        }

      _ ->
        %{
          strategy: "Balanced counter-composition",
          suggested_ships: ["Muninn", "Cerberus", "Scimitar", "Lachesis", "Sabre"],
          key_tactics: [
            "Maintain tactical flexibility",
            "Exploit specific weaknesses"
          ]
        }
    end
  end

  # Doctrine checking

  @dialyzer {:nowarn_function, check_doctrine_compliance: 1}
  defp check_doctrine_compliance(ship_analyses) do
    # Check against known doctrines
    doctrine_matches =
      @fleet_doctrines
      |> Enum.map(fn {doctrine_name, doctrine} ->
        compliance = calculate_doctrine_compliance(ship_analyses, doctrine)
        {doctrine_name, compliance}
      end)
      |> Enum.sort_by(&elem(&1, 1), :desc)

    best_match = List.first(doctrine_matches)

    if best_match && elem(best_match, 1) > 60 do
      {doctrine_name, compliance} = best_match
      doctrine = @fleet_doctrines[doctrine_name]

      %{
        detected_doctrine: doctrine_name,
        compliance_percentage: compliance,
        doctrine_details: doctrine,
        missing_elements: identify_missing_doctrine_elements(ship_analyses, doctrine),
        doctrine_effectiveness: assess_doctrine_effectiveness(doctrine_name)
      }
    else
      %{
        compliance_percentage: 0,
        doctrine_details: nil,
        missing_elements: [],
        doctrine_effectiveness: :unknown
      }
    end
  end

  @dialyzer {:nowarn_function, calculate_doctrine_compliance: 2}
  defp calculate_doctrine_compliance(ship_analyses, doctrine) do
    ship_names = Enum.map(ship_analyses, & &1.ship_name)
    doctrine_ships = doctrine.ships ++ Map.get(doctrine, :support, [])

    matching_ships =
      Enum.count(ship_names, fn name ->
        Enum.any?(doctrine_ships, fn doctrine_ship ->
          String.contains?(name || "", doctrine_ship)
        end)
      end)

    matching_ships / length(ship_names) * 100
  end

  @dialyzer {:nowarn_function, identify_missing_doctrine_elements: 2}
  defp identify_missing_doctrine_elements(ship_analyses, doctrine) do
    current_ships = Enum.map(ship_analyses, & &1.ship_name) |> MapSet.new()
    doctrine_ships = (doctrine.ships ++ Map.get(doctrine, :support, [])) |> MapSet.new()
    missing = MapSet.difference(doctrine_ships, current_ships) |> Enum.to_list()

    if Enum.empty?(missing) do
      []
    else
      ["Missing doctrine ships: #{Enum.join(missing, ", ")}"]
    end
  end

  @dialyzer {:nowarn_function, assess_doctrine_effectiveness: 1}
  defp assess_doctrine_effectiveness(doctrine_name) do
    case doctrine_name do
      :armor_brawl -> :good
      :shield_kite -> :excellent
      :alpha_fleet -> :good
      :nano_gang -> :situational
      _ -> :unknown
    end
  end

  # Matchup analysis

  @dialyzer {:nowarn_function, summarize_fleet: 1}
  defp summarize_fleet(analysis) do
    %{
      composition_type: analysis.composition.composition_type,
      total_dps: analysis.capabilities.firepower.total_dps,
      total_ehp: analysis.capabilities.defense.total_ehp,
      mobility: analysis.capabilities.mobility.mobility_rating,
      ewar_strength: analysis.capabilities.ewar.ewar_strength
    }
  end

  @dialyzer {:nowarn_function, analyze_advantages: 2}
  defp analyze_advantages(analysis_a, analysis_b) do
    base_advantages_a = []
    base_advantages_b = []

    # DPS advantage
    dps_advantages_a =
      if analysis_a.capabilities.firepower.total_dps >
           analysis_b.capabilities.firepower.total_dps * 1.2 do
        ["Superior firepower" | base_advantages_a]
      else
        base_advantages_a
      end

    dps_advantages_b =
      if analysis_b.capabilities.firepower.total_dps >
           analysis_a.capabilities.firepower.total_dps * 1.2 do
        ["Superior firepower" | base_advantages_b]
      else
        base_advantages_b
      end

    # Mobility advantage
    mob_a = mobility_to_number(analysis_a.capabilities.mobility.mobility_rating)
    mob_b = mobility_to_number(analysis_b.capabilities.mobility.mobility_rating)

    mobility_advantages_a =
      if mob_a > mob_b do
        ["Better mobility - can control engagement" | dps_advantages_a]
      else
        dps_advantages_a
      end

    mobility_advantages_b =
      if mob_b > mob_a do
        ["Better mobility - can control engagement" | dps_advantages_b]
      else
        dps_advantages_b
      end

    # EWAR advantage
    ewar_a = ewar_to_number(analysis_a.capabilities.ewar.ewar_strength)
    ewar_b = ewar_to_number(analysis_b.capabilities.ewar.ewar_strength)

    final_advantages_a =
      if ewar_a > ewar_b + 1 do
        ["EWAR superiority" | mobility_advantages_a]
      else
        mobility_advantages_a
      end

    final_advantages_b =
      if ewar_b > ewar_a + 1 do
        ["EWAR superiority" | mobility_advantages_b]
      else
        mobility_advantages_b
      end

    %{
      fleet_a_advantages: final_advantages_a,
      fleet_b_advantages: final_advantages_b
    }
  end

  @dialyzer {:nowarn_function, mobility_to_number: 1}
  defp mobility_to_number(rating) do
    case rating do
      :very_high -> 5
      :high -> 4
      :medium -> 3
      :very_low -> 1
      _ -> 0
    end
  end

  @dialyzer {:nowarn_function, ewar_to_number: 1}
  defp ewar_to_number(strength) do
    case strength do
      :strong -> 4
      :moderate -> 3
      :weak -> 2
      :minimal -> 1
      :none -> 0
    end
  end

  @dialyzer {:nowarn_function, recommend_engagement: 2}
  defp recommend_engagement(analysis_a, analysis_b) do
    # Generate tactical recommendations for fleet A
    base_recommendations = [
      "Focus fire on primary targets",
      "Maintain fleet cohesion",
      "Follow FC commands"
    ]

    # Range recommendations
    range_a = analysis_a.capabilities.engagement_range.dominant_range
    range_b = analysis_b.capabilities.engagement_range.dominant_range

    final_recommendations =
      case {range_a, range_b} do
        {:long, :brawl} -> ["Maintain range advantage - kite at 60-80km" | base_recommendations]
        {:brawl, :long} -> ["Close distance quickly - use MWD and tackle" | base_recommendations]
        _ -> base_recommendations
      end

    # Add more tactical recommendations based on matchup
    final_recommendations
  end

  # Utility functions

  defp add_recommendation_if(recommendations, condition, recommendation) do
    if condition, do: [recommendation | recommendations], else: recommendations
  end
end

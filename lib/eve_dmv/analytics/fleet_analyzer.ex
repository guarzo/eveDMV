defmodule EveDmv.Analytics.FleetAnalyzer do
  @moduledoc """
  Advanced fleet composition intelligence and doctrine recognition system.

  This module analyzes fleet compositions to identify known doctrines, assess
  tactical strengths/weaknesses, and provide actionable fleet intelligence
  recommendations based on ship role classifications and tactical patterns.

  Uses reference data from ship_info.md and real-time ship role analysis
  to provide comprehensive fleet analysis capabilities.
  """

  require Logger
  alias EveDmv.Repo
  import Ecto.Query

  # Doctrine pattern definitions based on ship_info.md reference data
  @doctrine_patterns %{
    # Battleship Doctrines
    "megathron_armor_fleet" => %{
      name: "Megathron Armor Fleet",
      # Megathron
      primary_ships: [641],
      # Guardian, Oneiros
      support_ships: [11987, 12003],
      # Damnation
      command_ships: [22852],
      tank_type: "armor",
      engagement_range: "long",
      min_fleet_size: 10,
      logistics_ratio: {0.15, 0.25},
      tactical_role: "alpha_strike",
      strengths: ["high_alpha", "armor_tank", "long_range"],
      weaknesses: ["mobility", "short_range_dps"]
    },
    "apocalypse_sniper" => %{
      name: "Apocalypse Sniper Fleet",
      # Apocalypse
      primary_ships: [642],
      # Guardian, Oneiros
      support_ships: [11987, 12003],
      # Damnation
      command_ships: [22852],
      tank_type: "armor",
      engagement_range: "extreme_long",
      min_fleet_size: 8,
      logistics_ratio: {0.20, 0.30},
      tactical_role: "sniper",
      strengths: ["extreme_range", "alpha_strike", "armor_tank"],
      weaknesses: ["mobility", "close_range_weakness"]
    },
    "machariel_speed_fleet" => %{
      name: "Machariel Speed Fleet",
      # Machariel
      primary_ships: [17738],
      # Basilisk, Scimitar
      support_ships: [11978, 11989],
      # Vulture
      command_ships: [22444],
      tank_type: "shield",
      engagement_range: "medium_long",
      min_fleet_size: 12,
      logistics_ratio: {0.15, 0.20},
      tactical_role: "mobile_dps",
      strengths: ["speed", "mobility", "projection"],
      weaknesses: ["sustained_damage", "tackle_vulnerability"]
    },

    # Battlecruiser Doctrines
    "ferox_railgun_fleet" => %{
      name: "Ferox Railgun Fleet",
      # Ferox
      primary_ships: [4306],
      # Basilisk, Scimitar
      support_ships: [11978, 11989],
      # Vulture
      command_ships: [22444],
      tank_type: "shield",
      engagement_range: "long",
      min_fleet_size: 15,
      logistics_ratio: {0.10, 0.18},
      tactical_role: "artillery_support",
      strengths: ["cost_effective", "range", "shield_tank"],
      weaknesses: ["alpha_damage", "cap_warfare"]
    },
    "hurricane_artillery" => %{
      name: "Hurricane Artillery Fleet",
      # Hurricane
      primary_ships: [4302],
      # Basilisk, Scimitar
      support_ships: [11978, 11989],
      # Vulture
      command_ships: [22444],
      tank_type: "shield",
      engagement_range: "medium_long",
      min_fleet_size: 12,
      logistics_ratio: {0.12, 0.20},
      tactical_role: "alpha_strike",
      strengths: ["alpha_damage", "speed", "cost"],
      weaknesses: ["tank", "sustained_dps"]
    },

    # HAC Doctrines
    "muninn_fleet" => %{
      name: "Muninn Fleet",
      # Muninn
      primary_ships: [22428],
      # Basilisk, Scimitar
      support_ships: [11978, 11989],
      # Vulture
      command_ships: [22444],
      tank_type: "shield",
      engagement_range: "long",
      min_fleet_size: 20,
      logistics_ratio: {0.15, 0.25},
      tactical_role: "kiting_dps",
      strengths: ["mobility", "range", "tracking"],
      weaknesses: ["close_range", "neut_pressure"]
    },
    "eagle_fleet" => %{
      name: "Eagle Fleet",
      # Eagle
      primary_ships: [12003],
      # Basilisk, Scimitar
      support_ships: [11978, 11989],
      # Vulture
      command_ships: [22444],
      tank_type: "shield",
      engagement_range: "long",
      min_fleet_size: 18,
      logistics_ratio: {0.18, 0.28},
      tactical_role: "sniper",
      strengths: ["extreme_range", "shield_tank", "alpha"],
      weaknesses: ["mobility", "cap_warfare"]
    },

    # Specialized Doctrines
    "leshak_triglavian" => %{
      name: "Leshak Triglavian Fleet",
      # Leshak
      primary_ships: [47270],
      # Guardian, Oneiros
      support_ships: [11987, 12003],
      # Damnation
      command_ships: [22852],
      tank_type: "armor",
      engagement_range: "medium",
      min_fleet_size: 8,
      logistics_ratio: {0.20, 0.35},
      tactical_role: "ramping_dps",
      strengths: ["ramping_damage", "armor_tank", "spider_tank"],
      weaknesses: ["initial_dps", "mobility", "range"]
    }
  }

  # Tactical thresholds and constants
  @optimal_logistics_ratio 0.20
  @min_logistics_ratio 0.10
  @max_logistics_ratio 0.35
  @min_fleet_size_for_analysis 5
  @doctrine_match_threshold 0.70

  ## Public API

  @doc """
  Perform comprehensive fleet composition analysis.

  Analyzes a list of ship type IDs to identify doctrine, assess tactical
  capabilities, and provide actionable recommendations.

  ## Examples
      
      iex> fleet_ships = [641, 641, 641, 11987, 11987]
      iex> FleetAnalyzer.analyze_fleet_composition(fleet_ships)
      %{
        doctrine_classification: %{doctrine: "megathron_armor_fleet", confidence: 0.85},
        tactical_assessment: %{strengths: ["armor_tank", "alpha_strike"], ...},
        role_distribution: %{dps: 0.60, logistics: 0.40, ...},
        recommendations: ["Consider adding EWAR support", ...],
        threat_level: 7.2
      }
  """
  def analyze_fleet_composition(fleet_ships) when is_list(fleet_ships) do
    if length(fleet_ships) < @min_fleet_size_for_analysis do
      {:error, :fleet_too_small}
    else
      Logger.debug("Analyzing fleet composition for #{length(fleet_ships)} ships")

      # Get ship role data for each ship
      ship_role_data = get_ship_role_data(fleet_ships)

      # Perform analysis
      %{
        doctrine_classification: identify_doctrine(fleet_ships, ship_role_data),
        tactical_assessment: assess_fleet_strengths(fleet_ships, ship_role_data),
        role_distribution: calculate_role_balance(ship_role_data),
        recommendations: generate_recommendations(fleet_ships, ship_role_data),
        threat_level: calculate_threat_score(fleet_ships, ship_role_data),
        fleet_size: length(fleet_ships),
        analysis_timestamp: DateTime.utc_now()
      }
    end
  end

  @doc """
  Identify the most likely doctrine for a given fleet composition.

  Returns doctrine classification with confidence score.
  """
  def identify_doctrine(fleet_ships, ship_role_data \\ nil) do
    _role_data = ship_role_data || get_ship_role_data(fleet_ships)

    # Count ship types
    ship_counts = Enum.frequencies(fleet_ships)
    fleet_size = length(fleet_ships)

    # Score each doctrine pattern
    doctrine_scores =
      @doctrine_patterns
      |> Enum.map(fn {doctrine_key, pattern} ->
        score = calculate_doctrine_score(ship_counts, pattern, fleet_size)

        # Logger.debug("Doctrine #{doctrine_key}: score=#{score}, primary_ships=#{inspect(pattern.primary_ships)}, ship_counts=#{inspect(ship_counts)}")
        {doctrine_key, pattern, score}
      end)
      |> Enum.sort_by(fn {_key, _pattern, score} -> score end, :desc)

    case doctrine_scores do
      [{best_doctrine, pattern, score} | _] when score >= @doctrine_match_threshold ->
        %{
          doctrine: best_doctrine,
          doctrine_name: pattern.name,
          confidence: score,
          pattern: pattern,
          match_quality: classify_match_quality(score)
        }

      [{best_doctrine, pattern, score} | _] when score > 0.0 ->
        %{
          doctrine: best_doctrine,
          doctrine_name: pattern.name,
          confidence: score,
          pattern: pattern,
          match_quality: "partial",
          note: "Fleet composition partially matches doctrine pattern"
        }

      _ ->
        %{
          doctrine: "unknown",
          doctrine_name: "Unknown Composition",
          confidence: 0.0,
          match_quality: "poor",
          note: "Fleet composition does not match known doctrine patterns"
        }
    end
  end

  @doc """
  Assess tactical strengths and weaknesses of fleet composition.
  """
  def assess_fleet_strengths(fleet_ships, ship_role_data \\ nil) do
    ship_role_data = ship_role_data || get_ship_role_data(fleet_ships)

    # Calculate tactical metrics
    logistics_analysis = analyze_logistics_ratio(ship_role_data)
    tank_analysis = analyze_tank_consistency(fleet_ships)
    range_analysis = analyze_range_coherence(fleet_ships)
    support_analysis = analyze_support_coverage(ship_role_data)

    # Aggregate tactical assessment
    %{
      logistics: logistics_analysis,
      tank_consistency: tank_analysis,
      range_coherence: range_analysis,
      support_coverage: support_analysis,
      overall_readiness:
        calculate_overall_readiness([
          logistics_analysis.score,
          tank_analysis.score,
          range_analysis.score,
          support_analysis.score
        ])
    }
  end

  @doc """
  Calculate role distribution percentages for the fleet.
  """
  def calculate_role_balance(ship_role_data) do
    total_ships = length(ship_role_data)

    if total_ships == 0 do
      %{
        "dps" => 0.0,
        "logistics" => 0.0,
        "ewar" => 0.0,
        "tackle" => 0.0,
        "command" => 0.0,
        "support" => 0.0
      }
    else
      # Sum up role scores from all ships
      role_totals =
        ship_role_data
        |> Enum.reduce(%{}, fn ship_data, acc ->
          case ship_data do
            %{role_distribution: roles} ->
              Enum.reduce(roles, acc, fn {role, score}, role_acc ->
                Map.update(role_acc, role, score, &(&1 + score))
              end)

            _ ->
              acc
          end
        end)

      # Convert to percentages
      role_totals
      |> Enum.map(fn {role, total} -> {role, total / total_ships} end)
      |> Enum.into(%{})
      |> ensure_all_roles()
    end
  end

  @doc """
  Generate actionable tactical recommendations based on fleet analysis.
  """
  def generate_recommendations(fleet_ships, ship_role_data \\ nil) do
    ship_role_data = ship_role_data || get_ship_role_data(fleet_ships)

    recommendations = []

    # Logistics recommendations
    logistics_analysis = analyze_logistics_ratio(ship_role_data)
    recommendations = recommendations ++ logistics_recommendations(logistics_analysis)

    # Role balance recommendations
    role_balance = calculate_role_balance(ship_role_data)
    recommendations = recommendations ++ role_balance_recommendations(role_balance)

    # Doctrine-specific recommendations
    doctrine_info = identify_doctrine(fleet_ships, ship_role_data)
    recommendations = recommendations ++ doctrine_recommendations(doctrine_info, fleet_ships)

    # Support coverage recommendations
    support_analysis = analyze_support_coverage(ship_role_data)
    recommendations = recommendations ++ support_recommendations(support_analysis)

    recommendations
    |> Enum.uniq()
    # Limit to top 8 recommendations
    |> Enum.take(8)
  end

  @doc """
  Calculate overall threat score for the fleet (0-10 scale).
  """
  def calculate_threat_score(fleet_ships, ship_role_data \\ nil) do
    ship_role_data = ship_role_data || get_ship_role_data(fleet_ships)

    fleet_size = length(fleet_ships)
    role_balance = calculate_role_balance(ship_role_data)

    # Base score from fleet size (logarithmic scaling)
    size_score = min(10.0, :math.log(fleet_size + 1) * 2.0)

    # Role effectiveness multiplier
    role_effectiveness = calculate_role_effectiveness(role_balance)

    # Doctrine bonus
    doctrine_info = identify_doctrine(fleet_ships, ship_role_data)
    doctrine_bonus = doctrine_info.confidence * 2.0

    # Calculate final threat score
    base_threat = size_score * role_effectiveness
    final_threat = min(10.0, base_threat + doctrine_bonus)

    Float.round(final_threat, 1)
  end

  ## Private Functions

  defp get_ship_role_data(fleet_ships) do
    # Get unique ship types
    unique_ship_types = Enum.uniq(fleet_ships)

    # Query ship role patterns for these ships
    query =
      from(s in "ship_role_patterns",
        where: s.ship_type_id in ^unique_ship_types,
        select: %{
          ship_type_id: s.ship_type_id,
          primary_role: s.primary_role,
          role_distribution: s.role_distribution,
          confidence_score: s.confidence_score
        }
      )

    role_data_map =
      Repo.all(query)
      |> Enum.map(fn ship -> {ship.ship_type_id, ship} end)
      |> Enum.into(%{})

    # Map each ship in fleet to its role data
    fleet_ships
    |> Enum.map(fn ship_type_id ->
      case Map.get(role_data_map, ship_type_id) do
        nil ->
          # No role data available, use default classification
          %{
            ship_type_id: ship_type_id,
            primary_role: "unknown",
            role_distribution: %{
              "dps" => 0.5,
              "logistics" => 0.0,
              "ewar" => 0.0,
              "tackle" => 0.0,
              "command" => 0.0,
              "support" => 0.5
            },
            confidence_score: Decimal.from_float(0.1)
          }

        role_data ->
          role_data
      end
    end)
  end

  defp calculate_doctrine_score(ship_counts, pattern, fleet_size) do
    # Check minimum fleet size
    if fleet_size < pattern.min_fleet_size do
      0.0
    else
      primary_ship_score =
        calculate_primary_ship_score(ship_counts, pattern.primary_ships, fleet_size)

      # If no primary ships match, this doctrine doesn't apply
      if primary_ship_score == 0.0 do
        0.0
      else
        support_ship_score =
          calculate_support_ship_score(ship_counts, pattern.support_ships, fleet_size)

        logistics_score =
          calculate_logistics_score(
            ship_counts,
            pattern.support_ships,
            pattern.logistics_ratio,
            fleet_size
          )

        # Weight the scores
        weighted_score =
          primary_ship_score * 0.5 + support_ship_score * 0.3 + logistics_score * 0.2

        min(1.0, weighted_score)
      end
    end
  end

  defp calculate_primary_ship_score(ship_counts, primary_ships, fleet_size) do
    primary_count =
      primary_ships
      |> Enum.map(&Map.get(ship_counts, &1, 0))
      |> Enum.sum()

    if primary_count == 0 do
      0.0
    else
      # Score based on percentage of fleet that are primary ships
      primary_ratio = primary_count / fleet_size
      # Optimal range is 50-80% primary ships
      cond do
        primary_ratio >= 0.5 and primary_ratio <= 0.8 -> 1.0
        primary_ratio >= 0.3 and primary_ratio < 0.5 -> primary_ratio * 2.0
        primary_ratio > 0.8 -> 1.0 - (primary_ratio - 0.8) * 2.0
        true -> primary_ratio * 3.0
      end
    end
  end

  defp calculate_support_ship_score(ship_counts, support_ships, fleet_size) do
    support_count =
      support_ships
      |> Enum.map(&Map.get(ship_counts, &1, 0))
      |> Enum.sum()

    if support_count == 0 do
      # Partial score if no support ships
      0.3
    else
      support_ratio = support_count / fleet_size
      # Optimal support ratio is 15-30%
      cond do
        support_ratio >= 0.15 and support_ratio <= 0.30 -> 1.0
        support_ratio >= 0.10 and support_ratio < 0.15 -> support_ratio * 6.0 - 0.6
        support_ratio > 0.30 -> 1.0 - (support_ratio - 0.30) * 2.0
        true -> support_ratio * 10.0
      end
    end
  end

  defp calculate_logistics_score(
         _ship_counts,
         _support_ships,
         {_min_ratio, _max_ratio},
         fleet_size
       )
       when fleet_size < 5 do
    # Small fleets get partial logistics score
    0.8
  end

  defp calculate_logistics_score(ship_counts, support_ships, {min_ratio, max_ratio}, fleet_size) do
    logistics_count =
      support_ships
      |> Enum.map(&Map.get(ship_counts, &1, 0))
      |> Enum.sum()

    logistics_ratio = logistics_count / fleet_size

    cond do
      logistics_ratio >= min_ratio and logistics_ratio <= max_ratio -> 1.0
      logistics_ratio < min_ratio -> logistics_ratio / min_ratio
      logistics_ratio > max_ratio -> max_ratio / logistics_ratio
      true -> 0.0
    end
  end

  defp classify_match_quality(score) when score >= 0.90, do: "excellent"
  defp classify_match_quality(score) when score >= 0.80, do: "good"
  defp classify_match_quality(score) when score >= 0.70, do: "fair"
  defp classify_match_quality(_score), do: "poor"

  defp analyze_logistics_ratio(ship_role_data) do
    total_ships = length(ship_role_data)

    logistics_count =
      ship_role_data
      |> Enum.count(fn ship -> ship.primary_role == "logistics" end)

    logistics_ratio = if total_ships > 0, do: logistics_count / total_ships, else: 0.0

    %{
      ratio: logistics_ratio,
      count: logistics_count,
      score: calculate_logistics_score_simple(logistics_ratio),
      assessment: assess_logistics_ratio(logistics_ratio),
      recommendation: logistics_ratio_recommendation(logistics_ratio)
    }
  end

  defp calculate_logistics_score_simple(ratio) do
    cond do
      ratio >= @min_logistics_ratio and ratio <= @max_logistics_ratio -> 1.0
      ratio < @min_logistics_ratio -> ratio / @min_logistics_ratio
      ratio > @max_logistics_ratio -> @max_logistics_ratio / ratio
      true -> 0.0
    end
  end

  defp assess_logistics_ratio(ratio) do
    cond do
      ratio < @min_logistics_ratio ->
        "insufficient"

      ratio > @max_logistics_ratio ->
        "excessive"

      ratio >= @optimal_logistics_ratio - 0.05 and ratio <= @optimal_logistics_ratio + 0.05 ->
        "optimal"

      true ->
        "adequate"
    end
  end

  defp logistics_ratio_recommendation(ratio) do
    cond do
      ratio < @min_logistics_ratio -> "Add more logistics ships for sustainability"
      ratio > @max_logistics_ratio -> "Consider converting some logistics to DPS"
      true -> "Logistics ratio is within acceptable range"
    end
  end

  defp analyze_tank_consistency(fleet_ships) do
    # This is a simplified implementation - in practice you'd check ship bonuses and typical fits
    # For now, we'll use ship type patterns to infer tank types

    armor_ships = get_armor_ship_types()
    shield_ships = get_shield_ship_types()

    armor_count = Enum.count(fleet_ships, &(&1 in armor_ships))
    shield_count = Enum.count(fleet_ships, &(&1 in shield_ships))
    total_ships = length(fleet_ships)

    armor_ratio = armor_count / total_ships
    shield_ratio = shield_count / total_ships

    consistency_score = max(armor_ratio, shield_ratio)

    %{
      score: consistency_score,
      dominant_tank: if(armor_ratio > shield_ratio, do: "armor", else: "shield"),
      armor_ratio: armor_ratio,
      shield_ratio: shield_ratio,
      assessment: assess_tank_consistency(consistency_score)
    }
  end

  defp assess_tank_consistency(score) when score >= 0.80, do: "excellent"
  defp assess_tank_consistency(score) when score >= 0.65, do: "good"
  defp assess_tank_consistency(score) when score >= 0.50, do: "mixed"
  defp assess_tank_consistency(_score), do: "inconsistent"

  defp analyze_range_coherence(_fleet_ships) do
    # Simplified implementation - would analyze weapon optimal ranges in practice
    %{
      score: 0.75,
      assessment: "mixed_range",
      dominant_range: "medium_long",
      recommendation: "Consider standardizing engagement range"
    }
  end

  defp analyze_support_coverage(ship_role_data) do
    role_balance = calculate_role_balance(ship_role_data)

    ewar_coverage = role_balance["ewar"] || 0.0
    tackle_coverage = role_balance["tackle"] || 0.0
    command_coverage = role_balance["command"] || 0.0

    coverage_score = min(1.0, (ewar_coverage + tackle_coverage + command_coverage) * 2.0)

    %{
      score: coverage_score,
      ewar_coverage: ewar_coverage,
      tackle_coverage: tackle_coverage,
      command_coverage: command_coverage,
      assessment: assess_support_coverage(coverage_score)
    }
  end

  defp assess_support_coverage(score) when score >= 0.75, do: "comprehensive"
  defp assess_support_coverage(score) when score >= 0.50, do: "adequate"
  defp assess_support_coverage(score) when score >= 0.25, do: "limited"
  defp assess_support_coverage(_score), do: "minimal"

  defp calculate_overall_readiness(scores) do
    average_score = Enum.sum(scores) / length(scores)

    cond do
      average_score >= 0.85 -> "combat_ready"
      average_score >= 0.70 -> "operational"
      average_score >= 0.50 -> "needs_improvement"
      true -> "not_ready"
    end
  end

  defp calculate_role_effectiveness(role_balance) do
    dps_score = min(1.0, (role_balance["dps"] || 0.0) * 1.5)
    logistics_score = calculate_logistics_score_simple(role_balance["logistics"] || 0.0)

    support_score =
      min(1.0, ((role_balance["ewar"] || 0.0) + (role_balance["tackle"] || 0.0)) * 3.0)

    dps_score * 0.5 + logistics_score * 0.3 + support_score * 0.2
  end

  defp ensure_all_roles(role_map) do
    base_roles = %{
      "dps" => 0.0,
      "logistics" => 0.0,
      "ewar" => 0.0,
      "tackle" => 0.0,
      "command" => 0.0,
      "support" => 0.0
    }

    Map.merge(base_roles, role_map)
  end

  defp logistics_recommendations(%{assessment: "insufficient"}) do
    ["Add more logistics ships - current ratio below minimum threshold"]
  end

  defp logistics_recommendations(%{assessment: "excessive"}) do
    ["Consider reducing logistics ships - current ratio above optimal"]
  end

  defp logistics_recommendations(_), do: []

  defp role_balance_recommendations(role_balance) do
    recommendations = []

    # Check for missing critical roles
    recommendations =
      if (role_balance["ewar"] || 0.0) < 0.05 do
        ["Consider adding EWAR support for tactical advantage" | recommendations]
      else
        recommendations
      end

    recommendations =
      if (role_balance["tackle"] || 0.0) < 0.05 do
        ["Add tackle ships for fleet control and engagement management" | recommendations]
      else
        recommendations
      end

    recommendations =
      if (role_balance["command"] || 0.0) < 0.02 do
        ["Consider adding command ship for fleet bonuses" | recommendations]
      else
        recommendations
      end

    recommendations
  end

  defp doctrine_recommendations(%{confidence: confidence}, fleet_ships) when confidence < 0.50 do
    fleet_size = length(fleet_ships)

    cond do
      fleet_size < 10 ->
        ["Consider standardizing around a known small-gang doctrine"]

      fleet_size < 25 ->
        ["Fleet composition doesn't match known doctrines - consider reorganizing"]

      true ->
        ["Large fleet with unknown composition - consider doctrine specialization"]
    end
  end

  defp doctrine_recommendations(%{pattern: pattern}, _fleet_ships) do
    case pattern.tactical_role do
      "alpha_strike" -> ["Focus on alpha damage coordination and target calling"]
      "sniper" -> ["Maintain optimal range and coordinate volleys"]
      "mobile_dps" -> ["Use mobility advantage - avoid prolonged engagements"]
      "kiting_dps" -> ["Maintain range control and use superior mobility"]
      _ -> []
    end
  end

  defp doctrine_recommendations(_, _), do: []

  defp support_recommendations(%{score: score}) when score < 0.30 do
    ["Fleet lacks support ships - consider adding EWAR, tackle, or command ships"]
  end

  defp support_recommendations(_), do: []

  # Ship type classifications (simplified - in practice this would be more comprehensive)
  defp get_armor_ship_types do
    [
      # Megathron
      641,
      # Apocalypse
      642,
      # Armageddon
      643,
      # Guardian
      11987,
      # Oneiros
      12003,
      # Damnation
      22852,
      # Leshak
      47270
    ]
  end

  defp get_shield_ship_types do
    [
      # Machariel
      17738,
      # Ferox
      4306,
      # Hurricane
      4302,
      # Muninn
      22428,
      # Eagle
      12003,
      # Basilisk
      11978,
      # Scimitar
      11989,
      # Vulture
      22444
    ]
  end
end

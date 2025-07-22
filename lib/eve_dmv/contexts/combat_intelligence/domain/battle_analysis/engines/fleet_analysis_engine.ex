defmodule EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysis.Engines.FleetAnalysisEngine do
  @moduledoc """
  Engine for analyzing fleet compositions, doctrine usage, and EWAR presence.

  Responsible for:
  - Analyzing side ship compositions
  - Detecting doctrine usage patterns
  - Identifying EWAR capabilities and intensity
  - Calculating logistics ratios
  - Classifying ship roles and types
  """

  @doc """
  Analyze ship composition for a side in the battle.
  """
  def analyze_side_ship_composition(participants) do
    participants
    |> Enum.flat_map(&MapSet.to_list(&1.ships_used))
    |> Enum.frequencies()
  end

  @doc """
  Detect doctrine usage patterns from ship composition.
  """
  def detect_doctrine_usage(ship_composition) do
    # Detect common doctrine patterns based on ship composition
    if Enum.empty?(ship_composition) do
      %{
        detected_doctrines: [],
        confidence: 0.0,
        analysis: "No ship composition data available"
      }
    else
      # Analyze ship composition to detect doctrine patterns
      ship_analysis = analyze_ship_patterns(ship_composition)
      doctrine_matches = match_known_doctrines(ship_analysis)

      # Calculate overall confidence based on pattern strength
      overall_confidence = calculate_doctrine_confidence(doctrine_matches, ship_analysis)

      %{
        detected_doctrines: doctrine_matches,
        confidence: overall_confidence,
        analysis: generate_doctrine_analysis(doctrine_matches, ship_analysis),
        ship_composition_breakdown: ship_analysis.breakdown,
        total_ships: ship_analysis.total_ships,
        dominant_ship_classes: ship_analysis.dominant_classes
      }
    end
  end

  @doc """
  Calculate the ratio of logistics ships to total ships.
  """
  def calculate_logistics_ratio(ship_composition) do
    # Calculate the ratio of logistics ships to total ships
    total_ships = Enum.sum(Map.values(ship_composition))

    if total_ships > 0 do
      logistics_ships =
        ship_composition

      Enum.filter(fn {ship_type_id, _count} ->
        classify_ship(ship_type_id) == :logistics
      end)

      Enum.map(fn {_, count} -> count end) |> Enum.sum()
      Float.round(logistics_ships / total_ships, 3)
    else
      0.0
    end
  end

  @doc """
  Detect electronic warfare ships and capabilities.
  """
  def detect_ewar_presence(ship_composition) do
    # Detect electronic warfare ships using static ship data
    if Enum.empty?(ship_composition) do
      %{
        ewar_detected: false,
        ewar_ships: [],
        ewar_types: [],
        ewar_intensity: 0.0,
        analysis: "No ship composition data available for EWAR analysis"
      }
    else
      # Analyze all ships in the composition for EWAR capabilities
      all_ships = extract_all_ships_from_composition(ship_composition)
      ewar_analysis = analyze_ships_for_ewar(all_ships)

      # Calculate EWAR intensity based on ship count and types
      ewar_intensity = calculate_ewar_intensity(ewar_analysis, length(all_ships))

      %{
        ewar_detected: length(ewar_analysis.ewar_ships) > 0,
        ewar_ships: ewar_analysis.ewar_ships,
        ewar_types: ewar_analysis.ewar_types,
        ewar_intensity: ewar_intensity,
        total_ewar_ships: length(ewar_analysis.ewar_ships),
        ewar_percentage: calculate_ewar_percentage(ewar_analysis.ewar_ships, all_ships),
        analysis: generate_ewar_analysis(ewar_analysis, ewar_intensity),
        detailed_breakdown: ewar_analysis.breakdown
      }
    end
  end

  # Private helper functions

  defp analyze_ship_patterns(ship_composition) do
    total_ships = Enum.sum(Map.values(ship_composition))

    # Classify ships by category
    ship_classes =
      ship_composition

    Enum.map(fn {ship_type_id, count} ->
      {classify_ship(ship_type_id), count}
    end)

    Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    Enum.map(fn {class, counts} -> {class, Enum.sum(counts)} end) |> Map.new()
    # Find dominant ship classes (>20% of fleet)
    dominant_classes =
      ship_classes

    Enum.filter(fn {_class, count} -> count / total_ships > 0.2 end)
    Enum.map(&elem(&1, 0))

    %{
      breakdown: ship_classes,
      total_ships: total_ships,
      dominant_classes: dominant_classes,
      diversity_score: calculate_ship_diversity(ship_classes, total_ships)
    }
  end

  defp match_known_doctrines(ship_analysis) do
    doctrines = []

    # Analyze for common doctrine patterns
    doctrines =
      doctrines

    maybe_add_doctrine(:artillery_doctrine, detect_artillery_doctrine(ship_analysis))
    maybe_add_doctrine(:logistics_heavy, detect_logistics_heavy(ship_analysis))
    maybe_add_doctrine(:alpha_strike, detect_alpha_strike_doctrine(ship_analysis))
    maybe_add_doctrine(:kiting_comp, detect_kiting_composition(ship_analysis))
    maybe_add_doctrine(:brawling_comp, detect_brawling_composition(ship_analysis))

    doctrines
  end

  defp calculate_doctrine_confidence(doctrine_matches, ship_analysis) do
    if Enum.empty?(doctrine_matches) do
      0.0
    else
      # Base confidence on ship diversity and pattern strength
      # Max 5 possible doctrines
      pattern_strength = length(doctrine_matches) / 5.0
      diversity_factor = min(1.0, ship_analysis.diversity_score)

      Float.round((pattern_strength + diversity_factor) / 2.0, 2)
    end
  end

  defp generate_doctrine_analysis(doctrine_matches, ship_analysis) do
    if Enum.empty?(doctrine_matches) do
      "No clear doctrine patterns detected. Fleet appears to use mixed composition."
    else
      primary_doctrine = List.first(doctrine_matches)
      total_ships = ship_analysis.total_ships

      "Detected #{primary_doctrine} doctrine with #{total_ships} ships. " <>
        "Composition shows #{format_doctrine_characteristics(doctrine_matches, ship_analysis)}."
    end
  end

  defp extract_all_ships_from_composition(ship_composition) do
    ship_composition

    Enum.flat_map(fn {ship_type_id, count} ->
      List.duplicate(ship_type_id, count)
    end)
  end

  defp analyze_ships_for_ewar(ships) do
    ewar_ships = Enum.filter(ships, &is_ewar_ship?/1)
    ewar_types = ewar_ships |> Enum.map(&classify_ewar_type/1) |> Enum.uniq()

    breakdown =
      ewar_ships

    Enum.map(&classify_ewar_type/1) |> Enum.frequencies()

    %{
      ewar_ships: ewar_ships,
      ewar_types: ewar_types,
      breakdown: breakdown
    }
  end

  defp calculate_ewar_intensity(ewar_analysis, total_ships) do
    if total_ships == 0 do
      0.0
    else
      ewar_count = length(ewar_analysis.ewar_ships)
      base_intensity = ewar_count / total_ships

      # Bonus for diversity of EWAR types
      diversity_bonus = length(ewar_analysis.ewar_types) * 0.1

      Float.round(min(1.0, base_intensity + diversity_bonus), 2)
    end
  end

  defp calculate_ewar_percentage(ewar_ships, all_ships) do
    if Enum.empty?(all_ships) do
      0.0
    else
      Float.round(length(ewar_ships) / length(all_ships) * 100, 1)
    end
  end

  defp generate_ewar_analysis(ewar_analysis, intensity) do
    cond do
      intensity >= 0.3 -> "Heavy EWAR presence detected with multiple types"
      intensity >= 0.15 -> "Moderate EWAR capabilities identified"
      intensity > 0 -> "Limited EWAR support present"
      true -> "No significant EWAR presence detected"
    end
  end

  defp classify_ship(ship_type_id) do
    # Classify ship based on type ID ranges (simplified EVE ship classification)
    cond do
      # Frigates
      ship_type_id in [582, 583, 584, 585, 586, 587, 588, 589] -> :frigate
      # Destroyers
      ship_type_id in [16_236, 16_238, 16_240, 16_242] -> :destroyer
      # Cruisers
      ship_type_id in [620, 621, 622, 623, 624, 625, 626, 627] -> :cruiser
      # Battlecruisers
      ship_type_id in [16_227, 16_229, 16_231, 16_233] -> :battlecruiser
      # Battleships
      ship_type_id in [638, 639, 640, 641, 642, 643, 644, 645] -> :battleship
      # Strategic Cruisers (T3C)
      ship_type_id in [29_984, 29_986, 29_988, 29_990] -> :strategic_cruiser
      # Logistics Cruisers
      ship_type_id in [11_985, 11_987, 11_989, 12_003] -> :logistics
      # Recon Ships
      ship_type_id in [11_957, 11_959, 11_961, 11_963] -> :recon
      # Heavy Assault Cruisers
      ship_type_id in [11_991, 12_005, 11_993, 11_995] -> :heavy_assault_cruiser
      # Capital ships
      ship_type_id > 20_000 and ship_type_id < 30_000 -> :capital
      # Default
      true -> :unknown
    end
  end

  defp calculate_ship_diversity(ship_classes, total_ships) do
    if total_ships == 0 do
      0.0
    else
      # Shannon diversity index calculation
      proportions =
        Map.values(ship_classes)

      Enum.map(&(&1 / total_ships))

      entropy =
        proportions

      Enum.map(fn p -> if p > 0, do: -p * :math.log2(p), else: 0 end) |> Enum.sum()
      # Normalize to 0-1 scale
      max_entropy = :math.log2(map_size(ship_classes))
      if max_entropy > 0, do: entropy / max_entropy, else: 0.0
    end
  end

  defp maybe_add_doctrine(doctrines, doctrine_name, detected?) do
    if detected?, do: [doctrine_name | doctrines], else: doctrines
  end

  defp detect_artillery_doctrine(ship_analysis) do
    # Look for battleships/battlecruisers dominance
    battleship_ratio =
      Map.get(ship_analysis.breakdown, :battleship, 0) / ship_analysis.total_ships

    battlecruiser_ratio =
      Map.get(ship_analysis.breakdown, :battlecruiser, 0) / ship_analysis.total_ships

    battleship_ratio + battlecruiser_ratio > 0.4
  end

  defp detect_logistics_heavy(ship_analysis) do
    logistics_ratio = Map.get(ship_analysis.breakdown, :logistics, 0) / ship_analysis.total_ships
    # >15% logistics ships
    logistics_ratio > 0.15
  end

  defp detect_alpha_strike_doctrine(ship_analysis) do
    # Look for high-damage ships without much logistics
    battleship_ratio =
      Map.get(ship_analysis.breakdown, :battleship, 0) / ship_analysis.total_ships

    logistics_ratio = Map.get(ship_analysis.breakdown, :logistics, 0) / ship_analysis.total_ships

    battleship_ratio > 0.5 and logistics_ratio < 0.1
  end

  defp detect_kiting_composition(ship_analysis) do
    # Look for cruiser/destroyer heavy with low battleship presence
    cruiser_ratio = Map.get(ship_analysis.breakdown, :cruiser, 0) / ship_analysis.total_ships
    destroyer_ratio = Map.get(ship_analysis.breakdown, :destroyer, 0) / ship_analysis.total_ships

    battleship_ratio =
      Map.get(ship_analysis.breakdown, :battleship, 0) / ship_analysis.total_ships

    cruiser_ratio + destroyer_ratio > 0.6 and battleship_ratio < 0.2
  end

  defp detect_brawling_composition(ship_analysis) do
    # Look for mixed ship classes with good logistics support
    diversity = ship_analysis.diversity_score
    logistics_ratio = Map.get(ship_analysis.breakdown, :logistics, 0) / ship_analysis.total_ships

    diversity > 0.6 and logistics_ratio > 0.1 and logistics_ratio < 0.3
  end

  defp format_doctrine_characteristics(doctrine_matches, ship_analysis) do
    primary = List.first(doctrine_matches)
    ship_count = ship_analysis.total_ships
    diversity = Float.round(ship_analysis.diversity_score * 100, 0)

    "#{primary} characteristics with #{ship_count} ships and #{diversity}% composition diversity"
  end

  defp is_ewar_ship?(ship_type_id) do
    # EWAR ship classification based on ship types
    ewar_ship_types = [
      # Recon ships
      11_957,
      11_959,
      11_961,
      11_963,
      # ECM ships  
      11_965,
      11_969,
      11_971,
      11_973,
      # Force recon
      12_019,
      12_021,
      12_023,
      12_025
    ]

    ship_type_id in ewar_ship_types
  end

  defp classify_ewar_type(ship_type_id) do
    cond do
      ship_type_id in [11_965, 11_969] -> :ecm
      ship_type_id in [11_971, 11_973] -> :sensor_dampening
      ship_type_id in [12_019, 12_021] -> :tracking_disruption
      ship_type_id in [12_023, 12_025] -> :target_painting
      true -> :general_ewar
    end
  end
end

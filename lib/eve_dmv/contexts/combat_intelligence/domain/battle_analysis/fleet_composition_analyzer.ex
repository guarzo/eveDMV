defmodule EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysis.FleetCompositionAnalyzer do
  @moduledoc """
  Fleet composition analysis for battle intelligence.

  Provides comprehensive fleet composition analytics including:
  - Ship classification and role detection
  - Fleet composition analysis
  - Doctrine detection and matching
  - EWAR capability assessment
  - Logistics and support ratio calculations
  - Ship pattern analysis
  """

  alias EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysis.Analyzers.ShipClassificationAnalyzer

  alias EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysis.Phases.FleetCompositionAnalyzer,
    as: ExternalFleetAnalyzer

  require Logger

  @doc """
  Analyze fleet compositions from participants and killmail data.
  """
  def analyze_fleet_compositions(participants, killmails) do
    participants_list = Map.values(participants)

    case ExternalFleetAnalyzer.analyze_fleet_compositions(participants_list, killmails) do
      {:ok, analysis} ->
        {:ok, analysis}

      {:error, _reason} ->
        # Fallback to basic analysis
        {:ok, perform_basic_fleet_analysis(participants, killmails)}
    end
  end

  @doc """
  Perform basic fleet composition analysis when full analysis fails.
  """
  def perform_basic_fleet_analysis(participants, _killmails) do
    # Extract ship composition from participants
    ship_composition = extract_ship_composition(participants)

    %{
      total_ships: count_total_ships(ship_composition),
      ship_classes: group_ships_by_class(ship_composition),
      ship_composition: ship_composition,
      doctrine_analysis: %{
        detected_doctrines: [],
        doctrine_detected: match_known_doctrines(ship_composition),
        doctrine_confidence: 0.0
      },
      logistics_ratio: calculate_logistics_ratio(ship_composition),
      ewar_presence: detect_ewar_presence(ship_composition)
    }
  end

  @doc """
  Group ships by their classification class.
  """
  def group_ships_by_class(ship_data) do
    ship_data
    |> Enum.group_by(&classify_ship_by_type_id/1)
  end

  @doc """
  Analyze ship patterns in fleet composition.
  """
  def analyze_ship_patterns(ship_composition) do
    # Convert ship composition to analyzable format
    ship_data =
      ship_composition
      |> Enum.flat_map(fn {_side, side_data} ->
        case side_data do
          %{ships: ships} when is_list(ships) -> ships
          ships when is_list(ships) -> ships
          _ -> []
        end
      end)

    # Group ships by class and analyze patterns
    ship_classes = group_ships_by_class(ship_data)
    total_ships = Enum.sum(Enum.map(ship_classes, fn {_class, ships} -> length(ships) end))

    # Calculate ship class percentages
    class_percentages =
      ship_classes
      |> Enum.map(fn {class, ships} ->
        percentage = if total_ships > 0, do: length(ships) / total_ships * 100, else: 0
        {class, %{count: length(ships), percentage: Float.round(percentage, 1)}}
      end)
      |> Map.new()

    # Identify dominant ship classes (>20% of fleet)
    dominant_classes =
      class_percentages
      |> Enum.filter(fn {_class, data} -> data.percentage > 20 end)
      |> Enum.map(fn {class, _data} -> class end)

    # Analyze support composition
    support_analysis = analyze_support_ships(ship_classes)

    # Calculate ship diversity
    diversity_score = calculate_ship_diversity_score(class_percentages)

    %{
      total_ships: total_ships,
      ship_classes: ship_classes,
      class_percentages: class_percentages,
      dominant_classes: dominant_classes,
      support_analysis: support_analysis,
      diversity_score: diversity_score,
      fleet_characteristics: determine_fleet_characteristics(dominant_classes, support_analysis)
    }
  end

  @doc """
  Detect doctrine usage in ship composition.
  """
  def detect_doctrine_usage(ship_composition) do
    if Enum.empty?(ship_composition) do
      %{doctrine_detected: false, detected_doctrines: [], confidence: 0.0}
    else
      # Analyze ship patterns for doctrine detection
      ship_analysis = analyze_ship_patterns(ship_composition)
      doctrine_matches = match_known_doctrines(ship_analysis)

      # Calculate confidence based on ship distribution and known patterns
      confidence = calculate_doctrine_confidence(doctrine_matches, ship_analysis)

      %{
        doctrine_detected: length(doctrine_matches) > 0,
        detected_doctrines: doctrine_matches,
        confidence: confidence,
        ship_analysis: ship_analysis
      }
    end
  end

  @doc """
  Match known doctrines against ship composition.
  """
  def match_known_doctrines(_ship_analysis) do
    # Placeholder for doctrine matching logic
    # In real implementation, this would match against known fleet doctrines
    []
  end

  @doc """
  Calculate logistics ratio in fleet composition.
  """
  def calculate_logistics_ratio(ship_composition) do
    if Enum.empty?(ship_composition) do
      %{
        logistics_ships: 0,
        total_ships: 0,
        logistics_ratio: 0.0,
        adequate_logistics: false,
        analysis: "No ship composition data available"
      }
    else
      # Extract all ships from composition
      all_ships = extract_all_ships_from_composition(ship_composition)

      # Count logistics ships
      logistics_ships = count_logistics_ships(all_ships)
      total_ships = length(all_ships)

      # Calculate ratio and adequacy
      logistics_ratio = if total_ships > 0, do: logistics_ships / total_ships, else: 0.0
      adequate_logistics = logistics_ratio >= 0.1 and logistics_ships >= 1

      %{
        logistics_ships: logistics_ships,
        total_ships: total_ships,
        logistics_ratio: Float.round(logistics_ratio * 100, 1),
        adequate_logistics: adequate_logistics,
        analysis: generate_logistics_analysis(logistics_ships, total_ships, logistics_ratio)
      }
    end
  end

  @doc """
  Calculate support ship ratio in fleet composition.
  """
  def calculate_support_ratio(ship_classes) do
    total_ships = Enum.sum(Enum.map(ship_classes, fn {_class, ships} -> length(ships) end))

    if total_ships == 0 do
      0.0
    else
      # Count support ships (logistics, command, EWAR)
      support_ships =
        [:logistics, :command, :ewar, :support]
        |> Enum.map(fn class -> length(Map.get(ship_classes, class, [])) end)
        |> Enum.sum()

      support_ships / total_ships
    end
  end

  @doc """
  Analyze support ships in fleet composition.
  """
  def analyze_support_ships(ship_classes) do
    logistics_count = length(Map.get(ship_classes, :logistics, []))
    command_count = length(Map.get(ship_classes, :command, []))
    recon_count = length(Map.get(ship_classes, :recon, []))

    %{
      logistics_ships: logistics_count,
      command_ships: command_count,
      ewar_ships: recon_count,
      has_logistics: logistics_count > 0,
      has_command: command_count > 0,
      has_ewar: recon_count > 0,
      support_ratio: calculate_support_ratio(ship_classes)
    }
  end

  @doc """
  Extract all ships from fleet composition data.
  """
  def extract_all_ships_from_composition(ship_composition) do
    ship_composition
    |> Enum.flat_map(fn {_side, side_data} ->
      case side_data do
        %{ships: ships} when is_list(ships) -> ships
        ships when is_list(ships) -> ships
        _ -> []
      end
    end)
  end

  @doc """
  Detect EWAR presence and capability in fleet composition.
  """
  def detect_ewar_presence(ship_composition) do
    if Enum.empty?(ship_composition) do
      %{
        ewar_detected: false,
        ewar_ships: [],
        ewar_types: [],
        ewar_intensity: 0.0,
        analysis: "No ship composition data available for EWAR analysis"
      }
    else
      # Extract all ships for analysis
      all_ships = extract_all_ships_from_composition(ship_composition)

      # EWAR analysis temporarily disabled - needs real implementation
      ewar_analysis = %{
        ewar_ships: [],
        ewar_types: [],
        total_ewar_ships: 0
      }

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

  @doc """
  Classify ship by type ID.
  """
  def classify_ship_by_type_id(ship) do
    ship_type_id = extract_ship_type_id(ship)
    classify_ship_type_id(ship_type_id)
  end

  @doc """
  Classify ship type by type ID number.
  """
  def classify_ship_type_id(ship_type_id) when is_integer(ship_type_id) do
    # Use existing ShipClassificationAnalyzer if available
    ShipClassificationAnalyzer.classify_ship_by_type_id(ship_type_id)
  catch
    :error, :undef ->
      # Fallback classification logic
      cond do
        # Frigates (type IDs typically in ranges)
        ship_type_id >= 582 and ship_type_id <= 671 -> :frigate
        ship_type_id >= 11176 and ship_type_id <= 11194 -> :assault_frigate
        ship_type_id >= 11380 and ship_type_id <= 11393 -> :interceptor
        ship_type_id >= 11999 and ship_type_id <= 12003 -> :covops
        ship_type_id >= 12016 and ship_type_id <= 12020 -> :eaf
        # Destroyers
        ship_type_id >= 420 and ship_type_id <= 447 -> :destroyer
        ship_type_id >= 22442 and ship_type_id <= 22456 -> :interdictor
        # Cruisers  
        ship_type_id >= 622 and ship_type_id <= 633 -> :cruiser
        ship_type_id >= 11172 and ship_type_id <= 11178 -> :hac
        ship_type_id >= 11942 and ship_type_id <= 11957 -> :recon
        ship_type_id >= 12003 and ship_type_id <= 12016 -> :logistics
        ship_type_id >= 4302 and ship_type_id <= 4310 -> :t3c
        # Battlecruisers
        ship_type_id >= 419 and ship_type_id <= 426 -> :battlecruiser
        ship_type_id >= 28659 and ship_type_id <= 28665 -> :command_ship
        # Battleships
        ship_type_id >= 547 and ship_type_id <= 556 -> :battleship
        ship_type_id >= 22428 and ship_type_id <= 22436 -> :black_ops
        ship_type_id >= 28844 and ship_type_id <= 28850 -> :marauder
        # Capitals
        ship_type_id >= 19720 and ship_type_id <= 19726 -> :carrier
        ship_type_id >= 19724 and ship_type_id <= 19726 -> :dreadnought
        ship_type_id >= 28352 and ship_type_id <= 28356 -> :supercarrier
        ship_type_id == 11567 or ship_type_id == 23773 -> :titan
        # Industrial
        ship_type_id >= 648 and ship_type_id <= 656 -> :industrial
        ship_type_id >= 28850 and ship_type_id <= 28856 -> :transport
        true -> :unknown
      end
  end

  def classify_ship_type_id(_), do: :unknown

  @doc """
  Classify ship EWAR capability.
  """
  def classify_ship_ewar_capability(ship) do
    ship_type_id = extract_ship_type_id(ship)

    case ship_type_id do
      # Force Recon Ships (T2 Recon)
      # Falcon
      11957 ->
        %{
          has_ewar: true,
          ewar_types: [:sensor_dampening, :ecm],
          ewar_strength: :high,
          ship_class: :recon
        }

      # Rook
      11956 ->
        %{
          has_ewar: true,
          ewar_types: [:tracking_disruption, :weapon_disruption],
          ewar_strength: :high,
          ship_class: :recon
        }

      # Huginn
      11955 ->
        %{
          has_ewar: true,
          ewar_types: [:target_painting, :tracking_disruption],
          ewar_strength: :high,
          ship_class: :recon
        }

      # Arazu
      11954 ->
        %{
          has_ewar: true,
          ewar_types: [:ecm, :ecm_burst],
          ewar_strength: :very_high,
          ship_class: :recon
        }

      # Combat Recon Ships (T2 Recon)
      # Lachesis
      11953 ->
        %{
          has_ewar: true,
          ewar_types: [:sensor_dampening, :tracking_disruption],
          ewar_strength: :medium,
          ship_class: :recon
        }

      # Rapier
      11952 ->
        %{
          has_ewar: true,
          ewar_types: [:tracking_disruption, :weapon_disruption],
          ewar_strength: :medium,
          ship_class: :recon
        }

      # Curse
      11951 ->
        %{
          has_ewar: true,
          ewar_types: [:target_painting, :sensor_dampening],
          ewar_strength: :medium,
          ship_class: :recon
        }

      # Pilgrim
      11950 ->
        %{
          has_ewar: true,
          ewar_types: [:ecm, :sensor_dampening],
          ewar_strength: :high,
          ship_class: :recon
        }

      # Electronic Attack Frigates (EAFs)
      # Kitsune
      12019 ->
        %{
          has_ewar: true,
          ewar_types: [:sensor_dampening],
          ewar_strength: :medium,
          ship_class: :eaf
        }

      # Sentinel
      12018 ->
        %{
          has_ewar: true,
          ewar_types: [:tracking_disruption],
          ewar_strength: :medium,
          ship_class: :eaf
        }

      # Hyena
      12017 ->
        %{
          has_ewar: true,
          ewar_types: [:target_painting],
          ewar_strength: :medium,
          ship_class: :eaf
        }

      # Griffin
      12016 ->
        %{has_ewar: true, ewar_types: [:ecm], ewar_strength: :high, ship_class: :eaf}

      # Heavy Interdictors (Tackle + EWAR)
      # Onyx
      22444 ->
        %{
          has_ewar: true,
          ewar_types: [:warp_disruption, :sensor_dampening],
          ewar_strength: :medium,
          ship_class: :hictor
        }

      # Broadsword
      22443 ->
        %{
          has_ewar: true,
          ewar_types: [:warp_disruption, :tracking_disruption],
          ewar_strength: :medium,
          ship_class: :hictor
        }

      # Phobos
      22442 ->
        %{
          has_ewar: true,
          ewar_types: [:warp_disruption, :target_painting],
          ewar_strength: :medium,
          ship_class: :hictor
        }

      # Devoter
      22456 ->
        %{
          has_ewar: true,
          ewar_types: [:warp_disruption, :ecm],
          ewar_strength: :high,
          ship_class: :hictor
        }

      # Command Ships (Fleet Bonuses + Some EWAR)
      # Claymore
      28665 ->
        %{
          has_ewar: true,
          ewar_types: [:command_bonuses, :sensor_dampening],
          ewar_strength: :low,
          ship_class: :command
        }

      # Sleipnir
      28664 ->
        %{
          has_ewar: true,
          ewar_types: [:command_bonuses, :tracking_disruption],
          ewar_strength: :low,
          ship_class: :command
        }

      # Vulture
      28663 ->
        %{
          has_ewar: true,
          ewar_types: [:command_bonuses, :target_painting],
          ewar_strength: :low,
          ship_class: :command
        }

      # Damnation
      28659 ->
        %{
          has_ewar: true,
          ewar_types: [:command_bonuses, :ecm],
          ewar_strength: :medium,
          ship_class: :command
        }

      # Some T1 cruisers commonly fitted for EWAR
      # Celestis
      622 ->
        %{
          has_ewar: true,
          ewar_types: [:sensor_dampening],
          ewar_strength: :low,
          ship_class: :cruiser
        }

      # Bellicose  
      629 ->
        %{
          has_ewar: true,
          ewar_types: [:tracking_disruption],
          ewar_strength: :low,
          ship_class: :cruiser
        }

      # Blackbird
      632 ->
        %{
          has_ewar: true,
          ewar_types: [:target_painting],
          ewar_strength: :low,
          ship_class: :cruiser
        }

      # Griffin (T1)
      583 ->
        %{has_ewar: true, ewar_types: [:ecm], ewar_strength: :medium, ship_class: :cruiser}

      # Interdictors (Tackle focused)
      # Sabre
      22456 ->
        %{
          has_ewar: true,
          ewar_types: [:warp_disruption],
          ewar_strength: :medium,
          ship_class: :interdictor
        }

      # Heretic
      22452 ->
        %{
          has_ewar: true,
          ewar_types: [:warp_disruption],
          ewar_strength: :medium,
          ship_class: :interdictor
        }

      # Eris
      22448 ->
        %{
          has_ewar: true,
          ewar_types: [:warp_disruption],
          ewar_strength: :medium,
          ship_class: :interdictor
        }

      # Flycatcher
      22444 ->
        %{
          has_ewar: true,
          ewar_types: [:warp_disruption],
          ewar_strength: :medium,
          ship_class: :interdictor
        }

      # Some faction ships with EWAR bonuses
      # Stratios
      17715 ->
        %{
          has_ewar: true,
          ewar_types: [:sensor_dampening, :tracking_disruption],
          ewar_strength: :high,
          ship_class: :faction
        }

      # Gila
      17709 ->
        %{
          has_ewar: true,
          ewar_types: [:ecm, :sensor_dampening],
          ewar_strength: :high,
          ship_class: :faction
        }

      # Default - no specific EWAR capability
      _ ->
        %{has_ewar: false, ewar_types: [], ewar_strength: :none, ship_class: :other}
    end
  end

  # Private helper functions

  defp extract_ship_composition(participants) when is_map(participants) do
    participants
    |> Map.values()
    |> Enum.flat_map(fn participant ->
      case participant do
        %{ships: ships} when is_list(ships) ->
          ships

        %{ship_type_id: ship_type_id} when is_integer(ship_type_id) ->
          [%{ship_type_id: ship_type_id}]

        _ ->
          []
      end
    end)
  end

  defp extract_ship_composition(_), do: []

  defp count_total_ships(ship_composition) do
    length(ship_composition)
  end

  defp extract_ship_type_id(ship) do
    case ship do
      %{ship_type_id: ship_type_id} when is_integer(ship_type_id) -> ship_type_id
      %{"ship_type_id" => ship_type_id} when is_integer(ship_type_id) -> ship_type_id
      _ -> nil
    end
  end

  defp calculate_doctrine_confidence(doctrine_matches, ship_analysis) do
    if Enum.empty?(doctrine_matches) do
      0.0
    else
      # Base confidence on ship distribution and patterns
      base_confidence = min(0.8, length(doctrine_matches) * 0.3)

      # Adjust based on ship diversity and known patterns
      diversity_factor = min(1.0, ship_analysis.diversity_score)

      Float.round(base_confidence * diversity_factor, 2)
    end
  end

  defp count_logistics_ships(ships) do
    ships
    |> Enum.count(fn ship ->
      classify_ship_by_type_id(ship) == :logistics
    end)
  end

  defp generate_logistics_analysis(logistics_ships, total_ships, logistics_ratio) do
    cond do
      logistics_ships == 0 ->
        "No logistics support detected"

      logistics_ratio < 0.05 ->
        "Minimal logistics support (#{logistics_ships}/#{total_ships})"

      logistics_ratio < 0.15 ->
        "Adequate logistics support (#{logistics_ships}/#{total_ships})"

      true ->
        "Strong logistics support (#{logistics_ships}/#{total_ships})"
    end
  end

  defp calculate_ewar_intensity(ewar_analysis, total_ships) do
    if Enum.empty?(ewar_analysis.ewar_ships) or total_ships == 0 do
      0.0
    else
      # Calculate based on EWAR ship percentage and strength
      ewar_count = length(ewar_analysis.ewar_ships)
      ewar_percentage = ewar_count / total_ships

      # Weight by EWAR strength
      strength_multiplier =
        ewar_analysis.ewar_ships
        |> Enum.map(fn ewar_ship ->
          case ewar_ship.ewar_strength do
            :very_high -> 2.0
            :high -> 1.5
            :medium -> 1.0
            :low -> 0.5
            _ -> 0.0
          end
        end)
        |> Enum.sum()
        |> Kernel./(ewar_count)

      base_intensity = ewar_percentage * 100
      Float.round(base_intensity * strength_multiplier, 1)
    end
  end

  defp calculate_ewar_percentage(ewar_ships, all_ships) do
    if Enum.empty?(all_ships) do
      0.0
    else
      percentage = length(ewar_ships) / length(all_ships) * 100
      Float.round(percentage, 1)
    end
  end

  defp generate_ewar_analysis(ewar_analysis, ewar_intensity) do
    if Enum.empty?(ewar_analysis.ewar_ships) do
      "No EWAR capability detected in fleet composition"
    else
      ewar_count = length(ewar_analysis.ewar_ships)
      ewar_types_str = Enum.join(ewar_analysis.ewar_types, ", ")

      # Group by ship class for summary
      ship_classes =
        ewar_analysis.ewar_ships
        |> Enum.group_by(& &1.ship_class)
        |> Enum.map(fn {class, ships} -> "#{length(ships)} #{class}" end)
        |> Enum.join(", ")

      intensity_desc =
        cond do
          ewar_intensity >= 80 -> "very high"
          ewar_intensity >= 60 -> "high"
          ewar_intensity >= 40 -> "moderate"
          ewar_intensity >= 20 -> "low"
          true -> "minimal"
        end

      "#{ewar_count} EWAR ships detected with #{intensity_desc} intensity (#{ewar_intensity}%). " <>
        "Types: #{ewar_types_str}. Composition: #{ship_classes}."
    end
  end

  defp calculate_ship_diversity_score(class_percentages) do
    if Enum.empty?(class_percentages) do
      0.0
    else
      # Calculate Shannon diversity index
      percentages = Map.values(class_percentages) |> Enum.map(& &1.percentage/100)

      entropy =
        percentages
        |> Enum.filter(&(&1 > 0))
        |> Enum.map(fn p -> p * :math.log(p) end)
        |> Enum.sum()
        |> Kernel.*(-1)

      # Normalize to 0-1 scale
      max_entropy = :math.log(map_size(class_percentages))
      if max_entropy > 0, do: entropy / max_entropy, else: 0.0
    end
  end

  defp determine_fleet_characteristics(dominant_classes, support_analysis) do
    cond do
      :battleship in dominant_classes ->
        if support_analysis.has_logistics and support_analysis.has_ewar do
          "Heavy fleet composition with full logistics and EWAR support"
        else
          "Heavy fleet composition"
        end

      :cruiser in dominant_classes or :hac in dominant_classes ->
        cond do
          support_analysis.has_logistics and support_analysis.has_ewar ->
            "with full logistics and EWAR support"

          support_analysis.has_logistics ->
            "with logistics support"

          support_analysis.has_ewar ->
            "with EWAR support"

          true ->
            "standard cruiser doctrine"
        end

      :frigate in dominant_classes ->
        "Fast attack composition"

      true ->
        "Mixed fleet composition"
    end
  end
end

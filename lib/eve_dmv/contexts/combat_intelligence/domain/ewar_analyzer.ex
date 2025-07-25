defmodule EveDmv.Contexts.CombatIntelligence.Domain.EwarAnalyzer do
  @moduledoc """
  Electronic Warfare (EWAR) ship detection and analysis for EVE Online.

  Identifies and analyzes EWAR capabilities including:
  - ECM (Electronic Counter Measures) - Jamming
  - Sensor Dampeners - Range/scan resolution reduction
  - Tracking Disruptors - Tracking/range disruption
  - Target Painters - Signature bloom
  - Energy Neutralizers - Capacitor warfare
  - Warp Disruptors/Scramblers - Tackle

  Provides threat assessment and counter-strategy recommendations.
  """

  alias EveDmv.StaticData

  require Logger

  # EWAR ship definitions by type
  @ewar_ships %{
    # ECM Ships
    ecm: %{
      t1: ["Griffin", "Blackbird", "Scorpion"],
      t2: ["Kitsune", "Falcon", "Rook", "Widow"],
      faction: ["Griffin Navy Issue", "Scorpion Navy Issue"],
      description: "Jamming - Breaks target locks"
    },

    # Sensor Dampeners
    damps: %{
      t1: ["Maulus", "Celestis"],
      t2: ["Keres", "Arazu", "Lachesis"],
      navy: ["Maulus Navy Issue", "Celestis Navy Issue"],
      description: "Sensor dampening - Reduces targeting range and scan resolution"
    },

    # Tracking Disruptors
    tracking_disruptors: %{
      t1: ["Crucifier", "Arbitrator"],
      t2: ["Sentinel", "Pilgrim", "Curse"],
      navy: ["Crucifier Navy Issue", "Arbitrator Navy Issue"],
      pirate: ["Ashimmu", "Bhaalgorn"],
      description: "Tracking disruption - Reduces turret tracking and range"
    },

    # Target Painters
    target_painters: %{
      t1: ["Vigil", "Bellicose", "Cyclone"],
      t2: ["Hyena", "Huginn", "Loki"],
      faction: ["Vigil Fleet Issue", "Bellicose Fleet Issue"],
      description: "Target painting - Increases target signature"
    },

    # Energy Warfare
    neuts: %{
      t1: ["Arbitrator", "Vexor", "Dominix"],
      t2: ["Sentinel", "Pilgrim", "Curse"],
      pirate: ["Cruor", "Ashimmu", "Bhaalgorn"],
      description: "Energy neutralization - Drains capacitor"
    },

    # Warp Disruption
    tackle: %{
      interdictors: ["Sabre", "Flycatcher", "Eris", "Heretic"],
      heavy_interdictors: ["Broadsword", "Onyx", "Devoter", "Phobos"],
      description: "Warp disruption - Prevents warping/MWD"
    }
  }

  # EWAR module type IDs (simplified subset)
  @ewar_modules %{
    # ECM
    ecm: [
      # Multispectral ECM
      1_952,
      1_953,
      1_954,
      1_955,
      # Racial ECM
      1_956,
      1_957,
      1_958,
      1_959
    ],
    # Damps
    sensor_dampener: [
      # Remote Sensor Dampener
      1_847,
      1_848,
      1_849,
      # T2 variants
      14_244,
      14_246
    ],
    # Tracking Disruptors
    tracking_disruptor: [
      # Tracking Disruptor
      1_978,
      1_979,
      # T2 variants
      14_250,
      14_252
    ],
    # Target Painters
    target_painter: [
      # Target Painter
      12_084,
      12_086,
      # T2 variants
      14_264,
      14_266
    ],
    # Neuts
    energy_neutralizer: [
      # Small/Medium/Heavy
      12_262,
      12_264,
      12_266,
      # T2 variants
      12_268,
      12_270
    ],
    # Points/Scrams
    warp_disruptor: [
      # Warp Disruptor/Scrambler
      3_241,
      3_243,
      # T2 variants
      14_660,
      14_662
    ]
  }

  @doc """
  Detect if a ship is an EWAR platform based on type ID or name.

  Returns detailed EWAR capabilities and threat assessment.
  """
  def analyze_ewar_ship(ship_type_id) when is_integer(ship_type_id) do
    with {:ok, ship_info} <- get_ship_info(ship_type_id) do
      analyze_ewar_capabilities(ship_info)
    end
  end

  def analyze_ewar_ship(ship_name) when is_binary(ship_name) do
    ewar_types = detect_ewar_types(ship_name)

    if Enum.empty?(ewar_types) do
      {:ok, %{is_ewar: false, ship_name: ship_name}}
    else
      {:ok, build_ewar_analysis(ship_name, ewar_types)}
    end
  end

  @doc """
  Analyze EWAR composition in a fleet or killmail.
  """
  def analyze_fleet_ewar(ship_list) when is_list(ship_list) do
    ewar_ships =
      ship_list
      |> Enum.map(&analyze_single_ship/1)
      |> Enum.filter(& &1.is_ewar)

    fleet_analysis = %{
      total_ships: length(ship_list),
      ewar_count: length(ewar_ships),
      ewar_percentage: calculate_percentage(length(ewar_ships), length(ship_list)),
      ewar_breakdown: group_ewar_by_type(ewar_ships),
      threat_assessment: assess_fleet_ewar_threat(ewar_ships),
      coverage_gaps: identify_ewar_gaps(ewar_ships),
      counter_recommendations: generate_counter_recommendations(ewar_ships)
    }

    {:ok, fleet_analysis}
  end

  @doc """
  Detect EWAR modules from killmail fitting data.
  """
  def detect_ewar_modules(fitting_items) when is_list(fitting_items) do
    ewar_items =
      fitting_items
      |> Enum.filter(&ewar_module?/1)
      |> Enum.map(&categorize_ewar_module/1)

    module_analysis = %{
      has_ewar: not Enum.empty?(ewar_items),
      module_count: length(ewar_items),
      module_types: Enum.frequencies_by(ewar_items, & &1.type),
      estimated_effectiveness: estimate_module_effectiveness(ewar_items),
      primary_ewar_role: determine_primary_ewar_role(ewar_items)
    }

    {:ok, module_analysis}
  end

  @doc """
  Generate EWAR threat profile for a specific ship.
  """
  def generate_threat_profile(ship_analysis) do
    threat_level = calculate_threat_level(ship_analysis)

    threat_profile = %{
      threat_level: threat_level,
      threat_score: calculate_threat_score(ship_analysis),
      primary_danger: ship_analysis.primary_ewar_type,
      effective_range: estimate_effective_range(ship_analysis),
      counter_difficulty: assess_counter_difficulty(ship_analysis),
      priority_target: should_primary?(ship_analysis),
      tactical_notes: generate_tactical_notes(ship_analysis)
    }

    {:ok, threat_profile}
  end

  # Private implementation functions

  defp get_ship_info(ship_type_id) do
    case StaticData.get_type(ship_type_id) do
      %{} = type_info -> {:ok, type_info}
      nil -> {:error, :ship_not_found}
    end
  end

  defp analyze_ewar_capabilities(ship_info) do
    ship_name = ship_info.type_name
    ewar_types = detect_ewar_types(ship_name)

    if Enum.empty?(ewar_types) do
      {:ok, %{is_ewar: false, ship_name: ship_name, ship_id: ship_info.type_id}}
    else
      analysis =
        build_ewar_analysis(ship_name, ewar_types)
        |> Map.put(:ship_id, ship_info.type_id)
        |> Map.put(:ship_group, ship_info.group_name)
        |> add_ship_bonuses(ship_info)

      {:ok, analysis}
    end
  end

  defp detect_ewar_types(ship_name) do
    normalized_name = String.downcase(ship_name)

    @ewar_ships
    |> Enum.reduce([], fn {ewar_type, ships}, acc ->
      all_ships =
        List.flatten([
          Map.get(ships, :t1, []),
          Map.get(ships, :t2, []),
          Map.get(ships, :faction, []),
          Map.get(ships, :navy, []),
          Map.get(ships, :pirate, []),
          Map.get(ships, :interdictors, []),
          Map.get(ships, :heavy_interdictors, [])
        ])

      if Enum.any?(all_ships, fn ship ->
           String.downcase(ship) == normalized_name
         end) do
        [ewar_type | acc]
      else
        acc
      end
    end)
  end

  defp build_ewar_analysis(ship_name, ewar_types) do
    primary_type = List.first(ewar_types)
    ship_category = determine_ship_category(ship_name, primary_type)

    %{
      is_ewar: true,
      ship_name: ship_name,
      ewar_types: ewar_types,
      primary_ewar_type: primary_type,
      ship_category: ship_category,
      capabilities: build_capability_list(ewar_types),
      effectiveness: estimate_ship_effectiveness(ship_name, primary_type),
      optimal_range: estimate_optimal_range(primary_type, ship_category),
      strengths: identify_strengths(ship_name, ewar_types),
      weaknesses: identify_weaknesses(ship_name, ewar_types),
      common_fits: suggest_common_fits(ship_name, primary_type)
    }
  end

  defp determine_ship_category(ship_name, _primary_type) do
    normalized = String.downcase(ship_name)

    cond do
      # Check ship class
      String.contains?(normalized, ["griffin", "maulus", "crucifier", "vigil"]) ->
        :frigate

      String.contains?(normalized, ["kitsune", "keres", "sentinel", "hyena"]) ->
        :t2_frigate

      String.contains?(normalized, ["blackbird", "celestis", "arbitrator", "bellicose"]) ->
        :cruiser

      String.contains?(normalized, [
        "falcon",
        "rook",
        "arazu",
        "lachesis",
        "pilgrim",
        "curse",
        "huginn"
      ]) ->
        :t2_cruiser

      String.contains?(normalized, ["scorpion", "dominix"]) ->
        :battleship

      String.contains?(normalized, ["widow"]) ->
        :black_ops

      String.contains?(normalized, ["sabre", "flycatcher", "eris", "heretic"]) ->
        :interdictor

      String.contains?(normalized, ["broadsword", "onyx", "devoter", "phobos"]) ->
        :heavy_interdictor

      true ->
        :unknown
    end
  end

  defp build_capability_list(ewar_types) do
    Enum.map(ewar_types, fn type ->
      ships = Map.get(@ewar_ships, type, %{})

      %{
        type: type,
        description: Map.get(ships, :description, "Unknown EWAR type"),
        effectiveness: base_effectiveness_for_type(type)
      }
    end)
  end

  defp base_effectiveness_for_type(type) do
    case type do
      :ecm ->
        %{jam_chance: "20-40%", optimal_range: "50-90km"}

      :damps ->
        %{range_reduction: "50-70%", scan_res_reduction: "50-70%", optimal_range: "60-100km"}

      :tracking_disruptors ->
        %{tracking_reduction: "50-70%", range_reduction: "50-70%", optimal_range: "50-80km"}

      :target_painters ->
        %{sig_bloom: "25-50%", optimal_range: "30-60km"}

      :neuts ->
        %{neut_amount: "varies", optimal_range: "10-25km"}

      :tackle ->
        %{point_strength: "1-∞", range: "20-30km"}

      _ ->
        %{}
    end
  end

  defp estimate_ship_effectiveness(ship_name, primary_type) do
    base_score = 50

    # T2 ships are more effective
    t2_bonus =
      if String.contains?(
           String.downcase(ship_name),
           [
             "falcon",
             "rook",
             "kitsune",
             "keres",
             "arazu",
             "lachesis",
             "sentinel",
             "pilgrim",
             "curse",
             "widow",
             "hyena",
             "huginn"
           ]
         ) do
        25
      else
        0
      end

    # Recon ships get bonus
    recon_bonus =
      if String.contains?(
           String.downcase(ship_name),
           ["falcon", "rook", "arazu", "lachesis", "pilgrim", "curse", "huginn"]
         ) do
        15
      else
        0
      end

    # Type-specific bonuses
    type_bonus =
      case primary_type do
        # ECM is powerful
        :ecm -> 10
        # Damps are very effective
        :damps -> 10
        # Neuts can be devastating
        :neuts -> 15
        _ -> 5
      end

    min(100, base_score + t2_bonus + recon_bonus + type_bonus)
  end

  defp estimate_optimal_range(ewar_type, ship_category) do
    base_range =
      case ewar_type do
        :ecm -> 75
        :damps -> 80
        :tracking_disruptors -> 65
        :target_painters -> 45
        :neuts -> 20
        :tackle -> 24
        _ -> 50
      end

    # Ship size affects range
    size_modifier =
      case ship_category do
        :frigate -> 0.8
        :t2_frigate -> 0.9
        :cruiser -> 1.0
        :t2_cruiser -> 1.1
        :battleship -> 1.2
        :black_ops -> 1.3
        _ -> 1.0
      end

    round(base_range * size_modifier)
  end

  defp identify_strengths(ship_name, ewar_types) do
    strengths = []

    normalized = String.downcase(ship_name)

    # Ship-specific strengths
    strengths =
      cond do
        String.contains?(normalized, "falcon") ->
          ["Covert ops cloak", "High jam strength" | strengths]

        String.contains?(normalized, "rook") ->
          ["Extreme range", "High jam strength" | strengths]

        String.contains?(normalized, "curse") ->
          ["Massive neut range", "Tracking disruption" | strengths]

        String.contains?(normalized, "lachesis") ->
          ["Long point range", "Tanky" | strengths]

        String.contains?(normalized, "huginn") ->
          ["Fast", "Long web range" | strengths]

        true ->
          strengths
      end

    # Type-based strengths
    strengths =
      if :ecm in ewar_types do
        ["Can break all locks" | strengths]
      else
        strengths
      end

    strengths =
      if :neuts in ewar_types do
        ["Capacitor warfare" | strengths]
      else
        strengths
      end

    Enum.uniq(strengths)
  end

  defp identify_weaknesses(ship_name, _ewar_types) do
    weaknesses = ["Typically low tank", "Priority target"]

    normalized = String.downcase(ship_name)

    # Ship-specific weaknesses
    cond do
      String.contains?(normalized, ["griffin", "kitsune"]) ->
        ["Very fragile", "Low DPS" | weaknesses]

      String.contains?(normalized, ["blackbird", "scorpion"]) ->
        ["Large signature", "Slow" | weaknesses]

      String.contains?(normalized, "widow") ->
        ["Expensive", "Jump fatigue" | weaknesses]

      true ->
        weaknesses
    end
  end

  defp suggest_common_fits(ship_name, primary_type) do
    normalized = String.downcase(ship_name)

    base_fit =
      case primary_type do
        :ecm ->
          %{
            high: ["Empty or Launchers"],
            mid: ["ECM modules", "Sensor Booster", "Shield Extender"],
            low: ["Signal Distortion Amplifiers", "Damage Control"]
          }

        :damps ->
          %{
            high: ["Drones or Guns"],
            mid: ["Remote Sensor Dampeners", "Tracking Computer", "Shield/Armor"],
            low: ["Sensor Dampening Amplifiers", "Tank modules"]
          }

        :tracking_disruptors ->
          %{
            high: ["Energy Neutralizers", "Drones"],
            mid: ["Tracking Disruptors", "Cap modules"],
            low: ["Tracking Disruptor Amplifiers", "Armor tank"]
          }

        :neuts ->
          %{
            high: ["Energy Neutralizers", "Energy Vampires"],
            mid: ["Cap Injector", "Prop mod", "Tank"],
            low: ["Capacitor Power Relays", "Tank modules"]
          }

        _ ->
          %{
            high: ["Weapons"],
            mid: ["EWAR modules", "Tank"],
            low: ["Damage/tank modules"]
          }
      end

    # Adjust for specific ships
    if String.contains?(normalized, ["falcon", "rook", "arazu", "lachesis"]) do
      Map.put(base_fit, :special, "Force Recon - Covert cloak capable")
    else
      base_fit
    end
  end

  defp add_ship_bonuses(analysis, ship_info) do
    # In production, would parse actual bonuses from SDE
    # For now, use common knowledge
    ship_name = String.downcase(ship_info.type_name)

    bonuses =
      cond do
        String.contains?(ship_name, "blackbird") ->
          ["20% ECM optimal range per level", "10% ECM strength per level"]

        String.contains?(ship_name, "celestis") ->
          ["20% damp effectiveness per level", "10% damp optimal range per level"]

        String.contains?(ship_name, "arbitrator") ->
          ["20% TD effectiveness per level", "10% drone hitpoints per level"]

        true ->
          []
      end

    Map.put(analysis, :ship_bonuses, bonuses)
  end

  # Fleet analysis functions

  defp analyze_single_ship(ship) do
    case ship do
      %{ship_type_id: id} ->
        case analyze_ewar_ship(id) do
          {:ok, analysis} -> analysis
          _ -> %{is_ewar: false}
        end

      %{ship_name: name} ->
        case analyze_ewar_ship(name) do
          {:ok, analysis} -> analysis
          _ -> %{is_ewar: false}
        end

      name when is_binary(name) ->
        case analyze_ewar_ship(name) do
          {:ok, analysis} -> analysis
          _ -> %{is_ewar: false}
        end

      _ ->
        %{is_ewar: false}
    end
  end

  defp calculate_percentage(count, total) when total > 0 do
    Float.round(count / total * 100, 1)
  end

  defp calculate_percentage(_, _), do: 0.0

  defp group_ewar_by_type(ewar_ships) do
    ewar_ships
    |> Enum.flat_map(fn ship ->
      Enum.map(ship.ewar_types, fn type -> {type, ship} end)
    end)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Enum.map(fn {type, ships} ->
      {type,
       %{
         count: length(ships),
         ships: Enum.map(ships, & &1.ship_name)
       }}
    end)
    |> Map.new()
  end

  defp assess_fleet_ewar_threat(ewar_ships) do
    if Enum.empty?(ewar_ships) do
      :minimal
    else
      # Count different EWAR types
      ewar_diversity =
        ewar_ships
        |> Enum.flat_map(& &1.ewar_types)
        |> Enum.uniq()
        |> length()

      # Check for force multipliers
      has_recons =
        Enum.any?(ewar_ships, fn ship ->
          ship.ship_category in [:t2_cruiser, :black_ops]
        end)

      cond do
        length(ewar_ships) > 5 and ewar_diversity > 3 -> :extreme
        has_recons and length(ewar_ships) > 2 -> :high
        length(ewar_ships) > 3 -> :high
        has_recons -> :medium
        true -> :low
      end
    end
  end

  defp identify_ewar_gaps(ewar_ships) do
    present_types =
      ewar_ships

    Enum.flat_map(& &1.ewar_types) |> Enum.uniq() |> MapSet.new()

    all_types =
      MapSet.new([:ecm, :damps, :tracking_disruptors, :target_painters, :neuts, :tackle])

    missing = MapSet.difference(all_types, present_types)

    missing
    |> Enum.map(fn type ->
      %{
        type: type,
        impact: assess_gap_impact(type),
        suggestion: suggest_ship_for_gap(type)
      }
    end)
  end

  defp assess_gap_impact(type) do
    case type do
      # No tackle is dangerous
      :tackle -> :critical
      # Damps are very powerful
      :damps -> :high
      # ECM is situational
      :ecm -> :medium
      # Neuts depend on comp
      :neuts -> :medium
      _ -> :low
    end
  end

  defp suggest_ship_for_gap(type) do
    case type do
      :tackle -> "Add Sabre, Lachesis, or Huginn"
      :damps -> "Add Keres, Celestis, or Maulus"
      :ecm -> "Add Blackbird or Griffin"
      :neuts -> "Add Curse, Sentinel, or Arbitrator"
      :target_painters -> "Add Vigil or Hyena"
      :tracking_disruptors -> "Add Crucifier or Arbitrator"
      _ -> "Consider EWAR support"
    end
  end

  defp generate_counter_recommendations(ewar_ships) do
    recommendations = []

    ewar_types =
      ewar_ships
      |> Enum.flat_map(& &1.ewar_types)
      |> Enum.uniq()

    recommendations =
      if :ecm in ewar_types do
        ["Use ECCM or sensor boosters", "Spread out to avoid multi-jams" | recommendations]
      else
        recommendations
      end

    recommendations =
      if :damps in ewar_types do
        ["Fit sensor boosters", "Use long-range weapons" | recommendations]
      else
        recommendations
      end

    recommendations =
      if :tracking_disruptors in ewar_types do
        ["Use missiles or drones", "Fit tracking computers" | recommendations]
      else
        recommendations
      end

    recommendations =
      if :neuts in ewar_types do
        ["Fit cap boosters", "Use cap-independent weapons" | recommendations]
      else
        recommendations
      end

    if Enum.empty?(recommendations) do
      ["Primary EWAR ships quickly", "Use fast tackle"]
    else
      ["Primary EWAR ships quickly" | recommendations]
    end
  end

  # Module detection functions

  defp ewar_module?(item) do
    type_id =
      case item do
        %{type_id: id} -> id
        %{"type_id" => id} -> id
        _ -> nil
      end

    if type_id do
      Enum.any?(@ewar_modules, fn {_type, ids} -> type_id in ids end)
    else
      false
    end
  end

  defp categorize_ewar_module(item) do
    type_id =
      case item do
        %{type_id: id} -> id
        %{"type_id" => id} -> id
      end

    module_type =
      Enum.find_value(@ewar_modules, fn {type, ids} ->
        if type_id in ids, do: type
      end)

    %{
      type_id: type_id,
      type: module_type,
      slot: determine_module_slot(module_type)
    }
  end

  defp determine_module_slot(module_type) do
    case module_type do
      :energy_neutralizer -> :high
      _ -> :mid
    end
  end

  defp estimate_module_effectiveness(ewar_items) do
    if Enum.empty?(ewar_items) do
      0
    else
      # Simple scoring based on module count and type
      base_score = length(ewar_items) * 20

      # Bonus for module diversity
      unique_types = ewar_items |> Enum.map(& &1.type) |> Enum.uniq() |> length()
      diversity_bonus = unique_types * 10

      min(100, base_score + diversity_bonus)
    end
  end

  defp determine_primary_ewar_role(ewar_items) do
    if Enum.empty?(ewar_items) do
      nil
    else
      ewar_items
      |> Enum.frequencies_by(& &1.type)
      |> Enum.max_by(fn {_type, count} -> count end)
      |> elem(0)
    end
  end

  # Threat assessment functions

  defp calculate_threat_level(ship_analysis) do
    effectiveness = Map.get(ship_analysis, :effectiveness, 0)

    cond do
      effectiveness >= 80 -> :extreme
      effectiveness >= 60 -> :high
      effectiveness >= 40 -> :medium
      effectiveness >= 20 -> :low
      true -> :minimal
    end
  end

  defp calculate_threat_score(ship_analysis) do
    base = Map.get(ship_analysis, :effectiveness, 0)

    # Modifiers
    multipliers = []

    multipliers =
      if ship_analysis[:ship_category] in [:t2_cruiser, :black_ops] do
        [1.5 | multipliers]
      else
        multipliers
      end

    multipliers =
      if :ecm in Map.get(ship_analysis, :ewar_types, []) do
        [1.2 | multipliers]
      else
        multipliers
      end

    final_multiplier =
      if Enum.empty?(multipliers) do
        1.0
      else
        Enum.reduce(multipliers, 1.0, &*/2)
      end

    round(base * final_multiplier)
  end

  defp estimate_effective_range(ship_analysis) do
    Map.get(ship_analysis, :optimal_range, 50)
  end

  defp assess_counter_difficulty(ship_analysis) do
    case ship_analysis[:primary_ewar_type] do
      # ECM is binary - works or doesn't
      :ecm -> :hard
      # Hard to counter neuts
      :neuts -> :hard
      # Can be partially countered
      :damps -> :medium
      # Multiple counter options
      :tracking_disruptors -> :easy
      _ -> :medium
    end
  end

  defp should_primary?(ship_analysis) do
    # High-value EWAR should be primaried
    ship_analysis[:effectiveness] > 60 or
      ship_analysis[:ship_category] in [:t2_cruiser, :black_ops]
  end

  defp generate_tactical_notes(ship_analysis) do
    notes = []

    notes =
      case ship_analysis[:primary_ewar_type] do
        :ecm -> ["Jam strength varies by race", "Multi-spectral less effective" | notes]
        :damps -> ["Can switch scripts mid-fight", "Very long range" | notes]
        :tracking_disruptors -> ["Useless vs missiles/drones" | notes]
        :neuts -> ["Range typically 10-25km", "Cap dependent" | notes]
        _ -> notes
      end

    notes =
      if ship_analysis[:ship_category] == :t2_frigate do
        ["Fast but fragile" | notes]
      else
        notes
      end

    notes
  end
end

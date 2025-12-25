defmodule EveDmv.Contexts.CorporationIntelligence.Domain.CombatDoctrine.DoctrineClassifier do
  @moduledoc """
  Doctrine classification and scoring for combat doctrine analysis.

  Classifies fleet compositions into recognized combat doctrines and
  calculates confidence scores for doctrine identification.
  """

  require Logger

  # Combat doctrine definitions
  @doctrine_patterns %{
    shield_kiting: %{
      name: "Shield Kiting",
      description: "Long-range shield tanked ships with high mobility and standoff capability",
      characteristics: [
        :shield_tank_dominance,
        :long_range_weapons,
        :high_mobility,
        :standoff_tactics
      ],
      typical_ships: [:interceptors, :assault_frigates, :hacs, :battlecruisers],
      engagement_style: :range_control
    },
    armor_brawling: %{
      name: "Armor Brawling",
      description: "Close-range armor tanked ships focused on sustained DPS and tank",
      characteristics: [:armor_tank_dominance, :short_range_weapons, :high_dps, :close_engagement],
      typical_ships: [:assault_frigates, :hacs, :battleships, :logistics],
      engagement_style: :close_combat
    },
    ewar_heavy: %{
      name: "EWAR Heavy",
      description:
        "Electronic warfare focused doctrine with force multiplication through disruption",
      characteristics: [
        :high_ewar_percentage,
        :coordination_focus,
        :support_heavy,
        :disruption_tactics
      ],
      typical_ships: [:recon_ships, :ewar_frigates, :command_ships, :logistics],
      engagement_style: :force_multiplication
    },
    capital_escalation: %{
      name: "Capital Escalation",
      description: "Doctrine built around capital ship deployment and escalation scenarios",
      characteristics: [:capital_presence, :escalation_ready, :heavy_logistics, :subcap_support],
      typical_ships: [:capitals, :hics, :dictors, :logistics, :battleships],
      engagement_style: :overwhelming_force
    },
    alpha_strike: %{
      name: "Alpha Strike",
      description: "High alpha damage doctrine focused on quickly eliminating priority targets",
      characteristics: [:high_alpha_damage, :coordination_heavy, :target_calling, :burst_damage],
      typical_ships: [:stealth_bombers, :artillery_ships, :alpha_battleships],
      engagement_style: :burst_elimination
    },
    nano_gang: %{
      name: "Nano Gang",
      description: "High speed, high mobility doctrine for hit-and-run tactics",
      characteristics: [:extreme_mobility, :speed_tanking, :hit_and_run, :small_gang_focus],
      typical_ships: [:interceptors, :assault_frigates, :nano_cruisers],
      engagement_style: :guerrilla_warfare
    },
    logistics_heavy: %{
      name: "Logistics Heavy",
      description: "Doctrine emphasizing survivability through extensive logistics support",
      characteristics: [
        :high_logistics_ratio,
        :survivability_focus,
        :sustained_engagement,
        :defensive_positioning
      ],
      typical_ships: [:logistics, :guardian_scimitar, :combat_ships_with_reps],
      engagement_style: :attrition_warfare
    }
  }

  @doc """
  Returns all defined doctrine patterns.
  """
  def doctrine_patterns, do: @doctrine_patterns

  @doc """
  Classifies combat doctrines based on fleet compositions.

  Analyzes fleet compositions to identify primary and secondary combat
  doctrines with confidence scores.
  """
  def classify_combat_doctrines(fleet_compositions) do
    doctrine_scores =
      @doctrine_patterns
      |> Enum.map(fn {doctrine_key, doctrine_def} ->
        score = calculate_doctrine_score(fleet_compositions, doctrine_key)
        confidence = calculate_doctrine_confidence(fleet_compositions, doctrine_key, score)

        {doctrine_key,
         %{
           name: doctrine_def.name,
           description: doctrine_def.description,
           score: score,
           confidence: confidence,
           supporting_evidence: extract_supporting_evidence(fleet_compositions, doctrine_key)
         }}
      end)
      |> Map.new()

    sorted_doctrines = Enum.sort_by(doctrine_scores, fn {_key, data} -> data.score end, :desc)

    {primary_key, primary_data} = List.first(sorted_doctrines)
    {secondary_key, secondary_data} = Enum.at(sorted_doctrines, 1, {nil, nil})

    classification = %{
      primary_doctrine: Map.put(primary_data, :key, primary_key),
      secondary_doctrine:
        if(secondary_data, do: Map.put(secondary_data, :key, secondary_key), else: nil),
      all_doctrine_scores: doctrine_scores,
      doctrine_certainty: calculate_doctrine_certainty(doctrine_scores),
      hybrid_characteristics: identify_hybrid_characteristics(doctrine_scores)
    }

    {:ok, classification}
  end

  @doc """
  Calculates doctrine score for a set of fleet compositions.
  """
  def calculate_doctrine_score(fleet_compositions, doctrine_key) do
    if Enum.empty?(fleet_compositions) do
      0.0
    else
      total_score =
        fleet_compositions
        |> Enum.map(fn composition ->
          calculate_single_engagement_doctrine_score(composition, doctrine_key)
        end)
        |> Enum.sum()

      total_score / length(fleet_compositions)
    end
  end

  @doc """
  Calculates doctrine score for a single engagement.
  """
  def calculate_single_engagement_doctrine_score(composition, doctrine_key) do
    indicators = get_doctrine_indicators(composition, doctrine_key)

    case doctrine_key do
      :shield_kiting ->
        safe_get(indicators, :shield_percentage, 0) * 0.3 +
          safe_get(indicators, :long_range_percentage, 0) * 0.3 +
          safe_get(indicators, :mobility_ships, 0) * 0.2 +
          if(safe_get(indicators, :engagement_duration, 999) < 300, do: 0.2, else: 0.0)

      :armor_brawling ->
        safe_get(indicators, :armor_percentage, 0) * 0.3 +
          safe_get(indicators, :short_range_percentage, 0) * 0.3 +
          safe_get(indicators, :heavy_ships_percentage, 0) * 0.2 +
          if(safe_get(indicators, :close_engagement, false), do: 0.2, else: 0.0)

      :ewar_heavy ->
        safe_get(indicators, :ewar_percentage, 0) * 0.4 +
          min(1.0, safe_get(indicators, :support_ratio, 0) * 2) * 0.3 +
          safe_get(indicators, :coordination_quality, 0) * 0.2 +
          safe_get(indicators, :specialized_ships, 0) * 0.1

      :capital_escalation ->
        safe_get(indicators, :capital_percentage, 0) * 0.4 +
          safe_get(indicators, :logistics_percentage, 0) * 0.2 +
          safe_get(indicators, :interdiction_percentage, 0) * 0.2 +
          if(
            safe_get(indicators, :escalation_pattern, :none) in [
              :moderate_escalation,
              :strong_escalation
            ],
            do: 0.2,
            else: 0.0
          )

      :alpha_strike ->
        safe_get(indicators, :alpha_ships_percentage, 0) * 0.4 +
          safe_get(indicators, :coordination_quality, 0) * 0.3 +
          if(safe_get(indicators, :target_focus, :none) in [:highly_focused, :moderately_focused],
            do: 0.2,
            else: 0.0
          ) +
          min(1.0, safe_get(indicators, :killmail_density, 0) / 2) * 0.1

      :nano_gang ->
        safe_get(indicators, :mobility_percentage, 0) * 0.4 +
          safe_get(indicators, :frigate_percentage, 0) * 0.3 +
          if(safe_get(indicators, :engagement_duration, 999) < 180, do: 0.2, else: 0.0) +
          if(safe_get(indicators, :multi_system, false), do: 0.1, else: 0.0)

      :logistics_heavy ->
        min(1.0, safe_get(indicators, :logistics_percentage, 0) * 4) * 0.4 +
          min(1.0, safe_get(indicators, :support_ratio, 0) * 2) * 0.3 +
          if(safe_get(indicators, :engagement_duration, 0) > 600, do: 0.2, else: 0.0) +
          if(safe_get(indicators, :survivability_focus, false), do: 0.1, else: 0.0)

      _ ->
        0.0
    end
  end

  @doc """
  Calculates confidence for a doctrine classification.
  """
  def calculate_doctrine_confidence(fleet_compositions, doctrine_key, score) do
    if length(fleet_compositions) < 3 do
      max(0.3, score * 0.7)
    else
      engagement_scores =
        Enum.map(
          fleet_compositions,
          &calculate_single_engagement_doctrine_score(&1, doctrine_key)
        )

      variance = calculate_variance(engagement_scores)
      consistency = 1.0 - min(1.0, variance / max(0.01, score * score))

      score * 0.7 + consistency * 0.3
    end
  end

  @doc """
  Calculates doctrine certainty based on score distribution.
  """
  def calculate_doctrine_certainty(doctrine_scores) do
    scores = Map.values(doctrine_scores) |> Enum.map(& &1.score)

    if length(scores) < 2 do
      0.5
    else
      sorted = Enum.sort(scores, :desc)
      top_score = hd(sorted)
      second_score = Enum.at(sorted, 1, 0)

      if top_score > 0 do
        gap = (top_score - second_score) / top_score
        min(1.0, gap + 0.3)
      else
        0.3
      end
    end
  end

  @doc """
  Identifies hybrid doctrine characteristics.
  """
  def identify_hybrid_characteristics(doctrine_scores) do
    significant_doctrines =
      doctrine_scores
      |> Enum.filter(fn {_key, data} -> data.score > 0.3 end)
      |> Enum.map(fn {key, _data} -> key end)

    if length(significant_doctrines) > 1 do
      %{
        is_hybrid: true,
        component_doctrines: significant_doctrines,
        hybrid_description: generate_hybrid_description(significant_doctrines)
      }
    else
      %{is_hybrid: false, component_doctrines: [], hybrid_description: nil}
    end
  end

  # Private functions

  defp get_doctrine_indicators(composition, _doctrine_key) do
    # Get indicators from composition or return empty map
    Map.get(composition, :doctrine_indicators, %{})
  end

  defp safe_get(map, key, default) when is_map(map) do
    Map.get(map, key, default) || default
  end

  defp safe_get(_, _, default), do: default

  defp extract_supporting_evidence(fleet_compositions, doctrine_key) do
    strongest_examples =
      fleet_compositions
      |> Enum.map(fn composition ->
        score = calculate_single_engagement_doctrine_score(composition, doctrine_key)
        {composition, score}
      end)
      |> Enum.sort_by(&elem(&1, 1), :desc)
      |> Enum.take(3)
      |> Enum.map(&elem(&1, 0))

    Enum.map(strongest_examples, fn composition ->
      %{
        engagement_id: Map.get(composition, :engagement_id),
        timestamp: Map.get(composition, :timestamp),
        participant_count: Map.get(composition, :participant_count),
        key_characteristics: extract_key_characteristics(composition, doctrine_key)
      }
    end)
  end

  defp extract_key_characteristics(composition, doctrine_key) do
    indicators = get_doctrine_indicators(composition, doctrine_key)

    case doctrine_key do
      :shield_kiting ->
        [
          "#{round(safe_get(indicators, :shield_percentage, 0) * 100)}% shield tanked ships",
          "#{round(safe_get(indicators, :long_range_percentage, 0) * 100)}% long-range weapons",
          "#{round(safe_get(indicators, :mobility_ships, 0) * 100)}% mobile ships"
        ]

      :armor_brawling ->
        [
          "#{round(safe_get(indicators, :armor_percentage, 0) * 100)}% armor tanked ships",
          "#{round(safe_get(indicators, :short_range_percentage, 0) * 100)}% short-range weapons",
          "#{round(safe_get(indicators, :heavy_ships_percentage, 0) * 100)}% heavy ships"
        ]

      :ewar_heavy ->
        [
          "#{round(safe_get(indicators, :ewar_percentage, 0) * 100)}% EWAR ships",
          "#{round(safe_get(indicators, :support_ratio, 0) * 100)}% support ships overall",
          "#{round(safe_get(indicators, :coordination_quality, 0) * 100)}% coordination quality"
        ]

      _ ->
        ["Analysis available for #{doctrine_key}"]
    end
  end

  defp calculate_variance(values) when length(values) < 2, do: 0.0

  defp calculate_variance(values) do
    mean = Enum.sum(values) / length(values)
    squared_diffs = Enum.map(values, fn v -> (v - mean) * (v - mean) end)
    Enum.sum(squared_diffs) / length(values)
  end

  defp generate_hybrid_description(doctrines) do
    doctrine_names =
      doctrines
      |> Enum.map_join(" / ", fn key ->
        case Map.get(@doctrine_patterns, key) do
          %{name: name} -> name
          _ -> to_string(key)
        end
      end)

    "Hybrid doctrine combining #{doctrine_names} characteristics"
  end
end

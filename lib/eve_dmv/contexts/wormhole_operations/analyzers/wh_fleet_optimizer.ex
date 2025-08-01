defmodule EveDmv.Contexts.WormholeOperations.Analyzers.WhFleetAnalyzer.FleetOptimizer do
  @moduledoc """
  Handles fleet optimization and recommendation generation.

  This module provides functionality for generating optimization
  recommendations, analyzing counter-doctrines, and creating
  situational variants of fleet compositions.
  """

  alias EveDmv.Intelligence.Fleet.FleetEffectivenessCalculator

  require Logger

  @doc """
  Generate optimization recommendations for a fleet composition.

  ## Parameters
  - `composition` - Fleet composition to optimize
  - `skill_analysis` - Skill gap analysis
  - `mass_analysis` - Mass efficiency analysis
  - `pilot_assignments` - Pilot assignment optimization

  ## Returns
  - `{:ok, optimization_results}` - Optimization recommendations
  """
  def generate_optimization_recommendations(
        composition,
        skill_analysis,
        mass_analysis,
        pilot_assignments
      ) do
    fleet_effectiveness =
      FleetEffectivenessCalculator.calculate_fleet_effectiveness(composition, pilot_assignments)

    counter_doctrines = generate_counter_doctrine_analysis(composition)
    improvements = identify_improvement_opportunities(composition, skill_analysis, mass_analysis)
    situational_variants = create_situational_variants(composition)

    optimization = %{
      "fleet_effectiveness" => fleet_effectiveness,
      "counter_doctrines" => counter_doctrines,
      "improvements" => improvements,
      "situational_variants" => situational_variants
    }

    {:ok, optimization}
  end

  @doc """
  Generate counter-doctrine analysis for a composition.

  ## Parameters
  - `composition` - Fleet composition to analyze

  ## Returns
  - List of counter-doctrine recommendations
  """
  def generate_counter_doctrine_analysis(composition) do
    # Generate real analysis based on composition strengths/weaknesses
    case analyze_composition_profile(composition) do
      {:ok, profile} ->
        generate_threat_analysis(profile, composition)

      {:error, _} ->
        # Return empty analysis if composition analysis fails
        []
    end
  end

  # Analyze the fleet composition to determine its strengths and weaknesses
  defp analyze_composition_profile(composition) do
    ships = extract_ship_types(composition)

    profile = %{
      ship_count: length(ships),
      has_logistics: has_logistics_ships?(ships),
      has_ewar: has_ewar_ships?(ships),
      has_capitals: has_capital_ships?(ships),
      primary_tank: determine_primary_tank_type(ships),
      primary_range: determine_primary_engagement_range(ships),
      alpha_potential: calculate_alpha_potential(ships),
      mobility: calculate_mobility_score(ships)
    }

    {:ok, profile}
  end

  # Generate threat analysis based on composition profile
  defp generate_threat_analysis(profile, _composition) do
    [
      analyze_vs_armor_hacs(profile),
      analyze_vs_shield_cruisers(profile),
      analyze_vs_kiting_doctrines(profile),
      analyze_vs_brawling_doctrines(profile)
    ]
    |> Enum.reject(&is_nil/1)
  end

  # Specific threat analysis functions
  defp analyze_vs_armor_hacs(profile) do
    effectiveness = calculate_effectiveness_vs_armor_hacs(profile)

    %{
      "threat_type" => "Armor HAC gang",
      "effectiveness" => effectiveness,
      "recommended_changes" => generate_armor_hac_counters(profile, effectiveness)
    }
  end

  defp analyze_vs_shield_cruisers(profile) do
    effectiveness = calculate_effectiveness_vs_shield_cruisers(profile)

    %{
      "threat_type" => "Shield cruiser gang",
      "effectiveness" => effectiveness,
      "recommended_changes" => generate_shield_cruiser_counters(profile, effectiveness)
    }
  end

  defp analyze_vs_kiting_doctrines(profile) do
    if profile.mobility < 0.3 do
      # Poor against kiters
      effectiveness = 0.2 + profile.alpha_potential * 0.3

      %{
        "threat_type" => "Kiting doctrines",
        "effectiveness" => Float.round(effectiveness, 2),
        "recommended_changes" => ["Add fast tackle", "Increase range", "Consider mobile doctrine"]
      }
    else
      # Good mobility, no special analysis needed
      nil
    end
  end

  defp analyze_vs_brawling_doctrines(profile) do
    # Brawling analysis
    effectiveness =
      if profile.primary_range == :short do
        0.7 + if profile.has_logistics, do: 0.2, else: 0.0
      else
        # Long range struggles in brawls
        0.4
      end

    %{
      "threat_type" => "Brawling doctrines",
      "effectiveness" => Float.round(effectiveness, 2),
      "recommended_changes" => generate_brawling_counters(profile)
    }
  end

  # Helper functions for composition analysis
  defp extract_ship_types(composition) do
    # Extract ship type IDs from composition data
    case composition do
      %{"ships" => ships} -> Enum.map(ships, &(&1["type_id"] || &1[:type_id]))
      ships when is_list(ships) -> Enum.map(ships, &(&1["type_id"] || &1[:type_id] || &1))
      _ -> []
    end
    |> Enum.reject(&is_nil/1)
  end

  defp has_logistics_ships?(ships) do
    Enum.any?(ships, &EveDmv.StaticData.ShipRoles.logistics_ship?/1)
  end

  defp has_ewar_ships?(ships) do
    Enum.any?(ships, &EveDmv.StaticData.ShipRoles.ewar_ship?/1)
  end

  defp has_capital_ships?(ships) do
    Enum.any?(ships, fn ship_id ->
      case EveDmv.StaticData.ShipAttributesService.get_ship_class(ship_id) do
        {:ok, :capital} -> true
        {:ok, :supercapital} -> true
        _ -> false
      end
    end)
  end

  defp determine_primary_tank_type(_ships) do
    # Simplified tank type detection - would need more sophisticated analysis
    # For now, assume armor unless clearly shield-focused
    :armor
  end

  defp determine_primary_engagement_range(_ships) do
    # Simplified range detection - would analyze weapon systems
    :medium
  end

  defp calculate_alpha_potential(ships) do
    # Calculate alpha strike potential based on ship types
    # Higher for battleships, lower for cruisers
    capital_count =
      Enum.count(ships, fn ship_id ->
        case EveDmv.StaticData.ShipAttributesService.get_ship_class(ship_id) do
          {:ok, class} -> class in [:battleship, :capital, :supercapital]
          _ -> false
        end
      end)

    total_ships = length(ships)

    if total_ships > 0 do
      Float.round(capital_count / total_ships, 2)
    else
      0.0
    end
  end

  defp calculate_mobility_score(ships) do
    # Calculate mobility based on ship classes
    fast_ships =
      Enum.count(ships, fn ship_id ->
        case EveDmv.StaticData.ShipAttributesService.get_ship_class(ship_id) do
          {:ok, class} -> class in [:frigate, :destroyer, :cruiser]
          _ -> false
        end
      end)

    total_ships = length(ships)

    if total_ships > 0 do
      Float.round(fast_ships / total_ships, 2)
    else
      0.0
    end
  end

  # Effectiveness calculation functions
  defp calculate_effectiveness_vs_armor_hacs(profile) do
    base_effectiveness = 0.5

    # Bonuses for good counters
    effectiveness =
      base_effectiveness
      # EWAR helps vs HACs
      |> add_if(profile.has_ewar, 0.2)
      # Alpha helps break reps
      |> add_if(profile.alpha_potential > 0.3, 0.15)
      # Logi helps sustain
      |> add_if(profile.has_logistics, 0.1)

    Float.round(min(effectiveness, 1.0), 2)
  end

  defp calculate_effectiveness_vs_shield_cruisers(profile) do
    # Generally easier target
    base_effectiveness = 0.6

    effectiveness =
      base_effectiveness
      # Range advantage
      |> add_if(profile.primary_range == :long, 0.15)
      # Mobility helps
      |> add_if(profile.mobility > 0.5, 0.1)

    Float.round(min(effectiveness, 1.0), 2)
  end

  # Counter recommendation functions
  defp generate_armor_hac_counters(profile, effectiveness) do
    []
    |> maybe_add_ewar_counter_advanced(effectiveness, profile.has_ewar)
    |> maybe_add_alpha_counter_advanced(effectiveness, profile.alpha_potential)
    |> maybe_add_neut_counter(effectiveness)
    |> finalize_armor_hac_counters_advanced()
  end

  defp maybe_add_ewar_counter_advanced(counters, _effectiveness, true), do: counters

  defp maybe_add_ewar_counter_advanced(counters, effectiveness, false) when effectiveness < 0.7 do
    ["Add EWAR support" | counters]
  end

  defp maybe_add_ewar_counter_advanced(counters, _effectiveness, false), do: counters

  defp maybe_add_alpha_counter_advanced(counters, effectiveness, alpha_potential)
       when effectiveness < 0.6 and alpha_potential < 0.3 do
    ["Increase alpha damage" | counters]
  end

  defp maybe_add_alpha_counter_advanced(counters, _effectiveness, _alpha_potential), do: counters

  defp maybe_add_neut_counter(counters, effectiveness) when effectiveness < 0.5 do
    ["Consider neut pressure" | counters]
  end

  defp maybe_add_neut_counter(counters, _effectiveness), do: counters

  defp finalize_armor_hac_counters_advanced([]), do: ["Composition effective as-is"]
  defp finalize_armor_hac_counters_advanced(counters), do: counters

  defp generate_shield_cruiser_counters(profile, effectiveness) do
    []
    |> maybe_add_range_counter_advanced(effectiveness, profile.primary_range)
    |> maybe_add_mobility_counter_advanced(effectiveness, profile.mobility)
    |> finalize_shield_cruiser_counters_advanced()
  end

  defp maybe_add_range_counter_advanced(counters, effectiveness, :short)
       when effectiveness < 0.6 do
    ["Increase engagement range" | counters]
  end

  defp maybe_add_range_counter_advanced(counters, _effectiveness, _range), do: counters

  defp maybe_add_mobility_counter_advanced(counters, effectiveness, mobility)
       when effectiveness < 0.7 and mobility < 0.4 do
    ["Add mobile elements" | counters]
  end

  defp maybe_add_mobility_counter_advanced(counters, _effectiveness, _mobility), do: counters

  defp finalize_shield_cruiser_counters_advanced([]), do: ["Good matchup"]
  defp finalize_shield_cruiser_counters_advanced(counters), do: counters

  defp generate_brawling_counters(profile) do
    if profile.primary_range == :long do
      ["Maintain range advantage", "Use kiting tactics"]
    else
      ["Ensure logistics support", "Focus fire coordination"]
    end
  end

  # Helper function for conditional additions
  defp add_if(value, condition, addition) do
    if condition, do: value + addition, else: value
  end

  @doc """
  Identify improvement opportunities for a fleet composition.

  ## Parameters
  - `composition` - Fleet composition to analyze
  - `skill_analysis` - Skill gap analysis
  - `mass_analysis` - Mass efficiency analysis

  ## Returns
  - List of improvement recommendations
  """
  def identify_improvement_opportunities(_composition, skill_analysis, mass_analysis) do
    improvements = []

    # Skill-based improvements
    skill_improvements =
      Enum.map(skill_analysis["critical_gaps"], fn gap ->
        %{
          "category" => "skills",
          "current_score" => 60,
          "target_score" => 85,
          "recommendation" => "Train #{gap["role"]} skills for #{gap["shortage"]} more pilots",
          "impact" => gap["impact"]
        }
      end)

    # Mass efficiency improvements
    mass_improvements =
      if mass_analysis["mass_optimization"]["efficiency_rating"] < 0.8 do
        [
          %{
            "category" => "mass_efficiency",
            "current_score" =>
              round(mass_analysis["mass_optimization"]["efficiency_rating"] * 100),
            "target_score" => 85,
            "recommendation" => "Optimize ship selection for better mass efficiency",
            "impact" => "medium"
          }
        ]
      else
        []
      end

    improvements ++ skill_improvements ++ mass_improvements
  end

  @doc """
  Create situational variants of a fleet composition.

  ## Parameters
  - `composition` - Base fleet composition

  ## Returns
  - Map of situational variants with modifications
  """
  def create_situational_variants(_composition) do
    # Create variants of the doctrine for different situations
    %{
      "home_defense" => %{
        "modifications" => [
          "Add HICs for tackle",
          "Increase logistics count",
          "Add triage support"
        ]
      },
      "chain_clearing" => %{
        "modifications" => ["More DPS ships", "Reduce logistics", "Add fast tackle"]
      },
      "eviction_response" => %{
        "modifications" => ["Capital support", "Triage carrier", "Multiple fleet coordination"]
      }
    }
  end

  @doc """
  Generate comprehensive fleet improvement recommendations.

  ## Parameters
  - `fleet_data` - Fleet analysis data
  - `effectiveness_metrics` - Fleet effectiveness metrics
  - `role_analysis` - Role distribution analysis

  ## Returns
  - Map with detailed improvement recommendations
  """
  def generate_fleet_improvements(fleet_data, effectiveness_metrics, role_analysis) do
    initial_priority_improvements = []
    initial_suggested_additions = []

    # Analyze survivability needs
    {survivability_priority_improvements, survivability_suggested_additions} =
      analyze_survivability_needs(
        effectiveness_metrics,
        role_analysis,
        initial_priority_improvements,
        initial_suggested_additions
      )

    # Analyze command capability
    {final_priority_improvements, final_suggested_additions} =
      analyze_command_capability(
        effectiveness_metrics,
        survivability_priority_improvements,
        survivability_suggested_additions
      )

    # Analyze doctrine compliance
    doctrine_suggestions = analyze_doctrine_compliance_suggestions(fleet_data)

    # Generate role-specific recommendations
    role_recommendations = generate_role_recommendations()

    %{
      priority_improvements: final_priority_improvements,
      suggested_additions: final_suggested_additions,
      role_recommendations: role_recommendations,
      doctrine_suggestions: doctrine_suggestions
    }
  end

  # Private helper functions

  defp analyze_survivability_needs(
         effectiveness_metrics,
         role_analysis,
         priority_improvements,
         suggested_additions
       ) do
    survivability = Map.get(effectiveness_metrics, :survivability_rating, 0)
    logi_count = Map.get(role_analysis, "logistics", 0)

    cond do
      survivability < 50 and logi_count == 0 ->
        {["Add logistics ships immediately" | priority_improvements],
         ["Guardian", "Scimitar" | suggested_additions]}

      survivability < 50 ->
        {["Increase logistics count" | priority_improvements], suggested_additions}

      true ->
        {priority_improvements, suggested_additions}
    end
  end

  defp analyze_command_capability(
         effectiveness_metrics,
         priority_improvements,
         suggested_additions
       ) do
    fc_capable = Map.get(effectiveness_metrics, :fc_capability, false)

    if fc_capable do
      {priority_improvements, suggested_additions}
    else
      {["Add fleet commander ship" | priority_improvements],
       ["Damnation", "Nighthawk" | suggested_additions]}
    end
  end

  defp analyze_doctrine_compliance_suggestions(fleet_data) do
    doctrine_compliance = Map.get(fleet_data, :doctrine_compliance, 0)

    if doctrine_compliance < 70 do
      ["Standardize ship types", "Remove off-doctrine ships"]
    else
      []
    end
  end

  defp generate_role_recommendations do
    %{
      "logistics" => "Increase to 20-25% of fleet",
      "dps" => "Should be 60-70% of fleet",
      "tackle" => "Add fast tackle for mobility",
      "ewar" => "Consider EWAR for force multiplication"
    }
  end
end

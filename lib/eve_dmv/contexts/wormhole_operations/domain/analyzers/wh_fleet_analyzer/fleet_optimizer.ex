defmodule EveDmv.Contexts.WormholeOperations.Domain.Analyzers.WhFleetAnalyzer.FleetOptimizer do
  @moduledoc """
  Handles fleet optimization and recommendation generation.

  This module provides functionality for generating optimization
  recommendations, analyzing counter-doctrines, and creating
  situational variants of fleet compositions.
  """
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
    # Use the doctrine effectiveness service for real analysis
    case EveDmv.Contexts.Combat.Services.DoctrineEffectivenessService.analyze_counter_doctrine_effectiveness(
           composition
         ) do
      {:ok, analyses} ->
        analyses

      {:error, _reason} ->
        # Fallback to basic composition analysis if service fails
        generate_basic_counter_analysis(composition)
    end
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

  defp generate_basic_counter_analysis(composition) do
    # Basic fallback analysis based on composition characteristics
    ship_types = extract_ship_types_from_composition(composition)

    [
      analyze_vs_armor_hacs_basic(ship_types),
      analyze_vs_shield_cruisers_basic(ship_types)
    ]
    |> Enum.reject(&is_nil/1)
  end

  defp extract_ship_types_from_composition(composition) do
    case composition do
      %{"ships" => ships} when is_list(ships) ->
        Enum.map(ships, &(&1["type_id"] || &1[:type_id]))

      ships when is_list(ships) ->
        Enum.map(ships, &(&1["type_id"] || &1[:type_id] || &1))

      %{} ->
        Map.keys(composition)

      _ ->
        []
    end
    |> Enum.reject(&is_nil/1)
  end

  defp analyze_vs_armor_hacs_basic(ship_types) do
    has_ewar = Enum.any?(ship_types, &EveDmv.StaticData.ShipRoles.ewar_ship?/1)
    has_high_alpha = has_alpha_ships?(ship_types)

    effectiveness = calculate_basic_effectiveness_vs_armor_hacs(has_ewar, has_high_alpha)

    %{
      "threat_type" => "Armor HAC gang",
      "effectiveness" => effectiveness,
      "recommended_changes" => generate_armor_hac_counters_basic(has_ewar, has_high_alpha)
    }
  end

  defp analyze_vs_shield_cruisers_basic(ship_types) do
    has_range = has_range_ships?(ship_types)
    has_mobility = has_mobile_ships?(ship_types)

    effectiveness = calculate_basic_effectiveness_vs_shield_cruisers(has_range, has_mobility)

    %{
      "threat_type" => "Shield cruiser gang",
      "effectiveness" => effectiveness,
      "recommended_changes" => generate_shield_cruiser_counters_basic(has_range, has_mobility)
    }
  end

  defp has_alpha_ships?(ship_types) do
    # Check for battleships and battlecruisers which typically have good alpha
    Enum.any?(ship_types, fn type_id ->
      case EveDmv.StaticData.ShipTypes.classify_ship_type(type_id) do
        class when class in [:battleship, :battlecruiser] -> true
        _ -> false
      end
    end)
  end

  defp has_range_ships?(ship_types) do
    # Assume cruisers and above have good range capabilities
    Enum.any?(ship_types, fn type_id ->
      case EveDmv.StaticData.ShipTypes.classify_ship_type(type_id) do
        class when class in [:cruiser, :battlecruiser, :battleship] -> true
        _ -> false
      end
    end)
  end

  defp has_mobile_ships?(ship_types) do
    # Check for frigates and destroyers
    Enum.any?(ship_types, fn type_id ->
      case EveDmv.StaticData.ShipTypes.classify_ship_type(type_id) do
        class when class in [:frigate, :destroyer] -> true
        _ -> false
      end
    end)
  end

  defp calculate_basic_effectiveness_vs_armor_hacs(has_ewar, has_high_alpha) do
    0.5
    |> add_ewar_bonus(has_ewar)
    |> add_alpha_bonus(has_high_alpha)
    |> min(1.0)
    |> Float.round(2)
  end

  defp add_ewar_bonus(base, true), do: base + 0.2
  defp add_ewar_bonus(base, false), do: base

  defp add_alpha_bonus(base, true), do: base + 0.15
  defp add_alpha_bonus(base, false), do: base

  defp calculate_basic_effectiveness_vs_shield_cruisers(has_range, has_mobility) do
    0.6
    |> add_range_bonus(has_range)
    |> add_mobility_bonus(has_mobility)
    |> min(1.0)
    |> Float.round(2)
  end

  defp add_range_bonus(base, true), do: base + 0.15
  defp add_range_bonus(base, false), do: base

  defp add_mobility_bonus(base, true), do: base + 0.1
  defp add_mobility_bonus(base, false), do: base

  defp generate_armor_hac_counters_basic(has_ewar, has_high_alpha) do
    []
    |> maybe_add_ewar_counter(has_ewar)
    |> maybe_add_alpha_counter(has_high_alpha)
    |> finalize_armor_hac_counters()
  end

  defp maybe_add_ewar_counter(counters, true), do: counters
  defp maybe_add_ewar_counter(counters, false), do: ["Add EWAR support" | counters]

  defp maybe_add_alpha_counter(counters, true), do: counters
  defp maybe_add_alpha_counter(counters, false), do: ["Increase alpha damage" | counters]

  defp finalize_armor_hac_counters([]), do: ["Composition effective as-is"]
  defp finalize_armor_hac_counters(counters), do: counters

  defp generate_shield_cruiser_counters_basic(has_range, has_mobility) do
    []
    |> maybe_add_range_counter(has_range)
    |> maybe_add_mobility_counter(has_mobility)
    |> finalize_shield_cruiser_counters()
  end

  defp maybe_add_range_counter(counters, true), do: counters
  defp maybe_add_range_counter(counters, false), do: ["Add long-range ships" | counters]

  defp maybe_add_mobility_counter(counters, true), do: counters
  defp maybe_add_mobility_counter(counters, false), do: ["Add mobile elements" | counters]

  defp finalize_shield_cruiser_counters([]), do: ["Good matchup"]
  defp finalize_shield_cruiser_counters(counters), do: counters
end

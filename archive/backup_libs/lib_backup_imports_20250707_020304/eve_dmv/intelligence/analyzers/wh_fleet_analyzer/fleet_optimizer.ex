defmodule EveDmv.Intelligence.Analyzers.WhFleetAnalyzer.FleetOptimizer do
  alias EveDmv.Intelligence.Fleet.FleetEffectivenessCalculator

  require Logger
  @moduledoc """
  Handles fleet optimization and recommendation generation.

  This module provides functionality for generating optimization
  recommendations, analyzing counter-doctrines, and creating
  situational variants of fleet compositions.
  """



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
  def generate_counter_doctrine_analysis(_composition) do
    # Generate analysis of how this doctrine performs against common threats
    [
      %{
        "threat_type" => "Armor HAC gang",
        "effectiveness" => 0.85,
        "recommended_changes" => ["Add EWAR support", "Increase alpha damage"]
      },
      %{
        "threat_type" => "Shield cruiser gang",
        "effectiveness" => 0.75,
        "recommended_changes" => ["Add neut pressure", "Focus on mobility"]
      }
    ]
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
    priority_improvements = []
    suggested_additions = []

    # Analyze survivability needs
    {priority_improvements, suggested_additions} =
      analyze_survivability_needs(
        effectiveness_metrics,
        role_analysis,
        priority_improvements,
        suggested_additions
      )

    # Analyze command capability
    {priority_improvements, suggested_additions} =
      analyze_command_capability(
        effectiveness_metrics,
        priority_improvements,
        suggested_additions
      )

    # Analyze doctrine compliance
    doctrine_suggestions = analyze_doctrine_compliance_suggestions(fleet_data)

    # Generate role-specific recommendations
    role_recommendations = generate_role_recommendations()

    %{
      priority_improvements: priority_improvements,
      suggested_additions: suggested_additions,
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

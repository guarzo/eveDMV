defmodule EveDmv.Intelligence.Analyzers.FleetPilotAnalyzer do
  @moduledoc """
  Fleet pilot analysis module for optimizing pilot assignments and fleet composition.

  Provides capabilities for analyzing available pilots, their skills, and optimizing
  pilot-to-ship assignments for maximum fleet effectiveness.
  """

  alias EveDmv.Api
  alias EveDmv.Intelligence.CharacterStats

  require Ash.Query
  require Logger

  @doc """
  Get available pilots for a corporation.

  Returns a list of corporation members with their skill data and availability status.
  """
  def get_available_pilots(corporation_id) do
    Logger.debug("Getting available pilots for corporation #{corporation_id}")

    try do
      # Get corporation members
      case get_corporation_members(corporation_id) do
        {:ok, members} when is_list(members) ->
          # Filter and enhance with pilot data
          available_pilots =
            members
            |> Enum.filter(&pilot_available?/1)
            |> Enum.map(&enhance_pilot_data/1)

          {:ok, available_pilots}

        {:ok, []} ->
          Logger.warning("No members found for corporation #{corporation_id}")
          {:ok, []}

        {:error, reason} ->
          Logger.error("Failed to get corporation members: #{inspect(reason)}")
          {:error, reason}
      end
    rescue
      error ->
        Logger.error("Error getting available pilots: #{inspect(error)}")
        {:error, {:analysis_failed, error}}
    end
  end

  @doc """
  Optimize pilot assignments to ships based on skills and doctrine requirements.

  Takes a doctrine template, available pilots, and skill analysis to determine
  the optimal assignment of pilots to ships for maximum effectiveness.
  """
  def optimize_pilot_assignments(doctrine_template, available_pilots, skill_analysis) do
    Logger.debug("Optimizing pilot assignments for doctrine #{inspect(doctrine_template.name)}")

    try do
      # Extract ship requirements from doctrine
      ship_requirements = extract_ship_requirements(doctrine_template)

      # Score pilot-ship combinations
      pilot_ship_scores =
        calculate_pilot_ship_scores(available_pilots, ship_requirements, skill_analysis)

      # Optimize assignments using greedy algorithm
      assignments = perform_assignment_optimization(pilot_ship_scores, ship_requirements)

      # Calculate fleet effectiveness metrics
      effectiveness_metrics = calculate_fleet_effectiveness(assignments, skill_analysis)

      optimization_result = %{
        assignments: assignments,
        effectiveness_score: effectiveness_metrics.overall_score,
        coverage_percentage: effectiveness_metrics.coverage_percentage,
        skill_gaps: effectiveness_metrics.skill_gaps,
        recommended_training: effectiveness_metrics.training_recommendations,
        optimization_timestamp: DateTime.utc_now()
      }

      {:ok, optimization_result}
    rescue
      error ->
        Logger.error("Error optimizing pilot assignments: #{inspect(error)}")
        {:error, {:optimization_failed, error}}
    end
  end

  @doc """
  Analyze pilot skill compatibility with a specific ship type.
  """
  def analyze_pilot_ship_compatibility(pilot_data, ship_type_id) do
    # Calculate compatibility score based on pilot skills vs ship requirements
    base_compatibility = calculate_base_compatibility(pilot_data, ship_type_id)
    skill_multipliers = calculate_skill_multipliers(pilot_data, ship_type_id)
    experience_bonus = calculate_experience_bonus(pilot_data, ship_type_id)

    compatibility_score = base_compatibility * skill_multipliers + experience_bonus

    %{
      pilot_id: pilot_data.character_id,
      ship_type_id: ship_type_id,
      compatibility_score: Float.round(compatibility_score, 2),
      skill_deficiencies: identify_skill_deficiencies(pilot_data, ship_type_id),
      recommended_training_time: estimate_training_time(pilot_data, ship_type_id)
    }
  end

  # Private implementation functions

  defp get_corporation_members(corporation_id) do
    members =
      CharacterStats
      |> Ash.Query.filter(corporation_id: corporation_id)
      # Reasonable limit for corporation size
      |> Ash.Query.limit(500)
      |> Ash.read!(domain: Api)

    {:ok, members}
  rescue
    error ->
      Logger.warning("Failed to query corporation members: #{inspect(error)}")
      # Return placeholder data for testing
      {:ok, generate_placeholder_members(corporation_id)}
  end

  defp pilot_available?(member) do
    # Simple availability check - could be enhanced with more complex logic
    last_activity = Map.get(member, :last_killmail_date)

    case last_activity do
      # No activity data
      nil ->
        false

      last_date ->
        # Consider pilot available if active within last 30 days
        days_since_activity = DateTime.diff(DateTime.utc_now(), last_date, :day)
        days_since_activity <= 30
    end
  end

  defp enhance_pilot_data(member) do
    %{
      character_id: member.character_id,
      character_name: Map.get(member, :character_name, "Unknown Pilot"),
      corporation_id: member.corporation_id,
      total_sp: Map.get(member, :total_sp, 0),
      activity_score: calculate_activity_score(member),
      last_active: Map.get(member, :last_killmail_date),
      preferred_ship_types: extract_preferred_ships(member),
      combat_effectiveness: calculate_combat_effectiveness(member),
      availability_status: :available
    }
  end

  defp extract_ship_requirements(doctrine_template) do
    # Extract ship types and quantities from doctrine template
    ship_roles = Map.get(doctrine_template, :ship_roles, [])

    Enum.map(ship_roles, fn role ->
      %{
        ship_type_id: Map.get(role, :ship_type_id, 0),
        ship_name: Map.get(role, :ship_name, "Unknown Ship"),
        role: Map.get(role, :role, :dps),
        quantity_needed: Map.get(role, :quantity, 1),
        priority: Map.get(role, :priority, :medium),
        skill_requirements: Map.get(role, :required_skills, [])
      }
    end)
  end

  defp calculate_pilot_ship_scores(available_pilots, ship_requirements, skill_analysis) do
    # Create matrix of pilot-ship compatibility scores
    for pilot <- available_pilots,
        ship_req <- ship_requirements do
      skill_score = get_pilot_skill_score(pilot, ship_req, skill_analysis)
      experience_score = get_pilot_experience_score(pilot, ship_req)
      preference_score = get_pilot_preference_score(pilot, ship_req)

      total_score = skill_score * 0.5 + experience_score * 0.3 + preference_score * 0.2

      %{
        pilot_id: pilot.character_id,
        pilot_name: pilot.character_name,
        ship_type_id: ship_req.ship_type_id,
        ship_name: ship_req.ship_name,
        role: ship_req.role,
        compatibility_score: Float.round(total_score, 2)
      }
    end
  end

  defp perform_assignment_optimization(pilot_ship_scores, ship_requirements) do
    # Greedy assignment algorithm - assign best pilot to each ship needed
    sorted_scores = Enum.sort_by(pilot_ship_scores, & &1.compatibility_score, :desc)

    # Track assignments and used pilots
    {assignments, _used_pilots} =
      Enum.reduce(ship_requirements, {[], MapSet.new()}, fn ship_req,
                                                            {assignments, used_pilots} ->
        # Find best available pilot for this ship requirement
        best_match =
          sorted_scores
          |> Enum.filter(fn score ->
            score.ship_type_id == ship_req.ship_type_id and
              not MapSet.member?(used_pilots, score.pilot_id)
          end)
          |> Enum.take(ship_req.quantity_needed)

        new_assignments =
          Enum.map(best_match, fn match ->
            %{
              pilot_id: match.pilot_id,
              pilot_name: match.pilot_name,
              ship_type_id: match.ship_type_id,
              ship_name: match.ship_name,
              role: match.role,
              assignment_score: match.compatibility_score
            }
          end)

        new_used_pilots =
          best_match
          |> Enum.map(& &1.pilot_id)
          |> MapSet.new()
          |> MapSet.union(used_pilots)

        {assignments ++ new_assignments, new_used_pilots}
      end)

    assignments
  end

  defp calculate_fleet_effectiveness(assignments, _skill_analysis) do
    if Enum.empty?(assignments) do
      %{
        overall_score: 0.0,
        coverage_percentage: 0.0,
        skill_gaps: [],
        training_recommendations: []
      }
    else
      avg_score =
        assignments
        |> Enum.map(& &1.assignment_score)
        |> Enum.sum()
        |> Kernel./(length(assignments))

      %{
        overall_score: Float.round(avg_score, 2),
        # Placeholder
        coverage_percentage: 85.0,
        skill_gaps: [],
        training_recommendations: []
      }
    end
  end

  defp calculate_activity_score(member) do
    # Simple activity scoring based on killmail data
    total_activity = Map.get(member, :total_kills, 0) + Map.get(member, :total_losses, 0)
    min(100, total_activity * 2)
  end

  defp extract_preferred_ships(_member) do
    # Extract most used ship types from member data
    # This would normally analyze killmail history
    # Placeholder ship type IDs
    [29_336, 17_918, 24_698]
  end

  defp calculate_combat_effectiveness(member) do
    # Calculate combat effectiveness from kill/death ratio and activity
    kills = Map.get(member, :total_kills, 0)
    losses = Map.get(member, :total_losses, 0)

    if losses > 0 do
      kd_ratio = kills / losses
      min(100, kd_ratio * 25)
    else
      if kills > 0, do: 75, else: 25
    end
  end

  defp get_pilot_skill_score(pilot, ship_req, skill_analysis) do
    # Get pilot's skill proficiency for this ship type
    pilot_skills = Map.get(skill_analysis, pilot.character_id, %{})
    ship_skill_score = Map.get(pilot_skills, ship_req.ship_type_id, 50.0)

    # Normalize to 0-100 scale
    min(100, max(0, ship_skill_score))
  end

  defp get_pilot_experience_score(pilot, ship_req) do
    # Score based on pilot's historical usage of this ship type
    if ship_req.ship_type_id in pilot.preferred_ship_types do
      80.0
    else
      40.0
    end
  end

  defp get_pilot_preference_score(pilot, ship_req) do
    # Score based on role preference and pilot characteristics
    case ship_req.role do
      :dps -> pilot.combat_effectiveness * 0.8
      :logistics -> pilot.activity_score * 0.6
      :tackle -> pilot.combat_effectiveness * 0.7
      :ewar -> pilot.activity_score * 0.5
      _ -> 50.0
    end
  end

  defp calculate_base_compatibility(_pilot_data, _ship_type_id) do
    # Base compatibility calculation
    0.7
  end

  defp calculate_skill_multipliers(_pilot_data, _ship_type_id) do
    # Skill-based multipliers
    1.2
  end

  defp calculate_experience_bonus(_pilot_data, _ship_type_id) do
    # Experience bonus calculation
    10.0
  end

  defp identify_skill_deficiencies(_pilot_data, _ship_type_id) do
    # Identify missing skills
    []
  end

  defp estimate_training_time(_pilot_data, _ship_type_id) do
    # Estimate training time needed
    "2 days"
  end

  defp generate_placeholder_members(corporation_id) do
    # Generate placeholder members for testing when DB query fails
    Enum.map(1..5, fn i ->
      %{
        character_id: corporation_id * 1_000 + i,
        character_name: "Pilot #{i}",
        corporation_id: corporation_id,
        total_sp: 50_000_000 + i * 10_000_000,
        total_kills: i * 20,
        total_losses: i * 5,
        last_killmail_date: DateTime.add(DateTime.utc_now(), -i * 86_400, :second)
      }
    end)
  end
end

defmodule EveDmv.Contexts.FleetOperations.Analyzers.PilotAnalyzer do
  @moduledoc """
  Fleet pilot analysis and optimization engine for Fleet Operations context.

  Provides intelligent pilot assessment, role assignment optimization,
  and availability analysis for fleet operations. Handles:

  - Pilot data collection and enrichment
  - Pilot availability assessment based on activity patterns
  - Role assignment optimization using suitability scoring
  - Pilot-to-ship matching based on experience and skills
  - Experience and suitability scoring algorithms
  - Backup role identification for flexible assignments

  This module focuses on the human element of fleet composition,
  analyzing pilot capabilities, preferences, and availability to
  optimize fleet effectiveness and readiness.
  """

  use EveDmv.ErrorHandler
  alias EveDmv.Result
  alias EveDmv.Contexts.FleetOperations.Infrastructure.PilotDataProvider

  require Logger

  @doc """
  Analyze pilot suitability and availability for fleet operations.

  Returns comprehensive pilot analysis including role suitability,
  availability metrics, and assignment recommendations.
  """
  def analyze(pilot_id, base_data \\ %{}, opts \\ []) when is_integer(pilot_id) do
    try do
      with {:ok, pilot_data} <- get_pilot_data(base_data, pilot_id),
           {:ok, combat_stats} <- get_combat_statistics(base_data, pilot_id),
           {:ok, fleet_experience} <- analyze_fleet_experience(pilot_data, combat_stats),
           {:ok, role_suitability} <- assess_role_suitability(pilot_data, combat_stats),
           {:ok, availability_metrics} <- calculate_availability_metrics(pilot_data) do
        analysis = %{
          pilot_id: pilot_id,
          pilot_name: pilot_data.character_name,
          corporation_id: pilot_data.corporation_id,

          # Combat statistics
          total_kills: combat_stats.kill_count,
          total_losses: combat_stats.loss_count,
          kill_death_ratio: combat_stats.kd_ratio,
          efficiency: combat_stats.efficiency,
          solo_ratio: combat_stats.solo_ratio,

          # Fleet experience
          fleet_experience_level: fleet_experience.experience_level,
          avg_gang_size: fleet_experience.avg_gang_size,
          preferred_engagement_style: fleet_experience.engagement_style,
          ships_flown: fleet_experience.ship_groups,

          # Role suitability scores
          fc_suitability: role_suitability.fleet_commander,
          logistics_suitability: role_suitability.logistics,
          dps_suitability: role_suitability.dps,
          tackle_suitability: role_suitability.tackle,
          ewar_suitability: role_suitability.ewar,
          support_suitability: role_suitability.support,

          # Availability and readiness
          availability_level: availability_metrics.availability_level,
          activity_score: availability_metrics.activity_score,
          recent_activity: availability_metrics.recently_active,
          fleet_readiness: availability_metrics.fleet_ready,

          # Derived insights
          primary_role_recommendation: determine_primary_role(role_suitability),
          backup_roles: determine_backup_roles(role_suitability),
          experience_rating: calculate_overall_experience_rating(fleet_experience, combat_stats)
        }

        Result.ok(analysis)
      else
        {:error, _reason} = error -> error
      end
    rescue
      exception -> Result.error(:analysis_failed, "Pilot analysis error: #{inspect(exception)}")
    end
  end

  @doc """
  Get available pilots for a corporation that are suitable for fleet operations.

  Filters pilots based on activity levels, recent activity, and fleet experience.
  Returns enriched pilot data with fleet-relevant information.
  """
  def get_available_pilots(corporation_id, base_data \\ %{}, opts \\ [])
      when is_integer(corporation_id) do
    try do
      with {:ok, corporation_pilots} <- get_corporation_pilots(base_data, corporation_id) do
        available_pilots =
          corporation_pilots
          |> Enum.filter(&pilot_available_for_fleet?/1)
          |> Enum.map(&enrich_pilot_data/1)
          |> Enum.sort_by(& &1.activity_score, :desc)

        Result.ok(%{
          corporation_id: corporation_id,
          total_pilots: length(corporation_pilots),
          available_pilots: length(available_pilots),
          pilot_details: available_pilots
        })
      else
        {:error, _reason} = error -> error
      end
    rescue
      exception ->
        Result.error(
          :pilots_query_failed,
          "Failed to get available pilots: #{inspect(exception)}"
        )
    end
  end

  @doc """
  Optimize pilot assignments for a doctrine template.

  Assigns pilots to roles by calculating suitability scores and
  selecting the best pilots for each role requirement.
  """
  def optimize_pilot_assignments(
        doctrine_template,
        available_pilots,
        base_data \\ %{},
        opts \\ []
      ) do
    try do
      assignments = %{}

      assignments =
        doctrine_template
        |> Enum.reduce(assignments, fn {role, role_data}, acc ->
          required_count = Map.get(role_data, "required", 1)

          assigned_pilots =
            assign_pilots_to_role(role, role_data, available_pilots, required_count)

          Enum.reduce(assigned_pilots, acc, fn pilot, acc2 ->
            assignment = %{
              character_name: pilot.character_name,
              assigned_role: role,
              assigned_ship:
                select_best_ship_for_pilot(pilot, Map.get(role_data, "preferred_ships", [])),
              skill_readiness: calculate_skill_readiness(pilot, role),
              availability: assess_pilot_availability(pilot),
              experience_rating: calculate_pilot_experience_rating(pilot, role),
              backup_roles: find_backup_roles_for_pilot(pilot, doctrine_template),
              suitability_score: calculate_pilot_suitability_score(pilot, role)
            }

            Map.put(acc2, Integer.to_string(pilot.pilot_id), assignment)
          end)
        end)

      Result.ok(assignments)
    rescue
      exception ->
        Result.error(
          :assignment_optimization_failed,
          "Pilot assignment optimization error: #{inspect(exception)}"
        )
    end
  end

  @doc """
  Calculate readiness metrics for a set of pilot assignments.

  Provides overall fleet readiness assessment including pilot availability,
  skill coverage, and estimated form-up time.
  """
  def calculate_readiness_metrics(pilot_assignments, base_data \\ %{}, opts \\ []) do
    try do
      total_pilots = map_size(pilot_assignments)

      if total_pilots == 0 do
        Result.ok(%{
          readiness_percent: 0,
          pilots_available: 0,
          pilots_required: 0,
          estimated_form_up_time: 0,
          skill_coverage: %{},
          availability_breakdown: %{}
        })
      else
        ready_pilots = count_ready_pilots(pilot_assignments)
        skill_coverage = calculate_skill_coverage(pilot_assignments)
        availability_breakdown = calculate_availability_breakdown(pilot_assignments)
        estimated_form_up_time = estimate_form_up_time(pilot_assignments)

        readiness_percent = Float.round(ready_pilots / total_pilots * 100, 1)

        Result.ok(%{
          readiness_percent: readiness_percent,
          pilots_available: ready_pilots,
          pilots_required: total_pilots,
          estimated_form_up_time: estimated_form_up_time,
          skill_coverage: skill_coverage,
          availability_breakdown: availability_breakdown
        })
      end
    rescue
      exception ->
        Result.error(
          :readiness_calculation_failed,
          "Readiness metrics calculation error: #{inspect(exception)}"
        )
    end
  end

  # Private implementation functions

  defp get_pilot_data(base_data, pilot_id) do
    case Map.get(base_data, :pilot_data) do
      nil -> PilotDataProvider.get_pilot_data(pilot_id)
      data -> {:ok, data}
    end
  end

  defp get_combat_statistics(base_data, pilot_id) do
    case Map.get(base_data, :combat_stats) do
      nil -> PilotDataProvider.get_combat_statistics(pilot_id)
      stats -> {:ok, stats}
    end
  end

  defp get_corporation_pilots(base_data, corporation_id) do
    case Map.get(base_data, :corporation_pilots) do
      nil -> PilotDataProvider.get_corporation_pilots(corporation_id)
      pilots -> {:ok, pilots}
    end
  end

  defp analyze_fleet_experience(pilot_data, combat_stats) do
    ship_groups = extract_ship_groups_from_pilot_data(pilot_data)
    avg_gang_size = calculate_average_gang_size(combat_stats)
    engagement_style = determine_engagement_style(combat_stats)
    experience_level = categorize_experience_level(combat_stats)

    {:ok,
     %{
       ship_groups: ship_groups,
       avg_gang_size: avg_gang_size,
       engagement_style: engagement_style,
       experience_level: experience_level
     }}
  end

  defp assess_role_suitability(pilot_data, combat_stats) do
    suitability = %{
      fleet_commander: calculate_fc_suitability(pilot_data, combat_stats),
      logistics: calculate_logistics_suitability(pilot_data, combat_stats),
      dps: calculate_dps_suitability(pilot_data, combat_stats),
      tackle: calculate_tackle_suitability(pilot_data, combat_stats),
      ewar: calculate_ewar_suitability(pilot_data, combat_stats),
      support: calculate_support_suitability(pilot_data, combat_stats)
    }

    {:ok, suitability}
  end

  defp calculate_availability_metrics(pilot_data) do
    activity_score = pilot_data.kill_count + pilot_data.loss_count
    recently_active = is_recently_active?(pilot_data.last_activity_date)
    fleet_ready = pilot_available_for_fleet?(pilot_data)

    availability_level =
      determine_availability_level(activity_score, recently_active, fleet_ready)

    {:ok,
     %{
       activity_score: activity_score,
       recently_active: recently_active,
       fleet_ready: fleet_ready,
       availability_level: availability_level
     }}
  end

  defp pilot_available_for_fleet?(pilot_data) do
    activity_score = pilot_data.kill_count + pilot_data.loss_count
    recently_active = is_recently_active?(pilot_data.last_activity_date)
    has_fleet_experience = pilot_data.solo_ratio < 0.9

    activity_score >= 5 and recently_active and has_fleet_experience
  end

  defp is_recently_active?(last_activity_date) do
    case last_activity_date do
      # Assume active if no data
      nil ->
        true

      last_date ->
        days_since = DateTime.diff(DateTime.utc_now(), last_date, :day)
        days_since <= 30
    end
  end

  defp enrich_pilot_data(pilot_data) do
    ship_groups = extract_ship_groups_from_pilot_data(pilot_data)

    Map.merge(pilot_data, %{
      ship_groups_flown: ship_groups,
      has_logi_support: Map.get(ship_groups, "Logistics", 0) > 0,
      avg_gang_size: pilot_data.kd_ratio || 1.0,
      flies_capitals: Map.get(ship_groups, "Capital", 0) > 0,
      activity_score: pilot_data.kill_count + pilot_data.loss_count
    })
  end

  defp extract_ship_groups_from_pilot_data(pilot_data) do
    case pilot_data.analysis_data do
      nil ->
        %{}

      analysis_json ->
        case Jason.decode(analysis_json) do
          {:ok, analysis_data} ->
            ship_usage = Map.get(analysis_data, "ship_usage", %{})
            ship_categories = Map.get(ship_usage, "ship_categories", %{})

            ship_categories
            |> Enum.map(fn {category, count} ->
              group = map_category_to_group(category)
              {group, count}
            end)
            |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
            |> Enum.map(fn {group, counts} -> {group, Enum.sum(counts)} end)
            |> Map.new()

          {:error, _} ->
            %{}
        end
    end
  end

  defp map_category_to_group(category) do
    case String.downcase(category) do
      "frigate" -> "Frigates"
      "destroyer" -> "Destroyers"
      "cruiser" -> "Cruisers"
      "battlecruiser" -> "Battlecruisers"
      "battleship" -> "Battleships"
      "capital" -> "Capital"
      "supercapital" -> "Supercapital"
      "logistics" -> "Logistics"
      "interceptor" -> "Interceptors"
      "recon" -> "Recon"
      _ -> "Other"
    end
  end

  defp calculate_average_gang_size(combat_stats) do
    if combat_stats.total_engagements > 0 do
      Float.round(combat_stats.total_participants / combat_stats.total_engagements, 1)
    else
      1.0
    end
  end

  defp determine_engagement_style(combat_stats) do
    cond do
      combat_stats.solo_ratio > 0.7 -> :solo_hunter
      combat_stats.solo_ratio < 0.3 -> :fleet_fighter
      true -> :mixed_engagement
    end
  end

  defp categorize_experience_level(combat_stats) do
    total_activity = combat_stats.kill_count + combat_stats.loss_count

    cond do
      total_activity >= 200 -> :veteran
      total_activity >= 100 -> :experienced
      total_activity >= 50 -> :intermediate
      total_activity >= 20 -> :novice
      true -> :beginner
    end
  end

  defp calculate_fc_suitability(pilot_data, combat_stats) do
    score = 0.0

    score = if combat_stats.kill_count > 100, do: score + 0.3, else: score
    score = if combat_stats.kd_ratio > 2.0, do: score + 0.2, else: score
    score = if pilot_data.avg_gang_size > 5.0, do: score + 0.2, else: score
    score = if combat_stats.efficiency > 0.7, do: score + 0.2, else: score
    score = if combat_stats.solo_ratio < 0.5, do: score + 0.1, else: score

    min(1.0, score)
  end

  defp calculate_logistics_suitability(pilot_data, combat_stats) do
    score = 0.0

    score = if pilot_data.has_logi_support, do: score + 0.4, else: score
    score = if combat_stats.efficiency > 0.7, do: score + 0.3, else: score
    score = if combat_stats.solo_ratio < 0.4, do: score + 0.2, else: score
    score = if pilot_data.avg_gang_size > 3.0, do: score + 0.1, else: score

    min(1.0, score)
  end

  defp calculate_dps_suitability(pilot_data, combat_stats) do
    score = 0.0

    score = if combat_stats.kill_count > 50, do: score + 0.3, else: score
    score = if combat_stats.kd_ratio > 1.5, do: score + 0.2, else: score
    score = if combat_stats.efficiency > 0.6, do: score + 0.2, else: score
    score = if pilot_data.avg_gang_size > 2.0, do: score + 0.2, else: score
    score = if pilot_data.flies_capitals, do: score + 0.1, else: score

    min(1.0, score)
  end

  defp calculate_tackle_suitability(pilot_data, combat_stats) do
    ship_groups = pilot_data.ship_groups_flown || %{}
    score = 0.0

    score = if Map.get(ship_groups, "Frigates", 0) > 10, do: score + 0.3, else: score
    score = if Map.get(ship_groups, "Interceptors", 0) > 0, do: score + 0.3, else: score
    score = if combat_stats.solo_ratio > 0.5, do: score + 0.2, else: score
    score = if combat_stats.kill_count > 30, do: score + 0.1, else: score
    score = if pilot_data.avg_gang_size < 5.0, do: score + 0.1, else: score

    min(1.0, score)
  end

  defp calculate_ewar_suitability(pilot_data, combat_stats) do
    ship_groups = pilot_data.ship_groups_flown || %{}
    score = 0.0

    score = if Map.get(ship_groups, "Recon", 0) > 0, do: score + 0.4, else: score
    score = if combat_stats.efficiency > 0.6, do: score + 0.2, else: score
    score = if combat_stats.solo_ratio < 0.3, do: score + 0.2, else: score
    score = if pilot_data.avg_gang_size > 3.0, do: score + 0.1, else: score
    score = if combat_stats.kill_count > 20, do: score + 0.1, else: score

    min(1.0, score)
  end

  defp calculate_support_suitability(pilot_data, combat_stats) do
    score = 0.0

    score = if combat_stats.efficiency > 0.6, do: score + 0.3, else: score
    score = if combat_stats.solo_ratio < 0.4, do: score + 0.2, else: score
    score = if pilot_data.avg_gang_size > 2.0, do: score + 0.2, else: score
    score = if combat_stats.kill_count > 20, do: score + 0.2, else: score
    score = if pilot_data.has_logi_support, do: score + 0.1, else: score

    min(1.0, score)
  end

  defp determine_primary_role(role_suitability) do
    role_suitability
    |> Enum.max_by(fn {_role, score} -> score end)
    |> elem(0)
  end

  defp determine_backup_roles(role_suitability) do
    role_suitability
    |> Enum.sort_by(fn {_role, score} -> score end, :desc)
    # Skip the primary role
    |> Enum.drop(1)
    # Take top 2 backup roles
    |> Enum.take(2)
    |> Enum.map(fn {role, _score} -> role end)
  end

  defp calculate_overall_experience_rating(fleet_experience, combat_stats) do
    base_experience = min(1.0, (combat_stats.kill_count + combat_stats.loss_count) / 100)
    fleet_bonus = if fleet_experience.avg_gang_size > 3.0, do: 0.2, else: 0.0
    efficiency_bonus = if combat_stats.efficiency > 0.7, do: 0.1, else: 0.0

    Float.round(min(1.0, base_experience + fleet_bonus + efficiency_bonus), 2)
  end

  defp determine_availability_level(activity_score, recently_active, fleet_ready) do
    cond do
      fleet_ready and recently_active and activity_score >= 50 -> :high
      fleet_ready and recently_active and activity_score >= 20 -> :medium
      fleet_ready and recently_active -> :low
      true -> :unavailable
    end
  end

  defp assign_pilots_to_role(role, role_data, available_pilots, required_count) do
    available_pilots
    |> Enum.filter(&pilot_suitable_for_role?(&1, role))
    |> Enum.sort_by(fn pilot -> calculate_pilot_suitability_score(pilot, role) end, :desc)
    |> Enum.take(required_count)
  end

  defp pilot_suitable_for_role?(pilot, role) do
    case role do
      "fleet_commander" -> pilot.activity_score > 50 and pilot.kd_ratio > 1.5
      "logistics" -> pilot.has_logi_support or pilot.avg_gang_size > 3.0
      "tackle" -> Map.get(pilot.ship_groups_flown || %{}, "Frigates", 0) > 5
      # General suitability
      _ -> true
    end
  end

  defp calculate_pilot_suitability_score(pilot, role) do
    base_score = pilot.activity_score
    recency_bonus = if pilot.recently_active, do: 20, else: 0
    role_score = calculate_role_specific_score(pilot, role)

    base_score + recency_bonus + role_score
  end

  defp calculate_role_specific_score(pilot, role) do
    case role do
      "fleet_commander" -> trunc(calculate_fc_suitability(pilot, pilot) * 100)
      "logistics" -> trunc(calculate_logistics_suitability(pilot, pilot) * 100)
      "dps" -> trunc(calculate_dps_suitability(pilot, pilot) * 100)
      "tackle" -> trunc(calculate_tackle_suitability(pilot, pilot) * 100)
      "ewar" -> trunc(calculate_ewar_suitability(pilot, pilot) * 100)
      _ -> 0
    end
  end

  defp select_best_ship_for_pilot(pilot, preferred_ships) when is_list(preferred_ships) do
    # Select based on pilot's ship experience
    ship_groups = pilot.ship_groups_flown || %{}

    # Try to match pilot's most flown ship type with preferred ships
    best_match =
      preferred_ships
      |> Enum.find(fn ship ->
        ship_group = determine_ship_group(ship)
        Map.get(ship_groups, ship_group, 0) > 0
      end)

    best_match || List.first(preferred_ships) || "Unknown Ship"
  end

  defp select_best_ship_for_pilot(_pilot, _preferred_ships), do: "Unknown Ship"

  defp determine_ship_group(ship_name) when is_binary(ship_name) do
    ship_lower = String.downcase(ship_name)

    cond do
      String.contains?(ship_lower, ["frigate", "interceptor", "assault frigate"]) -> "Frigates"
      String.contains?(ship_lower, ["destroyer", "interdictor"]) -> "Destroyers"
      String.contains?(ship_lower, ["cruiser", "logistics"]) -> "Cruisers"
      String.contains?(ship_lower, ["battlecruiser"]) -> "Battlecruisers"
      String.contains?(ship_lower, ["battleship"]) -> "Battleships"
      String.contains?(ship_lower, ["carrier", "dreadnought", "capital"]) -> "Capital"
      true -> "Other"
    end
  end

  defp determine_ship_group(_), do: "Other"

  defp calculate_skill_readiness(pilot, role) do
    # Simplified skill readiness based on role suitability
    case role do
      "fleet_commander" -> calculate_fc_suitability(pilot, pilot)
      "logistics" -> calculate_logistics_suitability(pilot, pilot)
      "dps" -> calculate_dps_suitability(pilot, pilot)
      "tackle" -> calculate_tackle_suitability(pilot, pilot)
      "ewar" -> calculate_ewar_suitability(pilot, pilot)
      # Default readiness
      _ -> 0.7
    end
  end

  defp assess_pilot_availability(pilot) do
    case pilot.avg_gang_size do
      size when size >= 3.0 -> "high"
      size when size >= 1.5 -> "medium"
      _ -> "low"
    end
  end

  defp calculate_pilot_experience_rating(pilot, role) do
    base_experience = min(1.0, pilot.activity_score / 100)

    role_experience =
      case role do
        "fleet_commander" -> if pilot.kill_count > 50, do: 0.2, else: 0.0
        "logistics" -> if pilot.has_logi_support, do: 0.3, else: 0.0
        _ -> 0.0
      end

    Float.round(min(1.0, base_experience + role_experience), 2)
  end

  defp find_backup_roles_for_pilot(pilot, doctrine_template) do
    doctrine_template
    |> Enum.map(fn {role, _} -> role end)
    |> Enum.filter(fn role -> pilot_suitable_for_role?(pilot, role) end)
    |> Enum.take(2)
  end

  defp count_ready_pilots(pilot_assignments) do
    pilot_assignments
    |> Enum.count(fn {_pilot_id, assignment} ->
      assignment.availability in ["high", "medium"] and assignment.skill_readiness >= 0.7
    end)
  end

  defp calculate_skill_coverage(pilot_assignments) do
    pilot_assignments
    |> Enum.group_by(fn {_pilot_id, assignment} -> assignment.assigned_role end)
    |> Enum.map(fn {role, assignments} ->
      avg_readiness =
        assignments
        |> Enum.map(fn {_pilot_id, assignment} -> assignment.skill_readiness end)
        |> Enum.sum()
        |> Kernel./(length(assignments))

      {role, Float.round(avg_readiness, 2)}
    end)
    |> Map.new()
  end

  defp calculate_availability_breakdown(pilot_assignments) do
    pilot_assignments
    |> Enum.map(fn {_pilot_id, assignment} -> assignment.availability end)
    |> Enum.frequencies()
  end

  defp estimate_form_up_time(pilot_assignments) do
    # Estimate form-up time based on pilot availability and readiness
    avg_availability =
      pilot_assignments
      |> Enum.map(fn {_pilot_id, assignment} ->
        case assignment.availability do
          "high" -> 5
          "medium" -> 10
          "low" -> 20
          _ -> 30
        end
      end)
      |> Enum.sum()
      |> Kernel./(map_size(pilot_assignments))

    trunc(avg_availability)
  end
end

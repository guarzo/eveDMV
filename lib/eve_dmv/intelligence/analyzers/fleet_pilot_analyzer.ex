defmodule EveDmv.Intelligence.Analyzers.FleetPilotAnalyzer do
  @moduledoc """
  Fleet pilot analysis and optimization engine.

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

  require Logger
  require Ash.Query

  alias EveDmv.Intelligence.CharacterStats

  @doc """
  Get available pilots for a corporation that are suitable for fleet operations.

  Filters pilots based on:
  - Activity levels (minimum PvP experience)
  - Recent activity (active within last 30 days)
  - Fleet experience (not purely solo players)

  Returns {:ok, enriched_pilots} or {:error, reason}
  """
  def get_available_pilots(corporation_id) do
    # Get corporation members who could participate in fleet operations
    query =
      CharacterStats
      |> Ash.Query.new()
      |> Ash.Query.filter(corporation_id == ^corporation_id)

    case Ash.read(query, domain: EveDmv.Api) do
      {:ok, stats} ->
        # Enrich pilot data with additional analysis
        pilots =
          stats
          |> Enum.filter(fn stats -> pilot_available_for_fleet?(stats) end)
          |> Enum.map(&enrich_pilot_data/1)

        {:ok, pilots}

      {:error, reason} ->
        Logger.warning("Could not load pilot data: #{inspect(reason)}")
        {:ok, []}
    end
  rescue
    error ->
      Logger.error("Error getting available pilots: #{inspect(error)}")
      {:ok, []}
  end

  @doc """
  Enrich pilot data with derived statistics and fleet-relevant information.

  Adds:
  - Ship groups flown (extracted from kill statistics)
  - Logistics capability indicators
  - Gang size preferences
  - Capital ship experience
  """
  def enrich_pilot_data(stats) do
    # Enrich pilot stats with derived ship group data
    ship_groups = extract_ship_groups_from_stats(stats)

    Map.merge(stats, %{
      ship_groups_flown: ship_groups,
      has_logi_support: Map.get(ship_groups, "Logistics", 0) > 0,
      # Proxy for gang preference
      avg_gang_size: stats.kd_ratio || 1.0,
      flies_capitals: Map.get(ship_groups, "Capital", 0) > 0
    })
  end

  @doc """
  Extract ship groups from pilot statistics analysis data.

  Parses stored analysis data to determine which ship categories
  a pilot has experience flying.
  """
  def extract_ship_groups_from_stats(stats) do
    # Extract ship groups from stored analysis data
    case Jason.decode(stats.analysis_data || "{}") do
      {:ok, analysis_data} ->
        ship_usage = Map.get(analysis_data, "ship_usage", %{})
        ship_categories = Map.get(ship_usage, "ship_categories", %{})

        # Convert to ship group counts
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

  @doc """
  Determine if a pilot is available and suitable for fleet operations.

  Checks:
  - Minimum activity threshold (at least 5 total kills/losses)
  - Recent activity (active within last 30 days)
  - Fleet experience (not purely solo PvP)
  """
  def pilot_available_for_fleet?(pilot_stats) do
    # Determine if a pilot is suitable for fleet operations
    # Consider multiple factors for fleet readiness

    # Activity threshold - at least some PvP experience
    activity_score = pilot_stats.kill_count + pilot_stats.loss_count

    # Recent activity check (if we have last_analyzed_at)
    recently_active =
      case pilot_stats.last_analyzed_at do
        # Assume active if no data
        nil ->
          true

        last_date ->
          days_since = DateTime.diff(DateTime.utc_now(), last_date, :day)
          # Active within last month
          days_since <= 30
      end

    # Fleet experience indicator (not purely solo)
    has_fleet_experience = pilot_stats.solo_ratio < 0.9

    activity_score >= 5 and recently_active and has_fleet_experience
  end

  @doc """
  Assign pilots to a specific role based on suitability and requirements.

  Selects the best pilots for a role by:
  - Calculating suitability scores
  - Ranking pilots by score
  - Taking required count of top pilots
  """
  def assign_pilots_to_role(role, role_data, available_pilots, required_count) do
    # Select the best pilots for this role
    _required_skills = role_data["skills_required"] || []

    suitable_pilots =
      available_pilots
      |> Enum.sort_by(fn pilot -> calculate_pilot_suitability_score(pilot, role) end, :desc)
      |> Enum.take(required_count)

    suitable_pilots
  end

  @doc """
  Calculate a pilot's suitability score for a specific role.

  Combines:
  - Base activity score (kills + losses)
  - Recency bonus (recent activity)
  - Role-specific scoring
  """
  def calculate_pilot_suitability_score(pilot, role) do
    # Calculate how suitable a pilot is for a specific role
    base_score = pilot.kill_count + pilot.loss_count
    recency_bonus = calculate_recency_bonus(pilot.last_analyzed_at)
    role_score = calculate_role_specific_score(pilot, role)

    base_score + recency_bonus + role_score
  end

  @doc """
  Calculate pilot experience rating for a specific role (0.0-1.0).

  Considers:
  - Overall combat experience
  - Role-specific experience bonuses
  """
  def calculate_pilot_experience_rating(pilot, role) do
    # Calculate pilot experience rating for specific role (0.0-1.0)
    base_experience = min(1.0, (pilot.total_kills + pilot.total_losses) / 100)

    # Role-specific experience bonus
    role_experience =
      case role do
        "fleet_commander" -> if pilot.total_kills > 50, do: 0.2, else: 0.0
        "logistics" -> if pilot.has_logi_support, do: 0.3, else: 0.0
        _ -> 0.0
      end

    Float.round(min(1.0, base_experience + role_experience), 2)
  end

  @doc """
  Assess pilot availability level for fleet operations.

  Returns availability rating based on average gang size:
  - "high": 3.0+ average gang size
  - "medium": 1.5-3.0 average gang size  
  - "low": < 1.5 average gang size
  """
  def assess_pilot_availability(pilot) do
    # Assess pilot availability for fleet operations
    case pilot.avg_gang_size do
      size when size >= 3.0 -> "high"
      size when size >= 1.5 -> "medium"
      _ -> "low"
    end
  end

  @doc """
  Find backup roles a pilot could fill based on doctrine template.

  Returns up to 2 alternative roles the pilot could be assigned to
  if their primary role is already filled.
  """
  def find_backup_roles_for_pilot(_pilot, doctrine_template) do
    # Find alternative roles this pilot could fill
    doctrine_template
    |> Enum.map(fn {role, _} -> role end)
    # Limit to 2 backup roles
    |> Enum.take(2)
  end

  @doc """
  Select the best ship for a pilot from preferred ship list.

  Currently selects the first ship from the preferred list.
  Could be enhanced to check pilot skills and ship availability.
  """
  def select_best_ship_for_pilot(_pilot, preferred_ships) do
    # Select the best ship from preferred list for this pilot
    # This would check pilot skills and ship availability
    List.first(preferred_ships) || "Unknown Ship"
  end

  @doc """
  Optimize pilot assignments for a doctrine template.

  Assigns pilots to roles by:
  - Iterating through doctrine roles
  - Assigning best pilots to each role
  - Building complete assignment mapping
  """
  def optimize_pilot_assignments(doctrine_template, available_pilots, _skill_analysis) do
    assignments = %{}

    # Assign pilots to roles based on skills and preferences
    assignments =
      doctrine_template
      |> Enum.reduce(assignments, fn {role, role_data}, acc ->
        required_count = role_data["required"] || 1
        assigned_pilots = assign_pilots_to_role(role, role_data, available_pilots, required_count)

        Enum.reduce(assigned_pilots, acc, fn pilot, acc2 ->
          Map.put(acc2, Integer.to_string(pilot.character_id), %{
            "character_name" => pilot.character_name,
            "assigned_role" => role,
            "assigned_ship" => select_best_ship_for_pilot(pilot, role_data["preferred_ships"]),
            "skill_readiness" => 1.0,
            "availability" => assess_pilot_availability(pilot),
            "experience_rating" => calculate_pilot_experience_rating(pilot, role),
            "backup_roles" => find_backup_roles_for_pilot(pilot, doctrine_template)
          })
        end)
      end)

    {:ok, assignments}
  end

  # Private helper functions

  defp map_category_to_group(category) do
    # Use consistent naming with ShipDatabase categories
    case String.downcase(category) do
      "frigate" -> "Frigates"
      "destroyer" -> "Destroyers"
      "cruiser" -> "Cruisers"
      "battlecruiser" -> "Battlecruisers"
      "battleship" -> "Battleships"
      "capital" -> "Capital"
      "supercapital" -> "Supercapital"
      _ -> "Other"
    end
  end

  defp calculate_recency_bonus(last_analyzed_at) do
    case last_analyzed_at do
      nil ->
        0

      last_date ->
        days_ago = DateTime.diff(DateTime.utc_now(), last_date, :day)
        # Up to 20 point bonus for recent activity
        max(0, 20 - days_ago)
    end
  end

  defp calculate_role_specific_score(pilot, role) do
    case role do
      "fleet_commander" -> calculate_fc_score(pilot)
      "logistics" -> calculate_logi_score(pilot)
      "tackle" -> calculate_tackle_score(pilot)
      "dps" -> calculate_dps_score(pilot)
      "ewar" -> calculate_ewar_score(pilot)
      _ -> 0
    end
  end

  defp calculate_fc_score(pilot) do
    score = 0
    score = if pilot.kill_count > 100, do: score + 50, else: score
    score = if pilot.kd_ratio > 2.0, do: score + 30, else: score
    if pilot.avg_gang_size > 5.0, do: score + 20, else: score
  end

  defp calculate_logi_score(pilot) do
    score = 0
    score = if pilot.has_logi_support, do: score + 50, else: score
    if pilot.efficiency > 0.7, do: score + 20, else: score
  end

  defp calculate_tackle_score(pilot) do
    ship_groups = Map.get(pilot, :ship_groups_flown, %{})
    score = 0

    score = if Map.get(ship_groups, "Frigates", 0) > 10, do: score + 30, else: score
    if Map.get(ship_groups, "Interceptors", 0) > 0, do: score + 40, else: score
  end

  defp calculate_dps_score(pilot) do
    score = 0
    score = if pilot.kill_count > 50, do: score + 30, else: score
    if pilot.kd_ratio > 1.5, do: score + 20, else: score
  end

  defp calculate_ewar_score(pilot) do
    # EWAR pilots often have fewer kills but high impact
    score = 0
    score = if pilot.efficiency > 0.6, do: score + 30, else: score
    # Team players
    if pilot.solo_ratio < 0.3, do: score + 20, else: score
  end
end

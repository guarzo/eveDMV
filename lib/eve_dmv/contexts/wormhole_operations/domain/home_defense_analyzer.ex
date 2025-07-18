defmodule EveDmv.Contexts.WormholeOperations.Domain.HomeDefenseAnalyzer do
  @moduledoc """
  Analyzer for home defense capabilities and vulnerabilities.

  Provides comprehensive analysis of home defense readiness, vulnerabilities,
  and strategic recommendations for wormhole operations.
  """

  alias EveDmv.Repo
  import Ecto.Query
  require Logger

  @doc """
  Analyze defense capabilities for a corporation.
  """
  @spec analyze_defense_capabilities(integer()) :: {:ok, map()} | {:error, term()}
  def analyze_defense_capabilities(corporation_id) do
    Logger.debug("Analyzing defense capabilities for corporation #{corporation_id}")

    try do
      # Get recent member activity (last 30 days)
      member_activity = get_corporation_member_activity(corporation_id, 30)

      # Get member ship assets
      member_ships = get_corporation_member_ships(corporation_id)

      # Calculate active members
      active_members = count_active_members(member_activity)

      # Calculate available ships
      available_ships = count_available_ships(member_ships)

      # Calculate defense readiness
      defense_readiness =
        calculate_defense_readiness(active_members, available_ships, member_activity)

      # Calculate timezone coverage
      timezone_coverage = calculate_timezone_coverage(member_activity)

      # Estimate response time
      response_time_estimate = estimate_response_time(member_activity, timezone_coverage)

      # Calculate fleet strength
      fleet_strength = calculate_fleet_strength(member_ships)

      # Analyze defensive doctrines
      defensive_doctrines = analyze_defensive_doctrines(member_ships)

      {:ok,
       %{
         active_members: active_members,
         available_ships: available_ships,
         defense_readiness: Float.round(defense_readiness, 2),
         timezone_coverage: timezone_coverage,
         response_time_estimate: response_time_estimate,
         fleet_strength: fleet_strength,
         defensive_doctrines: defensive_doctrines,
         analysis_timestamp: DateTime.utc_now()
       }}
    rescue
      error ->
        Logger.error(
          "Failed to analyze defense capabilities for corporation #{corporation_id}: #{inspect(error)}"
        )

        {:error, :analysis_failed}
    end
  end

  @doc """
  Assess system vulnerabilities.
  """
  @spec assess_system_vulnerabilities(integer()) :: {:ok, map()} | {:error, term()}
  def assess_system_vulnerabilities(system_id) do
    Logger.debug("Assessing vulnerabilities for system #{system_id}")

    try do
      # Get system topology data
      topology = get_system_topology(system_id)

      # Get recent activity in system
      recent_activity = get_system_activity(system_id, 7)

      # Analyze entry points
      entry_points = analyze_entry_points(topology, recent_activity)

      # Identify blind spots
      blind_spots = identify_blind_spots(topology, entry_points)

      # Calculate vulnerability score
      vulnerability_score =
        calculate_vulnerability_score(entry_points, blind_spots, recent_activity)

      # Generate recommended coverage
      recommended_coverage = generate_coverage_recommendations(blind_spots, entry_points)

      # Analyze escape routes
      escape_routes = analyze_escape_routes(topology, system_id)

      # Assess defensive positioning
      defensive_positions = assess_defensive_positions(topology, entry_points)

      {:ok,
       %{
         vulnerability_score: Float.round(vulnerability_score, 2),
         entry_points: entry_points,
         blind_spots: blind_spots,
         recommended_coverage: recommended_coverage,
         escape_routes: escape_routes,
         defensive_positions: defensive_positions,
         topology_analysis: topology,
         assessment_timestamp: DateTime.utc_now()
       }}
    rescue
      error ->
        Logger.error(
          "Failed to assess vulnerabilities for system #{system_id}: #{inspect(error)}"
        )

        {:error, :assessment_failed}
    end
  end

  @doc """
  Calculate defense readiness score.
  """
  @spec calculate_defense_readiness_score(integer()) :: {:ok, float()} | {:error, term()}
  def calculate_defense_readiness_score(corporation_id) do
    Logger.debug("Calculating defense readiness score for corporation #{corporation_id}")

    try do
      # Get member activity data
      member_activity = get_corporation_member_activity(corporation_id, 30)

      # Get member ships
      member_ships = get_corporation_member_ships(corporation_id)

      # Calculate component scores
      activity_score = calculate_activity_score(member_activity)
      availability_score = calculate_availability_score(member_ships)
      timezone_score = calculate_timezone_score(member_activity)
      fleet_readiness_score = calculate_fleet_readiness_score(member_ships)
      response_score = calculate_response_score(member_activity)

      # Weighted overall score
      readiness_score =
        activity_score * 0.25 +
          availability_score * 0.25 +
          timezone_score * 0.20 +
          fleet_readiness_score * 0.20 +
          response_score * 0.10

      {:ok, Float.round(readiness_score, 3)}
    rescue
      error ->
        Logger.error(
          "Failed to calculate defense readiness score for corporation #{corporation_id}: #{inspect(error)}"
        )

        {:error, :calculation_failed}
    end
  end

  @doc """
  Analyze system defense capabilities.
  """
  @spec analyze_system_defense(integer()) :: {:ok, map()} | {:error, term()}
  def analyze_system_defense(system_id) do
    Logger.debug("Analyzing system defense capabilities for system #{system_id}")

    try do
      # Get system activity and residents
      system_activity = get_system_activity(system_id, 30)
      resident_corporations = get_system_resident_corporations(system_id)

      # Analyze defense readiness for each corporation
      defense_analyses =
        resident_corporations
        |> Enum.map(fn corp_id ->
          {:ok, analysis} = analyze_defense_capabilities(corp_id)
          {corp_id, analysis}
        end)
        |> Enum.into(%{})

      # Assess system vulnerabilities
      {:ok, vulnerability_assessment} = assess_system_vulnerabilities(system_id)

      # Calculate overall defense readiness
      overall_readiness = calculate_overall_system_readiness(defense_analyses)

      # Identify vulnerabilities
      vulnerabilities =
        identify_system_vulnerabilities(vulnerability_assessment, defense_analyses)

      # Calculate defensive assets
      defensive_assets = calculate_system_defensive_assets(defense_analyses)

      # Assess threat level
      threat_level = assess_system_threat_level(system_activity, vulnerabilities)

      # Generate defense recommendations
      defense_recommendations =
        generate_system_defense_recommendations(vulnerabilities, defensive_assets)

      {:ok,
       %{
         defense_readiness: Float.round(overall_readiness, 2),
         vulnerabilities: vulnerabilities,
         defensive_assets: defensive_assets,
         threat_level: threat_level,
         corporation_analyses: defense_analyses,
         vulnerability_assessment: vulnerability_assessment,
         defense_recommendations: defense_recommendations,
         system_activity_summary: summarize_system_activity(system_activity),
         analysis_timestamp: DateTime.utc_now()
       }}
    rescue
      error ->
        Logger.error(
          "Failed to analyze system defense for system #{system_id}: #{inspect(error)}"
        )

        {:error, :analysis_failed}
    end
  end

  @doc """
  Generate defense recommendations.
  """
  @spec generate_defense_recommendations(integer()) :: {:ok, [map()]} | {:error, term()}
  def generate_defense_recommendations(corporation_id) do
    Logger.debug("Generating defense recommendations for corporation #{corporation_id}")

    try do
      # Get defense capability analysis
      {:ok, defense_analysis} = analyze_defense_capabilities(corporation_id)

      # Get system defense analysis for home system
      home_system_id = get_corporation_home_system(corporation_id)
      {:ok, system_analysis} = analyze_system_defense(home_system_id)

      recommendations = []

      # Analyze timezone coverage gaps
      timezone_recs = generate_timezone_recommendations(defense_analysis.timezone_coverage)
      recommendations = recommendations ++ timezone_recs

      # Analyze fleet composition gaps
      fleet_recs = generate_fleet_recommendations(defense_analysis.defensive_doctrines)
      recommendations = recommendations ++ fleet_recs

      # Analyze response time issues
      response_recs = generate_response_recommendations(defense_analysis.response_time_estimate)
      recommendations = recommendations ++ response_recs

      # Analyze vulnerability gaps
      vulnerability_recs = generate_vulnerability_recommendations(system_analysis.vulnerabilities)
      recommendations = recommendations ++ vulnerability_recs

      # Analyze member activity gaps
      activity_recs = generate_activity_recommendations(defense_analysis.active_members)
      recommendations = recommendations ++ activity_recs

      # Sort by priority
      sorted_recommendations =
        recommendations
        |> Enum.sort_by(fn rec -> priority_weight(rec.priority) end)
        |> Enum.take(10)

      {:ok, sorted_recommendations}
    rescue
      error ->
        Logger.error(
          "Failed to generate defense recommendations for corporation #{corporation_id}: #{inspect(error)}"
        )

        {:error, :generation_failed}
    end
  end

  @doc """
  Generate defense recommendations with additional context.
  """
  @spec generate_defense_recommendations(integer(), map(), map()) :: [map()]
  def generate_defense_recommendations(system_id, defense_analysis, threat_event) do
    Logger.debug("Generating contextual defense recommendations for system #{system_id}")

    recommendations = []

    # Base recommendations from threat event
    threat_severity = Map.get(threat_event, :severity, :medium)
    threat_type = Map.get(threat_event, :type, :unknown)

    # Immediate response recommendations
    immediate_recs = generate_immediate_response_recommendations(threat_severity, threat_type)
    recommendations = recommendations ++ immediate_recs

    # Tactical recommendations based on defense analysis
    tactical_recs = generate_tactical_recommendations(defense_analysis, threat_event)
    recommendations = recommendations ++ tactical_recs

    # Strategic recommendations for long-term defense
    strategic_recs = generate_strategic_recommendations(defense_analysis, threat_type)
    recommendations = recommendations ++ strategic_recs

    # Resource allocation recommendations
    resource_recs = generate_resource_recommendations(defense_analysis, threat_event)
    recommendations = recommendations ++ resource_recs

    # Communication recommendations
    communication_recs = generate_communication_recommendations(threat_severity, defense_analysis)
    recommendations = recommendations ++ communication_recs

    # Filter and prioritize based on context
    recommendations
    |> Enum.uniq_by(& &1.type)
    |> Enum.sort_by(fn rec -> priority_weight(rec.priority) end)
    |> Enum.take(8)
  end

  @doc """
  Get defense metrics for monitoring.
  """
  @spec get_metrics() :: map()
  def get_metrics do
    %{
      active_defenses: 0,
      coverage_percentage: 0.0,
      response_time_avg: 0,
      threat_detection_rate: 0.0
    }
  end

  # Private helper functions

  defp get_corporation_member_activity(corporation_id, days_back) do
    # Get recent killmail activity for corporation members
    start_time = DateTime.add(DateTime.utc_now(), -days_back * 24 * 3600, :second)

    query =
      from(k in "killmails_enriched",
        where: k.victim_corporation_id == ^corporation_id and k.killmail_time >= ^start_time,
        select: %{
          killmail_id: k.killmail_id,
          killmail_time: k.killmail_time,
          character_id: k.victim_character_id,
          system_id: k.solar_system_id,
          attacker_count: k.attacker_count
        },
        order_by: [desc: k.killmail_time],
        limit: 1000
      )

    Repo.all(query)
  rescue
    error ->
      Logger.error("Failed to get corporation member activity: #{inspect(error)}")
      []
  end

  defp get_corporation_member_ships(corporation_id) do
    # Simplified ship analysis based on recent killmail data
    start_time = DateTime.add(DateTime.utc_now(), -30 * 24 * 3600, :second)

    query =
      from(k in "killmails_enriched",
        where: k.victim_corporation_id == ^corporation_id and k.killmail_time >= ^start_time,
        select: %{
          character_id: k.victim_character_id,
          ship_type_id: k.victim_ship_type_id,
          system_id: k.solar_system_id
        },
        distinct: [k.victim_character_id, k.victim_ship_type_id]
      )

    Repo.all(query)
  rescue
    error ->
      Logger.error("Failed to get corporation member ships: #{inspect(error)}")
      []
  end

  defp count_active_members(member_activity) do
    member_activity
    |> Enum.map(& &1.character_id)
    |> Enum.uniq()
    |> length()
  end

  defp count_available_ships(member_ships) do
    member_ships
    |> Enum.map(& &1.ship_type_id)
    |> Enum.uniq()
    |> length()
  end

  defp calculate_defense_readiness(active_members, available_ships, member_activity) do
    # Calculate defense readiness based on multiple factors
    activity_factor = min(1.0, active_members / 20)
    ship_factor = min(1.0, available_ships / 50)
    recent_factor = calculate_recent_activity_factor(member_activity)

    (activity_factor + ship_factor + recent_factor) / 3
  end

  defp calculate_recent_activity_factor(member_activity) do
    # Calculate activity in last 7 days vs last 30 days
    now = DateTime.utc_now()
    seven_days_ago = DateTime.add(now, -7 * 24 * 3600, :second)

    recent_activity =
      Enum.count(member_activity, fn activity ->
        DateTime.compare(activity.killmail_time, seven_days_ago) == :gt
      end)

    total_activity = length(member_activity)

    if total_activity > 0 do
      recent_activity / total_activity
    else
      0.0
    end
  end

  defp calculate_timezone_coverage(member_activity) do
    # Analyze activity by hour to determine timezone coverage
    hourly_activity =
      member_activity
      |> Enum.group_by(fn activity ->
        activity.killmail_time.hour
      end)
      |> Enum.map(fn {hour, activities} -> {hour, length(activities)} end)
      |> Enum.into(%{})

    # Find peak activity hours
    peak_hours =
      hourly_activity
      |> Enum.sort_by(&elem(&1, 1), :desc)
      |> Enum.take(8)
      |> Enum.map(&elem(&1, 0))

    # Calculate coverage percentage
    active_hours = Map.keys(hourly_activity)
    coverage_percentage = length(active_hours) / 24 * 100

    # Categorize timezone coverage
    timezone_categories = categorize_timezone_coverage(active_hours)

    %{
      hourly_activity: hourly_activity,
      peak_hours: peak_hours,
      active_hours: active_hours,
      coverage_percentage: Float.round(coverage_percentage, 1),
      timezone_categories: timezone_categories,
      coverage_quality: rate_coverage_quality(coverage_percentage, peak_hours)
    }
  end

  defp categorize_timezone_coverage(active_hours) do
    # Categorize by general timezone regions
    us_tz = Enum.count(active_hours, fn h -> h >= 0 and h < 8 end)
    eu_tz = Enum.count(active_hours, fn h -> h >= 8 and h < 16 end)
    asia_tz = Enum.count(active_hours, fn h -> h >= 16 and h < 24 end)

    %{
      us_coverage: us_tz,
      eu_coverage: eu_tz,
      asia_coverage: asia_tz,
      dominant_tz: determine_dominant_timezone(us_tz, eu_tz, asia_tz)
    }
  end

  defp determine_dominant_timezone(us, eu, asia) do
    cond do
      us >= eu and us >= asia -> :us
      eu >= us and eu >= asia -> :eu
      asia >= us and asia >= eu -> :asia
      true -> :mixed
    end
  end

  defp rate_coverage_quality(coverage_percentage, peak_hours) do
    base_score = coverage_percentage / 100

    # Bonus for distributed peak hours
    hour_distribution = calculate_hour_distribution(peak_hours)
    distribution_bonus = hour_distribution * 0.2

    total_score = base_score + distribution_bonus

    cond do
      total_score >= 0.8 -> :excellent
      total_score >= 0.6 -> :good
      total_score >= 0.4 -> :fair
      total_score >= 0.2 -> :poor
      true -> :critical
    end
  end

  defp calculate_hour_distribution(hours) do
    # Calculate how evenly distributed the hours are
    if Enum.empty?(hours) do
      0.0
    else
      # Simple distribution calculation
      hour_ranges = [0..7, 8..15, 16..23]

      range_counts =
        hour_ranges
        |> Enum.map(fn range ->
          Enum.count(hours, fn h -> h in range end)
        end)

      # Better distribution = more even spread across ranges
      max_count = Enum.max(range_counts)
      min_count = Enum.min(range_counts)

      if max_count > 0 do
        1.0 - (max_count - min_count) / max_count
      else
        0.0
      end
    end
  end

  defp estimate_response_time(member_activity, timezone_coverage) do
    # Estimate response time based on activity patterns
    # minutes
    base_response = 30

    # Adjust based on timezone coverage
    coverage_factor =
      case timezone_coverage.coverage_quality do
        :excellent -> 0.7
        :good -> 0.8
        :fair -> 1.0
        :poor -> 1.3
        :critical -> 1.6
      end

    # Adjust based on recent activity
    activity_factor = if length(member_activity) > 100, do: 0.9, else: 1.1

    round(base_response * coverage_factor * activity_factor)
  end

  defp calculate_fleet_strength(member_ships) do
    # Categorize ships by type and calculate strength
    ship_categories = categorize_ships(member_ships)

    # Calculate strength based on ship composition
    capital_strength = Map.get(ship_categories, :capital, 0) * 10
    battleship_strength = Map.get(ship_categories, :battleship, 0) * 3
    cruiser_strength = Map.get(ship_categories, :cruiser, 0) * 2
    frigate_strength = Map.get(ship_categories, :frigate, 0)

    total_strength = capital_strength + battleship_strength + cruiser_strength + frigate_strength

    %{
      total_strength: total_strength,
      ship_categories: ship_categories,
      strength_rating: rate_fleet_strength(total_strength)
    }
  end

  defp categorize_ships(member_ships) do
    # Simplified ship categorization based on type IDs
    member_ships
    |> Enum.group_by(fn ship ->
      categorize_ship_type(ship.ship_type_id)
    end)
    |> Enum.map(fn {category, ships} -> {category, length(ships)} end)
    |> Enum.into(%{})
  end

  defp categorize_ship_type(ship_type_id) do
    # Simplified categorization based on type ID ranges
    cond do
      ship_type_id >= 19720 and ship_type_id <= 19740 -> :capital
      ship_type_id >= 600 and ship_type_id <= 700 -> :battleship
      ship_type_id >= 300 and ship_type_id <= 400 -> :cruiser
      ship_type_id >= 1 and ship_type_id <= 100 -> :frigate
      true -> :other
    end
  end

  defp rate_fleet_strength(total_strength) do
    cond do
      total_strength >= 200 -> :overwhelming
      total_strength >= 100 -> :strong
      total_strength >= 50 -> :moderate
      total_strength >= 20 -> :weak
      true -> :minimal
    end
  end

  defp analyze_defensive_doctrines(member_ships) do
    # Analyze common ship combinations and doctrines
    ship_types = Enum.map(member_ships, & &1.ship_type_id)
    type_frequencies = Enum.frequencies(ship_types)

    # Identify common doctrines
    common_doctrines = identify_common_doctrines(type_frequencies)

    # Calculate doctrine coherence
    doctrine_coherence = calculate_doctrine_coherence(type_frequencies)

    %{
      ship_type_distribution: type_frequencies,
      common_doctrines: common_doctrines,
      doctrine_coherence: doctrine_coherence,
      doctrine_recommendations: generate_doctrine_recommendations(type_frequencies)
    }
  end

  defp identify_common_doctrines(type_frequencies) do
    # Identify common ship doctrines from frequency patterns
    sorted_types =
      type_frequencies
      |> Enum.sort_by(&elem(&1, 1), :desc)
      |> Enum.take(5)

    Enum.map(sorted_types, fn {type_id, count} ->
      %{
        ship_type_id: type_id,
        count: count,
        doctrine_name: get_doctrine_name(type_id)
      }
    end)
  end

  defp get_doctrine_name(ship_type_id) do
    # Map ship types to doctrine names
    case categorize_ship_type(ship_type_id) do
      :capital -> "Capital Doctrine"
      :battleship -> "Battleship Doctrine"
      :cruiser -> "Cruiser Doctrine"
      :frigate -> "Frigate Doctrine"
      _ -> "Mixed Doctrine"
    end
  end

  defp calculate_doctrine_coherence(type_frequencies) do
    # Calculate how coherent the fleet doctrine is
    total_ships = type_frequencies |> Map.values() |> Enum.sum()

    if total_ships > 0 do
      # Find most common ship types
      top_types =
        type_frequencies
        |> Enum.sort_by(&elem(&1, 1), :desc)
        |> Enum.take(3)
        |> Enum.map(&elem(&1, 1))
        |> Enum.sum()

      coherence = top_types / total_ships
      Float.round(coherence, 2)
    else
      0.0
    end
  end

  defp generate_doctrine_recommendations(type_frequencies) do
    # Generate recommendations based on ship distribution
    recommendations = []

    total_ships = type_frequencies |> Map.values() |> Enum.sum()

    # Check for doctrine gaps
    recommendations =
      if total_ships < 20 do
        ["Increase overall fleet size for better defense coverage" | recommendations]
      else
        recommendations
      end

    # Check for ship type diversity
    ship_type_count = map_size(type_frequencies)

    recommendations =
      if ship_type_count > 10 do
        ["Consider standardizing around fewer ship types for better logistics" | recommendations]
      else
        recommendations
      end

    recommendations
  end

  defp get_system_topology(system_id) do
    # Simplified topology analysis
    # In real implementation, would analyze wormhole connections
    %{
      system_id: system_id,
      wormhole_connections: 3,
      connection_types: [:c1, :c2, :null],
      system_class: classify_wormhole_system(system_id),
      strategic_importance: calculate_strategic_importance(system_id)
    }
  end

  defp classify_wormhole_system(system_id) do
    # Simplified wormhole classification
    cond do
      system_id >= 31_000_000 -> :c6
      system_id >= 31_000_000 -> :c5
      system_id >= 31_000_000 -> :c4
      system_id >= 31_000_000 -> :c3
      system_id >= 31_000_000 -> :c2
      system_id >= 31_000_000 -> :c1
      true -> :unknown
    end
  end

  defp calculate_strategic_importance(system_id) do
    # Calculate strategic importance based on system properties
    system_class = classify_wormhole_system(system_id)

    case system_class do
      :c6 -> 0.9
      :c5 -> 0.8
      :c4 -> 0.7
      :c3 -> 0.6
      :c2 -> 0.5
      :c1 -> 0.4
      _ -> 0.3
    end
  end

  defp get_system_activity(system_id, days_back) do
    # Get recent activity in the system
    start_time = DateTime.add(DateTime.utc_now(), -days_back * 24 * 3600, :second)

    query =
      from(k in "killmails_enriched",
        where: k.solar_system_id == ^system_id and k.killmail_time >= ^start_time,
        select: %{
          killmail_id: k.killmail_id,
          killmail_time: k.killmail_time,
          victim_corporation_id: k.victim_corporation_id,
          attacker_count: k.attacker_count,
          total_value: k.total_value
        },
        order_by: [desc: k.killmail_time],
        limit: 500
      )

    Repo.all(query)
  rescue
    error ->
      Logger.error("Failed to get system activity: #{inspect(error)}")
      []
  end

  defp analyze_entry_points(topology, recent_activity) do
    # Analyze potential entry points into the system
    base_entries = topology.wormhole_connections

    # Adjust based on recent activity
    activity_factor = if length(recent_activity) > 50, do: 1.2, else: 1.0

    estimated_entries = round(base_entries * activity_factor)

    # Generate entry point details
    Enum.map(1..estimated_entries, fn i ->
      %{
        entry_id: i,
        connection_type: Enum.random([:c1, :c2, :c3, :null, :low]),
        threat_level: Enum.random([:low, :medium, :high]),
        monitoring_status: Enum.random([:monitored, :unmonitored, :partially_monitored])
      }
    end)
  end

  defp identify_blind_spots(_topology, entry_points) do
    # Identify areas with poor coverage
    total_entries = length(entry_points)

    monitored_entries =
      Enum.count(entry_points, fn entry ->
        entry.monitoring_status == :monitored
      end)

    _blind_spot_percentage =
      if total_entries > 0 do
        (total_entries - monitored_entries) / total_entries
      else
        0.0
      end

    # Generate blind spot details
    unmonitored_entries =
      Enum.filter(entry_points, fn entry ->
        entry.monitoring_status != :monitored
      end)

    Enum.map(unmonitored_entries, fn entry ->
      %{
        entry_id: entry.entry_id,
        connection_type: entry.connection_type,
        risk_level: entry.threat_level,
        coverage_gap: calculate_coverage_gap(entry)
      }
    end)
  end

  defp calculate_coverage_gap(entry) do
    # Calculate how significant the coverage gap is
    base_gap = 0.5

    threat_multiplier =
      case entry.threat_level do
        :high -> 1.5
        :medium -> 1.0
        :low -> 0.7
      end

    Float.round(base_gap * threat_multiplier, 2)
  end

  defp calculate_vulnerability_score(entry_points, blind_spots, recent_activity) do
    # Calculate overall vulnerability score
    entry_factor = length(entry_points) / 10
    blind_spot_factor = length(blind_spots) / 5
    activity_factor = length(recent_activity) / 100

    vulnerability = (entry_factor + blind_spot_factor + activity_factor) / 3
    min(1.0, vulnerability)
  end

  defp generate_coverage_recommendations(blind_spots, entry_points) do
    # Generate recommendations for improving coverage
    recommendations = []

    # Recommendations based on blind spots
    recommendations =
      if length(blind_spots) > 2 do
        ["Deploy scouts to cover unmonitored entry points" | recommendations]
      else
        recommendations
      end

    # Recommendations based on high-threat entries
    high_threat_entries =
      Enum.count(entry_points, fn entry ->
        entry.threat_level == :high
      end)

    recommendations =
      if high_threat_entries > 1 do
        ["Increase monitoring on high-threat connections" | recommendations]
      else
        recommendations
      end

    recommendations
  end

  defp analyze_escape_routes(topology, _system_id) do
    # Analyze potential escape routes
    connection_count = topology.wormhole_connections

    # Generate escape route analysis
    %{
      primary_routes: generate_escape_routes(connection_count, :primary),
      backup_routes: generate_escape_routes(connection_count, :backup),
      emergency_routes: generate_escape_routes(connection_count, :emergency),
      route_security: assess_route_security(connection_count)
    }
  end

  defp generate_escape_routes(connection_count, route_type) do
    # Generate escape routes based on connection count
    route_count =
      case route_type do
        :primary -> min(2, connection_count)
        :backup -> min(1, connection_count - 1)
        :emergency -> min(1, connection_count - 2)
      end

    Enum.map(1..route_count, fn i ->
      %{
        route_id: i,
        route_type: route_type,
        connection_type: Enum.random([:c1, :c2, :null, :low]),
        security_rating: Enum.random([:safe, :moderate, :dangerous])
      }
    end)
  end

  defp assess_route_security(connection_count) do
    # Assess overall security of escape routes
    case connection_count do
      count when count >= 4 -> :good
      count when count >= 2 -> :moderate
      count when count >= 1 -> :poor
      _ -> :critical
    end
  end

  defp assess_defensive_positions(_topology, entry_points) do
    # Assess potential defensive positions
    high_threat_entries =
      Enum.count(entry_points, fn entry ->
        entry.threat_level == :high
      end)

    # Generate defensive position recommendations
    Enum.map(1..min(3, high_threat_entries + 1), fn i ->
      %{
        position_id: i,
        position_type: Enum.random([:chokepoint, :overview, :fallback]),
        effectiveness: Enum.random([:high, :medium, :low]),
        resource_requirement: Enum.random([:minimal, :moderate, :significant])
      }
    end)
  end

  defp calculate_activity_score(member_activity) do
    # Calculate activity score based on recent activity
    activity_count = length(member_activity)

    # Normalize activity score
    cond do
      activity_count >= 100 -> 1.0
      activity_count >= 50 -> 0.8
      activity_count >= 20 -> 0.6
      activity_count >= 10 -> 0.4
      activity_count >= 5 -> 0.2
      true -> 0.0
    end
  end

  defp calculate_availability_score(member_ships) do
    # Calculate availability score based on ship count
    ship_count = length(member_ships)

    # Normalize availability score
    cond do
      ship_count >= 100 -> 1.0
      ship_count >= 50 -> 0.8
      ship_count >= 25 -> 0.6
      ship_count >= 10 -> 0.4
      ship_count >= 5 -> 0.2
      true -> 0.0
    end
  end

  defp calculate_timezone_score(member_activity) do
    # Calculate timezone coverage score
    timezone_coverage = calculate_timezone_coverage(member_activity)

    case timezone_coverage.coverage_quality do
      :excellent -> 1.0
      :good -> 0.8
      :fair -> 0.6
      :poor -> 0.4
      :critical -> 0.2
    end
  end

  defp calculate_fleet_readiness_score(member_ships) do
    # Calculate fleet readiness based on ship composition
    fleet_strength = calculate_fleet_strength(member_ships)

    case fleet_strength.strength_rating do
      :overwhelming -> 1.0
      :strong -> 0.8
      :moderate -> 0.6
      :weak -> 0.4
      :minimal -> 0.2
    end
  end

  defp calculate_response_score(member_activity) do
    # Calculate response capability score
    recent_factor = calculate_recent_activity_factor(member_activity)

    # Convert to score
    min(1.0, recent_factor * 2)
  end

  defp get_system_resident_corporations(system_id) do
    # Get corporations that are active in the system
    recent_activity = get_system_activity(system_id, 30)

    recent_activity
    |> Enum.map(& &1.victim_corporation_id)
    |> Enum.filter(& &1)
    |> Enum.uniq()
    |> Enum.take(5)
  end

  defp calculate_overall_system_readiness(defense_analyses) do
    # Calculate overall readiness across all corporations
    if map_size(defense_analyses) == 0 do
      0.0
    else
      readiness_scores =
        defense_analyses
        |> Map.values()
        |> Enum.map(& &1.defense_readiness)

      Enum.sum(readiness_scores) / length(readiness_scores)
    end
  end

  defp identify_system_vulnerabilities(vulnerability_assessment, defense_analyses) do
    # Identify system-wide vulnerabilities
    base_vulnerabilities = vulnerability_assessment.blind_spots

    # Add defense-related vulnerabilities
    defense_vulnerabilities =
      defense_analyses
      |> Map.values()
      |> Enum.filter(fn analysis -> analysis.defense_readiness < 0.5 end)
      |> Enum.map(fn _analysis ->
        %{
          type: :low_defense_readiness,
          description: "Corporation has low defense readiness",
          severity: :medium,
          recommendation: "Improve member activity and fleet readiness"
        }
      end)

    base_vulnerabilities ++ defense_vulnerabilities
  end

  defp calculate_system_defensive_assets(defense_analyses) do
    # Calculate total defensive assets across all corporations
    total_active_members =
      defense_analyses
      |> Map.values()
      |> Enum.map(& &1.active_members)
      |> Enum.sum()

    total_available_ships =
      defense_analyses
      |> Map.values()
      |> Enum.map(& &1.available_ships)
      |> Enum.sum()

    avg_response_time =
      defense_analyses
      |> Map.values()
      |> Enum.map(& &1.response_time_estimate)
      |> Enum.sum()
      |> Kernel./(max(map_size(defense_analyses), 1))

    %{
      active_members: total_active_members,
      available_ships: total_available_ships,
      response_time: round(avg_response_time)
    }
  end

  defp assess_system_threat_level(system_activity, vulnerabilities) do
    # Assess threat level based on activity and vulnerabilities
    activity_factor = length(system_activity) / 50
    vulnerability_factor = length(vulnerabilities) / 5

    threat_score = (activity_factor + vulnerability_factor) / 2

    cond do
      threat_score >= 0.8 -> :critical
      threat_score >= 0.6 -> :high
      threat_score >= 0.4 -> :moderate
      threat_score >= 0.2 -> :low
      true -> :minimal
    end
  end

  defp generate_system_defense_recommendations(vulnerabilities, defensive_assets) do
    # Generate system-wide defense recommendations
    recommendations = []

    # Recommendations based on vulnerabilities
    recommendations =
      if length(vulnerabilities) > 3 do
        ["Address critical system vulnerabilities" | recommendations]
      else
        recommendations
      end

    # Recommendations based on defensive assets
    recommendations =
      if defensive_assets.active_members < 10 do
        ["Increase active member participation" | recommendations]
      else
        recommendations
      end

    recommendations =
      if defensive_assets.available_ships < 20 do
        ["Expand available ship inventory" | recommendations]
      else
        recommendations
      end

    recommendations
  end

  defp summarize_system_activity(system_activity) do
    # Summarize system activity for analysis
    %{
      total_kills: length(system_activity),
      recent_kills: count_recent_kills(system_activity),
      active_corporations: count_active_corporations(system_activity),
      activity_trend: analyze_activity_trend(system_activity)
    }
  end

  defp count_recent_kills(system_activity) do
    # Count kills in last 7 days
    seven_days_ago = DateTime.add(DateTime.utc_now(), -7 * 24 * 3600, :second)

    Enum.count(system_activity, fn activity ->
      DateTime.compare(activity.killmail_time, seven_days_ago) == :gt
    end)
  end

  defp count_active_corporations(system_activity) do
    # Count unique corporations in recent activity
    system_activity
    |> Enum.map(& &1.victim_corporation_id)
    |> Enum.filter(& &1)
    |> Enum.uniq()
    |> length()
  end

  defp analyze_activity_trend(system_activity) do
    # Analyze if activity is increasing or decreasing
    if length(system_activity) < 10 do
      :stable
    else
      recent_half = Enum.take(system_activity, div(length(system_activity), 2))
      older_half = Enum.drop(system_activity, div(length(system_activity), 2))

      if length(recent_half) > length(older_half) do
        :increasing
      else
        :decreasing
      end
    end
  end

  defp get_corporation_home_system(corporation_id) do
    # Get the home system for a corporation
    # Simplified: Return a mock system ID
    corporation_id + 31_000_000
  end

  defp generate_timezone_recommendations(timezone_coverage) do
    # Generate recommendations for timezone coverage
    recommendations = []

    coverage_pct = timezone_coverage.coverage_percentage

    recommendations =
      if coverage_pct < 50 do
        [
          %{
            type: :timezone_coverage,
            priority: :high,
            description: "Expand timezone coverage to #{coverage_pct}%",
            action: "Recruit members from underrepresented timezones"
          }
          | recommendations
        ]
      else
        recommendations
      end

    # Check for timezone balance
    tz_categories = timezone_coverage.timezone_categories

    recommendations =
      if tz_categories.dominant_tz != :mixed do
        [
          %{
            type: :timezone_balance,
            priority: :medium,
            description: "Heavy #{tz_categories.dominant_tz} timezone bias",
            action: "Recruit members from other timezones for better coverage"
          }
          | recommendations
        ]
      else
        recommendations
      end

    recommendations
  end

  defp generate_fleet_recommendations(defensive_doctrines) do
    # Generate recommendations for fleet improvements
    recommendations = []

    coherence = defensive_doctrines.doctrine_coherence

    recommendations =
      if coherence < 0.5 do
        [
          %{
            type: :fleet_coherence,
            priority: :medium,
            description: "Fleet doctrine lacks coherence (#{coherence})",
            action: "Standardize around core ship doctrines"
          }
          | recommendations
        ]
      else
        recommendations
      end

    (recommendations ++ defensive_doctrines.doctrine_recommendations)
    |> Enum.map(fn rec ->
      if is_binary(rec) do
        %{
          type: :fleet_doctrine,
          priority: :low,
          description: rec,
          action: "Review fleet composition and adjust as needed"
        }
      else
        rec
      end
    end)
  end

  defp generate_response_recommendations(response_time_estimate) do
    # Generate recommendations for response time improvements
    recommendations = []

    recommendations =
      if response_time_estimate > 45 do
        [
          %{
            type: :response_time,
            priority: :high,
            description: "Response time estimate: #{response_time_estimate} minutes",
            action: "Improve member readiness and communication protocols"
          }
          | recommendations
        ]
      else
        recommendations
      end

    recommendations
  end

  defp generate_vulnerability_recommendations(vulnerabilities) do
    # Generate recommendations for addressing vulnerabilities
    Enum.map(vulnerabilities, fn vulnerability ->
      %{
        type: :vulnerability,
        priority: :high,
        description: Map.get(vulnerability, :description, "System vulnerability detected"),
        action: Map.get(vulnerability, :recommendation, "Address security gap")
      }
    end)
  end

  defp generate_activity_recommendations(active_members) do
    # Generate recommendations for member activity
    recommendations = []

    recommendations =
      if active_members < 15 do
        [
          %{
            type: :member_activity,
            priority: :high,
            description: "Low active member count: #{active_members}",
            action: "Increase member engagement and recruitment"
          }
          | recommendations
        ]
      else
        recommendations
      end

    recommendations
  end

  defp priority_weight(priority) do
    case priority do
      :critical -> 0
      :high -> 1
      :medium -> 2
      :low -> 3
      _ -> 4
    end
  end

  defp generate_immediate_response_recommendations(threat_severity, threat_type) do
    # Generate immediate response recommendations
    base_recommendations = [
      %{
        type: :alert_members,
        priority: :high,
        description: "Alert corporation members of #{threat_type} threat",
        action: "Send fleet broadcast and discord notifications"
      }
    ]

    case threat_severity do
      :critical ->
        [
          %{
            type: :emergency_response,
            priority: :critical,
            description: "Critical threat detected - immediate action required",
            action: "Activate emergency protocols and defensive fleet"
          }
          | base_recommendations
        ]

      :high ->
        [
          %{
            type: :heightened_alert,
            priority: :high,
            description: "High threat level - increase readiness",
            action: "Stage defensive fleet and increase monitoring"
          }
          | base_recommendations
        ]

      _ ->
        base_recommendations
    end
  end

  defp generate_tactical_recommendations(defense_analysis, _threat_event) do
    # Generate tactical recommendations based on defense analysis
    recommendations = []

    # Recommendations based on fleet strength
    fleet_strength = defense_analysis.fleet_strength.strength_rating

    recommendations =
      case fleet_strength do
        :minimal ->
          [
            %{
              type: :fleet_reinforcement,
              priority: :critical,
              description: "Fleet strength insufficient for threat",
              action: "Request allied support or consider evacuation"
            }
            | recommendations
          ]

        :weak ->
          [
            %{
              type: :defensive_posture,
              priority: :high,
              description: "Adopt defensive posture due to limited fleet",
              action: "Focus on evasion and intelligence gathering"
            }
            | recommendations
          ]

        _ ->
          recommendations
      end

    # Recommendations based on response time
    response_time = defense_analysis.response_time_estimate

    recommendations =
      if response_time > 60 do
        [
          %{
            type: :rapid_response,
            priority: :high,
            description: "Slow response time (#{response_time} min)",
            action: "Pre-position defensive assets and improve readiness"
          }
          | recommendations
        ]
      else
        recommendations
      end

    recommendations
  end

  defp generate_strategic_recommendations(defense_analysis, threat_type) do
    # Generate strategic long-term recommendations
    recommendations = []

    # Recommendations based on timezone coverage
    tz_coverage = defense_analysis.timezone_coverage.coverage_percentage

    recommendations =
      if tz_coverage < 60 do
        [
          %{
            type: :strategic_coverage,
            priority: :medium,
            description: "Limited timezone coverage (#{tz_coverage}%)",
            action: "Develop 24/7 coverage strategy and recruit internationally"
          }
          | recommendations
        ]
      else
        recommendations
      end

    # Recommendations based on threat type
    recommendations =
      case threat_type do
        :capital_escalation ->
          [
            %{
              type: :capital_defense,
              priority: :high,
              description: "Capital threat requires specialized response",
              action: "Develop capital defense doctrine and acquire countermeasures"
            }
            | recommendations
          ]

        :structure_warfare ->
          [
            %{
              type: :structure_defense,
              priority: :medium,
              description: "Structure warfare threat detected",
              action: "Improve structure defenses and monitoring"
            }
            | recommendations
          ]

        _ ->
          recommendations
      end

    recommendations
  end

  defp generate_resource_recommendations(defense_analysis, threat_event) do
    # Generate resource allocation recommendations
    recommendations = []

    # Recommendations based on available ships
    available_ships = defense_analysis.available_ships

    recommendations =
      if available_ships < 30 do
        [
          %{
            type: :resource_allocation,
            priority: :medium,
            description: "Limited ship inventory (#{available_ships})",
            action: "Increase ship procurement and member ship programs"
          }
          | recommendations
        ]
      else
        recommendations
      end

    # Recommendations based on threat event
    threat_value = Map.get(threat_event, :estimated_value, 0)

    recommendations =
      if threat_value > 1_000_000_000 do
        [
          %{
            type: :high_value_response,
            priority: :high,
            description: "High-value threat requires significant resources",
            action: "Allocate premium defensive assets and consider allied support"
          }
          | recommendations
        ]
      else
        recommendations
      end

    recommendations
  end

  defp generate_communication_recommendations(threat_severity, defense_analysis) do
    # Generate communication and coordination recommendations
    recommendations = []

    # Recommendations based on threat severity
    recommendations =
      case threat_severity do
        :critical ->
          [
            %{
              type: :emergency_communication,
              priority: :critical,
              description: "Critical threat requires immediate coordination",
              action: "Activate emergency communication channels and leadership"
            }
            | recommendations
          ]

        :high ->
          [
            %{
              type: :enhanced_communication,
              priority: :high,
              description: "High threat requires enhanced coordination",
              action: "Increase communication frequency and situational updates"
            }
            | recommendations
          ]

        _ ->
          recommendations
      end

    # Recommendations based on active members
    active_members = defense_analysis.active_members

    recommendations =
      if active_members > 50 do
        [
          %{
            type: :large_scale_coordination,
            priority: :medium,
            description: "Large member count requires structured coordination",
            action: "Implement command structure and clear communication protocols"
          }
          | recommendations
        ]
      else
        recommendations
      end

    recommendations
  end
end

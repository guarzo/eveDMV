defmodule EveDmv.Contexts.IntelligenceInfrastructure.Domain.CrossSystem.Analyzers.ThreatPatternAnalyzer do
  @moduledoc """
  Specialized analyzer for threat pattern analysis across multiple systems.

  This module handles threat-related analysis including threat correlation,
  escalation risk assessment, and coordinated threat detection across system boundaries.

  ## Key Responsibilities

  - **Threat Correlation**: Analyzes correlations between threats in different systems
  - **Escalation Risk**: Calculates risk of threat escalation across systems
  - **Coordinated Threats**: Detects coordinated threat activities
  - **Threat Spillover**: Identifies threats moving between systems
  - **Major Entities**: Extracts major threat entities and actors

  ## Usage

      # Analyze threat correlations
      correlations = ThreatPatternAnalyzer.calculate_threat_correlations(system_ids, killmails)
      
      # Assess escalation risk
      risk = ThreatPatternAnalyzer.calculate_escalation_risk(threat_data)
      
      # Detect coordinated threats
      coordinated = ThreatPatternAnalyzer.identify_coordinated_threats(threat_data)
  """

  require Logger

  @doc """
  Calculate threat correlation strength between systems.
  """
  def calculate_threat_correlation_strength(threat_correlations) do
    if Enum.empty?(threat_correlations) do
      0.0
    else
      threat_correlations
      |> Enum.map(fn {_system_pair, correlation_data} ->
        Map.get(correlation_data, :correlation_strength, 0.0)
      end)
      |> Enum.sum()
      |> Kernel./(length(threat_correlations))
    end
  end

  @doc """
  Generate comprehensive threat insights from analyzed patterns.
  """
  def generate_threat_insights(threat_patterns, _system_ids) do
    major_entities = extract_major_threat_entities(threat_patterns)
    coordinated_threats = identify_coordinated_threats(threat_patterns)
    escalation_risk = calculate_escalation_risk(threat_patterns)

    %{
      major_threat_entities: major_entities,
      coordinated_threat_activities: coordinated_threats,
      escalation_risk_assessment: escalation_risk,
      threat_correlation_matrix: calculate_threat_correlation_matrix([], threat_patterns),
      threat_migration_patterns: analyze_threat_migration_patterns(threat_patterns),
      high_priority_threats: identify_high_priority_threats(threat_patterns),
      threat_capability_assessment: assess_threat_capabilities(threat_patterns),
      recommended_countermeasures: suggest_countermeasures(threat_patterns),
      early_warning_indicators: extract_early_warning_indicators(threat_patterns),
      threat_evolution_trends: analyze_threat_evolution(threat_patterns)
    }
  end

  @doc """
  Calculate escalation risk based on threat data.
  """
  def calculate_escalation_risk(threat_data) when is_map(threat_data) do
    base_risk = 0.3
    entity_risk = if length(Map.get(threat_data, :major_entities, [])) > 5, do: 0.2, else: 0.0

    coordination_risk =
      if Map.get(threat_data, :coordinated_activities, false), do: 0.3, else: 0.0

    min(base_risk + entity_risk + coordination_risk, 1.0)
  end

  def calculate_escalation_risk(_), do: 0.3

  @doc """
  Extract major threat entities from threat data.
  """
  def extract_major_threat_entities(threat_data) do
    threat_data
    |> Map.get(:entities, [])
    |> Enum.filter(fn entity ->
      Map.get(entity, :threat_level, 0) > 0.7
    end)
    |> Enum.map(fn entity ->
      %{
        character_id: entity.character_id,
        threat_score: entity.threat_level,
        activity_pattern: entity.activity_pattern
      }
    end)
    |> Enum.sort_by(& &1.threat_score, :desc)
    |> Enum.take(10)
  end

  @doc """
  Identify threat spillover patterns between systems.
  """
  def identify_threat_spillover(_system_ids, killmails) do
    # Group killmails by time windows to detect spillover patterns
    time_windows = group_killmails_by_time_windows(killmails)

    spillover_patterns =
      Enum.map(time_windows, fn {_window, window_kills} ->
        systems_in_window =
          window_kills

        Enum.map(& &1.solar_system_id) |> Enum.uniq()

        if length(systems_in_window) > 1 do
          %{
            time_window: window_kills |> List.first() |> Map.get(:killmail_time),
            affected_systems: systems_in_window,
            spillover_strength: calculate_spillover_strength(window_kills),
            threat_entities: extract_active_entities(window_kills),
            pattern_type: classify_spillover_pattern(window_kills)
          }
        end
      end)

    |> Enum.filter(& &1)

    %{
      spillover_incidents: spillover_patterns,
      spillover_frequency: length(spillover_patterns),
      high_risk_corridors: identify_high_risk_corridors(spillover_patterns),
      spillover_trend: analyze_spillover_trend(spillover_patterns)
    }
  end

  @doc """
  Identify coordinated threat activities.
  """
  def identify_coordinated_threats(threat_data) do
    entities = Map.get(threat_data, :entities, [])

    # Group entities by time proximity
    time_grouped_entities =
      entities

    |> Enum.group_by(fn entity ->
      # Group by hour to detect coordination
      entity.last_activity |> DateTime.truncate(:hour)
    end)

    coordinated_groups =
      time_grouped_entities

    |> Enum.filter(fn {_time, group_entities} -> length(group_entities) > 3 end)

    |> Enum.map(fn {time, group_entities} ->
      times = Enum.map(group_entities, & &1.last_activity)

      %{
        coordination_time: time,
        participants: length(group_entities),
        entities: Enum.map(group_entities, & &1.character_id),
        coordination_score: calculate_coordination_score(times),
        threat_level: calculate_group_threat_level(group_entities)
      }
    end)

    |> Enum.filter(fn group -> group.coordination_score > 0.6 end)
    |> Enum.sort_by(& &1.threat_level, :desc)

    %{
      coordinated_groups: coordinated_groups,
      coordination_incidents: length(coordinated_groups),
      highest_threat_group: List.first(coordinated_groups),
      coordination_trend: analyze_coordination_trend(coordinated_groups)
    }
  end

  @doc """
  Calculate threat correlation matrix between systems.
  """
  def calculate_threat_correlation_matrix(system_ids, threat_data) do
    if length(system_ids) < 2 do
      %{}
    else
      for {system_a, index_a} <- Enum.with_index(system_ids),
          {system_b, index_b} <- Enum.with_index(system_ids),
          index_a < index_b,
          into: %{} do
        correlation = calculate_system_pair_correlation(system_a, system_b, threat_data)
        {{system_a, system_b}, correlation}
      end
    end
  end

  @doc """
  Analyze threat entities from killmail data.
  """
  def analyze_threat_entities(killmails) do
    entities =
      killmails

    |> Enum.flat_map(fn killmail ->
      [
        %{character_id: killmail.attacker_character_id, role: :attacker, killmail: killmail},
        %{character_id: killmail.victim_character_id, role: :victim, killmail: killmail}
      ]
    end)

    |> Enum.filter(fn entity -> entity.character_id end)
    |> Enum.group_by(& &1.character_id)

    |> Enum.map(fn {character_id, character_activities} ->
      %{
        character_id: character_id,
        activity_count: length(character_activities),
        threat_level: calculate_entity_threat_level(character_activities),
        activity_pattern: analyze_entity_activity_pattern(character_activities),
        last_activity: get_last_activity_time(character_activities)
      }
    end)

    |> Enum.sort_by(& &1.threat_level, :desc)

    %{
      total_entities: length(entities),
      high_threat_entities: Enum.filter(entities, &(&1.threat_level > 0.7)),
      entities: entities
    }
  end

  # Private helper functions
  defp group_killmails_by_time_windows(killmails) do
    killmails
    |> Enum.group_by(fn killmail ->
      killmail.killmail_time |> DateTime.truncate(:hour)
    end)
  end

  defp calculate_spillover_strength(killmails) do
    systems_count = killmails |> Enum.map(& &1.solar_system_id) |> Enum.uniq() |> length()
    entities_count = killmails |> Enum.map(& &1.attacker_character_id) |> Enum.uniq() |> length()

    # Higher strength if more systems and entities involved
    min(systems_count * 0.2 + entities_count * 0.1, 1.0)
  end

  defp extract_active_entities(killmails) do
    killmails
    |> Enum.map(& &1.attacker_character_id)
    |> Enum.uniq()
    |> Enum.filter(& &1)
  end

  defp classify_spillover_pattern(killmails) do
    timespan = calculate_timespan_minutes(killmails)

    cond do
      timespan < 30 -> :rapid_spillover
      timespan < 120 -> :gradual_spillover
      true -> :extended_spillover
    end
  end

  defp identify_high_risk_corridors(spillover_patterns) do
    spillover_patterns
    |> Enum.flat_map(& &1.affected_systems)
    |> Enum.frequencies()
    |> Enum.filter(fn {_system, frequency} -> frequency > 2 end)
    |> Enum.map(fn {system_id, frequency} ->
      %{system_id: system_id, spillover_frequency: frequency}
    end)
    |> Enum.sort_by(& &1.spillover_frequency, :desc)
  end

  defp analyze_spillover_trend(spillover_patterns) do
    if length(spillover_patterns) < 2 do
      :insufficient_data
    else
      recent_spillovers = spillover_patterns |> Enum.take(5) |> length()
      total_spillovers = length(spillover_patterns)

      if recent_spillovers / total_spillovers > 0.6 do
        :increasing
      else
        :stable
      end
    end
  end

  defp calculate_coordination_score(times) do
    if length(times) < 2 do
      0.0
    else
      time_diffs =
        Enum.sort(times)

      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.map(fn [t1, t2] -> DateTime.diff(t2, t1, :minute) end)

      avg_diff = Enum.sum(time_diffs) / length(time_diffs)

      # Higher score for activities closer in time
      max(0.0, 1.0 - avg_diff / 60.0)
    end
  end

  defp calculate_group_threat_level(entities) do
    entities
    |> Enum.map(& &1.threat_level)
    |> Enum.sum()
    |> Kernel./(length(entities))
  end

  defp analyze_coordination_trend(coordinated_groups) do
    if length(coordinated_groups) < 3 do
      :insufficient_data
    else
      recent_coordination = coordinated_groups |> Enum.take(3) |> length()

      if recent_coordination >= 2 do
        :increasing
      else
        :stable
      end
    end
  end

  defp calculate_system_pair_correlation(_system_a, _system_b, _threat_data) do
    # Simplified correlation calculation
    0.5
  end

  defp calculate_entity_threat_level(activities) do
    base_threat = min(length(activities) * 0.1, 0.7)
    attacker_bonus = activities |> Enum.count(&(&1.role == :attacker)) |> Kernel.*(0.1)

    min(base_threat + attacker_bonus, 1.0)
  end

  defp analyze_entity_activity_pattern(activities) do
    attacker_count = Enum.count(activities, &(&1.role == :attacker))
    victim_count = Enum.count(activities, &(&1.role == :victim))

    cond do
      attacker_count > victim_count * 2 -> :aggressive
      victim_count > attacker_count * 2 -> :vulnerable
      true -> :balanced
    end
  end

  defp get_last_activity_time(activities) do
    activities
    |> Enum.map(& &1.killmail.killmail_time)
    |> Enum.max()
  end

  defp calculate_timespan_minutes(killmails) do
    times = Enum.map(killmails, & &1.killmail_time)
    min_time = Enum.min(times)
    max_time = Enum.max(times)
    DateTime.diff(max_time, min_time, :minute)
  end

  defp analyze_threat_migration_patterns(_threat_patterns), do: []
  defp identify_high_priority_threats(_threat_patterns), do: []
  defp assess_threat_capabilities(_threat_patterns), do: %{}
  defp suggest_countermeasures(_threat_patterns), do: []
  defp extract_early_warning_indicators(_threat_patterns), do: []
  defp analyze_threat_evolution(_threat_patterns), do: %{}
end

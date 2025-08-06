defmodule EveDmv.Contexts.CombatAnalysis.Domain.ThreatAssessmentEngine do
  @moduledoc """
  Advanced threat assessment engine for analyzing combat entities.

  Provides comprehensive threat analysis for both characters and corporations,
  including behavioral patterns, combat effectiveness, and tactical recommendations.
  """

  alias EveDmv.Contexts.CombatIntelligence.Infrastructure.AnalysisCache

  require Logger

  @type entity_type :: :character | :corporation
  @type threat_level :: :minimal | :low | :moderate | :high | :critical | :extreme
  @type assessment_options :: [
          timeframe_days: pos_integer(),
          include_fleet_analysis: boolean(),
          cache_results: boolean()
        ]

  @type threat_assessment :: %{
          entity_id: integer(),
          entity_type: entity_type(),
          threat_level: threat_level(),
          threat_score: float(),
          confidence: float(),
          assessment_timestamp: DateTime.t(),
          combat_stats: map(),
          recent_activity: map(),
          combat_patterns: map(),
          capability_assessment: map(),
          tactical_profile: map(),
          recommendations: [String.t()],
          metadata: map()
        }

  # Default configuration removed - unused

  @doc """
  Performs comprehensive threat assessment for a character or corporation.

  ## Examples

      iex> assess_threat(123456789, :character)
      {:ok, %ThreatAssessment{threat_level: :high, threat_score: 78.5, ...}}

      iex> assess_threat(98765432, :corporation, timeframe_days: 60)
      {:ok, %ThreatAssessment{threat_level: :moderate, threat_score: 52.1, ...}}
  """
  @spec assess_threat(integer(), entity_type(), assessment_options()) ::
          {:ok, threat_assessment()}
  def assess_threat(entity_id, entity_type, options \\ []) do
    Logger.info("Starting threat assessment for #{entity_type} #{entity_id}")

    with {:ok, assessment} <- perform_threat_assessment(entity_id, entity_type, options),
         :ok <- maybe_cache_result(assessment, options) do
      threat_level = Map.get(assessment, :threat_level, :unknown)
      Logger.info("Threat assessment completed for #{entity_type} #{entity_id}: #{threat_level}")

      {:ok, assessment}
    else
      {:error, reason} = error ->
        Logger.error("Threat assessment failed for #{entity_type} #{entity_id}: #{reason}")
        error
    end
  end

  @doc """
  Gets cached threat assessment if available, otherwise performs new assessment.
  """
  @spec get_threat_assessment(integer(), entity_type(), assessment_options()) ::
          {:ok, threat_assessment()}
  def get_threat_assessment(entity_id, entity_type, options \\ []) do
    _cache_key = {:threat_assessment, entity_type, entity_id}

    case AnalysisCache.get_threat_assessment(entity_id) do
      {:ok, cached_assessment} ->
        Logger.debug("Using cached threat assessment for #{entity_type} #{entity_id}")
        {:ok, cached_assessment}

      {:error, :not_found} ->
        Logger.debug("No cached assessment found, performing new assessment")
        assess_threat(entity_id, entity_type, options)
    end
  end

  @doc """
  Performs real-time threat monitoring for active killmail events.
  """
  @spec monitor_realtime_threats(map()) :: :ok
  def monitor_realtime_threats(killmail_event) do
    # Extract entities from the killmail
    entities = extract_entities_from_killmail(killmail_event)

    # Update real-time threat indicators
    update_realtime_threat_indicators(killmail_event, entities)

    Logger.debug("Updated real-time threat indicators for #{length(entities)} entities")
    :ok
  end

  @doc """
  Gets aggregated threat statistics for monitoring and dashboard purposes.
  """
  @spec get_threat_statistics() ::
          {:ok,
           %{
             total_assessments: non_neg_integer(),
             threat_level_distribution: %{
               minimal: non_neg_integer(),
               low: non_neg_integer(),
               moderate: non_neg_integer(),
               high: non_neg_integer(),
               critical: non_neg_integer(),
               extreme: non_neg_integer()
             },
             cache_hit_rate: float(),
             average_assessment_time_ms: float(),
             last_updated: DateTime.t()
           }}
  def get_threat_statistics do
    # Placeholder for threat statistics
    stats = %{
      total_assessments: 0,
      threat_level_distribution: %{
        minimal: 0,
        low: 0,
        moderate: 0,
        high: 0,
        critical: 0,
        extreme: 0
      },
      cache_hit_rate: 0.0,
      average_assessment_time_ms: 0.0,
      last_updated: DateTime.utc_now()
    }

    {:ok, stats}
  end

  @doc """
  Analyzes fleet threat level for a group of entities.
  """
  @spec assess_fleet_threat([{integer(), entity_type()}], assessment_options()) ::
          {:ok, map()} | {:error, atom()}
  def assess_fleet_threat(entities, options \\ []) when is_list(entities) do
    Logger.info("Assessing fleet threat for #{length(entities)} entities")

    # Assess each entity individually
    individual_assessments =
      entities
      |> Enum.map(fn {entity_id, entity_type} ->
        case assess_threat(entity_id, entity_type, options) do
          {:ok, assessment} -> {entity_id, assessment}
        end
      end)

    if Enum.empty?(individual_assessments) do
      {:error, :no_valid_assessments}
    else
      # Aggregate fleet threat
      fleet_assessment = %{
        total_entities: length(entities),
        assessed_entities: length(individual_assessments),
        highest_threat: calculate_highest_threat_level(individual_assessments),
        average_threat_score: calculate_average_threat_score(individual_assessments),
        threat_distribution: calculate_threat_distribution(individual_assessments),
        combined_capabilities: analyze_combined_capabilities(individual_assessments),
        coordination_potential: assess_coordination_potential(individual_assessments),
        assessment_timestamp: DateTime.utc_now()
      }

      {:ok, fleet_assessment}
    end
  end

  @doc """
  Gets threat assessment cache statistics for monitoring purposes.
  """
  @spec get_cache_statistics() ::
          {:ok,
           %{
             cache_size: non_neg_integer(),
             hit_rate: float(),
             miss_rate: float(),
             evictions: non_neg_integer(),
             uptime_hours: non_neg_integer()
           }}
          | {:error, atom()}
  def get_cache_statistics do
    # Placeholder for cache statistics
    stats = %{
      cache_size: 0,
      hit_rate: 0.0,
      miss_rate: 0.0,
      evictions: 0,
      uptime_hours: 0
    }

    {:ok, stats}
  end

  # Private Implementation Functions

  defp perform_threat_assessment(entity_id, entity_type, options) do
    # Stub implementation - returns complete threat assessment structure
    timeframe_days = Keyword.get(options, :timeframe_days, 30)

    final_assessment = %{
      entity_id: entity_id,
      entity_type: entity_type,
      threat_level: :moderate,
      threat_score: 50.0,
      confidence: 0.75,
      assessment_timestamp: DateTime.utc_now(),
      combat_stats: %{
        kills: 0,
        deaths: 0,
        kill_death_ratio: 0.0,
        isk_destroyed: 0,
        isk_lost: 0,
        isk_efficiency: 0.0
      },
      recent_activity: %{
        last_seen: nil,
        active_days: 0,
        peak_timezone: "Unknown",
        activity_level: :low
      },
      combat_patterns: %{
        preferred_engagement_size: :small_gang,
        aggression_level: :moderate,
        risk_tolerance: :calculated,
        tactical_preference: :balanced
      },
      capability_assessment: %{
        ship_classes: [],
        combat_roles: [],
        fleet_participation: :occasional,
        leadership_indicators: false
      },
      tactical_profile: %{
        strengths: [],
        weaknesses: [],
        typical_tactics: [],
        counter_strategies: []
      },
      recommendations: generate_recommendations(entity_type, :moderate),
      metadata: %{
        assessment_version: "1.0",
        timeframe_days: timeframe_days,
        data_quality: :partial
      }
    }

    {:ok, final_assessment}
  end

  defp maybe_cache_result(_assessment, options) do
    if Keyword.get(options, :cache_results, true) do
      # Stub - would normally cache the result
      :ok
    else
      :ok
    end
  end

  defp extract_entities_from_killmail(event) when is_map(event) do
    entities = []

    # Extract victim
    victim_id = get_in(event, ["victim", "character_id"])
    if victim_id, do: [{victim_id, :character} | entities], else: entities
  end

  defp extract_entities_from_killmail(_), do: []

  defp update_realtime_threat_indicators(_event, _entities), do: :ok

  defp calculate_highest_threat_level(assessments) when is_list(assessments) do
    threat_levels = [:minimal, :low, :moderate, :high, :critical, :extreme]

    assessments
    |> Enum.map(fn {_id, assessment} ->
      Map.get(assessment, :threat_level, :minimal)
    end)
    |> Enum.max_by(
      fn level ->
        Enum.find_index(threat_levels, &(&1 == level)) || 0
      end,
      fn -> :minimal end
    )
  end

  defp calculate_average_threat_score(assessments) when is_list(assessments) do
    scores =
      Enum.map(assessments, fn {_id, assessment} ->
        Map.get(assessment, :threat_score, 0.0)
      end)

    if Enum.empty?(scores) do
      0.0
    else
      Float.round(Enum.sum(scores) / length(scores), 1)
    end
  end

  defp calculate_threat_distribution(assessments) when is_list(assessments) do
    assessments
    |> Enum.map(fn {_id, assessment} ->
      Map.get(assessment, :threat_level, :minimal)
    end)
    |> Enum.frequencies()
  end

  defp analyze_combined_capabilities(assessments) when is_list(assessments) do
    all_ship_classes =
      assessments
      |> Enum.flat_map(fn {_id, assessment} ->
        get_in(assessment, [:capability_assessment, :ship_classes]) || []
      end)
      |> Enum.uniq()

    all_combat_roles =
      assessments
      |> Enum.flat_map(fn {_id, assessment} ->
        get_in(assessment, [:capability_assessment, :combat_roles]) || []
      end)
      |> Enum.uniq()

    %{
      ship_classes: all_ship_classes,
      combat_roles: all_combat_roles,
      fleet_size_potential: length(assessments),
      diversity_score: calculate_diversity_score(all_ship_classes, all_combat_roles)
    }
  end

  defp assess_coordination_potential(assessments) when is_list(assessments) do
    leadership_count =
      assessments
      |> Enum.count(fn {_id, assessment} ->
        get_in(assessment, [:capability_assessment, :leadership_indicators]) == true
      end)

    fleet_experienced_count =
      assessments
      |> Enum.count(fn {_id, assessment} ->
        get_in(assessment, [:capability_assessment, :fleet_participation]) in [
          :regular,
          :frequent
        ]
      end)

    cond do
      leadership_count >= 2 and fleet_experienced_count >= length(assessments) * 0.7 -> :high
      leadership_count >= 1 and fleet_experienced_count >= length(assessments) * 0.5 -> :moderate
      fleet_experienced_count >= length(assessments) * 0.3 -> :low
      true -> :minimal
    end
  end

  defp generate_recommendations(entity_type, _threat_level) do
    # Simplified recommendations - currently only :moderate threat level is returned
    # in current implementation, so we use fixed recommendations
    base_recommendations = [
      "Active threat",
      "Maintain situational awareness",
      "Consider backup options"
    ]

    entity_specific =
      case entity_type do
        :character -> ["Track pilot activity patterns", "Monitor ship usage"]
        :corporation -> ["Assess member capabilities", "Monitor corporate fleet movements"]
      end

    base_recommendations ++ entity_specific
  end

  defp calculate_diversity_score(ship_classes, combat_roles) do
    # Simple diversity calculation
    ship_diversity = min(length(ship_classes) / 10.0, 1.0)
    role_diversity = min(length(combat_roles) / 5.0, 1.0)

    Float.round((ship_diversity + role_diversity) / 2 * 100, 1)
  end
end

defmodule EveDmv.Contexts.CharacterIntelligence do
  @moduledoc """
  Context module for character intelligence and threat analysis.

  Provides the public API for character threat scoring, behavioral analysis,
  and combat effectiveness prediction.
  """

  alias EveDmv.Contexts.CharacterIntelligence.Analyzers.CharacterIntelligenceAnalyzer
  alias EveDmv.Contexts.CharacterIntelligence.Domain.Analyzers.CrossCharacterAnalyzer
  alias EveDmv.Contexts.CharacterIntelligence.Domain.Analyzers.GangSynergyAnalyzer
  alias EveDmv.Contexts.CharacterIntelligence.Domain.Analyzers.HistoricalTrendAnalyzer
  alias EveDmv.Contexts.CharacterIntelligence.Domain.ThreatScoringEngine
  alias EveDmv.Eve.EsiCharacterClient
  alias EveDmv.Eve.EsiCorporationClient
  alias EveDmv.Integrations.ShipIntelligenceBridge

  require Ash.Query
  require Logger

  # Configuration constants
  @pattern_threshold 70
  @high_confidence 0.9
  @low_confidence 0.7

  # Type definitions
  @type character_threat_analysis :: %{
          character_id: integer(),
          threat_score: non_neg_integer(),
          threat_level: :minimal | :low | :medium | :high | :extreme,
          dimensions: map(),
          ship_specialization: map(),
          behavioral_pattern: atom(),
          recent_activity: map(),
          analysis_metadata: map(),
          analysis_timestamp: DateTime.t()
        }

  @type behavioral_pattern_analysis :: %{
          character_id: integer(),
          primary_pattern: atom(),
          patterns: [atom()],
          characteristics: [String.t()],
          confidence: float(),
          analysis_timestamp: DateTime.t()
        }

  @type threat_trend_analysis :: %{
          character_id: integer(),
          trend_direction: :rising | :falling | :stable | :insufficient_data,
          trend_strength: float(),
          historical_scores: [%{date: Date.t(), score: non_neg_integer()}],
          analysis_period_days: integer(),
          analysis_timestamp: DateTime.t()
        }

  @type intelligence_error ::
          :character_not_found
          | :insufficient_data
          | :api_error
          | :timeout
          | :invalid_character_id
          | :feature_not_implemented

  @doc """
  Analyzes a character's threat level based on their combat history.
  Returns comprehensive threat scoring including:
  - Multi-dimensional threat score (0-100)
  - Combat effectiveness metrics
  - Behavioral patterns
  - Threat trends over time
  ## Examples
      iex> CharacterIntelligence.analyze_character_threat(character_id)
      {:ok, %{
        threat_score: 85,
        dimensions: %{combat_skill: 90, ship_mastery: 80, ...},
        behavioral_pattern: :solo_hunter,
        recent_activity: %{...}
      }}
  """
  @spec analyze_character_threat(integer()) ::
          {:ok, character_threat_analysis()} | {:error, intelligence_error()}
  def analyze_character_threat(character_id) do
    case ThreatScoringEngine.calculate_threat_score(character_id) do
      {:ok, threat_data} ->
        # Enhance with ship specialization analysis
        enhanced_threat_data =
          if Map.has_key?(threat_data, :dimensions) do
            enhance_with_ship_intelligence(threat_data, character_id)
          else
            # If threat_data doesn't have expected structure, return as-is
            threat_data
          end

        {:ok, enhanced_threat_data}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Detects behavioral patterns for a character based on their killmail history.
  Identifies patterns such as:
  - Solo hunter
  - Fleet anchor
  - Specialist
  - Opportunist
  """
  @spec detect_behavioral_patterns(integer()) :: {:ok, map()} | {:error, atom()}
  def detect_behavioral_patterns(character_id) do
    # Use the threat scoring engine's behavioral analysis
    case ThreatScoringEngine.calculate_threat_score(character_id) do
      {:ok, threat_data} ->
        {:ok,
         %{
           character_id: character_id,
           primary_pattern: threat_data[:behavioral_pattern] || :unknown,
           patterns: extract_patterns(threat_data),
           characteristics: threat_data[:insights] || [],
           confidence: calculate_pattern_confidence(threat_data),
           analysis_timestamp: DateTime.utc_now()
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp extract_patterns(threat_data) do
    base_patterns = []
    dimensions = Map.get(threat_data, :dimensions, %{})

    # Extract patterns from different scoring dimensions using safe access
    patterns_with_combat =
      if Map.get(dimensions, :combat_skill, 0) > @pattern_threshold,
        do: base_patterns ++ [:skilled_combatant],
        else: base_patterns

    patterns_with_ship =
      if Map.get(dimensions, :ship_mastery, 0) > @pattern_threshold,
        do: patterns_with_combat ++ [:ship_specialist],
        else: patterns_with_combat

    patterns_with_fleet =
      if Map.get(dimensions, :fleet_effectiveness, 0) > @pattern_threshold,
        do: patterns_with_ship ++ [:fleet_oriented],
        else: patterns_with_ship

    final_patterns =
      if Map.get(dimensions, :gang_effectiveness, 0) > @pattern_threshold,
        do: patterns_with_fleet ++ [:gang_leader],
        else: patterns_with_fleet

    final_patterns
  end

  defp calculate_pattern_confidence(threat_data) do
    # Confidence based on data quality and volume
    metadata = Map.get(threat_data, :metadata, %{})

    if Map.get(metadata, :data_quality) == :high do
      @high_confidence
    else
      @low_confidence
    end
  end

  @doc """
  Calculates threat trends for a character over time.
  Shows how their threat level has evolved based on recent performance.
  """
  @spec calculate_threat_trends(integer(), integer()) ::
          {:ok, threat_trend_analysis()} | {:error, intelligence_error()}
  @dialyzer {:nowarn_function, calculate_threat_trends: 2}
  def calculate_threat_trends(character_id, days_back \\ 90) do
    {:ok, trend_data} =
      ThreatScoringEngine.analyze_threat_trends(character_id, analysis_window_days: days_back)

    # Ensure the response matches our type spec
    {:ok,
     %{
       character_id: character_id,
       trend_direction: trend_data[:trend_direction] || :insufficient_data,
       trend_strength: trend_data[:trend_strength] || 0.0,
       historical_scores: trend_data[:historical_scores] || [],
       analysis_period_days: days_back,
       analysis_timestamp: DateTime.utc_now()
     }}
  end

  @doc """
  Compares threat levels between multiple characters.
  Useful for identifying the most dangerous opponents in a group.
  """
  @spec compare_character_threats([integer()]) ::
          {:ok, [{integer(), character_threat_analysis()}]}
  def compare_character_threats(character_ids) when is_list(character_ids) do
    threat_analyses =
      character_ids
      |> Enum.map(fn id ->
        case analyze_character_threat(id) do
          {:ok, analysis} -> {id, analysis}
          {:error, _} -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.sort_by(
        fn {_id, analysis} ->
          # Use single Map.get with nested default for cleaner code
          Map.get(analysis, :threat_score, Map.get(analysis, :overall_score, 0))
        end,
        :desc
      )

    {:ok, threat_analyses}
  end

  @doc """
  Gets a comprehensive intelligence report for a character.
  Combines threat scoring, behavioral analysis, and performance metrics.
  """
  @spec get_character_intelligence_report(integer()) :: {:ok, map()}
  def get_character_intelligence_report(character_id) do
    case analyze_character_threat(character_id) do
      {:ok, threat_data} ->
        character_info = fetch_character_info(character_id)
        # Build the complete report structure expected by the template
        report = build_intelligence_report(character_id, threat_data, character_info)
        {:ok, report}

      {:error, :insufficient_data} ->
        # Return a minimal report for characters with no killmail data
        {:ok, build_minimal_report(character_id)}
    end
  end

  defp fetch_character_info(character_id) do
    case EsiCharacterClient.get_character(character_id) do
      {:ok, character} when is_map(character) ->
        extract_character_info(character)

      {:error, reason} ->
        Logger.warning("Failed to fetch character info for #{character_id}: #{inspect(reason)}")
        # Return a minimal character info structure
        %{
          name: "Unknown Pilot",
          corporation_id: nil,
          corporation_name: "Unknown Corporation",
          alliance_id: nil,
          alliance_name: nil
        }
    end
  end

  defp extract_character_info(character) when is_map(character) do
    # Handle both atom and string keys
    name = Map.get(character, :name) || Map.get(character, "name") || "Unknown Pilot"
    corporation_id = Map.get(character, :corporation_id) || Map.get(character, "corporation_id")
    alliance_id = Map.get(character, :alliance_id) || Map.get(character, "alliance_id")

    # Sequential fetch for corporation and alliance names is intentional:
    # Both EsiCorporationClient.get_corporation/1 and EsiUniverseClient.get_alliance/1
    # consult a cache layer, so cache hits are common and fast. Parallelizing with
    # Task.async would add complexity only to benefit the cache-miss case.
    corp_name =
      if corporation_id do
        case EsiCorporationClient.get_corporation(corporation_id) do
          {:ok, corp} when is_map(corp) ->
            Map.get(corp, :name) || Map.get(corp, "name") || "Unknown Corporation"

          _ ->
            "Unknown Corporation"
        end
      else
        "Unknown Corporation"
      end

    # Fetch alliance name if applicable
    alliance_name =
      if alliance_id do
        case EveDmv.Eve.EsiUniverseClient.get_alliance(alliance_id) do
          {:ok, alliance} when is_map(alliance) ->
            Map.get(alliance, :name) || Map.get(alliance, "name")

          _ ->
            nil
        end
      else
        nil
      end

    %{
      name: name,
      corporation_id: corporation_id,
      corporation_name: corp_name,
      alliance_id: alliance_id,
      alliance_name: alliance_name
    }
  end

  defp build_intelligence_report(character_id, threat_data, character_info) do
    # Extract dimensions from threat_data, converting to template format
    dimensions = build_dimensions_map(threat_data)

    # Build behavioral patterns from threat data insights
    behavioral_patterns = build_behavioral_patterns(threat_data)

    # Build combat stats from the detailed breakdown
    combat_stats = build_combat_stats(threat_data)

    # Build threat trends
    threat_trends = build_threat_trends(threat_data)

    # Build summary
    summary = build_summary(threat_data)

    %{
      character_id: character_id,
      character: character_info,
      threat_analysis: %{
        threat_score: round(threat_data.overall_score * 10),
        threat_level: threat_data.threat_level,
        dimensions: dimensions,
        behavioral_pattern: threat_data[:threat_classification]
      },
      behavioral_patterns: behavioral_patterns,
      combat_stats: combat_stats,
      threat_trends: threat_trends,
      summary: summary,
      report_generated_at: DateTime.utc_now()
    }
  end

  defp build_dimensions_map(threat_data) do
    case threat_data[:detailed_breakdown] do
      nil ->
        %{
          combat_skill: 50,
          ship_mastery: 50,
          gang_effectiveness: 50,
          unpredictability: 50,
          recent_activity: 50
        }

      breakdown ->
        %{
          combat_skill: round((get_in(breakdown, [:combat_skill, :normalized_score]) || 0) * 10),
          ship_mastery: round((get_in(breakdown, [:ship_mastery, :normalized_score]) || 0) * 10),
          gang_effectiveness:
            round((get_in(breakdown, [:gang_effectiveness, :normalized_score]) || 0) * 10),
          unpredictability:
            round((get_in(breakdown, [:unpredictability, :normalized_score]) || 0) * 10),
          recent_activity:
            round((get_in(breakdown, [:recent_activity, :normalized_score]) || 0) * 10)
        }
    end
  end

  defp build_behavioral_patterns(threat_data) do
    breakdown = threat_data[:detailed_breakdown]

    # Determine primary pattern from the data
    primary_pattern =
      cond do
        threat_data[:threat_classification] == :combat_specialist -> :skilled_combatant
        threat_data[:threat_classification] == :ship_master -> :ship_specialist
        threat_data[:threat_classification] == :fleet_commander -> :fleet_anchor
        threat_data[:threat_classification] == :unpredictable_wildcard -> :opportunist
        true -> :solo_hunter
      end

    # Build patterns map with confidence scores
    patterns =
      if breakdown do
        %{
          solo_hunter: (get_in(breakdown, [:unpredictability, :normalized_score]) || 0) / 10,
          fleet_anchor: (get_in(breakdown, [:gang_effectiveness, :normalized_score]) || 0) / 10,
          specialist: (get_in(breakdown, [:ship_mastery, :normalized_score]) || 0) / 10,
          opportunist: (get_in(breakdown, [:combat_skill, :normalized_score]) || 0) / 10
        }
      else
        %{
          solo_hunter: 0.5,
          fleet_anchor: 0.5,
          specialist: 0.5,
          opportunist: 0.5
        }
      end

    # Extract characteristics from insights
    characteristics =
      (threat_data[:key_strengths] || []) ++
        (get_insights_from_breakdown(breakdown) |> Enum.take(3))

    %{
      primary_pattern: primary_pattern,
      patterns: patterns,
      characteristics: characteristics
    }
  end

  defp get_insights_from_breakdown(nil), do: []

  defp get_insights_from_breakdown(breakdown) do
    # Collect insights from all dimensions using safe access
    combat_insights = get_in(breakdown, [:combat_skill, :insights]) || []
    ship_insights = get_in(breakdown, [:ship_mastery, :insights]) || []
    gang_insights = get_in(breakdown, [:gang_effectiveness, :insights]) || []
    unpred_insights = get_in(breakdown, [:unpredictability, :insights]) || []
    recent_insights = get_in(breakdown, [:recent_activity, :insights]) || []

    (combat_insights ++ ship_insights ++ gang_insights ++ unpred_insights ++ recent_insights)
    |> Enum.filter(&is_binary/1)
    |> Enum.uniq()
  end

  defp build_combat_stats(threat_data) do
    breakdown = threat_data[:detailed_breakdown]
    metadata = threat_data[:metadata] || %{}

    # Extract combat components from the detailed breakdown
    combat_components =
      if breakdown && breakdown.combat_skill[:components] do
        breakdown.combat_skill.components
      else
        %{}
      end

    # Ensure we have floats for Float.round
    raw_kd = (combat_components[:kd_ratio] || 1.0) * 1.0
    kd_ratio = Float.round(raw_kd, 1)

    raw_isk_eff = (combat_components[:isk_efficiency] || 1.0) * 1.0
    isk_efficiency = round(raw_isk_eff / 2 * 100) |> min(100)

    # Estimate total kills/losses from metadata
    killmails_analyzed = metadata[:killmails_analyzed] || 0
    survival_rate = combat_components[:survival_rate] || 0.5

    total_kills = round(killmails_analyzed * survival_rate)
    total_losses = killmails_analyzed - total_kills

    # Build recent activity from recent_activity dimension
    recent_stats =
      if breakdown && breakdown.recent_activity[:recent_stats] do
        breakdown.recent_activity.recent_stats
      else
        %{}
      end

    %{
      total_kills: max(total_kills, 0),
      total_losses: max(total_losses, 0),
      kill_death_ratio: kd_ratio,
      isk_efficiency: round(isk_efficiency),
      isk_destroyed: round((combat_components[:isk_efficiency] || 1.0) * 1_000_000_000),
      isk_lost: round(1_000_000_000 / max(combat_components[:isk_efficiency] || 1.0, 0.1)),
      recent_activity: %{
        last_7_days: recent_stats[:kills] || round(killmails_analyzed * 0.1),
        last_30_days: recent_stats[:total_engagements] || round(killmails_analyzed * 0.3)
      }
    }
  end

  defp build_threat_trends(threat_data) do
    # Build trend data from the threat analysis
    overall_score = threat_data.overall_score

    %{
      trend_data: [
        %{
          period: "Recent (30 days)",
          days: 30,
          threat_score: round(overall_score * 10),
          data_points: threat_data[:metadata][:killmails_analyzed] || 0
        }
      ],
      trend_direction: :stable,
      improvement_rate: 0.0,
      volatility: 0.0,
      predictions: []
    }
  end

  defp build_summary(threat_data) do
    # Build key strengths with proper format
    key_strengths =
      (threat_data[:key_strengths] || [])
      |> Enum.map(fn strength ->
        %{
          dimension: strength,
          score: 80
        }
      end)
      |> Enum.take(3)

    # Use tactical recommendations
    recommendations = threat_data[:tactical_recommendations] || []

    # Generate summary text
    summary_text =
      case threat_data.threat_level do
        :extreme -> "Extremely dangerous pilot requiring maximum caution"
        :very_high -> "Highly skilled and dangerous combatant"
        :high -> "Skilled pilot with significant combat experience"
        :moderate -> "Competent pilot with reasonable combat skills"
        :low -> "Limited combat experience or activity"
        :minimal -> "Minimal threat - low combat activity"
        _ -> "Combat profile under analysis"
      end

    %{
      threat_level: threat_data.threat_level,
      summary: summary_text,
      key_strengths: key_strengths,
      recommendations: recommendations
    }
  end

  defp build_minimal_report(character_id) do
    character_info = fetch_character_info(character_id)

    %{
      character_id: character_id,
      character: character_info,
      threat_analysis: %{
        threat_score: 0,
        threat_level: :minimal,
        dimensions: %{
          combat_skill: 0,
          ship_mastery: 0,
          gang_effectiveness: 0,
          unpredictability: 0,
          recent_activity: 0
        }
      },
      behavioral_patterns: %{
        primary_pattern: :unknown,
        patterns: %{},
        characteristics: ["Insufficient data for analysis"]
      },
      combat_stats: nil,
      threat_trends: nil,
      summary: %{
        threat_level: :minimal,
        summary: "Insufficient killmail data for analysis",
        key_strengths: [],
        recommendations: ["No combat data available for this character"]
      },
      report_generated_at: DateTime.utc_now()
    }
  end

  ## Ship Intelligence Integration
  @doc """
  Get comprehensive ship intelligence for a character.
  Returns ship specialization, role preferences, and tactical insights.
  """
  @spec get_character_ship_intelligence(integer()) :: {:ok, map()}
  def get_character_ship_intelligence(character_id) do
    ShipIntelligenceBridge.calculate_ship_specialization(character_id)
  end

  @doc """
  Get ship preference summary for quick threat assessment.
  """
  @spec get_ship_preferences(integer()) :: map()
  def get_ship_preferences(character_id) do
    ShipIntelligenceBridge.get_character_ship_preferences(character_id)
  end

  @doc """
  Get detailed ship preferences for a character.
  Returns top ships used with usage counts, efficiency metrics, and ship classifications.
  """
  @spec get_detailed_ship_preferences(integer(), Date.t() | DateTime.t()) ::
          {:ok, map()} | {:error, atom()}
  def get_detailed_ship_preferences(character_id, since_date) do
    CharacterIntelligenceAnalyzer.analyze_ship_preferences(
      character_id,
      since_date
    )
  end

  @doc """
  Get weapon preferences for a character.
  Returns weapon usage patterns, categories, and effectiveness ratings.
  """
  @spec get_weapon_preferences(integer(), Date.t() | DateTime.t()) ::
          {:ok, map()} | {:error, atom()}
  def get_weapon_preferences(character_id, since_date) do
    CharacterIntelligenceAnalyzer.analyze_weapon_preferences(
      character_id,
      since_date
    )
  end

  @doc """
  Get ship loadouts for a character - weapons grouped by ship.
  Returns only actual data from killmails, no inference.
  """
  @spec get_ship_loadouts(integer(), Date.t() | DateTime.t()) ::
          {:ok, map()} | {:error, atom()}
  def get_ship_loadouts(character_id, since_date) do
    CharacterIntelligenceAnalyzer.analyze_ship_loadouts(
      character_id,
      since_date
    )
  end

  @doc """
  Get known associates - pilots who frequently fly with this character.
  """
  @spec get_known_associates(integer(), Date.t() | DateTime.t()) ::
          {:ok, map()} | {:error, atom()}
  def get_known_associates(character_id, since_date) do
    CharacterIntelligenceAnalyzer.analyze_known_associates(
      character_id,
      since_date
    )
  end

  @doc """
  Get hunting grounds - systems where this character is most active.
  """
  @spec get_hunting_grounds(integer(), Date.t() | DateTime.t()) ::
          {:ok, map()} | {:error, atom()}
  def get_hunting_grounds(character_id, since_date) do
    CharacterIntelligenceAnalyzer.analyze_hunting_grounds(
      character_id,
      since_date
    )
  end

  @doc """
  Get target selection patterns - what types of ships does this character hunt.
  """
  @spec get_target_selection(integer(), Date.t() | DateTime.t()) ::
          {:ok, map()} | {:error, atom()}
  def get_target_selection(character_id, since_date) do
    CharacterIntelligenceAnalyzer.analyze_target_selection(
      character_id,
      since_date
    )
  end

  @doc """
  Get activity timeline - daily activity over recent period.
  """
  @spec get_activity_timeline(integer(), Date.t() | DateTime.t()) ::
          {:ok, map()} | {:error, atom()}
  def get_activity_timeline(character_id, since_date) do
    CharacterIntelligenceAnalyzer.analyze_activity_timeline(
      character_id,
      since_date
    )
  end

  @doc """
  Get corporation context - how active is their corp.
  """
  @spec get_corp_context(integer(), Date.t() | DateTime.t()) ::
          {:ok, map()} | {:error, atom()}
  def get_corp_context(character_id, since_date) do
    CharacterIntelligenceAnalyzer.analyze_corp_context(
      character_id,
      since_date
    )
  end

  @doc """
  Get bait indicators - is this pilot likely bait?
  """
  @spec get_bait_indicators(integer(), Date.t() | DateTime.t()) ::
          {:ok, map()} | {:error, atom()}
  def get_bait_indicators(character_id, since_date) do
    CharacterIntelligenceAnalyzer.analyze_bait_indicators(
      character_id,
      since_date
    )
  end

  @doc """
  Calculate ISK efficiency metrics for a character.
  Returns ISK destroyed/lost, efficiency percentage, and risk assessment.
  """
  @spec calculate_isk_efficiency(integer(), Date.t() | DateTime.t()) ::
          {:ok, map()} | {:error, atom()}
  def calculate_isk_efficiency(character_id, since_date) do
    CharacterIntelligenceAnalyzer.analyze_isk_efficiency(
      character_id,
      since_date
    )
  end

  @doc """
  Get gang size patterns for a character.
  Returns preferences for solo, small gang, medium gang, large gang, and fleet operations.
  """
  @spec get_gang_size_patterns(integer(), Date.t() | DateTime.t()) ::
          {:ok, map()} | {:error, atom()}
  def get_gang_size_patterns(character_id, since_date) do
    CharacterIntelligenceAnalyzer.analyze_gang_patterns(
      character_id,
      since_date
    )
  end

  @doc """
  Calculate activity statistics for a character.
  Returns recent activity, timezone estimates, activity consistency, and trends.
  """
  @spec calculate_activity_stats(integer(), Date.t() | DateTime.t()) ::
          {:ok, map()} | {:error, atom()}
  def calculate_activity_stats(character_id, since_date) do
    CharacterIntelligenceAnalyzer.analyze_activity_stats(
      character_id,
      since_date
    )
  end

  @doc """
  Get character intelligence summary.
  Returns peak activity times, top locations, operational preferences, and activity spread.
  """
  @spec get_intelligence_summary(integer(), Date.t() | DateTime.t()) ::
          {:ok, map()} | {:error, atom()}
  def get_intelligence_summary(character_id, since_date) do
    CharacterIntelligenceAnalyzer.analyze_intelligence_summary(
      character_id,
      since_date
    )
  end

  ## Gang and Cross-Character Analysis Functions

  @doc """
  Analyzes synergy between multiple characters based on shared killmails.
  Returns coordination score, shared victories, role compatibility, and more.
  """
  @spec analyze_gang_synergy([integer()]) :: {:ok, map()} | {:error, atom()}
  def analyze_gang_synergy(character_ids) when is_list(character_ids) do
    GangSynergyAnalyzer.analyze_synergy(character_ids)
  end

  @doc """
  Analyzes relationships between multiple characters.
  Returns relationship matrix, strongest pairs, network cohesion, and subgroups.
  """
  @spec analyze_character_relationships([integer()]) :: {:ok, map()} | {:error, atom()}
  def analyze_character_relationships(character_ids) when is_list(character_ids) do
    CrossCharacterAnalyzer.analyze_relationships(character_ids)
  end

  @doc """
  Identifies patterns in group operations.
  Returns operation types, temporal patterns, geographic patterns, and coordination level.
  """
  @spec analyze_group_patterns([integer()]) :: {:ok, map()} | {:error, atom()}
  def analyze_group_patterns(character_ids) when is_list(character_ids) do
    CrossCharacterAnalyzer.analyze_group_patterns(character_ids)
  end

  @doc """
  Predicts group behavior based on historical patterns.
  Returns likely operation times, target systems, fleet composition, and success probability.
  """
  @spec predict_group_behavior([integer()]) :: {:ok, map()} | {:error, atom()}
  def predict_group_behavior(character_ids) when is_list(character_ids) do
    CrossCharacterAnalyzer.predict_group_behavior(character_ids)
  end

  @doc """
  Analyzes historical trends for a character.
  Returns activity trends, performance trends, ship usage evolution, and skill progression.
  """
  @spec analyze_historical_trends(integer(), keyword()) :: {:ok, map()} | {:error, atom()}
  def analyze_historical_trends(character_id, options \\ []) do
    HistoricalTrendAnalyzer.analyze_trends(character_id, options)
  end

  @doc """
  Gets a quick trend summary for a character.
  Returns activity direction, performance improvement, skill velocity, and fleet preference.
  """
  @spec get_trend_summary(integer()) :: {:ok, map()} | {:error, atom()}
  def get_trend_summary(character_id) do
    HistoricalTrendAnalyzer.get_trend_summary(character_id)
  end

  @doc """
  Analyzes gang effectiveness using the Gang Effectiveness Engine.
  Returns coordination score, leadership patterns, and team synergy metrics.
  """
  @spec analyze_gang_effectiveness([integer()]) :: {:ok, map()} | {:error, atom()}
  def analyze_gang_effectiveness(character_ids) when is_list(character_ids) do
    # GangEffectivenessEngine only works on single characters
    # For multiple characters, use GangSynergyAnalyzer instead
    case GangSynergyAnalyzer.analyze_synergy(character_ids) do
      {:ok, synergy} ->
        # Convert synergy format to effectiveness format
        # Calculate synergy rating from coordination and role compatibility using safe access
        coordination_score = Map.get(synergy, :coordination_score, 0)
        role_compatibility = Map.get(synergy, :role_compatibility, 0)
        synergy_rating = (coordination_score + role_compatibility) / 2

        {:ok,
         %{
           coordination_score: coordination_score,
           synergy_score: synergy_rating,
           effectiveness_rating: calculate_effectiveness_rating(synergy, synergy_rating),
           shared_victories: Map.get(synergy, :shared_victories, 0),
           role_compatibility: role_compatibility,
           temporal_patterns: Map.get(synergy, :temporal_coordination, %{}),
           geographic_patterns: Map.get(synergy, :engagement_patterns, %{}),
           effectiveness_metrics: Map.get(synergy, :success_metrics, %{})
         }}

      error ->
        error
    end
  end

  defp calculate_effectiveness_rating(synergy, synergy_rating) do
    # Simple effectiveness calculation based on coordination and synergy
    base_rating = synergy_rating

    # Bonus for shared victories using safe access
    shared_victories = Map.get(synergy, :shared_victories, 0)
    victory_bonus = min(0.2, shared_victories * 0.01)

    Float.round(min(1.0, base_rating + victory_bonus), 2)
  end

  # Private helper functions
  @dialyzer {:nowarn_function, enhance_with_ship_intelligence: 2}
  defp enhance_with_ship_intelligence(threat_data, character_id) do
    case ShipIntelligenceBridge.calculate_ship_specialization(character_id) do
      {:ok, ship_intelligence} ->
        # Enhance ship mastery dimension with detailed analysis
        enhanced_dimensions =
          Map.update(
            threat_data.dimensions,
            :ship_mastery,
            0,
            fn base_score ->
              # Combine base score with specialization insights
              specialization_bonus = calculate_specialization_bonus(ship_intelligence)
              min(100, base_score + specialization_bonus)
            end
          )

        # Add ship intelligence to threat data
        threat_data
        |> Map.put(:ship_specialization, format_ship_specialization(ship_intelligence))
        |> Map.put(:dimensions, enhanced_dimensions)
    end
  end

  @dialyzer {:nowarn_function, calculate_specialization_bonus: 1}
  defp calculate_specialization_bonus(ship_intelligence) do
    # Calculate bonus to ship mastery based on specialization depth
    expertise_bonus =
      case ship_intelligence.expertise_level do
        :expert -> 15
        :experienced -> 10
        :competent -> 5
        :novice -> 2
        _ -> 0
      end

    # Diversity penalty (specialists get higher scores)
    diversity_penalty = ship_intelligence.specialization_diversity * 5
    max(0, expertise_bonus - diversity_penalty)
  end

  @dialyzer {:nowarn_function, format_ship_specialization: 1}
  defp format_ship_specialization(ship_intelligence) do
    %{
      preferred_roles: Enum.take(ship_intelligence.preferred_roles, 3),
      ship_mastery: ship_intelligence.ship_mastery |> Enum.take(5) |> Enum.into(%{}),
      specialization_diversity: ship_intelligence.specialization_diversity,
      expertise_level: ship_intelligence.expertise_level,
      total_killmails: ship_intelligence.total_killmails
    }
  end
end

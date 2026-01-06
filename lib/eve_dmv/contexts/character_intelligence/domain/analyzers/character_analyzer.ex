defmodule EveDmv.Intelligence.Analyzers.CharacterAnalyzer do
  @moduledoc """
  Character Analyzer - Uses bounded context APIs directly.

  This module provides character analysis by delegating to the
  PlayerProfile bounded context and maintains backward compatibility
  with existing code through format transformation.

  MIGRATION STATUS: ✅ Migrated to bounded context APIs
  - Calls PlayerAnalyzer directly (no adapter layer)
  - Uses AnalysisCache and ThreatCache for cache invalidation
  - Maintains full backward compatibility via format transformations
  """

  alias EveDmv.Contexts.CombatIntelligence.Infrastructure.AnalysisCache
  alias EveDmv.Contexts.PlayerProfile.Domain.PlayerAnalyzer
  alias EveDmv.Contexts.PlayerProfile.Formatters.CharacterDisplayFormatter
  alias EveDmv.Contexts.ThreatAssessment.Infrastructure.ThreatCache

  require Logger

  @type character_analysis :: %{
          character_id: integer(),
          character_name: String.t(),
          corporation_id: integer(),
          corporation_name: String.t(),
          alliance_id: integer() | nil,
          alliance_name: String.t() | nil,
          total_kills: non_neg_integer(),
          total_losses: non_neg_integer(),
          solo_kills: non_neg_integer(),
          kill_death_ratio: float(),
          isk_efficiency: float(),
          dangerous_rating: non_neg_integer()
        }

  @type comprehensive_character_analysis :: %{
          # Base character analysis fields
          character_id: integer(),
          character_name: String.t(),
          corporation_id: integer(),
          corporation_name: String.t(),
          alliance_id: integer() | nil,
          alliance_name: String.t() | nil,
          total_kills: non_neg_integer(),
          total_losses: non_neg_integer(),
          solo_kills: non_neg_integer(),
          kill_death_ratio: float(),
          isk_efficiency: float(),
          dangerous_rating: non_neg_integer(),
          # Comprehensive analysis additional fields
          activity_patterns: map(),
          engagement_behavior: map(),
          risk_profile: map(),
          behavioral_archetype: atom(),
          ship_usage_patterns: map(),
          role_specialization: map(),
          fitting_preferences: map(),
          signature_ship: map(),
          threat_vulnerabilities: map(),
          exploitation_risks: map(),
          analysis_scope: :comprehensive,
          plugins_used: [atom()],
          analysis_confidence: :high | :medium | :low
        }

  @doc """
  Invalidate all caches for a character.

  Clears character analysis, threat assessment, and intelligence scores
  from the cache infrastructure.
  """
  @spec invalidate_character_cache(integer()) :: :ok
  def invalidate_character_cache(character_id) do
    # Invalidate character analysis cache
    AnalysisCache.invalidate_character(character_id)

    # Invalidate threat assessment cache
    AnalysisCache.invalidate_threat_assessment(character_id)

    # Invalidate intelligence scores cache
    AnalysisCache.invalidate_intelligence_scores(character_id)

    # Invalidate threat entity cache (stub - logs only)
    ThreatCache.invalidate_entity(:character, character_id)

    Logger.debug("Invalidated all caches for character #{character_id}")
    :ok
  end

  @doc """
  Analyze a character using the PlayerProfile bounded context.

  Returns a character analysis map with combat statistics, threat indicators,
  and behavioral patterns.
  """
  @spec analyze_character(integer()) :: {:ok, character_analysis()} | {:error, term()}
  def analyze_character(character_id) do
    Logger.info("Analyzing character #{character_id} via PlayerAnalyzer")

    case PlayerAnalyzer.analyze_character(character_id, scope: :basic) do
      {:ok, analysis_result} ->
        # Transform PlayerAnalyzer format to legacy CharacterAnalyzer format
        legacy_result = transform_to_legacy_format(analysis_result)
        {:ok, legacy_result}

      {:error, reason} = error ->
        Logger.error("Character analysis failed for #{character_id}: #{inspect(reason)}")
        error
    end
  end

  @doc """
  Analyze multiple characters in batch using the PlayerProfile bounded context.

  Returns a list of results in the same order as the input character_ids,
  with each result being either `{:ok, analysis}` or `{:error, reason}`.
  """
  @spec analyze_characters([integer()]) :: {:ok, [any()]} | {:error, term()}
  def analyze_characters(character_ids) when is_list(character_ids) do
    Logger.info("Batch analyzing #{length(character_ids)} characters via PlayerAnalyzer")

    case PlayerAnalyzer.analyze_players(character_ids, scope: :basic) do
      {:ok, batch_results} ->
        # Convert batch results to the expected list format
        result_list =
          Enum.map(character_ids, fn char_id ->
            case Map.get(batch_results.successful, char_id) do
              nil ->
                reason = Map.get(batch_results.failed, char_id, :not_processed)
                {:error, reason}

              result ->
                {:ok, transform_to_legacy_format(result)}
            end
          end)

        {:ok, result_list}

      {:error, reason} = error ->
        Logger.error("Batch character analysis failed: #{inspect(reason)}")
        error
    end
  end

  @doc """
  Get comprehensive character analysis using the PlayerProfile bounded context.

  This provides detailed analysis including behavioral patterns, ship preferences,
  and threat assessment data.
  """
  @spec get_comprehensive_analysis(integer()) ::
          {:ok, comprehensive_character_analysis()} | {:error, term()}
  def get_comprehensive_analysis(character_id) do
    Logger.info(
      "Performing comprehensive character analysis for #{character_id} via PlayerAnalyzer"
    )

    case PlayerAnalyzer.analyze_player(character_id, scope: :full) do
      {:ok, analysis_result} ->
        # Transform to comprehensive format with all available data
        comprehensive_result = transform_to_comprehensive_format(character_id, analysis_result)
        {:ok, comprehensive_result}

      {:error, reason} = error ->
        Logger.error(
          "Comprehensive character analysis failed for #{character_id}: #{inspect(reason)}"
        )

        error
    end
  end

  @doc """
  Process killmail data - maintained for backward compatibility.

  Note: This function is now primarily used for data conversion.
  The Intelligence Engine handles killmail processing internally.
  """
  def process_killmail_data(raw_killmail_data) do
    # Simple data structure conversion for backward compatibility
    participants = raw_killmail_data["participants"] || []

    processed = %{
      killmail_id: raw_killmail_data["killmail_id"],
      killmail_time: raw_killmail_data["killmail_time"],
      solar_system_id: raw_killmail_data["solar_system_id"],
      participants: participants,
      victim: Enum.find(participants, &(&1["is_victim"] == true)),
      attackers: Enum.reject(participants, &(&1["is_victim"] == true)),
      zkb: raw_killmail_data["zkb"] || %{}
    }

    {:ok, processed}
  end

  @doc """
  Calculate danger rating - maintained for backward compatibility.
  """
  def calculate_danger_rating(stats) when is_map(stats) do
    # Simplified danger rating calculation for legacy compatibility
    kills = get_in(stats, [:total_kills]) || get_in(stats, [:basic_stats, :total_kills]) || 0
    losses = get_in(stats, [:total_losses]) || get_in(stats, [:basic_stats, :total_losses]) || 0
    solo_kills = get_in(stats, [:solo_kills]) || get_in(stats, [:basic_stats, :solo_kills]) || 0

    efficiency =
      get_in(stats, [:isk_efficiency]) || get_in(stats, [:basic_stats, :isk_efficiency]) || 50.0

    kd_ratio = if losses > 0, do: kills / losses, else: kills

    # Calculate danger score (0-100)
    kd_weight = min(kd_ratio * 20, 40)
    solo_weight = min(solo_kills * 2, 30)
    activity_weight = min(kills / 10, 20)
    efficiency_weight = efficiency / 10

    score = kd_weight + solo_weight + activity_weight + efficiency_weight

    # Convert to 1-5 rating
    cond do
      score >= 80 -> 5
      score >= 60 -> 4
      score >= 40 -> 3
      score >= 20 -> 2
      true -> 1
    end
  end

  @doc """
  Format character summary - delegates to formatters.
  """
  def format_character_summary(analysis_results) do
    CharacterDisplayFormatter.format_character_summary(analysis_results)
  end

  @doc """
  Format analysis summary - delegates to formatters.
  """
  def format_analysis_summary(character_stats) do
    CharacterDisplayFormatter.format_analysis_summary(character_stats)
  end

  # Private transformation functions

  # Transform PlayerAnalyzer format to legacy CharacterAnalyzer format
  defp transform_to_legacy_format(analysis_result) do
    combat_stats = Map.get(analysis_result, :combat_stats, %{})
    ship_prefs = Map.get(analysis_result, :ship_preferences, %{})

    # Extract basic stats with fallbacks
    basic_stats = Map.get(combat_stats, :basic_stats, %{})
    performance_metrics = Map.get(combat_stats, :performance_metrics, %{})

    total_kills = Map.get(basic_stats, :total_kills, 0)
    total_losses = Map.get(basic_stats, :total_losses, 0)
    solo_kills = Map.get(basic_stats, :solo_kills, 0)
    isk_efficiency = Map.get(basic_stats, :isk_efficiency, 50.0)

    kd_ratio =
      if total_losses > 0,
        do: total_kills / total_losses,
        else: if(total_kills > 0, do: total_kills * 1.0, else: 1.0)

    %{
      character_id: Map.get(analysis_result, :character_id, 0),
      character_name: get_nested(analysis_result, [:base_data, :character_name], "Unknown"),
      corporation_id: get_nested(analysis_result, [:base_data, :corporation_id], 0),
      corporation_name: get_nested(analysis_result, [:base_data, :corporation_name], "Unknown"),
      alliance_id: get_nested(analysis_result, [:base_data, :alliance_id]),
      alliance_name: get_nested(analysis_result, [:base_data, :alliance_name]),

      # Combat statistics
      total_kills: total_kills,
      total_losses: total_losses,
      solo_kills: solo_kills,
      kill_death_ratio: kd_ratio,
      isk_efficiency: isk_efficiency,
      dangerous_rating: Map.get(basic_stats, :dangerous_rating, 3),

      # Weapon analysis
      weapon_preferences: get_nested(combat_stats, [:weapon_analysis, :top_weapons], []),

      # Performance metrics
      activity_level: Map.get(basic_stats, :activity_level, :moderate),
      aggression_index: Map.get(performance_metrics, :aggression_index, 0.0),

      # Risk indicators
      threat_level: get_nested(combat_stats, [:risk_indicators, :threat_level], :medium),
      uses_cynos: get_nested(combat_stats, [:risk_indicators, :uses_cynos], false),
      flies_capitals: get_nested(combat_stats, [:risk_indicators, :flies_capitals], false),

      # Summary information
      combat_style: get_nested(combat_stats, [:summary, :combat_style], :mixed),
      experience_level: get_nested(combat_stats, [:summary, :experience_level], :intermediate),
      strengths: get_nested(combat_stats, [:summary, :strengths], []),
      weaknesses: get_nested(combat_stats, [:summary, :weaknesses], []),

      # Ship preferences summary
      primary_ship_role: get_nested(ship_prefs, [:role_distribution, :primary_role]),
      ship_diversity: get_nested(ship_prefs, [:diversity_metrics, :ship_diversity_index], 0.0),

      # Analysis metadata
      last_analyzed_at: Map.get(analysis_result, :analysis_timestamp, DateTime.utc_now()),
      data_completeness: 75,
      analysis_scope: :basic,
      source: "player_analyzer"
    }
  end

  # Transform PlayerAnalyzer full analysis to comprehensive format
  defp transform_to_comprehensive_format(character_id, analysis_result) do
    # Start with base legacy format from the analysis
    base_format =
      analysis_result
      |> Map.put(:character_id, character_id)
      |> transform_to_legacy_format()

    # Extract additional comprehensive data
    combat_stats = Map.get(analysis_result, :combat_statistics, %{})
    ship_prefs = Map.get(analysis_result, :ship_preferences, %{})
    risk_profile = Map.get(analysis_result, :risk_profile, %{})

    Map.merge(base_format, %{
      # Behavioral patterns from combat stats
      activity_patterns: Map.get(combat_stats, :activity_patterns, %{}),
      engagement_behavior: Map.get(combat_stats, :engagement_behavior, %{}),
      risk_profile: risk_profile,
      behavioral_archetype: Map.get(analysis_result, :player_archetype, :unknown),

      # Ship preferences
      ship_usage_patterns: Map.get(ship_prefs, :usage_patterns, %{}),
      role_specialization: Map.get(ship_prefs, :role_distribution, %{}),
      fitting_preferences: Map.get(ship_prefs, :fitting_preferences, %{}),
      signature_ship: get_nested(ship_prefs, [:top_ships, Access.at(0)], %{}),

      # Threat assessment
      threat_vulnerabilities: get_nested(risk_profile, [:risk_factors], []),
      exploitation_risks: get_nested(risk_profile, [:mitigation_suggestions], []),

      # Enhanced metadata
      analysis_scope: :comprehensive,
      plugins_used: [:player_profile, :combat_stats, :ship_preferences],
      analysis_confidence: :high,
      recommendations: Map.get(analysis_result, :recommendations, [])
    })
  end

  # Helper to safely get nested values with default
  defp get_nested(map, keys, default \\ nil)

  defp get_nested(nil, _keys, default), do: default

  defp get_nested(map, [], _default), do: map

  defp get_nested(map, [key | rest], default) when is_map(map) do
    case Map.get(map, key) do
      nil -> default
      value -> get_nested(value, rest, default)
    end
  end

  defp get_nested(_other, _keys, default), do: default
end

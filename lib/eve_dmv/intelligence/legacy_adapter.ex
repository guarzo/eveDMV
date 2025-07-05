defmodule EveDmv.Intelligence.LegacyAdapter do
  @moduledoc """
  Legacy adapter for bridging old Intelligence analyzers to the new Intelligence Engine.

  This module provides backward compatibility by wrapping the new Intelligence Engine
  plugin system with the old analyzer interfaces. This allows existing code to continue
  working while we migrate to the new system.
  """

  require Logger
  alias EveDmv.IntelligenceEngine

  @doc """
  Analyze a character using the new Intelligence Engine while maintaining the old interface.

  This function bridges the old CharacterAnalyzer.analyze_character/1 interface
  to the new Intelligence Engine plugin system.
  """
  @spec analyze_character(integer()) :: {:ok, map()} | {:error, term()}
  def analyze_character(character_id) do
    # Use the new Intelligence Engine with character domain and basic scope
    case IntelligenceEngine.analyze(:character, character_id, scope: :basic) do
      {:ok, analysis_result} ->
        # Convert new plugin results to legacy format for backward compatibility
        legacy_result = convert_to_legacy_character_format(analysis_result)
        {:ok, legacy_result}

      {:error, reason} = error ->
        Logger.error("Legacy character analysis failed for #{character_id}: #{inspect(reason)}")
        error
    end
  end

  @doc """
  Analyze multiple characters using the new Intelligence Engine.
  """
  @spec analyze_characters([integer()]) :: {:ok, [any()]} | {:error, term()}
  def analyze_characters(character_ids) when is_list(character_ids) do
    Logger.info("Legacy batch analyzing #{length(character_ids)} characters")

    # Use the new Intelligence Engine batch processing
    case IntelligenceEngine.analyze(:character, character_ids, scope: :basic, parallel: true) do
      {:ok, batch_results} ->
        # Convert batch results to legacy format
        legacy_results =
          batch_results.successful
          |> Enum.map(fn {char_id, result} ->
            {char_id, {:ok, convert_to_legacy_character_format(result)}}
          end)
          |> Enum.into(%{})

        # Add failed results
        failed_results =
          batch_results.failed
          |> Enum.map(fn {char_id, reason} ->
            {char_id, {:error, reason}}
          end)
          |> Enum.into(%{})

        all_results = Map.merge(legacy_results, failed_results)

        # Convert to list format expected by legacy code
        result_list =
          character_ids
          |> Enum.map(fn char_id -> Map.get(all_results, char_id, {:error, :not_processed}) end)

        {:ok, result_list}

      {:error, reason} = error ->
        Logger.error("Legacy batch character analysis failed: #{inspect(reason)}")
        error
    end
  end

  @doc """
  Analyze a corporation using the new Intelligence Engine.
  """
  @spec analyze_corporation(integer()) :: {:ok, map()} | {:error, term()}
  def analyze_corporation(corporation_id) do
    case IntelligenceEngine.analyze(:corporation, corporation_id, scope: :basic) do
      {:ok, analysis_result} ->
        legacy_result = convert_to_legacy_corporation_format(analysis_result)
        {:ok, legacy_result}

      {:error, reason} = error ->
        Logger.error(
          "Legacy corporation analysis failed for #{corporation_id}: #{inspect(reason)}"
        )

        error
    end
  end

  @doc """
  Analyze a fleet using the new Intelligence Engine.
  """
  @spec analyze_fleet(integer()) :: {:ok, map()} | {:error, term()}
  def analyze_fleet(fleet_id) do
    case IntelligenceEngine.analyze(:fleet, fleet_id, scope: :basic) do
      {:ok, analysis_result} ->
        legacy_result = convert_to_legacy_fleet_format(analysis_result)
        {:ok, legacy_result}

      {:error, reason} = error ->
        Logger.error("Legacy fleet analysis failed for #{fleet_id}: #{inspect(reason)}")
        error
    end
  end

  @doc """
  Perform threat analysis using the new Intelligence Engine.
  """
  @spec analyze_threat(integer(), atom()) :: {:ok, map()} | {:error, term()}
  def analyze_threat(entity_id, entity_type \\ :character) do
    case IntelligenceEngine.analyze(:threat, entity_id,
           scope: :basic,
           entity_type: entity_type
         ) do
      {:ok, analysis_result} ->
        legacy_result = convert_to_legacy_threat_format(analysis_result)
        {:ok, legacy_result}

      {:error, reason} = error ->
        Logger.error("Legacy threat analysis failed for #{entity_id}: #{inspect(reason)}")
        error
    end
  end

  @doc """
  Invalidate cache for a character using the new Intelligence Engine.
  """
  @spec invalidate_character_cache(integer()) :: :ok
  def invalidate_character_cache(character_id) do
    IntelligenceEngine.invalidate_cache(:character, character_id)
    Logger.debug("Invalidated cache for character #{character_id} via legacy adapter")
    :ok
  end

  @doc """
  Get comprehensive character analysis using multiple plugins.
  """
  @spec get_comprehensive_character_analysis(integer()) :: {:ok, map()} | {:error, term()}
  def get_comprehensive_character_analysis(character_id) do
    case IntelligenceEngine.analyze(:character, character_id, scope: :full) do
      {:ok, analysis_result} ->
        # The full scope includes combat_stats, behavioral_patterns, ship_preferences, 
        # threat_assessment, and alliance_activity plugins
        comprehensive_result = convert_to_comprehensive_character_format(analysis_result)
        {:ok, comprehensive_result}

      {:error, reason} = error ->
        Logger.error(
          "Comprehensive character analysis failed for #{character_id}: #{inspect(reason)}"
        )

        error
    end
  end

  # Conversion functions to maintain backward compatibility

  defp convert_to_legacy_character_format(analysis_result) do
    # Extract results from the combat_stats plugin (which should be present in basic scope)
    combat_stats = get_plugin_result(analysis_result, :combat_stats, %{})

    # Convert new plugin result format to legacy CharacterStats format
    %{
      character_id: extract_character_id(analysis_result),
      character_name: extract_character_name(analysis_result),
      corporation_id: extract_corporation_id(analysis_result),
      corporation_name: extract_corporation_name(analysis_result),
      alliance_id: extract_alliance_id(analysis_result),
      alliance_name: extract_alliance_name(analysis_result),

      # Combat statistics from combat_stats plugin
      total_kills: get_in(combat_stats, [:basic_stats, :total_kills]) || 0,
      total_losses: get_in(combat_stats, [:basic_stats, :total_losses]) || 0,
      solo_kills: get_in(combat_stats, [:basic_stats, :solo_kills]) || 0,
      kill_death_ratio: get_in(combat_stats, [:basic_stats, :kill_death_ratio]) || 1.0,
      isk_efficiency: get_in(combat_stats, [:basic_stats, :isk_efficiency]) || 50.0,
      dangerous_rating: get_in(combat_stats, [:basic_stats, :dangerous_rating]) || 3,

      # Weapon analysis
      weapon_preferences: get_in(combat_stats, [:weapon_analysis, :top_weapons]) || [],

      # Performance metrics
      activity_level: get_in(combat_stats, [:basic_stats, :activity_level]) || :moderate,
      aggression_index: get_in(combat_stats, [:performance_metrics, :aggression_index]) || 0.0,

      # Risk indicators
      threat_level: get_in(combat_stats, [:risk_indicators, :threat_level]) || :medium,
      uses_cynos: get_in(combat_stats, [:risk_indicators, :uses_cynos]) || false,
      flies_capitals: get_in(combat_stats, [:risk_indicators, :flies_capitals]) || false,

      # Summary information
      combat_style: get_in(combat_stats, [:summary, :combat_style]) || :mixed,
      experience_level: get_in(combat_stats, [:summary, :experience_level]) || :intermediate,
      strengths: get_in(combat_stats, [:summary, :strengths]) || [],
      weaknesses: get_in(combat_stats, [:summary, :weaknesses]) || [],

      # Analysis metadata
      last_analyzed_at: DateTime.utc_now(),
      # Default reasonable value
      data_completeness: 75,
      analysis_scope: :basic,
      source: "intelligence_engine"
    }
  end

  defp convert_to_legacy_corporation_format(analysis_result) do
    # Extract results from member_activity plugin
    member_activity = get_plugin_result(analysis_result, :member_activity, %{})

    %{
      corporation_id: extract_corporation_id(analysis_result),
      corporation_name: extract_corporation_name(analysis_result),

      # Overall activity metrics
      total_members: get_in(member_activity, [:overall_activity, :total_members]) || 0,
      active_members: get_in(member_activity, [:overall_activity, :active_members]) || 0,
      activity_rate: get_in(member_activity, [:overall_activity, :activity_rate]) || 0.0,
      activity_trend: get_in(member_activity, [:overall_activity, :activity_trend]) || :stable,

      # Engagement metrics
      engagement_score:
        get_in(member_activity, [:member_engagement, :overall_engagement_score]) || 0.0,
      top_performers: get_in(member_activity, [:member_engagement, :top_performers]) || [],

      # Timezone coverage
      timezone_coverage:
        get_in(member_activity, [:timezone_coverage, :overall_coverage_score]) || 0.0,
      coverage_gaps: get_in(member_activity, [:timezone_coverage, :coverage_gaps]) || [],

      # Health assessment
      health_score: get_in(member_activity, [:activity_summary, :health_score]) || 0.0,
      health_rating: get_in(member_activity, [:activity_summary, :health_rating]) || :fair,

      # Analysis metadata
      last_analyzed_at: DateTime.utc_now(),
      analysis_scope: :basic,
      source: "intelligence_engine"
    }
  end

  defp convert_to_legacy_fleet_format(analysis_result) do
    # Extract results from composition_analysis plugin
    composition = get_plugin_result(analysis_result, :composition_analysis, %{})

    %{
      fleet_id: extract_fleet_id(analysis_result),
      fleet_name: get_in(composition, [:fleet_overview, :fleet_name]) || "Unknown Fleet",

      # Fleet composition
      total_participants: get_in(composition, [:fleet_overview, :total_participants]) || 0,
      fleet_size_category:
        get_in(composition, [:fleet_overview, :fleet_size_category]) || :unknown,
      fleet_type: get_in(composition, [:fleet_overview, :fleet_type]) || :mixed_composition,
      total_fleet_value: get_in(composition, [:fleet_overview, :total_fleet_value]) || 0,

      # Ship composition
      ship_diversity: get_in(composition, [:ship_composition, :diversity_index]) || 0.0,
      most_common_ships: get_in(composition, [:ship_composition, :most_common_ships]) || [],

      # Role distribution
      role_balance_score: get_in(composition, [:role_distribution, :role_balance_score]) || 0.0,
      missing_roles: get_in(composition, [:role_distribution, :missing_critical_roles]) || [],

      # Tactical capabilities
      tactical_rating:
        get_in(composition, [:tactical_capabilities, :overall_tactical_rating]) || 0.0,
      estimated_dps:
        get_in(composition, [:effectiveness_metrics, :firepower, :estimated_dps]) || 0,
      effective_hp:
        get_in(composition, [:effectiveness_metrics, :survivability, :effective_hp]) || 0,

      # Overall assessment
      effectiveness_rating:
        get_in(composition, [:composition_summary, :effectiveness_rating]) || :unknown,
      primary_strengths: get_in(composition, [:composition_summary, :primary_strengths]) || [],
      primary_weaknesses: get_in(composition, [:composition_summary, :primary_weaknesses]) || [],

      # Analysis metadata
      last_analyzed_at: DateTime.utc_now(),
      analysis_scope: :basic,
      source: "intelligence_engine"
    }
  end

  defp convert_to_legacy_threat_format(analysis_result) do
    # Extract results from vulnerability_scan plugin
    vulnerability = get_plugin_result(analysis_result, :vulnerability_scan, %{})

    %{
      entity_id: extract_entity_id(analysis_result),
      entity_type: get_in(vulnerability, [:entity_profile, :entity_type]) || :unknown,

      # Vulnerability scores
      overall_vulnerability_score:
        get_in(vulnerability, [:exploitability_rating, :overall_exploitability_score]) || 0.0,
      exploitability_rating:
        get_in(vulnerability, [:exploitability_rating, :exploitability_rating]) || :unknown,

      # Vulnerability breakdown
      behavioral_vulnerabilities:
        get_in(vulnerability, [:behavioral_vulnerabilities, :behavioral_vulnerability_score]) ||
          0.0,
      tactical_vulnerabilities:
        get_in(vulnerability, [:tactical_vulnerabilities, :tactical_vulnerability_score]) || 0.0,
      operational_vulnerabilities:
        get_in(vulnerability, [:operational_vulnerabilities, :operational_vulnerability_score]) ||
          0.0,
      social_vulnerabilities:
        get_in(vulnerability, [:social_vulnerabilities, :social_vulnerability_score]) || 0.0,

      # Key findings
      primary_attack_vectors:
        get_in(vulnerability, [:exploitability_rating, :primary_attack_vectors]) || [],
      key_vulnerabilities:
        get_in(vulnerability, [:vulnerability_summary, :key_vulnerabilities]) || [],
      critical_risks: get_in(vulnerability, [:vulnerability_summary, :critical_risks]) || [],

      # Security assessment
      security_rating:
        get_in(vulnerability, [:security_assessment, :security_rating]) || :unknown,
      security_gaps: get_in(vulnerability, [:security_assessment, :identified_gaps]) || [],

      # Recommendations
      immediate_actions:
        get_in(vulnerability, [:vulnerability_summary, :immediate_actions_required]) || [],
      mitigation_roadmap:
        get_in(vulnerability, [:vulnerability_summary, :mitigation_roadmap]) || %{},

      # Analysis metadata
      overall_vulnerability_level:
        get_in(vulnerability, [:vulnerability_summary, :overall_vulnerability_level]) || :unknown,
      assessment_timestamp:
        get_in(vulnerability, [:vulnerability_summary, :assessment_timestamp]) ||
          DateTime.utc_now(),
      analysis_scope: :basic,
      source: "intelligence_engine"
    }
  end

  defp convert_to_comprehensive_character_format(analysis_result) do
    # For comprehensive analysis, combine results from multiple plugins
    base_result = convert_to_legacy_character_format(analysis_result)

    # Add behavioral patterns data
    behavioral = get_plugin_result(analysis_result, :behavioral_patterns, %{})
    ship_prefs = get_plugin_result(analysis_result, :ship_preferences, %{})
    threat_assess = get_plugin_result(analysis_result, :threat_assessment, %{})

    Map.merge(base_result, %{
      # Behavioral patterns
      activity_patterns: get_in(behavioral, [:activity_patterns]) || %{},
      engagement_behavior: get_in(behavioral, [:engagement_behavior]) || %{},
      risk_profile: get_in(behavioral, [:risk_profile]) || %{},
      behavioral_archetype:
        get_in(behavioral, [:behavioral_summary, :behavioral_archetype]) || :unknown,

      # Ship preferences
      ship_usage_patterns: get_in(ship_prefs, [:ship_usage_patterns]) || %{},
      role_specialization: get_in(ship_prefs, [:role_specialization]) || %{},
      fitting_preferences: get_in(ship_prefs, [:fitting_preferences]) || %{},
      signature_ship: get_in(ship_prefs, [:preferences_summary, :signature_ship]) || %{},

      # Threat assessment
      threat_vulnerabilities: get_in(threat_assess, [:vulnerability_analysis]) || %{},
      exploitation_risks: get_in(threat_assess, [:exploitation_rating]) || %{},

      # Enhanced metadata
      analysis_scope: :comprehensive,
      plugins_used: Map.keys(analysis_result.plugin_results || %{}),
      analysis_confidence: :high
    })
  end

  # Helper functions for extracting common data from analysis results

  defp get_plugin_result(analysis_result, plugin_name, default) do
    get_in(analysis_result, [:plugin_results, plugin_name]) || default
  end

  defp extract_character_id(analysis_result) do
    analysis_result.entity_id || 0
  end

  defp extract_character_name(analysis_result) do
    get_in(analysis_result, [:base_data, :character_name]) || "Unknown Character"
  end

  defp extract_corporation_id(analysis_result) do
    get_in(analysis_result, [:base_data, :corporation_id]) || 0
  end

  defp extract_corporation_name(analysis_result) do
    get_in(analysis_result, [:base_data, :corporation_name]) || "Unknown Corporation"
  end

  defp extract_alliance_id(analysis_result) do
    get_in(analysis_result, [:base_data, :alliance_id])
  end

  defp extract_alliance_name(analysis_result) do
    get_in(analysis_result, [:base_data, :alliance_name])
  end

  defp extract_fleet_id(analysis_result) do
    analysis_result.entity_id || 0
  end

  defp extract_entity_id(analysis_result) do
    analysis_result.entity_id || 0
  end
end

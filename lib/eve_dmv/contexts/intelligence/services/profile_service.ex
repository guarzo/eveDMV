defmodule EveDmv.Contexts.Intelligence.Services.ProfileService do
  @moduledoc """
  Service for generating comprehensive character profiles and handling exports.
  """

  alias EveDmv.Contexts.Intelligence.Core.{
    CharacterAnalyzer,
    ThreatAssessmentEngine,
    PerformanceAnalyzer
  }

  alias EveDmv.Cache

  require Logger

  @cache_ttl :timer.hours(2)

  @doc """
  Generate a full comprehensive profile for a character.
  """
  def generate_full_profile(character_id) do
    cache_key = {:full_profile, character_id}

    Cache.get_or_compute(
      :analysis,
      cache_key,
      fn ->
        build_comprehensive_profile(character_id)
      end,
      ttl: @cache_ttl
    )
  end

  @doc """
  Export character profile in specified format.

  Supported formats:
  - :json - JSON format (default)
  - :yaml - YAML format
  - :pdf - PDF report (future implementation)
  - :html - HTML report
  """
  def export_profile(character_id, format \\ :json) do
    with {:ok, profile} <- generate_full_profile(character_id) do
      case format do
        :json -> export_as_json(profile)
        :yaml -> export_as_yaml(profile)
        :html -> export_as_html(profile)
        :pdf -> export_as_pdf(profile)
        _ -> {:error, :unsupported_format}
      end
    end
  end

  @doc """
  Share profile with specific sharing options.

  Options:
    - visibility: :public, :corp, :alliance, :private (default: :private)
    - expiry: DateTime when share expires (default: 7 days)
    - sections: List of sections to include (default: all)
    - redact_sensitive: Boolean to redact sensitive info (default: true)
  """
  def share_profile(character_id, sharing_options \\ []) do
    with {:ok, profile} <- generate_full_profile(character_id) do
      share_data = prepare_profile_for_sharing(profile, sharing_options)

      # Generate share token
      share_token = generate_share_token()

      # Store share data (in practice, would store in database)
      share_record = %{
        token: share_token,
        character_id: character_id,
        profile_data: share_data,
        visibility: Keyword.get(sharing_options, :visibility, :private),
        expires_at: calculate_expiry(sharing_options),
        created_at: DateTime.utc_now()
      }

      # Cache the share record
      Cache.put(:analysis, {:profile_share, share_token}, share_record, ttl: :timer.hours(24 * 7))

      {:ok,
       %{
         share_token: share_token,
         share_url: build_share_url(share_token),
         expires_at: share_record.expires_at
       }}
    end
  end

  @doc """
  Get shared profile by token.
  """
  def get_shared_profile(share_token) do
    case Cache.get(:analysis, {:profile_share, share_token}) do
      nil ->
        {:error, :not_found}

      share_record ->
        if DateTime.compare(DateTime.utc_now(), share_record.expires_at) == :lt do
          {:ok, share_record.profile_data}
        else
          {:error, :expired}
        end
    end
  end

  # Private Functions

  defp build_comprehensive_profile(character_id) do
    Logger.info("Building comprehensive profile for character #{character_id}")

    # Gather all available data
    with {:ok, character_analysis} <- CharacterAnalyzer.analyze_character(character_id),
         {:ok, threat_assessment} <- ThreatAssessmentEngine.assess_threat(character_id),
         {:ok, performance_analysis} <- PerformanceAnalyzer.analyze_performance(character_id) do
      profile = %{
        character_id: character_id,
        generated_at: DateTime.utc_now(),

        # Basic Information
        basic_info: extract_basic_info(character_analysis),

        # Threat Assessment
        threat_profile: build_threat_profile(threat_assessment),

        # Combat Analysis
        combat_profile: build_combat_profile(character_analysis),

        # Ship Preferences
        ship_profile: build_ship_profile(character_analysis),

        # Behavioral Patterns
        behavioral_profile: build_behavioral_profile(character_analysis),

        # Performance Metrics
        performance_profile: build_performance_profile(performance_analysis),

        # Strategic Assessment
        strategic_assessment:
          build_strategic_assessment(character_analysis, threat_assessment, performance_analysis),

        # Intelligence Summary
        intelligence_summary:
          build_intelligence_summary(character_analysis, threat_assessment, performance_analysis)
      }

      {:ok, profile}
    end
  end

  defp extract_basic_info(character_analysis) do
    summary = character_analysis.summary

    %{
      character_id: character_analysis.character_id,
      total_kills: summary.total_kills,
      total_losses: summary.total_losses,
      isk_efficiency: summary.isk_efficiency,
      favorite_ship: summary.favorite_ship,
      primary_timezone: summary.primary_timezone,
      activity_level: summary.activity_level,
      pilot_type: character_analysis.classifications.pilot_type,
      skill_level: character_analysis.classifications.skill_level
    }
  end

  defp build_threat_profile(threat_assessment) do
    %{
      overall_score: threat_assessment.overall_score,
      threat_level: threat_assessment.threat_level,
      aspect_breakdown: threat_assessment.aspect_scores,
      primary_threats: threat_assessment.analysis.primary_threats,
      engagement_recommendation:
        generate_engagement_recommendation(threat_assessment.threat_level),
      last_assessed: threat_assessment.assessed_at
    }
  end

  defp build_combat_profile(character_analysis) do
    combat_data = character_analysis.data[:combat_stats] || %{}

    %{
      kill_death_ratio: combat_data[:kill_death_ratio] || 0,
      solo_effectiveness: combat_data[:solo_ratio] || 0,
      preferred_engagement_size: determine_preferred_engagement(combat_data),
      weapon_preferences: combat_data[:weapon_preferences] || [],
      engagement_patterns: combat_data[:engagement_patterns] || %{},
      combat_strengths: character_analysis.strengths,
      combat_weaknesses: character_analysis.weaknesses
    }
  end

  defp build_ship_profile(character_analysis) do
    ship_data = character_analysis.data[:ship_preferences] || %{}

    %{
      favorite_ships: ship_data[:favorite_ships] || [],
      ship_diversity: ship_data[:ship_diversity] || 0,
      specialization_level: ship_data[:specialization_index] || 0,
      capital_usage: ship_data[:capital_usage] || 0,
      tech_progression: ship_data[:tech_advancement] || %{},
      fitting_patterns: ship_data[:fitting_patterns] || []
    }
  end

  defp build_behavioral_profile(character_analysis) do
    behavior_data = character_analysis.data[:behavioral_patterns] || %{}

    %{
      activity_patterns: behavior_data[:activity_patterns] || %{},
      timezone_estimate: behavior_data[:timezone] || "Unknown",
      predictability_score: behavior_data[:predictability] || 0.5,
      geographic_preferences: behavior_data[:geographic_preferences] || %{},
      operational_patterns: behavior_data[:operational_patterns] || %{},
      notable_patterns: character_analysis.notable_patterns
    }
  end

  defp build_performance_profile(performance_analysis) do
    %{
      core_metrics: performance_analysis.core_metrics,
      efficiency_metrics: performance_analysis.efficiency_metrics,
      improvement_trends: performance_analysis.improvement_metrics,
      performance_rating: performance_analysis.performance_rating,
      strengths: performance_analysis.strengths,
      improvement_areas: performance_analysis.areas_for_improvement
    }
  end

  defp build_strategic_assessment(character_analysis, threat_assessment, performance_analysis) do
    %{
      overall_assessment: generate_overall_assessment(character_analysis, threat_assessment),
      engagement_recommendations:
        generate_detailed_engagement_recs(threat_assessment, performance_analysis),
      counter_strategies: generate_counter_strategies(character_analysis, threat_assessment),
      intelligence_value: assess_intelligence_value(character_analysis, threat_assessment),
      recruitment_potential:
        assess_recruitment_potential(character_analysis, performance_analysis)
    }
  end

  defp build_intelligence_summary(character_analysis, threat_assessment, _performance_analysis) do
    %{
      key_insights: extract_key_insights(character_analysis, threat_assessment),
      threat_summary: summarize_threat_level(threat_assessment),
      tactical_notes: generate_tactical_notes(character_analysis),
      last_updated: DateTime.utc_now(),
      confidence_level: assess_data_confidence(character_analysis)
    }
  end

  defp generate_engagement_recommendation(:critical) do
    "AVOID - Extreme threat level. Engage only with overwhelming advantage."
  end

  defp generate_engagement_recommendation(:high) do
    "CAUTION - High threat. Ensure numerical superiority and proper intel."
  end

  defp generate_engagement_recommendation(:moderate) do
    "ASSESS - Moderate threat. Evaluate situation before engagement."
  end

  defp generate_engagement_recommendation(:low) do
    "STANDARD - Low threat. Normal engagement protocols apply."
  end

  defp generate_engagement_recommendation(:minimal) do
    "OPPORTUNITY - Minimal threat. Favorable engagement conditions."
  end

  defp determine_preferred_engagement(combat_data) do
    solo_ratio = combat_data[:solo_ratio] || 0
    small_gang_ratio = combat_data[:small_gang_ratio] || 0
    fleet_ratio = combat_data[:fleet_ratio] || 0

    cond do
      solo_ratio > 0.6 -> :solo
      small_gang_ratio > 0.5 -> :small_gang
      fleet_ratio > 0.5 -> :fleet
      true -> :mixed
    end
  end

  defp generate_overall_assessment(character_analysis, threat_assessment) do
    threat_level = threat_assessment.threat_level
    pilot_type = character_analysis.classifications.pilot_type
    skill_level = character_analysis.classifications.skill_level

    "#{String.capitalize(to_string(skill_level))} #{String.replace(to_string(pilot_type), "_", " ")} with #{to_string(threat_level)} threat level."
  end

  defp generate_detailed_engagement_recs(threat_assessment, performance_analysis) do
    base_rec = generate_engagement_recommendation(threat_assessment.threat_level)

    # Add performance-based modifications
    performance_modifiers = []

    performance_modifiers =
      if performance_analysis.core_metrics.solo_effectiveness > 70 do
        ["Avoid solo engagements" | performance_modifiers]
      else
        performance_modifiers
      end

    performance_modifiers =
      if performance_analysis.core_metrics.versatility_score > 80 do
        ["Expect tactical flexibility" | performance_modifiers]
      else
        performance_modifiers
      end

    %{
      primary_recommendation: base_rec,
      tactical_considerations: performance_modifiers
    }
  end

  defp generate_counter_strategies(character_analysis, threat_assessment) do
    strategies = []

    # Based on threat aspects
    strategies =
      if threat_assessment.aspect_scores.combat_effectiveness > 70 do
        ["Use numerical advantage", "Avoid direct confrontation" | strategies]
      else
        strategies
      end

    strategies =
      if threat_assessment.aspect_scores.operational_security > 70 do
        ["Use intelligence networks", "Predict patterns carefully" | strategies]
      else
        strategies
      end

    # Based on weaknesses
    strategies = character_analysis.weaknesses ++ strategies

    Enum.uniq(strategies)
  end

  defp assess_intelligence_value(character_analysis, threat_assessment) do
    # High-threat pilots are valuable intelligence targets
    base_value = threat_assessment.overall_score / 100

    # Add bonuses for interesting characteristics
    total_value =
      0
      |> add_elite_hunter_bonus(character_analysis.classifications.pilot_type)
      |> add_pattern_complexity_bonus(character_analysis.notable_patterns)
      |> Kernel.+(base_value)
      |> min(1.0)

    cond do
      total_value > 0.8 -> :very_high
      total_value > 0.6 -> :high
      total_value > 0.4 -> :medium
      total_value > 0.2 -> :low
      true -> :minimal
    end
  end

  defp add_elite_hunter_bonus(bonus, :elite_solo_hunter), do: bonus + 0.2
  defp add_elite_hunter_bonus(bonus, _pilot_type), do: bonus

  defp add_pattern_complexity_bonus(bonus, patterns) when length(patterns) > 3, do: bonus + 0.1
  defp add_pattern_complexity_bonus(bonus, _patterns), do: bonus

  defp assess_recruitment_potential(character_analysis, performance_analysis) do
    # Based on skill level and performance trends
    skill_score =
      case character_analysis.classifications.skill_level do
        :elite -> 1.0
        :veteran -> 0.8
        :experienced -> 0.6
        :intermediate -> 0.4
        :novice -> 0.2
      end

    improvement_score = performance_analysis.improvement_metrics.improvement_rate / 100

    total_score = (skill_score + improvement_score) / 2

    cond do
      total_score > 0.8 -> :excellent
      total_score > 0.6 -> :good
      total_score > 0.4 -> :moderate
      total_score > 0.2 -> :poor
      true -> :unsuitable
    end
  end

  defp extract_key_insights(character_analysis, threat_assessment) do
    []
    |> maybe_add_threat_insight(threat_assessment.overall_score)
    |> add_pattern_insights(character_analysis.notable_patterns)
    |> add_strength_insights(character_analysis.strengths)
    |> Enum.take(5)
  end

  defp maybe_add_threat_insight(insights, overall_score) when overall_score > 80 do
    ["Extremely dangerous opponent" | insights]
  end

  defp maybe_add_threat_insight(insights, _overall_score), do: insights

  defp add_pattern_insights(insights, patterns), do: patterns ++ insights

  defp add_strength_insights(insights, strengths), do: strengths ++ insights

  defp summarize_threat_level(threat_assessment) do
    %{
      level: threat_assessment.threat_level,
      score: threat_assessment.overall_score,
      primary_aspects:
        threat_assessment.aspect_scores
        |> Enum.sort_by(fn {_, score} -> score end, :desc)
        |> Enum.take(3)
        |> Enum.map(fn {aspect, _} -> aspect end)
    }
  end

  defp generate_tactical_notes(character_analysis) do
    []
    |> add_pilot_type_notes(character_analysis.classifications.pilot_type)
    |> add_engagement_style_notes(character_analysis.classifications.engagement_style)
  end

  defp add_pilot_type_notes(notes, pilot_type) do
    case pilot_type do
      :elite_solo_hunter -> ["Exceptionally dangerous in solo combat" | notes]
      :solo_specialist -> ["Prefers solo engagements" | notes]
      :fleet_pilot -> ["Operates primarily in fleets" | notes]
      :gang_specialist -> ["Small gang specialist" | notes]
      _ -> notes
    end
  end

  defp add_engagement_style_notes(notes, engagement_style) do
    case engagement_style do
      :hot_dropper -> ["Uses capital ships for surprise attacks" | notes]
      :gate_camper -> ["Camps gates and choke points" | notes]
      :roamer -> ["Roams across multiple systems" | notes]
      :home_defender -> ["Defends home territory" | notes]
      _ -> notes
    end
  end

  defp assess_data_confidence(character_analysis) do
    # Based on amount of data available
    total_activities =
      character_analysis.summary.total_kills + character_analysis.summary.total_losses

    cond do
      total_activities > 500 -> :very_high
      total_activities > 100 -> :high
      total_activities > 50 -> :medium
      total_activities > 10 -> :low
      true -> :very_low
    end
  end

  defp export_as_json(profile) do
    {:ok, Jason.encode!(profile, pretty: true)}
  end

  defp export_as_yaml(_profile) do
    # YamlElixir not available as dependency
    {:error, "YAML export not implemented - YamlElixir dependency not available"}
  end

  defp export_as_html(profile) do
    # Generate HTML report
    html = """
    <!DOCTYPE html>
    <html>
    <head>
        <title>Character Profile - #{profile.character_id}</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 20px; }
            .section { margin-bottom: 20px; }
            .header { background-color: #f0f0f0; padding: 10px; }
            .threat-critical { color: red; font-weight: bold; }
            .threat-high { color: orange; font-weight: bold; }
            .threat-moderate { color: yellow; }
            .threat-low { color: green; }
            .threat-minimal { color: lightgreen; }
        </style>
    </head>
    <body>
        <h1>Character Intelligence Profile</h1>
        <div class="section">
            <div class="header">Basic Information</div>
            <p><strong>Character ID:</strong> #{profile.character_id}</p>
            <p><strong>Generated:</strong> #{profile.generated_at}</p>
            <p><strong>Activity Level:</strong> #{profile.basic_info.activity_level}</p>
        </div>

        <div class="section">
            <div class="header">Threat Assessment</div>
            <p><strong>Threat Level:</strong> <span class="threat-#{profile.threat_profile.threat_level}">#{String.upcase(to_string(profile.threat_profile.threat_level))}</span></p>
            <p><strong>Threat Score:</strong> #{profile.threat_profile.overall_score}/100</p>
            <p><strong>Recommendation:</strong> #{profile.threat_profile.engagement_recommendation}</p>
        </div>

        <div class="section">
            <div class="header">Intelligence Summary</div>
            #{Enum.map_join(profile.intelligence_summary.key_insights, "", fn insight -> "<li>#{insight}</li>" end)}
        </div>
    </body>
    </html>
    """

    {:ok, html}
  end

  defp export_as_pdf(_profile) do
    # PDF generation would require additional dependencies
    {:error, :not_implemented}
  end

  defp prepare_profile_for_sharing(profile, options) do
    # Redact sensitive information if requested
    if Keyword.get(options, :redact_sensitive, true) do
      redact_sensitive_data(profile)
    else
      profile
    end

    # Filter sections if specified
    |> filter_sections(Keyword.get(options, :sections, :all))
  end

  defp redact_sensitive_data(profile) do
    # Remove or obscure sensitive information
    profile
    |> put_in([:strategic_assessment, :counter_strategies], ["[REDACTED]"])
    |> put_in([:intelligence_summary, :tactical_notes], ["[REDACTED]"])
  end

  defp filter_sections(profile, :all), do: profile

  defp filter_sections(profile, sections) when is_list(sections) do
    Map.take(profile, [:character_id, :generated_at] ++ sections)
  end

  defp generate_share_token do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  end

  defp calculate_expiry(options) do
    case Keyword.get(options, :expiry) do
      %DateTime{} = expiry ->
        expiry

      days when is_integer(days) ->
        DateTime.utc_now() |> DateTime.add(days * 24 * 60 * 60, :second)

      # Default 7 days
      _ ->
        DateTime.utc_now() |> DateTime.add(7 * 24 * 60 * 60, :second)
    end
  end

  defp build_share_url(token) do
    # In practice, would use proper URL generation
    "https://app.evedmv.com/shared/profiles/#{token}"
  end
end

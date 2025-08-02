defmodule EveDmv.Shared.Intelligence.ReportBuilder do
  @moduledoc """

  Builds comprehensive intelligence reports from fused intelligence data.

  This module is responsible for formatting and structuring intelligence
  into readable, actionable reports with appropriate metadata and assessments.
  """

  alias EveDmv.Core.Utils.DateTimeUtils

  require Logger

  @doc """
  Compiles a comprehensive intelligence report from fused intelligence.
  """
  def compile_intelligence_report(fused_intelligence, confidence_assessment, options \\ []) do
    report_format = Keyword.get(options, :format, :full)
    include_raw_data = Keyword.get(options, :include_raw_data, false)

    base_report = %{
      report_id: generate_report_id(),
      generated_at: DateTime.utc_now(),
      report_type: :intelligence_fusion,
      classification: determine_classification(fused_intelligence),
      executive_summary: build_executive_summary(fused_intelligence, confidence_assessment),
      key_findings: extract_key_findings(fused_intelligence),
      threat_assessment: format_threat_assessment(fused_intelligence.threat_assessment),
      activity_summary: format_activity_summary(fused_intelligence.activity_summary),
      correlations: format_correlations(fused_intelligence.correlations),
      recommendations: generate_recommendations(fused_intelligence),
      confidence_assessment: confidence_assessment,
      metadata: build_report_metadata(fused_intelligence)
    }

    final_report =
      if include_raw_data do
        Map.put(base_report, :raw_intelligence, fused_intelligence)
      else
        base_report
      end

    format_report(final_report, report_format)
  end

  @doc """
  Assesses the intelligence value of a report.
  """
  def assess_intelligence_value(intelligence_report, assessment_criteria \\ []) do
    timeliness_value = assess_timeliness_value(intelligence_report)
    relevance_value = assess_relevance_value(intelligence_report, assessment_criteria)
    actionability_value = assess_actionability_value(intelligence_report)
    uniqueness_value = assess_uniqueness_value(intelligence_report)

    overall_value =
      calculate_overall_value(%{
        timeliness: timeliness_value,
        relevance: relevance_value,
        actionability: actionability_value,
        uniqueness: uniqueness_value
      })

    %{
      overall_score: overall_value,
      value_components: %{
        timeliness: timeliness_value,
        relevance: relevance_value,
        actionability: actionability_value,
        uniqueness: uniqueness_value
      },
      value_classification: classify_intelligence_value(overall_value),
      priority: determine_report_priority(overall_value, intelligence_report)
    }
  end

  @doc """
  Formats a report for specific output requirements.
  """
  def format_for_output(report, output_type) do
    case output_type do
      :discord -> format_for_discord(report)
      :email -> format_for_email(report)
      :api -> format_for_api(report)
      :web -> format_for_web(report)
      _ -> report
    end
  end

  # Private functions

  defp generate_report_id do
    timestamp = :os.system_time(:millisecond)
    # Use UUID for unique report IDs instead of random numbers
    unique_id = :crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)
    "INT-#{timestamp}-#{unique_id}"
  end

  defp determine_classification(fused_intelligence) do
    threat_level = get_in(fused_intelligence, [:threat_assessment, :composite_threat_score]) || 0

    cond do
      threat_level > 0.8 -> :critical
      threat_level > 0.6 -> :high_priority
      threat_level > 0.4 -> :standard
      true -> :routine
    end
  end

  defp build_executive_summary(fused_intelligence, confidence_assessment) do
    %{
      summary_text: generate_summary_text(fused_intelligence),
      key_points: extract_summary_points(fused_intelligence),
      overall_assessment: generate_overall_assessment(fused_intelligence),
      confidence_level: confidence_assessment.confidence_level,
      recommended_actions: extract_top_recommendations(fused_intelligence, 3)
    }
  end

  defp generate_summary_text(fused_intelligence) do
    systems_analyzed = get_in(fused_intelligence, [:fused_intelligence, :systems]) || []
    total_events = get_in(fused_intelligence, [:activity_summary, :total_events]) || 0
    threat_level = get_in(fused_intelligence, [:threat_assessment, :composite_threat_score]) || 0

    threat_descriptor =
      case threat_level do
        n when n > 0.8 -> "critical"
        n when n > 0.6 -> "elevated"
        n when n > 0.4 -> "moderate"
        _ -> "low"
      end

    "Intelligence fusion analysis of #{length(systems_analyzed)} systems " <>
      "identified #{total_events} events with #{threat_descriptor} overall threat level. " <>
      "Analysis confidence is #{format_confidence(fused_intelligence.confidence_score)}."
  end

  defp format_confidence(score) when score >= 0.8, do: "high"
  defp format_confidence(score) when score >= 0.6, do: "moderate"
  defp format_confidence(_), do: "low"

  defp extract_summary_points(fused_intelligence) do
    points = []

    # Add threat points
    threat_points =
      case get_in(fused_intelligence, [:threat_assessment, :immediate_threats]) do
        threats when is_list(threats) and threats != [] ->
          ["#{length(threats)} immediate threats identified"]

        _ ->
          []
      end

    # Add activity points
    activity_points =
      case get_in(fused_intelligence, [:activity_summary, :activity_intensity]) do
        :high -> ["High activity intensity detected"]
        :very_high -> ["Very high activity intensity detected"]
        _ -> []
      end

    # Add correlation points
    correlation_points =
      case fused_intelligence.correlations do
        correlations when length(correlations) > 5 ->
          ["#{length(correlations)} significant correlations found"]

        _ ->
          []
      end

    points ++ threat_points ++ activity_points ++ correlation_points
  end

  defp generate_overall_assessment(fused_intelligence) do
    threat_score = get_in(fused_intelligence, [:threat_assessment, :composite_threat_score]) || 0

    activity_intensity =
      get_in(fused_intelligence, [:activity_summary, :activity_intensity]) || :low

    correlation_count = length(fused_intelligence.correlations)

    cond do
      threat_score > 0.8 && activity_intensity in [:high, :very_high] ->
        "Critical situation requiring immediate attention"

      threat_score > 0.6 ->
        "Elevated threat environment with significant activity"

      correlation_count > 10 ->
        "Complex situation with multiple correlated events"

      activity_intensity in [:high, :very_high] ->
        "High activity levels warrant close monitoring"

      true ->
        "Standard operational environment"
    end
  end

  defp extract_key_findings(fused_intelligence) do
    findings = []

    # System findings
    system_findings = extract_system_findings(fused_intelligence)

    # Threat findings
    threat_findings = extract_threat_findings(fused_intelligence)

    # Pattern findings
    pattern_findings = extract_pattern_findings(fused_intelligence)

    # Anomaly findings
    anomaly_findings = extract_anomaly_findings(fused_intelligence)

    (findings ++ system_findings ++ threat_findings ++ pattern_findings ++ anomaly_findings)
    # Limit to top 10 findings
    |> Enum.take(10)
  end

  defp extract_system_findings(fused_intelligence) do
    systems = get_in(fused_intelligence, [:fused_intelligence, :systems]) || []

    high_activity_systems =
      systems
      |> Enum.filter(&(&1.activity_level in [:high, :very_high]))
      |> Enum.map(fn system ->
        %{
          type: :system_activity,
          severity: :high,
          description: "System #{system.system_id} showing #{system.activity_level} activity",
          system_id: system.system_id,
          details: system
        }
      end)

    Enum.take(high_activity_systems, 3)
  end

  defp extract_threat_findings(fused_intelligence) do
    threats = get_in(fused_intelligence, [:threat_assessment, :identified_threats]) || []

    Enum.map(threats, fn threat ->
      %{
        type: :threat,
        severity: :critical,
        description: format_threat_description(threat),
        threat_data: threat
      }
    end)
  end

  defp format_threat_description(threat) do
    "Threat identified: #{Map.get(threat, :type, "Unknown")} - #{Map.get(threat, :description, "No description")}"
  end

  defp extract_pattern_findings(fused_intelligence) do
    patterns = get_in(fused_intelligence, [:fused_intelligence, :patterns]) || []

    Enum.map(patterns, fn pattern ->
      %{
        type: :pattern,
        severity: :medium,
        description: "Pattern detected: #{format_pattern(pattern)}",
        pattern_data: pattern
      }
    end)
  end

  defp format_pattern(_pattern) do
    "Activity pattern identified"
  end

  defp extract_anomaly_findings(fused_intelligence) do
    anomalies = get_in(fused_intelligence, [:activity_summary, :anomalies]) || []

    Enum.map(anomalies, fn anomaly ->
      %{
        type: :anomaly,
        severity: :high,
        description: "Anomaly detected: #{format_anomaly(anomaly)}",
        anomaly_data: anomaly
      }
    end)
  end

  defp format_anomaly(_anomaly) do
    "Unusual activity pattern"
  end

  defp format_threat_assessment(threat_assessment) do
    %{
      summary: %{
        overall_threat_level: threat_assessment.composite_threat_score,
        immediate_threat_count: length(threat_assessment.immediate_threats),
        emerging_threat_count: length(threat_assessment.emerging_threats)
      },
      immediate_threats: format_threats(threat_assessment.immediate_threats),
      emerging_threats: format_threats(threat_assessment.emerging_threats),
      threat_trends: threat_assessment.threat_trends,
      geographic_concentration: threat_assessment.threat_concentration
    }
  end

  defp format_threats(threats) do
    Enum.map(threats, fn threat ->
      %{
        id: Map.get(threat, :id, generate_threat_id()),
        type: Map.get(threat, :type, :unknown),
        severity: Map.get(threat, :severity, :medium),
        description: Map.get(threat, :description, "Unspecified threat"),
        recommended_response: Map.get(threat, :response, "Monitor closely")
      }
    end)
  end

  defp generate_threat_id do
    timestamp = :os.system_time(:microsecond)
    unique_id = :crypto.strong_rand_bytes(3) |> Base.encode16(case: :lower)
    "THREAT-#{timestamp}-#{unique_id}"
  end

  defp format_activity_summary(activity_summary) do
    %{
      total_events: activity_summary.total_events,
      event_breakdown: activity_summary.event_distribution,
      intensity: activity_summary.activity_intensity,
      key_findings: format_activity_findings(activity_summary.key_findings),
      anomalies: format_activity_anomalies(activity_summary.anomalies)
    }
  end

  defp format_activity_findings(findings) do
    Enum.map(findings, fn finding ->
      %{
        type: Map.get(finding, :type, :general),
        description: Map.get(finding, :description, "Activity finding"),
        impact: Map.get(finding, :impact, :low)
      }
    end)
  end

  defp format_activity_anomalies(anomalies) do
    Enum.map(anomalies, fn anomaly ->
      %{
        type: Map.get(anomaly, :type, :behavioral),
        description: Map.get(anomaly, :description, "Anomalous activity detected"),
        confidence: Map.get(anomaly, :confidence, 0.5)
      }
    end)
  end

  defp format_correlations(correlations) do
    correlations
    |> Enum.sort_by(& &1.correlation_strength, :desc)
    |> Enum.take(10)
    |> Enum.map(&format_single_correlation/1)
  end

  defp format_single_correlation(correlation) do
    %{
      type: correlation.type,
      strength: correlation.correlation_strength,
      description: generate_correlation_description(correlation),
      events: Enum.map(correlation.events, &summarize_event/1)
    }
  end

  defp generate_correlation_description(correlation) do
    case correlation.type do
      :temporal -> "Events occurred within #{correlation.time_difference} seconds"
      :entity -> "Events involve same entity"
      :geographic -> "Events in same or adjacent systems"
      _ -> "Correlated events detected"
    end
  end

  defp summarize_event(event) do
    %{
      timestamp: event.timestamp,
      source: event.source,
      type: Map.get(event, :type, :unknown),
      system_id: Map.get(event, :system_id)
    }
  end

  defp generate_recommendations(fused_intelligence) do
    recommendations = []

    # Threat-based recommendations
    threat_recommendations = generate_threat_recommendations(fused_intelligence.threat_assessment)

    # Activity-based recommendations
    activity_recommendations =
      generate_activity_recommendations(fused_intelligence.activity_summary)

    # Correlation-based recommendations
    correlation_recommendations =
      generate_correlation_recommendations(fused_intelligence.correlations)

    all_recommendations =
      recommendations ++
        threat_recommendations ++
        activity_recommendations ++ correlation_recommendations

    all_recommendations
    |> Enum.uniq_by(& &1.action)
    |> Enum.sort_by(& &1.priority, :desc)
    |> Enum.take(5)
  end

  defp generate_threat_recommendations(threat_assessment) do
    base_recs = []

    immediate_threat_recs =
      if Enum.empty?(threat_assessment.immediate_threats) do
        []
      else
        [
          %{
            action: "Deploy defensive fleet immediately",
            priority: :critical,
            reason: "Immediate threats detected",
            category: :defensive
          }
        ]
      end

    threat_level_recs =
      case threat_assessment.composite_threat_score do
        score when score > 0.8 ->
          [
            %{
              action: "Initiate emergency protocols",
              priority: :critical,
              reason: "Critical threat level detected",
              category: :defensive
            }
          ]

        score when score > 0.6 ->
          [
            %{
              action: "Increase defensive readiness",
              priority: :high,
              reason: "Elevated threat environment",
              category: :defensive
            }
          ]

        _ ->
          []
      end

    base_recs ++ immediate_threat_recs ++ threat_level_recs
  end

  defp generate_activity_recommendations(activity_summary) do
    case activity_summary.activity_intensity do
      intensity when intensity in [:high, :very_high] ->
        [
          %{
            action: "Deploy additional scouts",
            priority: :high,
            reason: "High activity levels require enhanced monitoring",
            category: :intelligence
          }
        ]

      _ ->
        []
    end
  end

  defp generate_correlation_recommendations(correlations) do
    if length(correlations) > 10 do
      [
        %{
          action: "Investigate correlated events for coordinated activity",
          priority: :medium,
          reason: "Multiple correlations suggest coordinated operations",
          category: :analysis
        }
      ]
    else
      []
    end
  end

  defp extract_top_recommendations(fused_intelligence, count) do
    generate_recommendations(fused_intelligence)
    |> Enum.take(count)
    |> Enum.map(& &1.action)
  end

  defp build_report_metadata(fused_intelligence) do
    %{
      fusion_metadata: fused_intelligence.fusion_metadata,
      report_version: "2.0",
      analysis_depth: classify_analysis_depth(fused_intelligence),
      data_sources_used: get_in(fused_intelligence, [:fusion_metadata, :sources_used]) || [],
      processing_notes: generate_processing_notes(fused_intelligence)
    }
  end

  defp classify_analysis_depth(fused_intelligence) do
    source_count = length(get_in(fused_intelligence, [:fusion_metadata, :sources_used]) || [])
    event_count = get_in(fused_intelligence, [:activity_summary, :total_events]) || 0

    cond do
      source_count >= 4 && event_count > 100 -> :comprehensive
      source_count >= 3 && event_count > 50 -> :detailed
      source_count >= 2 -> :standard
      true -> :limited
    end
  end

  defp generate_processing_notes(_fused_intelligence) do
    []
  end

  defp format_report(report, :full), do: report

  defp format_report(report, :summary) do
    Map.take(report, [
      :report_id,
      :generated_at,
      :classification,
      :executive_summary,
      :key_findings,
      :recommendations
    ])
  end

  defp format_report(report, :brief) do
    %{
      id: report.report_id,
      timestamp: report.generated_at,
      classification: report.classification,
      summary: get_in(report, [:executive_summary, :summary_text]),
      threat_level: get_in(report, [:threat_assessment, :summary, :overall_threat_level])
    }
  end

  defp assess_timeliness_value(report) do
    # Value decreases over time
    age_minutes = DateTimeUtils.diff(DateTime.utc_now(), report.generated_at, :minute)

    cond do
      age_minutes < 5 -> 1.0
      age_minutes < 30 -> 0.8
      age_minutes < 60 -> 0.6
      age_minutes < 180 -> 0.4
      true -> 0.2
    end
  end

  defp assess_relevance_value(_report, _criteria) do
    # In production, would check against specific criteria
    0.8
  end

  defp assess_actionability_value(report) do
    recommendation_count = length(report.recommendations)
    threat_count = get_in(report, [:threat_assessment, :summary, :immediate_threat_count]) || 0

    base_score = min(1.0, (recommendation_count + threat_count) / 10)

    # Boost for high classification
    classification_boost =
      case report.classification do
        :critical -> 0.3
        :high_priority -> 0.2
        :standard -> 0.1
        _ -> 0
      end

    min(1.0, base_score + classification_boost)
  end

  defp assess_uniqueness_value(_report) do
    # In production, would compare against recent reports
    0.7
  end

  defp calculate_overall_value(components) do
    weights = %{
      timeliness: 0.3,
      relevance: 0.3,
      actionability: 0.25,
      uniqueness: 0.15
    }

    weighted_sum =
      Enum.reduce(weights, 0.0, fn {component, weight}, acc ->
        value = Map.get(components, component, 0.0)
        acc + value * weight
      end)

    Float.round(weighted_sum, 2)
  end

  defp classify_intelligence_value(score) do
    cond do
      score >= 0.8 -> :high_value
      score >= 0.6 -> :moderate_value
      score >= 0.4 -> :low_value
      true -> :minimal_value
    end
  end

  defp determine_report_priority(value_score, report) do
    base_priority =
      cond do
        value_score >= 0.8 -> 1
        value_score >= 0.6 -> 2
        value_score >= 0.4 -> 3
        true -> 4
      end

    # Adjust for classification
    classification_adjustment =
      case report.classification do
        :critical -> -2
        :high_priority -> -1
        :standard -> 0
        :routine -> 1
      end

    max(1, min(5, base_priority + classification_adjustment))
  end

  defp format_for_discord(report) do
    %{
      embeds: [
        %{
          title: "Intelligence Report #{report.report_id}",
          description: get_in(report, [:executive_summary, :summary_text]),
          color: get_discord_color(report.classification),
          fields: build_discord_fields(report),
          timestamp: report.generated_at
        }
      ]
    }
  end

  defp get_discord_color(:critical), do: 0xFF0000
  defp get_discord_color(:high_priority), do: 0xFF8800
  defp get_discord_color(:standard), do: 0x0088FF
  defp get_discord_color(:routine), do: 0x00FF00

  defp build_discord_fields(report) do
    [
      %{
        name: "Classification",
        value: to_string(report.classification),
        inline: true
      },
      %{
        name: "Threat Level",
        value: format_threat_level_for_discord(report),
        inline: true
      },
      %{
        name: "Key Findings",
        value: format_findings_for_discord(report.key_findings),
        inline: false
      },
      %{
        name: "Recommendations",
        value: format_recommendations_for_discord(report.recommendations),
        inline: false
      }
    ]
  end

  defp format_threat_level_for_discord(report) do
    threat_level = get_in(report, [:threat_assessment, :summary, :overall_threat_level]) || 0
    "#{Float.round(threat_level * 100, 1)}%"
  end

  defp format_findings_for_discord(findings) do
    findings
    |> Enum.take(3)
    |> Enum.map_join("\n", &"• #{&1.description}")
  end

  defp format_recommendations_for_discord(recommendations) do
    recommendations
    |> Enum.take(3)
    |> Enum.map_join("\n", &"• #{&1.action}")
  end

  defp format_for_email(report), do: report
  defp format_for_api(report), do: report
  defp format_for_web(report), do: report
end

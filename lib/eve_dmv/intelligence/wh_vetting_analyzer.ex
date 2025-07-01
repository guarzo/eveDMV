defmodule EveDmv.Intelligence.WHVettingAnalyzer do
  @moduledoc """
  Comprehensive vetting analysis for wormhole corporation recruitment.

  Provides deep analysis of potential recruits including J-space experience,
  security risk assessment, eviction group detection, and alt character analysis.
  """

  require Logger

  alias EveDmv.Api
  alias EveDmv.Intelligence.{CharacterStats, WHVetting}
  alias EveDmv.Killmails.{KillmailEnriched, Participant}

  @doc """
  Perform comprehensive vetting analysis for a character.

  Returns {:ok, vetting_record} or {:error, reason}
  """
  def analyze_character(character_id, requested_by_id \\ nil) do
    Logger.info("Starting WH vetting analysis for character #{character_id}")

    with {:ok, character_info} <- get_character_info(character_id),
         {:ok, j_space_activity} <- analyze_j_space_activity(character_id),
         {:ok, eviction_associations} <- analyze_eviction_associations(character_id),
         {:ok, alt_analysis} <- analyze_alt_patterns(character_id),
         {:ok, competency_metrics} <- analyze_small_gang_competency(character_id),
         {:ok, risk_factors} <- analyze_risk_factors(character_id),
         {:ok, employment_history} <- analyze_employment_history(character_id) do
      scores =
        calculate_scores(
          j_space_activity,
          eviction_associations,
          alt_analysis,
          competency_metrics,
          risk_factors,
          employment_history
        )

      recommendation = generate_recommendation(scores, risk_factors)
      auto_summary = generate_auto_summary(character_info, scores, risk_factors)

      vetting_data = %{
        character_id: character_id,
        character_name: character_info.character_name,
        corporation_id: character_info.corporation_id,
        corporation_name: character_info.corporation_name,
        alliance_id: character_info.alliance_id,
        alliance_name: character_info.alliance_name,
        vetting_requested_by: requested_by_id,
        overall_risk_score: scores.overall_risk_score,
        wh_experience_score: scores.wh_experience_score,
        competency_score: scores.competency_score,
        security_score: scores.security_score,
        j_space_activity: j_space_activity,
        eviction_associations: eviction_associations,
        alt_analysis: alt_analysis,
        competency_metrics: competency_metrics,
        risk_factors: risk_factors,
        employment_history: employment_history,
        recommendation: recommendation.decision,
        recommendation_confidence: recommendation.confidence,
        auto_generated_summary: auto_summary,
        requires_manual_review: recommendation.requires_manual_review,
        data_completeness_percent:
          calculate_data_completeness([
            j_space_activity,
            eviction_associations,
            alt_analysis,
            competency_metrics
          ]),
        status: "complete"
      }

      # Create or update vetting record
      case WHVetting.get_by_character(character_id) do
        {:ok, [existing]} ->
          WHVetting.update_analysis(existing, vetting_data)

        {:ok, []} ->
          WHVetting.create(vetting_data)

        {:error, _} ->
          WHVetting.create(vetting_data)
      end
    else
      {:error, reason} ->
        Logger.error(
          "WH vetting analysis failed for character #{character_id}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  # Character information retrieval
  defp get_character_info(character_id) do
    # For now, use a placeholder implementation
    # In production this would integrate with ESI
    character_stats = get_or_create_character_stats(character_id)

    {:ok,
     %{
       character_name: character_stats.character_name || "Character #{character_id}",
       corporation_id: character_stats.corporation_id,
       corporation_name: character_stats.corporation_name,
       alliance_id: character_stats.alliance_id,
       alliance_name: character_stats.alliance_name
     }}
  end

  # J-space activity analysis
  defp analyze_j_space_activity(character_id) do
    # Get killmails in J-space (security < 0.0 typically indicates wormhole space)
    j_space_kills = get_j_space_killmails(character_id, :kills)
    j_space_losses = get_j_space_killmails(character_id, :losses)

    total_kills = get_total_killmails(character_id, :kills)
    total_losses = get_total_killmails(character_id, :losses)

    j_space_time_percent =
      calculate_j_space_time_percentage(
        j_space_kills ++ j_space_losses,
        total_kills + total_losses
      )

    wh_classes_active = extract_wh_classes(j_space_kills ++ j_space_losses)
    home_holes = identify_home_holes(j_space_kills ++ j_space_losses)

    rolling_participation = analyze_rolling_patterns(character_id)
    scanning_skills = analyze_scanning_patterns(j_space_kills ++ j_space_losses)

    activity = %{
      "total_j_kills" => length(j_space_kills),
      "total_j_losses" => length(j_space_losses),
      "j_space_time_percent" => j_space_time_percent,
      "wh_classes_active" => wh_classes_active,
      "home_holes" => home_holes,
      "rolling_participation" => rolling_participation,
      "wh_scanning_skills" => scanning_skills
    }

    {:ok, activity}
  end

  # Eviction group detection
  defp analyze_eviction_associations(character_id) do
    # Known eviction groups (this would be configurable in a real system)
    known_eviction_groups = [
      "Hard Knocks Citizens",
      "Lazerhawks",
      "No Holes Barred",
      "Mouth Trumpet Cavalry",
      "Inner Hell"
    ]

    eviction_participation = analyze_eviction_participation(character_id, known_eviction_groups)
    seed_scout_indicators = analyze_seed_scout_patterns(character_id)

    associations = %{
      "known_eviction_groups" =>
        find_eviction_group_connections(character_id, known_eviction_groups),
      "eviction_participation" => eviction_participation,
      "seed_scout_indicators" => seed_scout_indicators
    }

    {:ok, associations}
  end

  # Alt character analysis
  defp analyze_alt_patterns(character_id) do
    potential_alts = find_potential_alts(character_id)
    character_bazaar_indicators = analyze_character_bazaar_signs(character_id)

    # Get character creation date and age
    account_age = calculate_account_age(character_id)
    main_confidence = assess_main_character_confidence(character_id, potential_alts)

    analysis = %{
      "potential_alts" => potential_alts,
      "main_character_confidence" => main_confidence,
      "account_age_days" => account_age,
      "character_bazaar_indicators" => character_bazaar_indicators
    }

    {:ok, analysis}
  end

  # Small gang competency analysis
  defp analyze_small_gang_competency(character_id) do
    gang_performance = analyze_small_gang_performance(character_id)
    ship_specializations = analyze_ship_specializations(character_id)
    wh_specific_skills = assess_wh_skills(character_id)

    competency = %{
      "small_gang_performance" => gang_performance,
      "ship_specializations" => ship_specializations,
      "wh_specific_skills" => wh_specific_skills
    }

    {:ok, competency}
  end

  # Risk factor analysis
  defp analyze_risk_factors(character_id) do
    security_flags = identify_security_flags(character_id)
    behavioral_flags = identify_behavioral_red_flags(character_id)
    awox_risk = assess_awox_risk(character_id, security_flags, behavioral_flags)
    spy_risk = assess_spy_risk(character_id, security_flags, behavioral_flags)

    risks = %{
      "security_flags" => security_flags,
      "behavioral_red_flags" => behavioral_flags,
      "awox_risk" => awox_risk,
      "spy_risk" => spy_risk
    }

    {:ok, risks}
  end

  # Employment history analysis
  defp analyze_employment_history(_character_id) do
    # This would integrate with ESI to get employment history
    # For now, we'll use placeholder data
    history = %{
      "corp_changes" => 3,
      "avg_tenure_days" => 245,
      "suspicious_patterns" => [],
      "history" => []
    }

    {:ok, history}
  end

  # Helper functions for specific analyses
  defp get_j_space_killmails(character_id, type) do
    # J-space systems typically have negative security or are in specific regions
    # This is a simplified implementation
    case Ash.read(KillmailEnriched, domain: Api) do
      {:ok, killmails} ->
        case type do
          :kills ->
            Enum.filter(killmails, fn km ->
              has_character_participation?(km, character_id, :attacker) and
                j_space_system?(km.system_id)
            end)

          :losses ->
            Enum.filter(killmails, fn km ->
              has_character_participation?(km, character_id, :victim) and
                j_space_system?(km.system_id)
            end)
        end

      {:error, _} ->
        []
    end
  rescue
    _ -> []
  end

  defp get_total_killmails(character_id, type) do
    case Ash.read(KillmailEnriched, domain: Api) do
      {:ok, killmails} ->
        case type do
          :kills ->
            Enum.count(killmails, fn km ->
              has_character_participation?(km, character_id, :attacker)
            end)

          :losses ->
            Enum.count(killmails, fn km ->
              has_character_participation?(km, character_id, :victim)
            end)
        end

      {:error, _} ->
        0
    end
  rescue
    _ -> 0
  end

  defp has_character_participation?(killmail, character_id, role) do
    case Ash.read(Participant, domain: Api) do
      {:ok, participants} ->
        relevant_participants =
          Enum.filter(participants, fn p -> p.killmail_id == killmail.killmail_id end)

        Enum.any?(relevant_participants, fn p ->
          p.character_id == character_id and
            ((role == :attacker and not p.is_victim) or (role == :victim and p.is_victim))
        end)

      {:error, _} ->
        false
    end
  rescue
    _ -> false
  end

  defp j_space_system?(system_id) do
    # Wormhole systems typically have IDs in the 31000000+ range
    # This is a simplified check - in production you'd check against static data
    system_id >= 31_000_000
  end

  defp calculate_j_space_time_percentage(j_space_kms, total_kms) do
    if total_kms > 0 do
      Float.round(length(j_space_kms) / total_kms * 100, 1)
    else
      0.0
    end
  end

  defp extract_wh_classes(_killmails) do
    # Extract wormhole classes from system data
    # Placeholder implementation
    [1, 2, 3, 4, 5]
  end

  defp identify_home_holes(_killmails) do
    # Identify likely home wormhole systems
    # Placeholder implementation
    []
  end

  defp analyze_rolling_patterns(_character_id) do
    # Analyze participation in wormhole rolling activities
    %{
      "times_rolled" => 0,
      "times_helped_roll" => 0,
      "rolling_competency" => 0.0
    }
  end

  defp analyze_scanning_patterns(_killmails) do
    # Analyze probe usage and scanning competency
    %{
      "probe_usage" => 0,
      "scan_success_rate" => 0.0,
      "deep_safe_usage" => false
    }
  end

  defp find_eviction_group_connections(_character_id, _known_groups) do
    # Check for connections to known eviction groups
    []
  end

  defp analyze_eviction_participation(_character_id, _known_groups) do
    %{
      "evictions_involved" => 0,
      "victim_corps" => [],
      "typical_role" => "unknown"
    }
  end

  defp analyze_seed_scout_patterns(_character_id) do
    %{
      "suspicious_applications" => 0,
      "timing_patterns" => [],
      "information_gathering" => false
    }
  end

  defp find_potential_alts(_character_id) do
    []
  end

  defp analyze_character_bazaar_signs(_character_id) do
    %{
      "likely_purchased" => false,
      "skill_inconsistencies" => [],
      "name_history" => []
    }
  end

  defp calculate_account_age(_character_id) do
    # Calculate days since character creation
    # Placeholder - would use ESI data
    365
  end

  defp assess_main_character_confidence(_character_id, _potential_alts) do
    0.8
  end

  defp analyze_small_gang_performance(character_id) do
    case get_or_create_character_stats(character_id) do
      stats ->
        %{
          "avg_gang_size" => stats.avg_gang_size || 1.0,
          "preferred_size" => determine_preferred_gang_size(stats.avg_gang_size || 1.0),
          # Would be determined from ship usage
          "role_flexibility" => ["dps"],
          "fc_experience" => %{"times_fc" => 0, "success_rate" => 0.0}
        }
    end
  end

  defp determine_preferred_gang_size(avg_size) do
    cond do
      avg_size <= 1.5 -> "solo"
      avg_size <= 3.0 -> "2-3"
      avg_size <= 8.0 -> "small_gang"
      avg_size <= 15.0 -> "medium_gang"
      true -> "large_gang"
    end
  end

  defp analyze_ship_specializations(character_id) do
    stats = get_or_create_character_stats(character_id)

    primary_classes = extract_primary_ship_classes(stats.ship_usage || %{})

    %{
      "primary_classes" => primary_classes,
      "doctrine_familiarity" => ["unknown"],
      "capital_experience" => stats.flies_capitals || false
    }
  end

  defp extract_primary_ship_classes(_ship_usage) do
    # Analyze ship usage to determine primary classes
    # Placeholder implementation
    ["frigates"]
  end

  defp assess_wh_skills(_character_id) do
    # Would integrate with ESI to check actual skills
    %{
      "probe_scanning" => 0,
      "cloaking" => 0,
      "covops" => 0,
      "t3_cruisers" => 0
    }
  end

  defp identify_security_flags(_character_id) do
    []
  end

  defp identify_behavioral_red_flags(_character_id) do
    []
  end

  defp assess_awox_risk(_character_id, _security_flags, _behavioral_flags) do
    %{
      "probability" => 0.1,
      "indicators" => [],
      "mitigations" => ["limited_roles", "probation_period"]
    }
  end

  defp assess_spy_risk(_character_id, _security_flags, _behavioral_flags) do
    %{
      "probability" => 0.15,
      "indicators" => [],
      "mitigations" => ["information_compartmentalization"]
    }
  end

  # Scoring calculations
  defp calculate_scores(
         j_space_activity,
         eviction_associations,
         alt_analysis,
         competency_metrics,
         risk_factors,
         employment_history
       ) do
    wh_experience_score = calculate_wh_experience_score(j_space_activity, employment_history)
    competency_score = calculate_competency_score(competency_metrics, j_space_activity)
    security_score = calculate_security_score(risk_factors, eviction_associations, alt_analysis)

    overall_risk_score =
      calculate_overall_risk_score(security_score, wh_experience_score, competency_score)

    %{
      wh_experience_score: wh_experience_score,
      competency_score: competency_score,
      security_score: security_score,
      overall_risk_score: overall_risk_score
    }
  end

  defp calculate_wh_experience_score(j_space_activity, _employment_history) do
    j_kills = j_space_activity["total_j_kills"] || 0
    j_losses = j_space_activity["total_j_losses"] || 0
    j_time_percent = j_space_activity["j_space_time_percent"] || 0.0
    wh_classes = length(j_space_activity["wh_classes_active"] || [])

    base_score = min(90, j_kills * 2 + j_losses)
    time_bonus = min(20, j_time_percent / 5)
    class_bonus = min(15, wh_classes * 3)

    round(base_score + time_bonus + class_bonus)
  end

  defp calculate_competency_score(competency_metrics, j_space_activity) do
    gang_perf = competency_metrics["small_gang_performance"] || %{}
    ship_specs = competency_metrics["ship_specializations"] || %{}
    wh_skills = competency_metrics["wh_specific_skills"] || %{}

    avg_gang_size = gang_perf["avg_gang_size"] || 1.0
    primary_classes = length(ship_specs["primary_classes"] || [])
    skill_levels = Enum.sum(Map.values(wh_skills))

    # Small gang focused scoring
    gang_score =
      cond do
        avg_gang_size >= 2.0 and avg_gang_size <= 8.0 -> 30
        avg_gang_size > 1.0 -> 20
        true -> 10
      end

    ship_score = min(25, primary_classes * 8)
    skill_score = min(25, skill_levels * 3)
    activity_score = min(20, (j_space_activity["total_j_kills"] || 0) / 5)

    round(gang_score + ship_score + skill_score + activity_score)
  end

  defp calculate_security_score(risk_factors, eviction_associations, alt_analysis) do
    security_flags = length(risk_factors["security_flags"] || [])
    behavioral_flags = length(risk_factors["behavioral_red_flags"] || [])
    eviction_groups = length(eviction_associations["known_eviction_groups"] || [])
    awox_risk = risk_factors["awox_risk"]["probability"] || 0.1
    spy_risk = risk_factors["spy_risk"]["probability"] || 0.1
    main_confidence = alt_analysis["main_character_confidence"] || 0.8

    base_score = 100
    penalty = security_flags * 15 + behavioral_flags * 10 + eviction_groups * 20
    risk_penalty = (awox_risk + spy_risk) * 50
    alt_penalty = (1.0 - main_confidence) * 30

    max(0, round(base_score - penalty - risk_penalty - alt_penalty))
  end

  defp calculate_overall_risk_score(security_score, wh_experience_score, competency_score) do
    # Lower risk score is better
    base_risk = 100 - security_score
    experience_reduction = wh_experience_score / 5
    competency_reduction = competency_score / 10

    max(0, round(base_risk - experience_reduction - competency_reduction))
  end

  # Recommendation generation
  defp generate_recommendation(scores, _risk_factors) do
    %{
      overall_risk_score: risk,
      wh_experience_score: exp,
      competency_score: comp,
      security_score: sec
    } = scores

    cond do
      sec < 40 or risk > 80 ->
        %{decision: "reject", confidence: 0.9, requires_manual_review: false}

      exp > 70 and comp > 60 and sec > 70 ->
        %{decision: "approve", confidence: 0.8, requires_manual_review: false}

      exp > 40 and comp > 40 and sec > 60 ->
        %{decision: "conditional", confidence: 0.7, requires_manual_review: true}

      true ->
        %{decision: "more_info", confidence: 0.5, requires_manual_review: true}
    end
  end

  defp generate_auto_summary(character_info, scores, _risk_factors) do
    experience_level =
      case scores.wh_experience_score do
        score when score >= 70 -> "experienced"
        score when score >= 40 -> "competent"
        score when score >= 20 -> "novice"
        _ -> "minimal"
      end

    risk_level =
      case scores.overall_risk_score do
        score when score >= 70 -> "high"
        score when score >= 40 -> "medium"
        _ -> "low"
      end

    "#{character_info.character_name} shows #{experience_level} wormhole experience with #{risk_level} security risk. " <>
      "WH Experience: #{scores.wh_experience_score}/100, Competency: #{scores.competency_score}/100, " <>
      "Security: #{scores.security_score}/100."
  end

  defp calculate_data_completeness(data_sections) do
    # Calculate percentage of data sections that have meaningful content
    non_empty_sections =
      Enum.count(data_sections, fn section ->
        case section do
          map when is_map(map) -> map_size(map) > 0
          _ -> false
        end
      end)

    round(non_empty_sections / length(data_sections) * 100)
  end

  defp get_or_create_character_stats(character_id) do
    case CharacterStats.get_by_character_id(character_id) do
      {:ok, [stats]} ->
        stats

      _ ->
        # Create basic stats if none exist
        %CharacterStats{
          character_id: character_id,
          character_name: "Unknown",
          total_kills: 0,
          total_losses: 0,
          avg_gang_size: 1.0,
          ship_usage: %{},
          flies_capitals: false
        }
    end
  end
end

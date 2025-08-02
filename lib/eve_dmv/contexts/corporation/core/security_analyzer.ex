defmodule EveDmv.Contexts.Corporation.Core.SecurityAnalyzer do
  @moduledoc """
  Analyzes corporation security aspects including member vetting,
  infiltration risks, and operational security.

  Provides comprehensive security analysis for corporation management
  to identify potential threats and security vulnerabilities.
  """

  alias EveDmv.Contexts.Corporation.Core.MemberActivityAnalyzer
  alias EveDmv.Contexts.Corporation.Core.MemberRiskAssessment
  alias EveDmv.Core.Utils.DateTimeUtils
  alias EveDmv.Database.CharacterRepository
  alias EveDmv.Platform.Cache.Corporation.CorporationCache
  alias EveDmv.Platform.Database.CorporationRepository

  require Logger

  @cache_ttl :timer.hours(4)

  @doc """
  Perform comprehensive security analysis for a corporation.
  """
  def analyze_corporation_security(corporation_id) do
    cache_key = {:security_analysis, corporation_id}

    case CorporationCache.get(cache_key) do
      nil ->
        result = perform_security_analysis(corporation_id)

        if match?({:ok, _}, result) do
          {:ok, analysis} = result
          CorporationCache.put(cache_key, analysis, ttl: @cache_ttl)
        end

        result

      cached_result ->
        {:ok, cached_result}
    end
  end

  @doc """
  Vet a specific member for security concerns.
  """
  def vet_member(character_id, corporation_id) do
    with {:ok, character_data} <- get_character_security_data(character_id),
         {:ok, vetting_results} <- perform_member_vetting(character_data, corporation_id) do
      {:ok, vetting_results}
    end
  end

  @doc """
  Analyze infiltration risks for the corporation.
  """
  def analyze_infiltration_risks(corporation_id) do
    case analyze_corporation_security(corporation_id) do
      {:ok, analysis} -> {:ok, analysis.infiltration_risk_assessment}
      error -> error
    end
  end

  @doc """
  Get security recommendations for the corporation.
  """
  def get_security_recommendations(corporation_id) do
    case analyze_corporation_security(corporation_id) do
      {:ok, analysis} -> {:ok, analysis.security_recommendations}
      error -> error
    end
  end

  # Private Functions

  defp perform_security_analysis(corporation_id) do
    Logger.info("Performing security analysis for corporation #{corporation_id}")

    with {:ok, members} <- CorporationRepository.get_corporation_members(corporation_id),
         {:ok, activity_analysis} <-
           MemberActivityAnalyzer.analyze_member_activity(corporation_id),
         {:ok, risk_assessment} <- MemberRiskAssessment.assess_member_risks(corporation_id),
         {:ok, security_risks} <-
           analyze_security_risks(members, activity_analysis, risk_assessment) do
      analysis = %{
        corporation_id: corporation_id,
        total_members: length(members),
        security_score: calculate_security_score(security_risks),
        infiltration_risk_assessment: security_risks.infiltration_risks,
        operational_security: assess_operational_security(members, activity_analysis),
        member_vetting_status: analyze_member_vetting_status(members),
        suspicious_patterns: identify_suspicious_patterns(members, activity_analysis),
        security_vulnerabilities: identify_security_vulnerabilities(security_risks),
        threat_indicators: compile_threat_indicators(security_risks, activity_analysis),
        security_recommendations: generate_security_recommendations(security_risks),
        analyzed_at: DateTime.utc_now()
      }

      {:ok, analysis}
    end
  end

  defp analyze_security_risks(members, activity_analysis, risk_assessment) do
    # Analyze various security risk factors

    infiltration_risks = analyze_infiltration_risk_factors(members, activity_analysis)
    awox_risks = analyze_awox_risks(members, risk_assessment)
    spy_indicators = identify_potential_spies(members, activity_analysis)

    security_risks = %{
      infiltration_risks: infiltration_risks,
      awox_risk_assessment: awox_risks,
      spy_indicators: spy_indicators,
      overall_risk_level:
        determine_overall_security_risk(infiltration_risks, awox_risks, spy_indicators)
    }

    {:ok, security_risks}
  end

  defp analyze_infiltration_risk_factors(members, activity_analysis) do
    # Analyze factors that indicate infiltration risk

    # New members (joined in last 30 days)
    recent_cutoff = DateTime.utc_now() |> DateTimeUtils.add(-30 * 24 * 60 * 60, :second)

    new_members =
      Enum.filter(members, fn member ->
        member.join_date && DateTimeUtils.compare(member.join_date, recent_cutoff) == :gt
      end)

    # Members with low activity but present
    member_metrics = activity_analysis.member_metrics || []

    low_activity_members =
      Enum.filter(member_metrics, fn metric ->
        metric.activity_score < 20 && metric.last_seen &&
          DateTimeUtils.diff(DateTime.utc_now(), metric.last_seen, :day) < 7
      end)

    # Members with suspicious activity patterns
    suspicious_members = identify_suspicious_activity_patterns(member_metrics)

    %{
      new_member_ratio: Float.round(length(new_members) / max(length(members), 1) * 100, 1),
      low_activity_count: length(low_activity_members),
      suspicious_pattern_count: length(suspicious_members),
      risk_level:
        assess_infiltration_risk_level(new_members, low_activity_members, suspicious_members),
      high_risk_members:
        compile_high_risk_members(new_members, low_activity_members, suspicious_members)
    }
  end

  defp identify_suspicious_activity_patterns(member_metrics) do
    # Identify members with suspicious patterns
    member_metrics
    |> Enum.filter(fn metric ->
      # Very low killmail participation but online
      has_low_participation = metric.total_killmails < 3

      # Irregular activity patterns
      has_irregular_patterns = metric.consistency_score < 20

      # Only losses, no kills (potential feeder)
      only_losses = metric.recent_kills == 0 && metric.recent_losses > 5

      has_low_participation || has_irregular_patterns || only_losses
    end)
  end

  defp assess_infiltration_risk_level(new_members, low_activity_members, suspicious_members) do
    base_risk_score = 0

    # High ratio of new members
    # Normalized
    new_member_ratio = length(new_members) / 100
    new_member_risk = base_risk_score + new_member_ratio * 30

    # Low activity members present
    low_activity_score = min(length(low_activity_members) * 5, 30)
    low_activity_risk = new_member_risk + low_activity_score

    # Suspicious patterns
    suspicious_score = min(length(suspicious_members) * 10, 40)
    final_risk_score = low_activity_risk + suspicious_score

    cond do
      final_risk_score >= 70 -> :critical
      final_risk_score >= 50 -> :high
      final_risk_score >= 30 -> :moderate
      final_risk_score >= 15 -> :low
      true -> :minimal
    end
  end

  defp compile_high_risk_members(new_members, low_activity_members, _suspicious_members) do
    # Combine and deduplicate high-risk members

    # Add new members with risk flags
    new_member_risks =
      Enum.map(new_members, fn member ->
        %{
          character_id: member.character_id,
          character_name: member.character_name,
          risk_factors: ["New member (joined #{days_since_join(member.join_date)} days ago)"],
          risk_score: 40
        }
      end)

    # Add low activity members
    low_activity_risks =
      Enum.map(low_activity_members, fn metric ->
        %{
          character_id: metric.character_id,
          character_name: metric.character_name,
          risk_factors: ["Low activity score (#{metric.activity_score})"],
          risk_score: 50
        }
      end)

    # Merge and deduplicate
    (new_member_risks ++ low_activity_risks)
    |> Enum.group_by(& &1.character_id)
    |> Enum.map(fn {char_id, risks} ->
      combined_factors = risks |> Enum.flat_map(& &1.risk_factors) |> Enum.uniq()
      max_score = risks |> Enum.map(& &1.risk_score) |> Enum.max()

      %{
        character_id: char_id,
        character_name: List.first(risks).character_name,
        risk_factors: combined_factors,
        risk_score: max_score
      }
    end)
    |> Enum.sort_by(& &1.risk_score, :desc)
    |> Enum.take(10)
  end

  defp days_since_join(nil), do: "unknown"

  defp days_since_join(join_date) do
    DateTimeUtils.diff(DateTime.utc_now(), join_date, :day)
  end

  defp analyze_awox_risks(_members, risk_assessment) do
    # Analyze AWOX (Awful Wardecking) risks - members who might attack friendlies
    flight_risks = risk_assessment.flight_risks || []

    # Members with concerning patterns
    potential_awoxers =
      flight_risks
      |> Enum.filter(fn member ->
        # High risk members with specific patterns
        member.risk_score > 70 ||
          Enum.any?(member.risk_indicators, &String.contains?(&1, "Poor combat performance"))
      end)
      |> Enum.map(fn member ->
        %{
          character_id: member.character_id,
          character_name: member.character_name,
          awox_risk_score: calculate_awox_risk_score(member),
          risk_indicators: member.risk_indicators,
          recommended_monitoring: determine_monitoring_level(member.risk_score)
        }
      end)

    %{
      potential_awoxers: potential_awoxers,
      awox_risk_level: determine_awox_risk_level(potential_awoxers),
      monitoring_required: length(potential_awoxers)
    }
  end

  defp calculate_awox_risk_score(member) do
    # Base from general risk
    base_score = member.risk_score * 0.5

    # Additional factors for AWOX risk
    performance_penalty =
      if Enum.any?(member.risk_indicators, &String.contains?(&1, "Poor combat")) do
        20
      else
        0
      end

    new_member_penalty =
      if Enum.any?(member.risk_indicators, &String.contains?(&1, "new member")) do
        15
      else
        0
      end

    Float.round(base_score + performance_penalty + new_member_penalty, 1)
  end

  defp determine_monitoring_level(risk_score) do
    cond do
      risk_score >= 80 -> :continuous_monitoring
      risk_score >= 60 -> :frequent_monitoring
      risk_score >= 40 -> :regular_monitoring
      true -> :periodic_checks
    end
  end

  defp determine_awox_risk_level(potential_awoxers) do
    if Enum.empty?(potential_awoxers) do
      :minimal
    else
      max_risk =
        potential_awoxers
        |> Enum.map(& &1.awox_risk_score)
        |> Enum.max()

      cond do
        max_risk >= 80 -> :critical
        max_risk >= 60 -> :high
        max_risk >= 40 -> :moderate
        true -> :low
      end
    end
  end

  defp identify_potential_spies(_members, activity_analysis) do
    # Identify members who might be gathering intelligence
    member_metrics = activity_analysis.member_metrics || []

    spy_indicators =
      member_metrics
      |> Enum.map(fn metric ->
        indicators = []

        # Low combat participation but active
        indicators =
          if metric.total_killmails < 5 && metric.last_seen &&
               DateTimeUtils.diff(DateTime.utc_now(), metric.last_seen, :day) < 7 do
            ["Active but minimal combat participation" | indicators]
          else
            indicators
          end

        # Solo player in corp environment
        indicators =
          if metric.gang_participation.solo_ratio > 0.9 do
            ["Exclusively solo activity" | indicators]
          else
            indicators
          end

        # Irregular timezone activity
        indicators =
          if length(metric.peak_activity_hours) > 0 &&
               unusual_timezone_pattern?(metric.peak_activity_hours) do
            ["Unusual timezone patterns" | indicators]
          else
            indicators
          end

        if Enum.empty?(indicators) do
          nil
        else
          %{
            character_id: metric.character_id,
            character_name: metric.character_name,
            spy_indicators: indicators,
            suspicion_level: calculate_suspicion_level(indicators)
          }
        end
      end)
      |> Enum.filter(& &1)

    %{
      potential_spies: spy_indicators,
      spy_risk_level: assess_spy_risk_level(spy_indicators)
    }
  end

  defp unusual_timezone_pattern?(peak_hours) do
    # Check if activity pattern suggests monitoring rather than playing
    # e.g., brief logins at regular intervals
    # Only active in one hour
    # Regular interval checks
    length(peak_hours) == 1 ||
      (length(peak_hours) > 0 && Enum.all?(peak_hours, &(&1 in [0, 6, 12, 18])))
  end

  defp calculate_suspicion_level(indicators) do
    case length(indicators) do
      n when n >= 3 -> :high
      2 -> :moderate
      1 -> :low
      _ -> :minimal
    end
  end

  defp assess_spy_risk_level(spy_indicators) do
    high_suspicion_count = Enum.count(spy_indicators, &(&1.suspicion_level == :high))

    cond do
      high_suspicion_count >= 3 -> :high
      high_suspicion_count >= 1 -> :moderate
      length(spy_indicators) > 0 -> :low
      true -> :minimal
    end
  end

  defp determine_overall_security_risk(infiltration_risks, awox_risks, spy_indicators) do
    # Combine all risk factors
    risk_levels = [
      infiltration_risks.risk_level,
      awox_risks.awox_risk_level,
      spy_indicators.spy_risk_level
    ]

    # Find the highest risk
    critical_count = Enum.count(risk_levels, &(&1 == :critical))
    high_count = Enum.count(risk_levels, &(&1 == :high))
    moderate_count = Enum.count(risk_levels, &(&1 == :moderate))

    cond do
      critical_count > 0 -> :critical
      high_count >= 2 -> :high
      high_count >= 1 || moderate_count >= 2 -> :moderate
      moderate_count >= 1 -> :low
      true -> :minimal
    end
  end

  defp assess_operational_security(members, activity_analysis) do
    # Assess operational security practices

    # Check for predictable patterns
    predictability_score = assess_activity_predictability(activity_analysis)

    # Check for information leaks
    opsec_violations = identify_opsec_violations(members)

    # Fleet security assessment
    fleet_security = assess_fleet_security(activity_analysis)

    %{
      predictability_risk: predictability_score,
      opsec_violations: opsec_violations,
      fleet_security: fleet_security,
      overall_opsec_score:
        calculate_opsec_score(predictability_score, opsec_violations, fleet_security)
    }
  end

  defp assess_activity_predictability(activity_analysis) do
    # Check if corporation has predictable activity patterns
    engagement_patterns = activity_analysis.engagement_patterns || %{}
    peak_hours = Map.get(engagement_patterns, :peak_activity_hours, [])

    cond do
      length(peak_hours) <= 2 ->
        # Active only in narrow window
        :highly_predictable

      length(peak_hours) <= 4 ->
        :moderately_predictable

      true ->
        :unpredictable
    end
  end

  defp identify_opsec_violations(_members) do
    # Would check for operational security violations
    # Simplified implementation
    []
  end

  defp assess_fleet_security(activity_analysis) do
    participation_rates = activity_analysis.participation_rates || %{}
    overall_participation = Map.get(participation_rates, :overall_participation, 0)

    %{
      participation_visibility: if(overall_participation > 0.7, do: :high, else: :moderate),
      fleet_predictability: :moderate,
      security_practices: :standard
    }
  end

  defp calculate_opsec_score(predictability, violations, fleet_security) do
    # Start with decent score
    base_score = 70

    # Deduct for predictability
    predictability_penalty =
      case predictability do
        :highly_predictable -> 30
        :moderately_predictable -> 15
        _ -> 0
      end

    # Deduct for violations
    violation_penalty = length(violations) * 10

    # Deduct for poor fleet security
    fleet_penalty = if fleet_security.participation_visibility == :high, do: 10, else: 0

    score = base_score - predictability_penalty - violation_penalty - fleet_penalty
    max(0, min(100, score))
  end

  defp analyze_member_vetting_status(members) do
    # Analyze how well members have been vetted
    total = length(members)

    # Categorize by join date
    well_vetted =
      Enum.count(members, fn member ->
        member.join_date && DateTimeUtils.diff(DateTime.utc_now(), member.join_date, :day) > 90
      end)

    recently_vetted =
      Enum.count(members, fn member ->
        member.join_date &&
          DateTimeUtils.diff(DateTime.utc_now(), member.join_date, :day) <= 90 &&
          DateTimeUtils.diff(DateTime.utc_now(), member.join_date, :day) > 30
      end)

    unvetted =
      Enum.count(members, fn member ->
        is_nil(member.join_date) ||
          DateTimeUtils.diff(DateTime.utc_now(), member.join_date, :day) <= 30
      end)

    %{
      total_members: total,
      well_vetted: well_vetted,
      recently_vetted: recently_vetted,
      unvetted: unvetted,
      vetting_coverage: Float.round((well_vetted + recently_vetted) / max(total, 1) * 100, 1)
    }
  end

  defp identify_suspicious_patterns(_members, activity_analysis) do
    member_metrics = activity_analysis.member_metrics || []

    initial_patterns = []

    # Check for feeding patterns (only losses)
    feeders =
      member_metrics
      |> Enum.filter(fn m -> m.recent_kills == 0 && m.recent_losses > 5 end)
      |> Enum.map(& &1.character_name)

    feeder_patterns =
      if length(feeders) > 0 do
        ["Potential feeders detected: #{Enum.join(feeders, ", ")}" | initial_patterns]
      else
        initial_patterns
      end

    # Check for inactive but present members
    lurkers =
      member_metrics
      |> Enum.filter(fn m ->
        m.activity_score < 10 && m.last_seen &&
          DateTimeUtils.diff(DateTime.utc_now(), m.last_seen, :day) < 7
      end)
      |> length()

    final_patterns =
      if lurkers > 3 do
        ["#{lurkers} members with minimal activity but recent logins" | feeder_patterns]
      else
        feeder_patterns
      end

    Enum.reverse(final_patterns)
  end

  defp identify_security_vulnerabilities(security_risks) do
    initial_vulnerabilities = []

    # Infiltration vulnerabilities
    infiltration_vulnerabilities =
      if security_risks.infiltration_risks.risk_level in [:high, :critical] do
        ["High infiltration risk from new/inactive members" | initial_vulnerabilities]
      else
        initial_vulnerabilities
      end

    # AWOX vulnerabilities
    awox_vulnerabilities =
      if security_risks.awox_risk_assessment.awox_risk_level in [:high, :critical] do
        ["Potential AWOX threats identified" | infiltration_vulnerabilities]
      else
        infiltration_vulnerabilities
      end

    # Spy vulnerabilities
    final_vulnerabilities =
      if security_risks.spy_indicators.spy_risk_level in [:high, :critical] do
        ["Possible intelligence gathering activities detected" | awox_vulnerabilities]
      else
        awox_vulnerabilities
      end

    if Enum.empty?(final_vulnerabilities) do
      ["No critical security vulnerabilities identified"]
    else
      Enum.reverse(final_vulnerabilities)
    end
  end

  defp compile_threat_indicators(security_risks, activity_analysis) do
    indicators = %{
      infiltration_indicators: extract_infiltration_indicators(security_risks.infiltration_risks),
      behavioral_indicators: extract_behavioral_indicators(activity_analysis),
      operational_indicators: extract_operational_indicators(security_risks)
    }

    indicators
  end

  defp extract_infiltration_indicators(infiltration_risks) do
    initial_indicators = []

    new_member_indicators =
      if infiltration_risks.new_member_ratio > 20 do
        [
          "High ratio of new members (#{infiltration_risks.new_member_ratio}%)"
          | initial_indicators
        ]
      else
        initial_indicators
      end

    final_indicators =
      if infiltration_risks.low_activity_count > 5 do
        [
          "#{infiltration_risks.low_activity_count} low-activity members present"
          | new_member_indicators
        ]
      else
        new_member_indicators
      end

    Enum.reverse(final_indicators)
  end

  defp extract_behavioral_indicators(activity_analysis) do
    summary = activity_analysis.summary || %{}

    initial_behavioral_indicators = []

    final_behavioral_indicators =
      if Map.get(summary, :participation_rate, 100) < 40 do
        ["Low overall participation rate" | initial_behavioral_indicators]
      else
        initial_behavioral_indicators
      end

    Enum.reverse(final_behavioral_indicators)
  end

  defp extract_operational_indicators(security_risks) do
    initial_operational_indicators = []

    final_operational_indicators =
      if length(security_risks.spy_indicators.potential_spies) > 0 do
        ["Suspicious activity patterns detected" | initial_operational_indicators]
      else
        initial_operational_indicators
      end

    Enum.reverse(final_operational_indicators)
  end

  defp calculate_security_score(security_risks) do
    # Calculate overall security score (0-100, higher is better)
    base_score = 100

    # Deductions for various risks
    infiltration_penalty =
      case security_risks.infiltration_risks.risk_level do
        :critical -> 30
        :high -> 20
        :moderate -> 10
        :low -> 5
        _ -> 0
      end

    awox_penalty =
      case security_risks.awox_risk_assessment.awox_risk_level do
        :critical -> 25
        :high -> 15
        :moderate -> 10
        :low -> 5
        _ -> 0
      end

    spy_penalty =
      case security_risks.spy_indicators.spy_risk_level do
        :high -> 20
        :moderate -> 10
        :low -> 5
        _ -> 0
      end

    final_score = base_score - infiltration_penalty - awox_penalty - spy_penalty
    max(0, min(100, final_score))
  end

  defp generate_security_recommendations(security_risks) do
    initial_recommendations = []

    # Infiltration recommendations
    infiltration_recommendations =
      case security_risks.infiltration_risks.risk_level do
        level when level in [:high, :critical] ->
          [
            "Implement stricter vetting procedures for new members",
            "Monitor low-activity members for suspicious behavior" | initial_recommendations
          ]

        :moderate ->
          ["Review new member onboarding process" | initial_recommendations]

        _ ->
          initial_recommendations
      end

    # AWOX recommendations
    awox_recommendations =
      case security_risks.awox_risk_assessment.awox_risk_level do
        level when level in [:high, :critical] ->
          [
            "Implement fleet role restrictions for high-risk members",
            "Monitor identified AWOX risks during operations" | infiltration_recommendations
          ]

        :moderate ->
          ["Review fleet access permissions" | infiltration_recommendations]

        _ ->
          infiltration_recommendations
      end

    # Spy recommendations
    spy_recommendations =
      case security_risks.spy_indicators.spy_risk_level do
        :high ->
          [
            "Limit access to sensitive operational information",
            "Implement need-to-know information policies" | awox_recommendations
          ]

        :moderate ->
          ["Review information security practices" | awox_recommendations]

        _ ->
          awox_recommendations
      end

    # General recommendations
    final_recommendations =
      if security_risks.overall_risk_level in [:high, :critical] do
        [
          "Conduct immediate security review of all members",
          "Implement enhanced monitoring procedures" | spy_recommendations
        ]
      else
        ["Maintain regular security assessments" | spy_recommendations]
      end

    Enum.reverse(final_recommendations) |> Enum.uniq()
  end

  defp get_character_security_data(character_id) do
    # Gather comprehensive security data for a character
    with {:ok, killmail_data} <- get_character_killmail_history(character_id),
         {:ok, activity_data} <- get_character_activity_pattern(character_id),
         {:ok, affiliation_data} <- get_character_affiliations(character_id) do
      security_data = %{
        character_id: character_id,
        killmail_history: killmail_data,
        activity_patterns: activity_data,
        affiliations: affiliation_data,
        security_flags: identify_security_flags(killmail_data, activity_data, affiliation_data)
      }

      {:ok, security_data}
    end
  end

  defp get_character_killmail_history(character_id) do
    # 6 months
    start_date = DateTime.utc_now() |> DateTimeUtils.add(-180 * 24 * 60 * 60, :second)

    case CharacterRepository.get_character_killmails_since(character_id, start_date) do
      {:ok, killmails} ->
        history = %{
          total_killmails: length(killmails),
          kills: Enum.count(killmails, fn km -> km.victim.character_id != character_id end),
          losses: Enum.count(killmails, fn km -> km.victim.character_id == character_id end),
          friendly_fire_incidents: count_friendly_fire(killmails, character_id),
          operational_areas: extract_operational_areas(killmails)
        }

        {:ok, history}

      error ->
        error
    end
  end

  defp count_friendly_fire(_killmails, _character_id) do
    # Count potential friendly fire incidents
    # Simplified - would need corp/alliance history to properly identify
    0
  end

  defp extract_operational_areas(killmails) do
    killmails
    |> Enum.map(& &1.solar_system_id)
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_system, count} -> count end, :desc)
    |> Enum.take(5)
    |> Enum.map(fn {system_id, count} ->
      %{system_id: system_id, activity_count: count}
    end)
  end

  defp get_character_activity_pattern(character_id) do
    # Use killmail data to infer activity patterns
    start_date = DateTime.utc_now() |> DateTimeUtils.add(-90 * 24 * 60 * 60, :second)

    case CharacterRepository.get_character_killmails_since(character_id, start_date) do
      {:ok, killmails} when killmails != [] ->
        activity_analysis = analyze_activity_from_killmails(killmails)

        {:ok,
         %{
           timezone_pattern: determine_timezone_pattern(activity_analysis.peak_hours),
           activity_gaps: identify_activity_gaps_from_killmails(killmails),
           consistency_score: calculate_consistency_from_killmails(killmails)
         }}

      {:ok, []} ->
        {:ok,
         %{
           timezone_pattern: :unknown,
           activity_gaps: [],
           consistency_score: 0
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_character_affiliations(character_id) do
    # Extract affiliation data from killmail history
    start_date = DateTime.utc_now() |> DateTimeUtils.add(-180 * 24 * 60 * 60, :second)

    case CharacterRepository.get_character_killmails_since(character_id, start_date) do
      {:ok, killmails} ->
        affiliations = extract_affiliations_from_killmails(killmails, character_id)

        {:ok,
         %{
           current_corporation: affiliations.current_corporation,
           corporation_history: affiliations.corporation_changes,
           known_associates: extract_known_associates_from_killmails(character_id, killmails)
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp identify_security_flags(killmail_data, activity_data, _affiliation_data) do
    initial_flags = []

    # Check for concerning killmail patterns
    feeder_flags =
      if killmail_data.kills == 0 && killmail_data.losses > 10 do
        ["Only losses recorded - potential feeder" | initial_flags]
      else
        initial_flags
      end

    friendly_fire_flags =
      if killmail_data.friendly_fire_incidents > 0 do
        ["Friendly fire incidents recorded" | feeder_flags]
      else
        feeder_flags
      end

    # Check activity patterns
    final_flags =
      if activity_data.consistency_score < 30 do
        ["Highly irregular activity patterns" | friendly_fire_flags]
      else
        friendly_fire_flags
      end

    Enum.reverse(final_flags)
  end

  defp perform_member_vetting(character_data, corporation_id) do
    # Perform comprehensive vetting analysis

    vetting_results = %{
      character_id: character_data.character_id,
      corporation_id: corporation_id,
      security_assessment: assess_character_security(character_data),
      risk_factors: character_data.security_flags,
      killmail_analysis: analyze_killmail_patterns_for_vetting(character_data.killmail_history),
      activity_assessment: assess_activity_for_vetting(character_data.activity_patterns),
      recommendation: make_vetting_recommendation(character_data),
      confidence_level: calculate_vetting_confidence(character_data),
      vetted_at: DateTime.utc_now()
    }

    {:ok, vetting_results}
  end

  defp assess_character_security(character_data) do
    flags_count = length(character_data.security_flags)

    cond do
      flags_count >= 3 -> :high_risk
      flags_count >= 2 -> :moderate_risk
      flags_count >= 1 -> :low_risk
      true -> :minimal_risk
    end
  end

  defp analyze_killmail_patterns_for_vetting(killmail_history) do
    %{
      combat_participation: killmail_history.total_killmails > 0,
      kill_death_ratio: calculate_kd_ratio(killmail_history.kills, killmail_history.losses),
      primary_operational_area: List.first(killmail_history.operational_areas),
      concerning_patterns: []
    }
  end

  defp calculate_kd_ratio(kills, losses) do
    if losses > 0 do
      Float.round(kills / losses, 2)
    else
      kills
    end
  end

  defp assess_activity_for_vetting(activity_patterns) do
    %{
      consistency: activity_patterns.consistency_score,
      timezone_assessment: activity_patterns.timezone_pattern,
      activity_gaps: activity_patterns.activity_gaps
    }
  end

  defp make_vetting_recommendation(character_data) do
    risk_level = assess_character_security(character_data)

    case risk_level do
      :high_risk -> :reject
      :moderate_risk -> :conditional_accept
      :low_risk -> :accept_with_monitoring
      :minimal_risk -> :accept
    end
  end

  defp calculate_vetting_confidence(character_data) do
    # Higher killmail count = more data = higher confidence
    data_points = character_data.killmail_history.total_killmails

    cond do
      data_points >= 100 -> :high_confidence
      data_points >= 50 -> :moderate_confidence
      data_points >= 20 -> :low_confidence
      true -> :minimal_confidence
    end
  end

  defp analyze_activity_from_killmails(killmails) do
    # Extract activity patterns from killmail timestamps
    hour_counts =
      killmails
      |> Enum.map(fn km -> km.killmail_time |> DateTime.to_time() |> Map.get(:hour) end)
      |> Enum.frequencies()

    peak_hours =
      hour_counts
      |> Enum.sort_by(fn {_hour, count} -> count end, :desc)
      |> Enum.take(4)
      |> Enum.map(fn {hour, _count} -> hour end)

    %{peak_hours: peak_hours}
  end

  defp identify_activity_gaps_from_killmails(killmails) do
    # Find gaps in killmail activity indicating inactivity
    if length(killmails) < 2 do
      []
    else
      killmails
      |> Enum.sort_by(& &1.killmail_time, DateTime)
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.filter(fn [km1, km2] ->
        DateTimeUtils.diff(km2.killmail_time, km1.killmail_time, :day) > 7
      end)
      |> Enum.map(fn [km1, km2] ->
        %{
          start_date: km1.killmail_time,
          end_date: km2.killmail_time,
          gap_days: DateTimeUtils.diff(km2.killmail_time, km1.killmail_time, :day)
        }
      end)
    end
  end

  defp calculate_consistency_from_killmails(killmails) do
    if length(killmails) < 10 do
      0
    else
      # Calculate activity consistency based on killmail distribution
      days_with_activity =
        killmails
        |> Enum.map(fn km -> DateTime.to_date(km.killmail_time) end)
        |> Enum.uniq()
        |> length()

      max_time =
        killmails
        |> Enum.max_by(& &1.killmail_time)
        |> Map.get(:killmail_time)

      min_time =
        killmails
        |> Enum.min_by(& &1.killmail_time)
        |> Map.get(:killmail_time)

      total_days = DateTimeUtils.diff(max_time, min_time, :day)

      if total_days > 0 do
        round(days_with_activity / total_days * 100)
      else
        0
      end
    end
  end

  defp extract_affiliations_from_killmails(killmails, character_id) do
    # Extract corporation changes from killmail data
    character_corporations =
      killmails
      |> Enum.filter(fn km ->
        km.victim.character_id == character_id ||
          Enum.any?(km.attackers, fn att -> att.character_id == character_id end)
      end)
      |> Enum.map(fn km ->
        if km.victim.character_id == character_id do
          {km.killmail_time, km.victim.corporation_id}
        else
          attacker = Enum.find(km.attackers, fn att -> att.character_id == character_id end)
          {km.killmail_time, attacker.corporation_id}
        end
      end)
      |> Enum.sort_by(fn {time, _corp} -> time end, DateTime)

    current_corporation =
      case List.last(character_corporations) do
        {_time, corp_id} -> corp_id
        nil -> nil
      end

    # Track corporation changes
    corporation_changes =
      character_corporations
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.filter(fn [{_time1, corp1}, {_time2, corp2}] -> corp1 != corp2 end)
      |> Enum.map(fn [{time1, corp1}, {time2, corp2}] ->
        %{
          from_corporation: corp1,
          to_corporation: corp2,
          change_date: time2,
          days_in_previous: DateTimeUtils.diff(time2, time1, :day)
        }
      end)

    %{
      current_corporation: current_corporation,
      corporation_changes: corporation_changes
    }
  end

  defp extract_known_associates_from_killmails(character_id, killmails) do
    # Find characters frequently appearing in same killmails
    associates =
      killmails
      |> Enum.flat_map(fn km ->
        if km.victim.character_id == character_id do
          # Get attackers when character was victim
          Enum.map(km.attackers, fn att -> att.character_id end)
        else
          # Get other attackers when character was attacker
          other_attackers =
            Enum.reject(km.attackers, fn att -> att.character_id == character_id end)

          [km.victim.character_id | Enum.map(other_attackers, fn att -> att.character_id end)]
        end
      end)
      |> Enum.filter(fn char_id -> char_id != character_id && char_id != nil end)
      |> Enum.frequencies()
      # Appeared together 3+ times
      |> Enum.filter(fn {_char_id, count} -> count >= 3 end)
      |> Enum.sort_by(fn {_char_id, count} -> count end, :desc)
      |> Enum.take(10)
      |> Enum.map(fn {char_id, encounter_count} ->
        %{character_id: char_id, encounter_count: encounter_count}
      end)

    associates
  end

  defp determine_timezone_pattern(peak_hours) when is_list(peak_hours) do
    case length(peak_hours) do
      n when n <= 2 -> :highly_predictable
      n when n <= 4 -> :moderately_predictable
      _ -> :unpredictable
    end
  end

  defp determine_timezone_pattern(_), do: :unknown
end

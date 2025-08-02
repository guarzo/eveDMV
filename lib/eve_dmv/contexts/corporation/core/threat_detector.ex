defmodule EveDmv.Contexts.Corporation.Core.ThreatDetector do
  @moduledoc """
  Real-time threat detection for corporation security.

  Monitors corporation activities and member behaviors to identify
  emerging threats, suspicious activities, and security incidents.
  """
  """

  alias EveDmv.Contexts.Corporation.Core.SecurityAnalyzer
  alias EveDmv.Core.Utils.DateTimeUtils
  alias EveDmv.Database.KillmailRepository
  alias EveDmv.Platform.Cache.Corporation.CorporationCache
  alias EveDmv.Platform.Database.CorporationRepository
  alias EveDmv.Platform.PubSub.EventBus

  require Logger

  @cache_ttl :timer.minutes(30)

  @doc """
  Detect active threats to the corporation.
  """
  @spec detect_active_threats(integer()) :: {:ok, map()} | {:error, term()}
  def detect_active_threats(corporation_id) do
    cache_key = {:active_threats, corporation_id}

    case CorporationCache.get(cache_key) do
      nil ->
        result = perform_threat_detection(corporation_id)

        if match?({:ok, _}, result) do
          {:ok, threats} = result
          CorporationCache.put(cache_key, threats, ttl: @cache_ttl)
        end

        result

      cached_result ->
        {:ok, cached_result}
    end
  end

  @doc """
  Monitor real-time threat indicators.
  """
  @spec monitor_threat_indicators(integer()) :: {:ok, map()} | {:error, term()}
  def monitor_threat_indicators(corporation_id) do
    with {:ok, current_threats} <- detect_active_threats(corporation_id),
         {:ok, threat_trends} <- analyze_threat_trends(corporation_id) do
      monitoring_data = %{
        active_threats: current_threats.active_threats,
        threat_level: current_threats.overall_threat_level,
        trending_threats: threat_trends,
        monitoring_recommendations:
          generate_monitoring_recommendations(current_threats, threat_trends)
      }

      # Publish threat alerts if needed
      publish_threat_alerts(corporation_id, monitoring_data)

      {:ok, monitoring_data}
    end
  end

  @doc """
  Analyze specific threat patterns.
  """
  @spec analyze_threat_pattern(integer(), atom()) :: {:ok, map()} | {:error, term()}
  def analyze_threat_pattern(corporation_id, pattern_type) do
    case pattern_type do
      :infiltration -> detect_infiltration_patterns(corporation_id)
      :hostile_activity -> detect_hostile_activity_patterns(corporation_id)
      :espionage -> detect_espionage_patterns(corporation_id)
      :awox -> detect_awox_patterns(corporation_id)
      _ -> {:error, :unknown_pattern_type}
    end
  end

  @doc """
  Get threat detection alerts for a corporation.
  """
  @spec get_threat_alerts(integer(), atom()) :: {:ok, list(map())} | {:error, term()}
  def get_threat_alerts(corporation_id, time_window \\ :hour) do
    with {:ok, threats} <- detect_active_threats(corporation_id) do
      alerts = filter_alerts_by_time_window(threats.threat_alerts, time_window)
      {:ok, alerts}
    end
  end

  # Private Functions

  defp perform_threat_detection(corporation_id) do
    Logger.info("Performing threat detection for corporation #{corporation_id}")

    with {:ok, members} <- CorporationRepository.get_corporation_members(corporation_id),
         {:ok, recent_activity} <- get_recent_corporation_activity(corporation_id),
         {:ok, security_analysis} <-
           SecurityAnalyzer.analyze_corporation_security(corporation_id),
         {:ok, threat_indicators} <-
           compile_threat_indicators(members, recent_activity, security_analysis) do
      active_threats = identify_active_threats(threat_indicators)
      threat_patterns = analyze_threat_patterns(threat_indicators)

      threat_detection = %{
        corporation_id: corporation_id,
        detection_timestamp: DateTime.utc_now(),
        overall_threat_level: calculate_overall_threat_level(active_threats),
        active_threats: active_threats,
        threat_patterns: threat_patterns,
        threat_indicators: threat_indicators,
        threat_alerts: generate_threat_alerts(active_threats, threat_patterns),
        mitigation_priorities: prioritize_threat_mitigation(active_threats),
        detection_confidence: calculate_detection_confidence(threat_indicators)
      }

      {:ok, threat_detection}
    end
  end

  defp get_recent_corporation_activity(corporation_id) do
    # Get activity from last 24 hours
    start_time = DateTime.utc_now() |> DateTimeUtils.add(-24 * 60 * 60, :second)

    with {:ok, members} <- CorporationRepository.get_corporation_members(corporation_id),
         {:ok, killmails} <- get_recent_corporation_killmails(members, start_time) do
      activity = %{
        member_logins: analyze_member_login_patterns(members, start_time),
        combat_activity: analyze_recent_combat_activity(killmails),
        unusual_events: identify_unusual_events(killmails, members),
        activity_anomalies: detect_activity_anomalies(members, killmails)
      }

      {:ok, activity}
    end
  end

  defp get_recent_corporation_killmails(members, start_time) do
    member_ids = Enum.map(members, & &1.character_id)

    # Get killmails involving corporation members
    case KillmailRepository.get_killmails_by_characters(member_ids, start_time) do
      {:ok, killmails} -> {:ok, killmails}
      error -> error
    end
  end

  defp analyze_member_login_patterns(members, start_time) do
    # Analyze recent login patterns
    recent_logins =
      members
      |> Enum.filter(fn member ->
        member.last_seen && DateTimeUtils.compare(member.last_seen, start_time) == :gt
      end)

    %{
      recent_login_count: length(recent_logins),
      unusual_login_times: detect_unusual_login_times(recent_logins),
      new_member_logins: count_new_member_logins(recent_logins),
      dormant_reactivations: detect_dormant_reactivations(members, start_time)
    }
  end

  defp detect_unusual_login_times(recent_logins) do
    # Detect logins at unusual times
    unusual_hour_logins =
      recent_logins
      |> Enum.filter(fn member ->
        if member.last_seen do
          hour = DateTime.to_time(member.last_seen).hour
          # Dead hours for most timezones
          hour in [2, 3, 4, 5]
        else
          false
        end
      end)
      |> Enum.map(& &1.character_name)

    unusual_hour_logins
  end

  defp count_new_member_logins(recent_logins) do
    # Count logins from members who joined in last 7 days
    new_member_cutoff = DateTime.utc_now() |> DateTimeUtils.add(-7 * 24 * 60 * 60, :second)

    Enum.count(recent_logins, fn member ->
      member.join_date && DateTimeUtils.compare(member.join_date, new_member_cutoff) == :gt
    end)
  end

  defp detect_dormant_reactivations(members, start_time) do
    # Detect previously inactive members who suddenly became active
    # 30 days of inactivity
    dormant_period = DateTimeUtils.add(start_time, -30 * 24 * 60 * 60, :second)

    reactivated =
      members
      |> Enum.filter(fn member ->
        if member.last_seen do
          was_dormant = DateTimeUtils.compare(member.last_seen, dormant_period) == :lt
          now_active = DateTimeUtils.compare(member.last_seen, start_time) == :gt
          was_dormant && now_active
        else
          false
        end
      end)
      |> Enum.map(fn member ->
        %{
          character_name: member.character_name,
          dormant_days: DateTimeUtils.diff(start_time, member.last_seen, :day),
          reactivation_flag: :suspicious
        }
      end)

    reactivated
  end

  defp analyze_recent_combat_activity(killmails) do
    %{
      total_engagements: length(killmails),
      member_losses: count_member_losses(killmails),
      suspicious_losses: identify_suspicious_losses(killmails),
      blue_on_blue: detect_blue_on_blue_incidents(killmails),
      unusual_targets: identify_unusual_targets(killmails)
    }
  end

  defp count_member_losses(killmails) do
    # Count losses where corporation member was the victim
    # This is simplified - would need corporation ID checking
    Enum.count(killmails, fn km ->
      # Check if victim is from our corporation
      km.victim != nil
    end)
  end

  defp identify_suspicious_losses(killmails) do
    # Identify losses that seem suspicious
    suspicious =
      killmails
      |> Enum.filter(fn km ->
        # High-value loss with minimal resistance
        # 1B ISK
        high_value = (km.total_value || 0) > 1_000_000_000
        minimal_damage = length(km.attackers) == 1

        high_value && minimal_damage
      end)
      |> Enum.map(fn km ->
        %{
          killmail_id: km.killmail_id,
          victim: km.victim.character_name,
          value: km.total_value,
          suspicion_reason: "High-value loss with minimal resistance"
        }
      end)

    suspicious
  end

  defp detect_blue_on_blue_incidents(_killmails) do
    # Detect friendly fire incidents
    # Would need corporation/alliance checking
    []
  end

  defp identify_unusual_targets(killmails) do
    # Identify unusual targeting patterns
    targets =
      killmails
      |> Enum.map(& &1.victim.character_id)
      |> Enum.frequencies()
      # Same target hit 3+ times
      |> Enum.filter(fn {_target, count} -> count >= 3 end)

    if map_size(targets) > 0 do
      ["Repeated targeting of specific individuals detected"]
    else
      []
    end
  end

  defp identify_unusual_events(killmails, members) do
    events = []

    # Mass logout event
    recent_cutoff = DateTime.utc_now() |> DateTimeUtils.add(-1 * 60 * 60, :second)

    recent_active =
      Enum.count(members, fn m ->
        m.last_seen && DateTimeUtils.compare(m.last_seen, recent_cutoff) == :gt
      end)

    logout_events =
      if recent_active < length(members) * 0.1 do
        ["Mass logout detected - only #{recent_active} members active" | events]
      else
        events
      end

    # Sudden spike in losses
    recent_losses =
      Enum.count(killmails, fn km ->
        DateTimeUtils.compare(km.killmail_time, recent_cutoff) == :gt
      end)

    loss_events =
      if recent_losses > 10 do
        ["Spike in combat losses - #{recent_losses} in last hour" | logout_events]
      else
        logout_events
      end

    Enum.reverse(loss_events)
  end

  defp detect_activity_anomalies(members, killmails) do
    anomalies = %{
      login_anomalies: detect_login_anomalies(members),
      combat_anomalies: detect_combat_anomalies(killmails),
      pattern_deviations: detect_pattern_deviations(members, killmails)
    }

    anomalies
  end

  defp detect_login_anomalies(members) do
    # Detect anomalous login patterns
    anomalies = []

    # Multiple new members logging in together
    new_member_cutoff = DateTime.utc_now() |> DateTimeUtils.add(-24 * 60 * 60, :second)

    new_member_logins =
      Enum.count(members, fn m ->
        m.join_date && DateTimeUtils.compare(m.join_date, new_member_cutoff) == :gt
      end)

    login_anomalies =
      if new_member_logins >= 5 do
        ["#{new_member_logins} new members joined in last 24 hours" | anomalies]
      else
        anomalies
      end

    Enum.reverse(login_anomalies)
  end

  defp detect_combat_anomalies(killmails) do
    # Detect anomalous combat patterns
    anomalies = []

    # All losses, no kills
    if length(killmails) > 5 && all_losses?(killmails) do
      ["Only losses recorded - no kills" | anomalies]
    else
      anomalies
    end
  end

  defp all_losses?(killmails) do
    # Check if corporation members only appear as victims (potential farming/feeding)
    if length(killmails) < 10 do
      false
    else
      loss_ratio =
        killmails
        |> Enum.count(fn km ->
          # Check if any corp member is the victim
          km.victim.corporation_id in extract_corp_ids(killmails)
        end)

      total_killmails = length(killmails)
      # 90%+ losses indicates concerning pattern
      loss_ratio / total_killmails > 0.9
    end
  end

  defp detect_pattern_deviations(_members, killmails) do
    # Detect deviations from normal activity patterns
    deviations = []

    # Check for unusual activity spikes
    spike_deviations = check_activity_spikes(killmails) ++ deviations

    # Check for new/unusual operational areas
    area_deviations = check_new_operational_areas(killmails) ++ spike_deviations

    # Check for unusual ship type usage
    ship_deviations = check_unusual_ship_usage(killmails) ++ area_deviations

    # Check for timing pattern changes
    timing_deviations = check_timing_deviations(killmails) ++ ship_deviations

    timing_deviations
  end

  defp compile_threat_indicators(members, recent_activity, security_analysis) do
    indicators = %{
      security_indicators: extract_security_threat_indicators(security_analysis),
      activity_indicators: extract_activity_threat_indicators(recent_activity),
      member_indicators: extract_member_threat_indicators(members),
      composite_indicators: calculate_composite_indicators(security_analysis, recent_activity)
    }

    {:ok, indicators}
  end

  defp extract_security_threat_indicators(security_analysis) do
    %{
      infiltration_risk: security_analysis.infiltration_risk_assessment.risk_level,
      suspicious_members:
        length(security_analysis.infiltration_risk_assessment.high_risk_members),
      security_score: security_analysis.security_score,
      identified_threats: security_analysis.security_vulnerabilities
    }
  end

  defp extract_activity_threat_indicators(recent_activity) do
    %{
      unusual_logins: recent_activity.member_logins.unusual_login_times,
      dormant_reactivations: recent_activity.member_logins.dormant_reactivations,
      suspicious_losses: recent_activity.combat_activity.suspicious_losses,
      unusual_events: recent_activity.unusual_events
    }
  end

  defp extract_member_threat_indicators(members) do
    # Extract threat indicators from member data
    # Last 3 days
    new_member_surge = count_recent_joins(members, 3)

    %{
      new_member_surge: new_member_surge > 10,
      mass_inactivity: count_inactive_members(members) > length(members) * 0.5,
      coordination_indicators: detect_coordination_indicators(members)
    }
  end

  defp count_recent_joins(members, days) do
    cutoff = DateTime.utc_now() |> DateTimeUtils.add(-days * 24 * 60 * 60, :second)

    Enum.count(members, fn member ->
      member.join_date && DateTimeUtils.compare(member.join_date, cutoff) == :gt
    end)
  end

  defp count_inactive_members(members) do
    cutoff = DateTime.utc_now() |> DateTimeUtils.add(-7 * 24 * 60 * 60, :second)

    Enum.count(members, fn member ->
      is_nil(member.last_seen) || DateTimeUtils.compare(member.last_seen, cutoff) == :lt
    end)
  end

  defp detect_coordination_indicators(members) do
    # Detect indicators of coordinated activity
    indicators = []

    # Check for synchronized join dates
    join_dates =
      members
      |> Enum.map(& &1.join_date)
      |> Enum.filter(& &1)
      |> Enum.group_by(&DateTime.to_date/1)

    synchronized_joins =
      join_dates
      |> Enum.filter(fn {_date, members} -> length(members) >= 3 end)
      |> Enum.map(fn {date, members} ->
        "#{length(members)} members joined on #{date}"
      end)

    indicators ++ synchronized_joins
  end

  defp calculate_composite_indicators(security_analysis, recent_activity) do
    # Calculate composite threat indicators

    infiltration_score =
      case security_analysis.infiltration_risk_assessment.risk_level do
        :critical -> 1.0
        :high -> 0.8
        :moderate -> 0.5
        :low -> 0.3
        _ -> 0.1
      end

    activity_score = calculate_activity_threat_score(recent_activity)

    %{
      composite_threat_score: (infiltration_score + activity_score) / 2,
      threat_vector_count: count_threat_vectors(security_analysis, recent_activity),
      threat_convergence: assess_threat_convergence(security_analysis, recent_activity)
    }
  end

  defp calculate_activity_threat_score(recent_activity) do
    score = 0

    # Unusual logins
    login_score = score + length(recent_activity.member_logins.unusual_login_times) * 0.1

    # Dormant reactivations
    reactivation_score =
      login_score + length(recent_activity.member_logins.dormant_reactivations) * 0.15

    # Suspicious losses
    final_score =
      reactivation_score + length(recent_activity.combat_activity.suspicious_losses) * 0.2

    min(1.0, final_score)
  end

  defp count_threat_vectors(security_analysis, recent_activity) do
    vectors = 0

    infiltration_vectors =
      vectors +
        if security_analysis.infiltration_risk_assessment.risk_level in [:high, :critical],
          do: 1,
          else: 0

    combat_vectors =
      infiltration_vectors +
        if length(recent_activity.combat_activity.suspicious_losses) > 0, do: 1, else: 0

    total_vectors =
      combat_vectors +
        if length(recent_activity.member_logins.dormant_reactivations) > 0, do: 1, else: 0

    total_vectors
  end

  defp assess_threat_convergence(_security_analysis, _recent_activity) do
    # Assess if multiple threat indicators point to coordinated threat
    :possible_convergence
  end

  defp identify_active_threats(threat_indicators) do
    threats = []

    # Infiltration threat
    infiltration_threats =
      if threat_indicators.security_indicators.infiltration_risk in [:high, :critical] do
        threat = %{
          threat_type: :infiltration,
          severity: threat_indicators.security_indicators.infiltration_risk,
          description: "High risk of corporation infiltration detected",
          affected_members: threat_indicators.security_indicators.suspicious_members,
          indicators: ["New member surge", "Low activity members present"],
          confidence: :high
        }

        [threat | threats]
      else
        threats
      end

    # Espionage threat
    espionage_threats =
      if length(threat_indicators.activity_indicators.dormant_reactivations) > 0 do
        threat = %{
          threat_type: :espionage,
          severity: :moderate,
          description: "Potential intelligence gathering activity",
          affected_members:
            Enum.map(
              threat_indicators.activity_indicators.dormant_reactivations,
              & &1.character_name
            ),
          indicators: ["Dormant account reactivations", "Unusual login patterns"],
          confidence: :moderate
        }

        [threat | infiltration_threats]
      else
        infiltration_threats
      end

    # Asset theft threat
    asset_threats =
      if length(threat_indicators.activity_indicators.suspicious_losses) > 0 do
        threat = %{
          threat_type: :asset_theft,
          severity: :high,
          description: "Suspicious asset losses detected",
          affected_members:
            Enum.map(threat_indicators.activity_indicators.suspicious_losses, & &1.victim),
          indicators: ["High-value losses with minimal resistance"],
          confidence: :high
        }

        [threat | espionage_threats]
      else
        espionage_threats
      end

    # Coordinated threat
    coordinated_threats =
      if threat_indicators.composite_indicators.threat_vector_count >= 3 do
        threat = %{
          threat_type: :coordinated_operation,
          severity: :critical,
          description: "Multiple threat indicators suggest coordinated hostile operation",
          affected_members: [],
          indicators: ["Multiple threat vectors active", "Pattern convergence detected"],
          confidence: :moderate
        }

        [threat | asset_threats]
      else
        asset_threats
      end

    Enum.reverse(coordinated_threats)
  end

  defp analyze_threat_patterns(threat_indicators) do
    patterns = %{
      temporal_patterns: analyze_temporal_threat_patterns(threat_indicators),
      behavioral_patterns: analyze_behavioral_threat_patterns(threat_indicators),
      coordination_patterns: analyze_coordination_patterns(threat_indicators)
    }

    patterns
  end

  defp analyze_temporal_threat_patterns(threat_indicators) do
    # Analyze timing patterns in threats
    patterns = []

    # Check for time-coordinated activities
    temporal_patterns =
      if length(threat_indicators.activity_indicators.unusual_logins) > 3 do
        ["Coordinated login times detected" | patterns]
      else
        patterns
      end

    temporal_patterns
  end

  defp analyze_behavioral_threat_patterns(threat_indicators) do
    # Analyze behavioral patterns
    patterns = []

    # Check for feeder behavior
    behavioral_patterns =
      if Enum.any?(threat_indicators.activity_indicators.suspicious_losses, fn loss ->
           String.contains?(loss.suspicion_reason, "minimal resistance")
         end) do
        ["Potential feeder behavior detected" | patterns]
      else
        patterns
      end

    behavioral_patterns
  end

  defp analyze_coordination_patterns(threat_indicators) do
    # Analyze coordination between threats
    if threat_indicators.composite_indicators.threat_convergence == :possible_convergence do
      ["Multiple threat indicators suggest coordination"]
    else
      []
    end
  end

  defp calculate_overall_threat_level(active_threats) do
    if Enum.empty?(active_threats) do
      :minimal
    else
      max_severity =
        active_threats
        |> Enum.map(& &1.severity)
        |> Enum.max_by(&severity_to_number/1)

      max_severity
    end
  end

  defp severity_to_number(severity) do
    case severity do
      :critical -> 5
      :high -> 4
      :moderate -> 3
      :low -> 2
      _ -> 1
    end
  end

  defp generate_threat_alerts(active_threats, threat_patterns) do
    alerts = []

    # Generate alerts for active threats
    threat_alerts =
      Enum.map(active_threats, fn threat ->
        %{
          alert_id: generate_alert_id(),
          alert_type: :active_threat,
          threat_type: threat.threat_type,
          severity: threat.severity,
          description: threat.description,
          timestamp: DateTime.utc_now(),
          requires_action: threat.severity in [:critical, :high]
        }
      end)

    # Generate alerts for patterns
    pattern_alerts =
      if length(threat_patterns.coordination_patterns) > 0 do
        [
          %{
            alert_id: generate_alert_id(),
            alert_type: :threat_pattern,
            threat_type: :coordinated_activity,
            severity: :high,
            description: "Coordinated threat activity detected",
            timestamp: DateTime.utc_now(),
            requires_action: true
          }
        ]
      else
        []
      end

    alerts ++ threat_alerts ++ pattern_alerts
  end

  defp generate_alert_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16()
  end

  defp prioritize_threat_mitigation(active_threats) do
    # Prioritize threats for mitigation
    active_threats
    |> Enum.sort_by(&severity_to_number(&1.severity), :desc)
    |> Enum.map(fn threat ->
      %{
        threat_type: threat.threat_type,
        priority: determine_mitigation_priority(threat),
        recommended_actions: generate_mitigation_actions(threat),
        timeline: determine_mitigation_timeline(threat.severity)
      }
    end)
  end

  defp determine_mitigation_priority(threat) do
    case threat.severity do
      :critical -> :immediate
      :high -> :urgent
      :moderate -> :high
      _ -> :normal
    end
  end

  defp generate_mitigation_actions(threat) do
    case threat.threat_type do
      :infiltration ->
        [
          "Review and restrict new member permissions",
          "Audit recent member activities",
          "Implement enhanced vetting procedures"
        ]

      :espionage ->
        [
          "Monitor identified accounts closely",
          "Restrict access to sensitive information",
          "Review operational security procedures"
        ]

      :asset_theft ->
        [
          "Investigate suspicious losses immediately",
          "Review asset access permissions",
          "Implement asset tracking procedures"
        ]

      :coordinated_operation ->
        [
          "Initiate full security review",
          "Alert leadership immediately",
          "Consider temporary operational restrictions"
        ]

      _ ->
        ["Monitor situation closely", "Review security procedures"]
    end
  end

  defp determine_mitigation_timeline(severity) do
    case severity do
      :critical -> "Immediate action required"
      :high -> "Action required within 4 hours"
      :moderate -> "Action required within 24 hours"
      _ -> "Review within 48 hours"
    end
  end

  defp calculate_detection_confidence(threat_indicators) do
    # Calculate confidence in threat detection
    indicator_count = count_total_indicators(threat_indicators)

    confidence_score = min(100, indicator_count * 10)

    %{
      confidence_score: confidence_score,
      confidence_level: categorize_confidence(confidence_score),
      data_quality: assess_data_quality(threat_indicators)
    }
  end

  defp count_total_indicators(threat_indicators) do
    security_count =
      if threat_indicators.security_indicators.suspicious_members > 0, do: 1, else: 0

    activity_count =
      length(threat_indicators.activity_indicators.unusual_logins) +
        length(threat_indicators.activity_indicators.dormant_reactivations) +
        length(threat_indicators.activity_indicators.suspicious_losses)

    security_count + activity_count
  end

  defp categorize_confidence(score) do
    cond do
      score >= 80 -> :high
      score >= 60 -> :moderate
      score >= 40 -> :low
      true -> :minimal
    end
  end

  defp assess_data_quality(_threat_indicators) do
    # Assess quality of threat detection data
    # Simplified
    :good
  end

  defp analyze_threat_trends(_corporation_id) do
    # Analyze threat trends over time
    # This would query historical threat data

    trends = %{
      threat_frequency: :stable,
      severity_trend: :stable,
      emerging_patterns: [],
      prediction: "Threat levels expected to remain stable"
    }

    {:ok, trends}
  end

  defp detect_infiltration_patterns(corporation_id) do
    with {:ok, threats} <- detect_active_threats(corporation_id) do
      infiltration_threats =
        Enum.filter(threats.active_threats, &(&1.threat_type == :infiltration))

      patterns = %{
        active_infiltrations: length(infiltration_threats),
        infiltration_methods: extract_infiltration_methods(infiltration_threats),
        risk_level: if(length(infiltration_threats) > 0, do: :high, else: :low)
      }

      {:ok, patterns}
    end
  end

  defp extract_infiltration_methods(infiltration_threats) do
    infiltration_threats
    |> Enum.flat_map(& &1.indicators)
    |> Enum.uniq()
  end

  defp detect_hostile_activity_patterns(corporation_id) do
    with {:ok, threats} <- detect_active_threats(corporation_id) do
      hostile_patterns = %{
        active_hostiles: count_hostile_threats(threats.active_threats),
        hostile_indicators: extract_hostile_indicators(threats),
        escalation_risk: assess_escalation_risk(threats)
      }

      {:ok, hostile_patterns}
    end
  end

  defp count_hostile_threats(active_threats) do
    Enum.count(active_threats, fn threat ->
      threat.threat_type in [:asset_theft, :coordinated_operation]
    end)
  end

  defp extract_hostile_indicators(threats) do
    threats.threat_indicators.activity_indicators.unusual_events
  end

  defp assess_escalation_risk(threats) do
    if threats.overall_threat_level in [:critical, :high], do: :high, else: :low
  end

  defp detect_espionage_patterns(corporation_id) do
    with {:ok, threats} <- detect_active_threats(corporation_id) do
      espionage_threats = Enum.filter(threats.active_threats, &(&1.threat_type == :espionage))

      patterns = %{
        suspected_spies: length(espionage_threats),
        espionage_indicators: extract_espionage_indicators(espionage_threats),
        information_risk: if(length(espionage_threats) > 0, do: :high, else: :low)
      }

      {:ok, patterns}
    end
  end

  defp extract_espionage_indicators(espionage_threats) do
    espionage_threats
    |> Enum.flat_map(& &1.indicators)
    |> Enum.uniq()
  end

  defp detect_awox_patterns(corporation_id) do
    with {:ok, security_analysis} <- SecurityAnalyzer.analyze_corporation_security(corporation_id) do
      awox_assessment = security_analysis.infiltration_risk_assessment

      patterns = %{
        potential_awoxers: length(awox_assessment.high_risk_members),
        awox_risk_level: awox_assessment.risk_level,
        awox_indicators: extract_awox_indicators(awox_assessment)
      }

      {:ok, patterns}
    end
  end

  defp extract_awox_indicators(awox_assessment) do
    awox_assessment.high_risk_members
    |> Enum.flat_map(& &1.risk_factors)
    |> Enum.uniq()
  end

  defp filter_alerts_by_time_window(alerts, time_window) do
    cutoff_time =
      case time_window do
        :hour -> DateTime.utc_now() |> DateTimeUtils.add(-1 * 60 * 60, :second)
        :day -> DateTime.utc_now() |> DateTimeUtils.add(-24 * 60 * 60, :second)
        :week -> DateTime.utc_now() |> DateTimeUtils.add(-7 * 24 * 60 * 60, :second)
        _ -> DateTime.utc_now() |> DateTimeUtils.add(-1 * 60 * 60, :second)
      end

    Enum.filter(alerts, fn alert ->
      DateTimeUtils.compare(alert.timestamp, cutoff_time) == :gt
    end)
  end

  defp publish_threat_alerts(corporation_id, monitoring_data) do
    # Publish threat alerts to PubSub for real-time notifications
    if monitoring_data.threat_level in [:critical, :high] do
      EventBus.broadcast("corporation:#{corporation_id}:threats", %{
        event: :threat_detected,
        threat_level: monitoring_data.threat_level,
        active_threats: monitoring_data.active_threats,
        timestamp: DateTime.utc_now()
      })
    end
  end

  defp generate_monitoring_recommendations(current_threats, threat_trends) do
    recommendations = []

    # Based on threat level
    threat_level_recommendations =
      case current_threats.overall_threat_level do
        :critical ->
          ["Implement 24/7 monitoring", "Alert all leadership immediately" | recommendations]

        :high ->
          ["Increase monitoring frequency", "Review security procedures" | recommendations]

        :moderate ->
          ["Maintain regular monitoring", "Update threat assessments daily" | recommendations]

        _ ->
          ["Standard monitoring procedures sufficient" | recommendations]
      end

    # Based on trends
    trend_recommendations =
      case threat_trends.threat_frequency do
        :increasing ->
          ["Prepare for escalation", "Review defensive measures" | threat_level_recommendations]

        :decreasing ->
          ["Maintain vigilance during de-escalation" | threat_level_recommendations]

        _ ->
          threat_level_recommendations
      end

    Enum.reverse(trend_recommendations) |> Enum.uniq()
  end

  defp extract_corp_ids(killmails) do
    killmails
    |> Enum.flat_map(fn km ->
      [km.victim.corporation_id | Enum.map(km.attackers, & &1.corporation_id)]
    end)
    |> Enum.uniq()
    |> Enum.reject(&is_nil/1)
  end

  defp check_activity_spikes(killmails) do
    # Group killmails by day and check for unusual spikes
    daily_counts =
      killmails
      |> Enum.group_by(fn km -> DateTime.to_date(km.killmail_time) end)
      |> Enum.map(fn {date, kms} -> {date, length(kms)} end)
      |> Enum.sort_by(fn {date, _count} -> date end)

    if length(daily_counts) < 7 do
      []
    else
      counts = Enum.map(daily_counts, fn {_date, count} -> count end)
      avg_daily = Enum.sum(counts) / length(counts)

      daily_counts
      # 3x average
      |> Enum.filter(fn {_date, count} -> count > avg_daily * 3 end)
      |> Enum.map(fn {date, count} ->
        %{
          type: :activity_spike,
          date: date,
          killmail_count: count,
          severity: if(count > avg_daily * 5, do: :high, else: :moderate)
        }
      end)
    end
  end

  defp check_new_operational_areas(killmails) do
    # Check for operations in new/unusual systems
    recent_systems =
      killmails
      # Recent 50 killmails
      |> Enum.take(50)
      |> Enum.map(& &1.solar_system_id)
      |> Enum.uniq()

    historical_systems =
      killmails
      # Older killmails
      |> Enum.drop(50)
      |> Enum.map(& &1.solar_system_id)
      |> Enum.uniq()

    new_systems = recent_systems -- historical_systems

    if length(new_systems) > 3 do
      [
        %{
          type: :new_operational_areas,
          new_systems: new_systems,
          count: length(new_systems),
          severity: if(length(new_systems) > 5, do: :high, else: :moderate)
        }
      ]
    else
      []
    end
  end

  defp check_unusual_ship_usage(killmails) do
    # Check for unusual ship types being used
    recent_ships =
      killmails
      |> Enum.take(30)
      |> Enum.flat_map(fn km ->
        [km.victim.ship_type_id | Enum.map(km.attackers, & &1.ship_type_id)]
      end)
      |> Enum.frequencies()

    # Look for ships used in unusual quantities (more than 5 instances)
    unusual_ships =
      recent_ships
      |> Enum.filter(fn {_ship_id, count} -> count > 5 end)

    if length(unusual_ships) > 0 do
      [
        %{
          type: :unusual_ship_usage,
          ships: unusual_ships,
          severity: :moderate
        }
      ]
    else
      []
    end
  end

  defp check_timing_deviations(killmails) do
    # Check for unusual timing patterns
    hour_distribution =
      killmails
      |> Enum.map(fn km -> DateTime.to_time(km.killmail_time).hour end)
      |> Enum.frequencies()

    # Check if activity is concentrated in unusual hours (0-6 UTC)
    night_activity = Enum.sum(for h <- 0..6, do: Map.get(hour_distribution, h, 0))
    total_activity = Enum.sum(Map.values(hour_distribution))

    if total_activity > 0 && night_activity / total_activity > 0.6 do
      [
        %{
          type: :unusual_timing,
          night_activity_ratio: night_activity / total_activity,
          severity: :moderate
        }
      ]
    else
      []
    end
  end
end

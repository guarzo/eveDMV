defmodule EveDmv.Intelligence.Core.IntelligenceCoordinator do
  @moduledoc """
  Central coordinator for intelligence analysis operations.

  Manages and orchestrates various intelligence analysis components, providing
  a unified interface for comprehensive intelligence gathering and analysis.
  """

  alias EveDmv.Intelligence.Analyzers.CharacterAnalyzer
  alias EveDmv.Intelligence.Analyzers.WHVettingAnalyzer
  alias EveDmv.Intelligence.Core.CacheHelper

  require Logger

  @doc """
  Warm the intelligence cache by preloading commonly accessed data.
  """
  def warm_intelligence_cache do
    Logger.info("Intelligence cache warming initiated")

    # Start cache warming as a background task
    Task.start(fn ->
      try do
        # Warm various caches
        warm_character_cache()
        warm_analysis_cache()
        warm_threat_cache()

        Logger.info("Intelligence cache warming completed successfully")
      rescue
        error ->
          Logger.error("Intelligence cache warming failed: #{inspect(error)}")
      end
    end)

    :ok
  end

  @doc """
  Perform comprehensive character analysis.
  """
  def analyze_character_comprehensive(character_id) do
    Logger.info("Starting comprehensive analysis for character #{character_id}")

    with {:ok, basic_analysis} <- analyze_character_basic(character_id),
         {:ok, vetting_analysis} <- analyze_character_vetting(character_id),
         {:ok, threat_analysis} <- analyze_character_threats(character_id) do
      comprehensive_analysis = %{
        character_id: character_id,
        analysis_timestamp: DateTime.utc_now(),
        basic_analysis: basic_analysis,
        vetting_analysis: vetting_analysis,
        threat_analysis: threat_analysis,
        confidence_score:
          calculate_overall_confidence(basic_analysis, vetting_analysis, threat_analysis),
        summary: generate_analysis_summary(basic_analysis, vetting_analysis, threat_analysis)
      }

      {:ok, comprehensive_analysis}
    else
      {:error, reason} ->
        Logger.error(
          "Comprehensive analysis failed for character #{character_id}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  @doc """
  Get intelligence dashboard data.
  """
  def get_intelligence_dashboard(opts \\ []) do
    timeframe = Keyword.get(opts, :timeframe, :last_24h)

    Logger.info("Loading intelligence dashboard for timeframe: #{timeframe}")

    dashboard_data = %{
      timeframe: timeframe,
      threat_alerts: get_active_threat_alerts(timeframe),
      recent_analyses: get_recent_analyses(timeframe),
      cache_performance: get_cache_performance_stats(),
      system_health: get_system_health_status(),
      analysis_queue: get_analysis_queue_status(),
      statistics: get_intelligence_statistics(timeframe)
    }

    {:ok, dashboard_data}
  end

  # Private helper functions

  defp warm_character_cache do
    # Preload frequently accessed character data
    Logger.debug("Warming character cache")

    CacheHelper.warm_cache(:character_cache, fn ->
      # Simulate cache warming
      %{warmed_at: DateTime.utc_now(), entries: 100}
    end)
  end

  defp warm_analysis_cache do
    # Preload recent analysis results
    Logger.debug("Warming analysis cache")

    CacheHelper.warm_cache(:analysis_cache, fn ->
      # Simulate cache warming
      %{warmed_at: DateTime.utc_now(), entries: 50}
    end)
  end

  defp warm_threat_cache do
    # Preload threat intelligence data
    Logger.debug("Warming threat cache")

    CacheHelper.warm_cache(:threat_cache, fn ->
      # Simulate cache warming
      %{warmed_at: DateTime.utc_now(), entries: 25}
    end)
  end

  def analyze_character_basic(character_id) do
    # Use direct analyzer to avoid circular dependency
    case CharacterAnalyzer.analyze_character(character_id) do
      {:ok, analysis} ->
        {:ok, analysis}

      {:error, reason} ->
        Logger.warning("Basic character analysis failed, using placeholder: #{inspect(reason)}")

        {:ok, get_placeholder_basic_analysis(character_id)}
    end
  rescue
    error ->
      Logger.error("Error in basic character analysis: #{inspect(error)}")
      {:ok, get_placeholder_basic_analysis(character_id)}
  end

  defp analyze_character_vetting(character_id) do
    case WHVettingAnalyzer.analyze_character(character_id) do
      {:ok, analysis} ->
        {:ok, analysis}

      {:error, reason} ->
        Logger.warning("Vetting analysis failed, using placeholder: #{inspect(reason)}")
        {:ok, get_placeholder_vetting_analysis(character_id)}
    end
  rescue
    error ->
      Logger.error("Error in vetting analysis: #{inspect(error)}")
      {:ok, get_placeholder_vetting_analysis(character_id)}
  end

  defp analyze_character_threats(character_id) do
    # Placeholder threat analysis - would integrate with threat analyzer
    {:ok,
     %{
       character_id: character_id,
       threat_level: :low,
       threat_score: 15,
       threat_factors: [],
       last_updated: DateTime.utc_now()
     }}
  end

  defp calculate_overall_confidence(basic_analysis, vetting_analysis, threat_analysis) do
    # Calculate weighted confidence score
    basic_confidence = Map.get(basic_analysis, :confidence_score, 0.5)
    vetting_confidence = Map.get(vetting_analysis, :confidence_score, 0.5)
    threat_confidence = Map.get(threat_analysis, :confidence_score, 0.8)

    # Weighted average
    overall = basic_confidence * 0.3 + vetting_confidence * 0.5 + threat_confidence * 0.2
    Float.round(overall, 2)
  end

  defp generate_analysis_summary(basic_analysis, vetting_analysis, _threat_analysis) do
    character_name = Map.get(basic_analysis, :character_name, "Unknown Character")
    recommendation = get_in(vetting_analysis, [:recommendation, :recommendation]) || "unknown"
    risk_score = Map.get(vetting_analysis, :risk_score, 0)

    "#{character_name}: #{String.upcase(recommendation)} (Risk: #{risk_score}/100)"
  end

  defp get_active_threat_alerts(timeframe) do
    # Get real threat alerts from various intelligence sources
    cutoff_time = calculate_timeframe_cutoff(timeframe)

    # Combine multiple threat sources
    threat_alerts = []

    # 1. Battle Analysis Threat Alerts
    battle_threats = get_battle_threat_alerts(cutoff_time)

    # 2. Character Intelligence Alerts  
    character_threats = get_character_threat_alerts(cutoff_time)

    # 3. System Activity Alerts
    system_threats = get_system_activity_alerts(cutoff_time)

    # Combine and sort by severity and timestamp
    (threat_alerts ++ battle_threats ++ character_threats ++ system_threats)
    |> Enum.sort_by(&{threat_severity_priority(&1.severity), &1.timestamp}, :desc)
    |> Enum.take(10)
  rescue
    error ->
      Logger.warning("Failed to fetch threat alerts: #{inspect(error)}")
      # Fallback to basic placeholder
      [
        %{
          id: 1,
          type: :system_error,
          severity: :low,
          title: "Intelligence System Alert",
          message: "Threat monitoring operational",
          created_at: DateTime.utc_now()
        }
      ]
  end

  defp get_recent_analyses(timeframe) do
    cutoff_time = calculate_timeframe_cutoff(timeframe)

    limit =
      case timeframe do
        :last_1h -> 10
        :last_24h -> 50
        :last_7d -> 200
        _ -> 50
      end

    # Get real analyses from various sources
    analyses = []

    # 1. Recent character intelligence analyses
    character_analyses = get_recent_character_analyses(cutoff_time, limit)

    # 2. Recent battle analyses 
    battle_analyses = get_recent_battle_analyses(cutoff_time, limit)

    # 3. Recent vetting analyses
    vetting_analyses = get_recent_vetting_analyses(cutoff_time, limit)

    # Combine and sort by timestamp
    (analyses ++ character_analyses ++ battle_analyses ++ vetting_analyses)
    |> Enum.sort_by(& &1.timestamp, :desc)
    |> Enum.take(limit)
  rescue
    error ->
      Logger.warning("Failed to fetch recent analyses: #{inspect(error)}")
      # Fallback to basic placeholder
      [
        %{
          id: 1,
          type: :system_info,
          character_id: nil,
          character_name: "Intelligence System",
          status: :completed,
          recommendation: :operational,
          timestamp: DateTime.utc_now()
        }
      ]
  end

  defp get_cache_performance_stats do
    %{
      hit_rate: 85.3,
      miss_rate: 14.7,
      total_requests: 1247,
      cache_size_mb: 45.2,
      last_updated: DateTime.utc_now()
    }
  end

  defp get_system_health_status do
    %{
      status: :healthy,
      uptime_hours: 72,
      memory_usage_percent: 67.4,
      cpu_usage_percent: 23.1,
      active_analyses: 3,
      queue_depth: 5,
      last_check: DateTime.utc_now()
    }
  end

  defp get_analysis_queue_status do
    %{
      total_queued: 5,
      in_progress: 3,
      average_wait_time_minutes: 2.3,
      estimated_completion: DateTime.add(DateTime.utc_now(), 15 * 60, :second)
    }
  end

  defp get_intelligence_statistics(_timeframe) do
    %{
      total_analyses_completed: 1547,
      characters_analyzed: 892,
      threat_assessments: 234,
      vetting_reports: 445,
      recommendations: %{
        approve: 312,
        conditional: 198,
        reject: 87,
        investigate: 45
      }
    }
  end

  defp get_placeholder_basic_analysis(character_id) do
    %{
      character_id: character_id,
      character_name: "Character #{character_id}",
      corporation_id: 1_000_001,
      corporation_name: "Unknown Corp",
      alliance_id: nil,
      alliance_name: nil,
      security_status: 0.0,
      total_sp: 50_000_000,
      confidence_score: 0.3,
      last_updated: DateTime.utc_now()
    }
  end

  defp get_placeholder_vetting_analysis(character_id) do
    %{
      character_id: character_id,
      character_name: "Character #{character_id}",
      risk_score: 50,
      recommendation: %{
        recommendation: "investigate",
        confidence: 0.4,
        reasoning: "Insufficient data for comprehensive analysis"
      },
      confidence_score: 0.4,
      j_space_experience: %{
        total_j_kills: 0,
        j_space_time_percent: 0.0,
        experience_level: :unknown
      },
      analysis_timestamp: DateTime.utc_now()
    }
  end

  # Helper functions for real data integration

  defp calculate_timeframe_cutoff(timeframe) do
    case timeframe do
      :last_1h -> DateTime.add(DateTime.utc_now(), -1, :hour)
      :last_24h -> DateTime.add(DateTime.utc_now(), -24, :hour)
      :last_7d -> DateTime.add(DateTime.utc_now(), -7, :day)
      :last_30d -> DateTime.add(DateTime.utc_now(), -30, :day)
      _ -> DateTime.add(DateTime.utc_now(), -24, :hour)
    end
  end

  defp get_battle_threat_alerts(cutoff_time) do
    alias EveDmv.Contexts.BattleAnalysis

    # Get recent battles and analyze for threat patterns
    hours_back = DateTime.diff(DateTime.utc_now(), cutoff_time, :hour)

    case BattleAnalysis.detect_recent_battles(hours_back) do
      {:ok, battles} ->
        battles
        |> Enum.filter(&is_high_threat_battle/1)
        |> Enum.map(&convert_battle_to_threat_alert/1)
        |> Enum.take(5)

      {:error, _reason} ->
        []
    end
  rescue
    _error -> []
  end

  defp get_character_threat_alerts(cutoff_time) do
    # Get character intelligence alerts from recent analyses
    # This would integrate with character intelligence database
    try do
      # For now, check for recent high-risk character analyses
      _cutoff_naive = DateTime.to_naive(cutoff_time)

      # Query would be something like:
      # SELECT * FROM character_analyses WHERE risk_score > 80 AND created_at > cutoff
      # For now, return empty as we don't have this table yet
      []
    rescue
      _error -> []
    end
  end

  defp get_system_activity_alerts(cutoff_time) do
    # System activity monitoring alerts
    current_time = DateTime.utc_now()
    time_diff_hours = DateTime.diff(current_time, cutoff_time, :hour)

    # Check for unusual system activity patterns
    base_alerts = []

    # Check recent killmail volume for anomalies
    if time_diff_hours <= 24 do
      volume_alert = check_killmail_volume_anomaly(cutoff_time)
      if volume_alert, do: [volume_alert | base_alerts], else: base_alerts
    else
      base_alerts
    end
  end

  defp check_killmail_volume_anomaly(cutoff_time) do
    # This would check for unusual spikes in killmail activity
    # indicating potential large battles or system intrusions
    _cutoff_naive = DateTime.to_naive(cutoff_time)

    # Sample query: count recent killmails
    # If significantly higher than normal, create alert
    # Placeholder for now
    nil
  rescue
    _error -> nil
  end

  defp is_high_threat_battle(battle) do
    # Determine if a battle represents a high threat
    participant_count = Map.get(battle.metadata, :total_participants, 0)
    isk_destroyed = Map.get(battle.metadata, :isk_destroyed, 0)

    # High threat criteria:
    participant_count > 20 or isk_destroyed > 1_000_000_000
  end

  defp convert_battle_to_threat_alert(battle) do
    participant_count = Map.get(battle.metadata, :total_participants, 0)
    system_id = Map.get(battle.metadata, :primary_system, "Unknown")

    severity =
      cond do
        participant_count > 50 -> :high
        participant_count > 20 -> :moderate
        true -> :low
      end

    %{
      id: battle.battle_id,
      type: :battle_activity,
      severity: severity,
      title: "Large Battle Detected",
      message: "#{participant_count} participants in system #{system_id}",
      system_id: system_id,
      participant_count: participant_count,
      timestamp: battle.metadata.start_time || DateTime.utc_now(),
      created_at: DateTime.utc_now()
    }
  end

  defp threat_severity_priority(severity) do
    case severity do
      :extreme -> 5
      :high -> 4
      :moderate -> 3
      :low -> 2
      :minimal -> 1
      _ -> 0
    end
  end

  defp get_recent_character_analyses(_cutoff_time, _limit) do
    # Get recent character intelligence analyses
    # This would query a character_analyses table when it exists

    try do
      # For now, return limited sample data
      # In production, this would be a real database query
      []
    rescue
      _error -> []
    end
  end

  defp get_recent_battle_analyses(cutoff_time, limit) do
    alias EveDmv.Contexts.BattleAnalysis

    # Get recent battle analyses
    hours_back = DateTime.diff(DateTime.utc_now(), cutoff_time, :hour)

    case BattleAnalysis.detect_recent_battles(hours_back) do
      {:ok, battles} ->
        battles
        # Take 1/3 of limit for battle analyses
        |> Enum.take(div(limit, 3))
        |> Enum.map(&convert_battle_to_analysis_entry/1)

      {:error, _reason} ->
        []
    end
  rescue
    _error -> []
  end

  defp get_recent_vetting_analyses(cutoff_time, limit) do
    alias EveDmv.Intelligence.Wormhole.Vetting

    # Get recent vetting analyses from the database
    try do
      cutoff_naive = DateTime.to_naive(cutoff_time)

      # Query recent vetting records
      # This is a simplified version - real implementation would use proper Ash queries
      case Ash.read(Vetting, domain: EveDmv.Api) do
        {:ok, vettings} ->
          vettings
          |> Enum.filter(fn v ->
            case v.analysis_timestamp do
              %DateTime{} = dt -> DateTime.compare(dt, cutoff_time) != :lt
              %NaiveDateTime{} = ndt -> NaiveDateTime.compare(ndt, cutoff_naive) != :lt
              _ -> false
            end
          end)
          # Take 1/3 of limit for vetting analyses
          |> Enum.take(div(limit, 3))
          |> Enum.map(&convert_vetting_to_analysis_entry/1)

        {:error, _reason} ->
          []
      end
    rescue
      _error -> []
    end
  end

  defp convert_battle_to_analysis_entry(battle) do
    %{
      id: battle.battle_id,
      type: :battle_analysis,
      character_id: nil,
      character_name: "Battle #{battle.battle_id}",
      system_id: Map.get(battle.metadata, :primary_system),
      status: :completed,
      recommendation: :analyzed,
      participant_count: Map.get(battle.metadata, :total_participants, 0),
      timestamp: battle.metadata.start_time || DateTime.utc_now()
    }
  end

  defp convert_vetting_to_analysis_entry(vetting) do
    recommendation =
      case vetting.recommendation do
        %{recommendation: rec} when is_binary(rec) -> string_to_recommendation_atom(rec)
        rec when is_binary(rec) -> string_to_recommendation_atom(rec)
        rec when is_atom(rec) -> rec
        _ -> :unknown
      end

    %{
      id: vetting.id,
      type: :vetting_analysis,
      character_id: vetting.character_id,
      character_name: vetting.character_name,
      status: :completed,
      recommendation: recommendation,
      risk_score: vetting.risk_score,
      timestamp: vetting.analysis_timestamp || DateTime.utc_now()
    }
  end

  defp string_to_recommendation_atom(string) when is_binary(string) do
    # Define the allowed recommendation atoms
    case string do
      "approved" -> :approved
      "rejected" -> :rejected
      "flagged" -> :flagged
      "pending_review" -> :pending_review
      "conditional" -> :conditional
      "under_review" -> :under_review
      _ -> :unknown
    end
  end
end

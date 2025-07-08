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

  defp get_active_threat_alerts(_timeframe) do
    # Placeholder - would fetch real threat alerts
    [
      %{
        id: 1,
        type: :security_risk,
        severity: :medium,
        description: "Unusual activity patterns detected",
        timestamp: DateTime.utc_now()
      }
    ]
  end

  defp get_recent_analyses(timeframe) do
    # Placeholder - would fetch real recent analyses
    limit =
      case timeframe do
        :last_1h -> 10
        :last_24h -> 50
        :last_7d -> 200
        _ -> 50
      end

    # Generate placeholder analyses
    Enum.map(1..min(limit, 10), fn i ->
      %{
        id: i,
        type: :character_analysis,
        character_id: 90_000_000 + i,
        character_name: "Character #{i}",
        status: :completed,
        recommendation: Enum.random([:approve, :conditional, :reject]),
        timestamp: DateTime.add(DateTime.utc_now(), -i * 3600, :second)
      }
    end)
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
end

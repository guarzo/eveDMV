defmodule EveDmv.Contexts.CorporationIntelligence do
  @moduledoc """
  Context module for corporation intelligence and combat doctrine analysis.
  
  Provides the public API for corporation threat assessment, doctrine recognition,
  and tactical intelligence gathering.
  """
  
  alias EveDmv.Contexts.CorporationIntelligence.Domain.CombatDoctrineAnalyzer
  
  @doc """
  Analyzes a corporation's combat doctrines based on their killmail history.
  
  Identifies doctrine patterns such as:
  - Shield Kiting
  - Armor Brawling
  - EWAR Heavy
  - Capital Escalation
  - Alpha Strike
  - Nano Gang
  - Logistics Heavy
  
  ## Examples
  
      iex> CorporationIntelligence.analyze_combat_doctrines(corporation_id)
      {:ok, %{
        primary_doctrine: :shield_kiting,
        doctrine_confidence: 0.85,
        secondary_doctrines: [:nano_gang],
        fleet_compositions: [...],
        tactical_preferences: %{...}
      }}
  """
  def analyze_combat_doctrines(corporation_id, options \\ []) do
    case CombatDoctrineAnalyzer.analyze_combat_doctrines(corporation_id, options) do
      {:ok, analysis} -> {:ok, analysis}
      error -> error
    end
  end
  
  @doc """
  Compares combat doctrines between multiple corporations.
  
  Useful for identifying tactical advantages and vulnerabilities.
  """
  def compare_combat_doctrines(corporation_ids, options \\ []) when is_list(corporation_ids) do
    case CombatDoctrineAnalyzer.compare_combat_doctrines(corporation_ids, options) do
      {:ok, comparison} -> {:ok, comparison}
      error -> error
    end
  end
  
  @doc """
  Generates counter-doctrine recommendations against a target corporation.
  
  Analyzes the target's preferred doctrines and suggests effective counters.
  """
  def generate_counter_doctrine(target_corporation_id, options \\ []) do
    case CombatDoctrineAnalyzer.generate_counter_doctrine(target_corporation_id, options) do
      {:ok, recommendations} -> {:ok, recommendations}
      error -> error
    end
  end
  
  @doc """
  Tracks doctrine evolution over time for a corporation.
  
  Shows how tactics and fleet compositions have changed.
  """
  def track_doctrine_evolution(corporation_id, options \\ []) do
    case CombatDoctrineAnalyzer.track_doctrine_evolution(corporation_id, options) do
      {:ok, evolution} -> {:ok, evolution}
      error -> error
    end
  end
  
  @doc """
  Gets a comprehensive intelligence report for a corporation.
  
  Combines doctrine analysis, member threat assessments, and activity metrics.
  """
  def get_corporation_intelligence_report(corporation_id) do
    with {:ok, doctrine_analysis} <- analyze_combat_doctrines(corporation_id),
         {:ok, doctrine_evolution} <- track_doctrine_evolution(corporation_id),
         {:ok, member_threats} <- analyze_top_member_threats(corporation_id),
         {:ok, activity_metrics} <- calculate_activity_metrics(corporation_id),
         {:ok, corp_info} <- get_corporation_info(corporation_id) do
      {:ok, %{
        corporation: corp_info,
        doctrine_analysis: doctrine_analysis,
        doctrine_evolution: doctrine_evolution,
        member_threats: member_threats,
        activity_metrics: activity_metrics,
        summary: generate_intelligence_summary(doctrine_analysis, member_threats, activity_metrics)
      }}
    end
  end
  
  @doc """
  Analyzes threat levels of top members in a corporation.
  """
  def analyze_top_member_threats(_corporation_id, _limit \\ 10) do
    # In production, this would query corporation members and analyze their threat scores
    # For now, return mock data structure
    {:ok, %{
      top_threats: [],
      average_threat_score: 0,
      threat_distribution: %{
        extreme: 0,
        high: 0,
        moderate: 0,
        low: 0,
        minimal: 0
      }
    }}
  end
  
  @doc """
  Calculates activity metrics for a corporation.
  """
  def calculate_activity_metrics(_corporation_id, _days_back \\ 30) do
    # In production, this would calculate real metrics from killmail data
    {:ok, %{
      active_members: 0,
      kills_per_day: 0.0,
      prime_timezone: "Unknown",
      activity_trend: :stable,
      engagement_frequency: 0.0
    }}
  end
  
  # Private helper functions
  
  defp get_corporation_info(corporation_id) do
    # In production, this would query the corporation table or EVE API
    {:ok, %{
      corporation_id: corporation_id,
      name: "Corporation #{corporation_id}",
      ticker: "CORP",
      member_count: 0,
      alliance_id: nil,
      alliance_name: nil
    }}
  end
  
  defp generate_intelligence_summary(doctrine_analysis, member_threats, _activity_metrics) do
    primary_doctrine = Map.get(doctrine_analysis, :primary_doctrine, :unknown)
    doctrine_confidence = Map.get(doctrine_analysis, :doctrine_confidence, 0)
    avg_threat = Map.get(member_threats, :average_threat_score, 0)
    
    threat_level = cond do
      avg_threat >= 75 and doctrine_confidence > 0.7 -> "Very High"
      avg_threat >= 50 or doctrine_confidence > 0.8 -> "High"
      avg_threat >= 25 -> "Moderate"
      true -> "Low"
    end
    
    %{
      threat_level: threat_level,
      primary_doctrine: primary_doctrine,
      doctrine_confidence: doctrine_confidence,
      average_member_threat: avg_threat,
      summary: "#{threat_level} threat corporation specializing in #{format_doctrine_name(primary_doctrine)} doctrine",
      key_capabilities: extract_key_capabilities(doctrine_analysis),
      vulnerabilities: identify_vulnerabilities(doctrine_analysis),
      recommendations: generate_tactical_recommendations(doctrine_analysis, member_threats)
    }
  end
  
  defp format_doctrine_name(doctrine) do
    doctrine
    |> to_string()
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end
  
  defp extract_key_capabilities(doctrine_analysis) do
    doctrine = Map.get(doctrine_analysis, :primary_doctrine, :unknown)
    
    case doctrine do
      :shield_kiting -> ["Long range engagement", "High mobility", "Kiting tactics"]
      :armor_brawling -> ["Close range DPS", "Heavy tank", "Sustained combat"]
      :ewar_heavy -> ["Electronic warfare", "Force multiplication", "Disruption tactics"]
      :capital_escalation -> ["Capital ship deployment", "Escalation capability", "Heavy assets"]
      :alpha_strike -> ["High alpha damage", "Coordinated strikes", "Target elimination"]
      :nano_gang -> ["Hit and run tactics", "High speed", "Small gang warfare"]
      :logistics_heavy -> ["Strong logistics", "Sustained fights", "Defensive positioning"]
      _ -> ["Unknown capabilities"]
    end
  end
  
  defp identify_vulnerabilities(doctrine_analysis) do
    doctrine = Map.get(doctrine_analysis, :primary_doctrine, :unknown)
    
    case doctrine do
      :shield_kiting -> ["Vulnerable to fast tackle", "Weak in close range", "Capacitor dependent"]
      :armor_brawling -> ["Limited range", "Slow mobility", "Vulnerable to kiting"]
      :ewar_heavy -> ["DPS limited", "Requires coordination", "Vulnerable to alpha"]
      :capital_escalation -> ["Immobile assets", "Escalation trap risk", "Subcap dependent"]
      :alpha_strike -> ["Reload vulnerability", "Close range weakness", "Coordination dependent"]
      :nano_gang -> ["Low tank", "Numbers disadvantage", "Vulnerable to camps"]
      :logistics_heavy -> ["DPS limited", "Logistics vulnerable", "Slow positioning"]
      _ -> ["Doctrine not identified"]
    end
  end
  
  defp generate_tactical_recommendations(doctrine_analysis, member_threats) do
    doctrine = Map.get(doctrine_analysis, :primary_doctrine, :unknown)
    
    base_recommendations = case doctrine do
      :shield_kiting -> [
        "Use fast tackle to close range",
        "Employ damping/tracking disruption",
        "Force close-range engagement"
      ]
      :armor_brawling -> [
        "Maintain range control",
        "Use mobility advantage",
        "Avoid prolonged brawls"
      ]
      :ewar_heavy -> [
        "Focus fire on EWAR ships",
        "Use sensor boosters",
        "Bring ECCM support"
      ]
      :capital_escalation -> [
        "Avoid escalation traps",
        "Use hit-and-run tactics",
        "Target subcap support first"
      ]
      _ -> [
        "Gather more intelligence",
        "Assess doctrine patterns",
        "Prepare flexible response"
      ]
    end
    
    # Add recommendations based on member threats
    threat_recommendations = if member_threats.average_threat_score >= 50 do
      ["Exercise caution - skilled pilots", "Expect advanced tactics"]
    else
      []
    end
    
    base_recommendations ++ threat_recommendations
  end
end
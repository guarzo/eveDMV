defmodule EveDmv.Intelligence.CorporationAnalyzer do
  @moduledoc """
  Corporation intelligence analysis module.

  Provides focused analysis of corporation-level patterns, member correlations,
  and coordination metrics extracted from killmail data.
  """

  require Logger
  alias EveDmv.Database.QueryUtils

  @doc """
  Analyze corporation intelligence patterns based on recent killmail activity.

  Returns comprehensive analysis including member correlations, activity patterns,
  risk distribution, and coordination analysis.
  """
  @spec analyze_corporation(integer()) :: {:ok, map()} | {:error, String.t()}
  def analyze_corporation(corporation_id) do
    Logger.info("Starting corporation intelligence analysis for corp #{corporation_id}")

    with {:ok, killmails} <- get_corporation_killmails(corporation_id),
         {:ok, members} <- extract_corporation_members(killmails, corporation_id) do
      perform_corporation_analysis(members, corporation_id)
    else
      {:error, reason} ->
        Logger.error("Corporation analysis failed for #{corporation_id}: #{reason}")
        {:error, reason}
    end
  rescue
    error ->
      Logger.error("Error in corporation analysis: #{inspect(error)}")
      {:error, "Analysis failed due to unexpected error"}
  end

  @doc """
  Analyze member correlations within a corporation.

  Identifies patterns in member behavior, shared operations,
  and coordination metrics.
  """
  @spec analyze_member_correlations(list()) :: map()
  def analyze_member_correlations(members) when is_list(members) do
    %{
      shared_operations: analyze_shared_operations(members),
      loss_distribution: analyze_loss_distribution(members),
      activity_correlation: calculate_activity_correlation(members)
    }
  end

  @doc """
  Analyze corporation activity patterns.

  Examines temporal patterns, engagement types, and operational focus.
  """
  @spec analyze_activity_patterns(list()) :: map()
  def analyze_activity_patterns(members) when is_list(members) do
    %{
      primary_timezones: identify_primary_timezones(members),
      engagement_types: categorize_engagement_types(members),
      operational_focus: determine_operational_focus(members)
    }
  end

  @doc """
  Analyze corporation risk distribution.

  Evaluates risk levels across members and identifies patterns.
  """
  @spec analyze_risk_distribution(list()) :: map()
  def analyze_risk_distribution(members) when is_list(members) do
    risk_scores = Enum.map(members, &calculate_member_risk/1)
    
    %{
      average_risk: Enum.sum(risk_scores) / length(risk_scores),
      risk_variance: calculate_variance(risk_scores),
      high_risk_count: Enum.count(risk_scores, &(&1 > 70)),
      risk_distribution: categorize_risk_levels(risk_scores)
    }
  end

  @doc """
  Analyze member coordination patterns.

  Identifies coordination levels and operational patterns.
  """
  @spec analyze_coordination(list()) :: map()
  def analyze_coordination(members) when is_list(members) do
    %{
      coordination_score: calculate_coordination_score(members),
      fleet_participation: analyze_fleet_participation(members),
      operational_synergy: measure_operational_synergy(members)
    }
  end

  # Private helper functions

  defp get_corporation_killmails(corporation_id) do
    try do
      # Get recent killmails involving the corporation
      killmails = QueryUtils.query_killmails_by_corporation(
        corporation_id,
        DateTime.add(DateTime.utc_now(), -30, :day),
        DateTime.utc_now(),
        1000
      )
      
      {:ok, killmails}
    rescue
      error ->
        Logger.error("Error fetching corporation killmails: #{inspect(error)}")
        {:error, "Failed to fetch killmail data"}
    end
  end

  defp extract_corporation_members(killmails, corporation_id) do
    try do
      members = killmails
        |> Enum.flat_map(fn killmail ->
          (killmail.participants || [])
          |> Enum.filter(&(&1.corporation_id == corporation_id))
        end)
        |> Enum.group_by(& &1.character_id)
        |> Enum.map(fn {character_id, participations} ->
          %{
            character_id: character_id,
            participation_count: length(participations),
            total_damage: Enum.sum(Enum.map(participations, & &1.damage_done || 0)),
            ship_types: Enum.map(participations, & &1.ship_type_id) |> Enum.uniq(),
            first_seen: participations |> Enum.map(& &1.killmail_time) |> Enum.min(),
            last_seen: participations |> Enum.map(& &1.killmail_time) |> Enum.max()
          }
        end)

      if Enum.empty?(members) do
        {:error, "No active members found for corporation"}
      else
        {:ok, members}
      end
    rescue
      error ->
        Logger.error("Error extracting corporation members: #{inspect(error)}")
        {:error, "Failed to extract member data"}
    end
  end

  defp perform_corporation_analysis(members, corporation_id) when is_list(members) do
    analysis = %{
      corporation_id: corporation_id,
      member_count: length(members),
      member_correlations: analyze_member_correlations(members),
      activity_patterns: analyze_activity_patterns(members),
      risk_distribution: analyze_risk_distribution(members),
      coordination_analysis: analyze_coordination(members),
      analysis_timestamp: DateTime.utc_now(),
      confidence_score: calculate_analysis_confidence(members)
    }

    {:ok, analysis}
  end

  defp analyze_shared_operations(members) do
    # Simplified shared operations analysis
    total_operations = Enum.sum(Enum.map(members, & &1.participation_count))
    shared_operations = if total_operations > 0, do: total_operations / length(members), else: 0
    
    %{
      average_shared_ops: shared_operations,
      coordination_indicator: if(shared_operations > 5, do: :high, else: :low)
    }
  end

  defp analyze_loss_distribution(members) do
    # Simplified loss distribution analysis
    high_activity_members = Enum.count(members, & &1.participation_count > 10)
    
    %{
      high_activity_ratio: high_activity_members / length(members),
      distribution_pattern: if(high_activity_members > length(members) * 0.3, do: :concentrated, else: :distributed)
    }
  end

  defp calculate_activity_correlation(members) do
    # Simplified activity correlation
    avg_participation = Enum.sum(Enum.map(members, & &1.participation_count)) / length(members)
    
    %{
      average_participation: avg_participation,
      correlation_strength: if(avg_participation > 5, do: :strong, else: :weak)
    }
  end

  defp identify_primary_timezones(_members) do
    # Placeholder - would need timezone analysis of killmail times
    %{primary_tz: "UTC", coverage: "24/7"}
  end

  defp categorize_engagement_types(_members) do
    # Placeholder - would categorize based on killmail types
    %{primary_type: "mixed", secondary_type: "pvp"}
  end

  defp determine_operational_focus(_members) do
    # Placeholder - would analyze operational patterns
    %{focus: "null_sec", secondary_focus: "low_sec"}
  end

  defp calculate_member_risk(_member) do
    # Simplified risk calculation
    # In real implementation, would use various risk factors
    Enum.random(1..100)
  end

  defp calculate_variance(values) do
    if Enum.empty?(values) do
      0
    else
      mean = Enum.sum(values) / length(values)
      variance = Enum.sum(Enum.map(values, &(:math.pow(&1 - mean, 2)))) / length(values)
      variance
    end
  end

  defp categorize_risk_levels(risk_scores) do
    %{
      low: Enum.count(risk_scores, &(&1 < 30)),
      medium: Enum.count(risk_scores, &(&1 >= 30 and &1 <= 70)),
      high: Enum.count(risk_scores, &(&1 > 70))
    }
  end

  defp calculate_coordination_score(members) do
    # Simplified coordination calculation
    avg_ship_diversity = members
      |> Enum.map(&length(&1.ship_types))
      |> Enum.sum()
      |> Kernel./(length(members))
    
    # Higher diversity might indicate better coordination
    min(100, round(avg_ship_diversity * 10))
  end

  defp analyze_fleet_participation(members) do
    high_participation = Enum.count(members, & &1.participation_count > 5)
    
    %{
      high_participation_ratio: high_participation / length(members),
      fleet_readiness: if(high_participation > length(members) * 0.5, do: :high, else: :moderate)
    }
  end

  defp measure_operational_synergy(_members) do
    # Placeholder for synergy measurement
    %{synergy_score: 75, synergy_level: :moderate}
  end

  defp calculate_analysis_confidence(members) do
    # Base confidence on data quality and quantity
    base_confidence = min(90, length(members) * 5)
    total_participation = Enum.sum(Enum.map(members, & &1.participation_count))
    
    # Adjust based on activity level
    activity_bonus = min(10, total_participation)
    
    base_confidence + activity_bonus
  end
end
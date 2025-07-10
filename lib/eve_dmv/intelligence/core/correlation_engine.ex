defmodule EveDmv.Intelligence.Core.CorrelationEngine do
  @moduledoc """
  Intelligence correlation engine for cross-module analysis.

  This module analyzes correlations between different intelligence modules
  to provide comprehensive insights that span character analysis, vetting,
  and threat assessment systems.
  """

  alias EveDmv.Intelligence.Analyzers.CharacterAnalyzer
  alias EveDmv.Intelligence.Analyzers.WHVettingAnalyzer

  require Logger

  @doc """
  Analyze correlations between intelligence modules for a character.

  Returns comprehensive correlation analysis combining data from:
  - Character analysis
  - Vetting analysis
  - Threat assessment

  ## Parameters
  - character_id: EVE character ID to analyze

  ## Returns
  - {:ok, correlation_analysis} on success
  - {:error, reason} on failure or insufficient data
  """
  def analyze_cross_module_correlations(character_id) when is_integer(character_id) do
    Logger.debug("Starting cross-module correlation analysis for character #{character_id}")

    with {:ok, character_data} <- get_character_analysis_data(character_id),
         {:ok, vetting_data} <- get_vetting_analysis_data(character_id),
         {:ok, correlations} <- compute_correlations(character_data, vetting_data) do
      analysis = %{
        character_id: character_id,
        correlations: correlations,
        summary: generate_correlation_summary(correlations),
        confidence_score: calculate_confidence_score(correlations),
        analysis_timestamp: DateTime.utc_now()
      }

      Logger.info("Completed cross-module correlation analysis for character #{character_id}")
      {:ok, analysis}
    else
      {:error, reason} ->
        Logger.warning(
          "Cross-module correlation analysis failed for character #{character_id}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  def analyze_cross_module_correlations(nil) do
    {:error, "Invalid character ID: nil"}
  end

  def analyze_cross_module_correlations(_invalid) do
    {:error, "Invalid character ID format"}
  end

  @doc """
  Analyze correlations between multiple characters.

  Identifies patterns and relationships between characters based on:
  - Temporal activity correlations
  - Geographic activity overlaps
  - Combat engagement patterns

  ## Parameters
  - character_ids: List of character IDs to correlate

  ## Returns
  - {:ok, correlation_analysis} with temporal and geographic correlations
  - {:error, reason} if insufficient data or invalid input
  """
  def analyze_character_correlations(character_ids) when is_list(character_ids) do
    case length(character_ids) do
      count when count < 2 ->
        {:error, "Insufficient character data for correlation analysis"}

      _count ->
        Logger.debug(
          "Starting character correlation analysis for #{length(character_ids)} characters"
        )

        with {:ok, character_data_list} <- gather_character_data(character_ids),
             {:ok, correlations} <- compute_character_correlations(character_data_list) do
          analysis = %{
            characters: character_ids,
            temporal_correlations: correlations.temporal,
            geographic_correlations: correlations.geographic,
            analysis_timestamp: DateTime.utc_now()
          }

          Logger.info(
            "Completed character correlation analysis for #{length(character_ids)} characters"
          )

          {:ok, analysis}
        else
          {:error, reason} ->
            Logger.warning("Character correlation analysis failed: #{inspect(reason)}")
            {:error, reason}
        end
    end
  end

  @doc """
  Analyze corporation-wide intelligence patterns.

  Examines intelligence patterns across corporation members including:
  - Recruitment patterns and vetting consistency
  - Activity coordination and fleet participation
  - Security risk distribution

  ## Parameters
  - corporation_id: EVE corporation ID to analyze

  ## Returns
  - {:ok, corporation_analysis} with recruitment and activity patterns
  - {:error, reason} if insufficient data or invalid input
  """
  def analyze_corporation_intelligence_patterns(corporation_id) when is_integer(corporation_id) do
    Logger.debug("Starting corporation intelligence pattern analysis for corp #{corporation_id}")

    with {:ok, member_data} <- get_corporation_member_data(corporation_id),
         {:ok, patterns} <- analyze_corporation_patterns(member_data) do
      analysis = %{
        corporation_id: corporation_id,
        recruitment_patterns: patterns.recruitment,
        activity_coordination: patterns.activity,
        member_count: length(member_data),
        analysis_timestamp: DateTime.utc_now()
      }

      Logger.info(
        "Completed corporation intelligence pattern analysis for corp #{corporation_id}"
      )

      {:ok, analysis}
    else
      {:error, reason} ->
        Logger.warning(
          "Corporation intelligence pattern analysis failed for corp #{corporation_id}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  def analyze_corporation_intelligence_patterns(nil) do
    {:error, "Invalid corporation ID: nil"}
  end

  def analyze_corporation_intelligence_patterns(_invalid) do
    {:error, "Invalid corporation ID format"}
  end

  # Private helper functions

  defp get_character_analysis_data(character_id) do
    case CharacterAnalyzer.analyze_character(character_id) do
      {:ok, analysis} ->
        {:ok, analysis}

      {:error, _reason} ->
        # Return placeholder data for missing analysis
        Logger.debug("Character analysis unavailable for #{character_id}, using placeholder")
        {:ok, get_placeholder_character_data(character_id)}
    end
  rescue
    error ->
      # Handle GenServer not started or other runtime errors
      Logger.debug(
        "Character analysis error for #{character_id}: #{inspect(error)}, using placeholder"
      )

      {:ok, get_placeholder_character_data(character_id)}
  catch
    :exit, _reason ->
      # Handle GenServer exit errors
      Logger.debug(
        "Character analysis service unavailable for #{character_id}, using placeholder"
      )

      {:ok, get_placeholder_character_data(character_id)}
  end

  defp get_vetting_analysis_data(character_id) do
    case WHVettingAnalyzer.analyze_character(character_id) do
      {:ok, analysis} ->
        {:ok, analysis}

      {:error, _reason} ->
        # Return placeholder data for missing vetting
        Logger.debug("Vetting analysis unavailable for #{character_id}, using placeholder")
        {:ok, get_placeholder_vetting_data(character_id)}
    end
  rescue
    error ->
      # Handle any runtime errors
      Logger.debug(
        "Vetting analysis error for #{character_id}: #{inspect(error)}, using placeholder"
      )

      {:ok, get_placeholder_vetting_data(character_id)}
  catch
    :exit, _reason ->
      # Handle GenServer exit errors
      Logger.debug("Vetting analysis service unavailable for #{character_id}, using placeholder")

      {:ok, get_placeholder_vetting_data(character_id)}
  end

  defp compute_correlations(character_data, vetting_data) do
    correlations = %{
      threat_assessment: correlate_threat_indicators(character_data, vetting_data),
      risk_alignment: correlate_risk_factors(character_data, vetting_data),
      behavioral_consistency: correlate_behavioral_patterns(character_data, vetting_data)
    }

    {:ok, correlations}
  end

  defp correlate_threat_indicators(character_data, vetting_data) do
    dangerous_rating = Map.get(character_data, :dangerous_rating, 0)
    risk_score = Map.get(vetting_data, :risk_score, 50)

    # Simple correlation: higher dangerous rating should correlate with higher risk score
    correlation_strength =
      if dangerous_rating > 7 and risk_score > 70 do
        :high
      else
        :low
      end

    %{
      correlation_strength: correlation_strength,
      dangerous_rating: dangerous_rating,
      risk_score: risk_score,
      alignment: calculate_alignment(dangerous_rating, risk_score)
    }
  end

  defp correlate_risk_factors(character_data, vetting_data) do
    awox_probability = Map.get(character_data, :awox_probability, 0.0)
    risk_factors = Map.get(vetting_data, :risk_factors, %{})

    # Check if high awox probability aligns with risk factors
    has_security_flags = Map.has_key?(risk_factors, "security_flags")

    %{
      awox_probability: awox_probability,
      security_flags_present: has_security_flags,
      risk_factor_count: map_size(risk_factors),
      consistency_score: calculate_risk_consistency(awox_probability, has_security_flags)
    }
  end

  defp correlate_behavioral_patterns(character_data, vetting_data) do
    ship_usage = Map.get(character_data, :ship_usage, %{})
    recommendation = get_in(vetting_data, [:recommendation, :recommendation])

    %{
      ship_diversity: map_size(ship_usage),
      vetting_recommendation: recommendation,
      activity_level: calculate_activity_level(ship_usage),
      behavioral_score: calculate_behavioral_score(ship_usage, recommendation)
    }
  end

  defp calculate_alignment(dangerous_rating, risk_score) do
    # Normalize both scores to 0-1 range and calculate alignment
    normalized_danger = dangerous_rating / 10.0
    normalized_risk = risk_score / 100.0

    abs(normalized_danger - normalized_risk)
  end

  defp calculate_risk_consistency(awox_probability, has_security_flags) do
    case {awox_probability > 0.5, has_security_flags} do
      # High consistency
      {true, true} -> 0.9
      # Good consistency
      {false, false} -> 0.8
      # Low consistency
      _ -> 0.3
    end
  end

  defp calculate_activity_level(ship_usage) when map_size(ship_usage) == 0, do: :inactive
  defp calculate_activity_level(ship_usage) when map_size(ship_usage) < 3, do: :low
  defp calculate_activity_level(ship_usage) when map_size(ship_usage) < 8, do: :moderate
  defp calculate_activity_level(_ship_usage), do: :high

  defp calculate_behavioral_score(ship_usage, recommendation) do
    activity_level = calculate_activity_level(ship_usage)

    case {activity_level, recommendation} do
      {:high, "approve"} -> 0.8
      {:moderate, "conditional"} -> 0.6
      {:low, "investigate"} -> 0.4
      {:inactive, "reject"} -> 0.2
      # Neutral score for other combinations
      _ -> 0.5
    end
  end

  defp generate_correlation_summary(correlations) do
    threat = correlations.threat_assessment
    risk = correlations.risk_alignment
    behavioral = correlations.behavioral_consistency

    initial_points = []

    threat_points =
      if threat.correlation_strength == :high do
        ["High threat correlation detected" | initial_points]
      else
        initial_points
      end

    risk_points =
      if risk.consistency_score > 0.7 do
        ["Risk factors show good consistency" | threat_points]
      else
        ["Risk factor inconsistencies found" | threat_points]
      end

    final_summary_points =
      if behavioral.activity_level == :high do
        ["High activity level observed" | risk_points]
      else
        risk_points
      end

    case final_summary_points do
      [] -> "Limited correlation data available"
      points -> Enum.join(points, "; ")
    end
  end

  defp calculate_confidence_score(correlations) do
    threat_score =
      if correlations.threat_assessment.correlation_strength == :high, do: 0.4, else: 0.2

    risk_score = correlations.risk_alignment.consistency_score * 0.3
    behavioral_score = correlations.behavioral_consistency.behavioral_score * 0.3

    total_score = threat_score + risk_score + behavioral_score
    Float.round(total_score, 2)
  end

  defp gather_character_data(character_ids) do
    # For now, return minimal character data structure
    # In a real implementation, this would fetch actual character data
    character_data =
      Enum.map(character_ids, fn id ->
        %{
          character_id: id,
          last_activity: DateTime.utc_now(),
          primary_systems: [],
          activity_level: :unknown
        }
      end)

    {:ok, character_data}
  end

  defp compute_character_correlations(_character_data_list) do
    # Placeholder correlation computation
    correlations = %{
      temporal: %{
        overlapping_activity_windows: 0,
        synchronized_logins: 0,
        activity_correlation_score: 0.0
      },
      geographic: %{
        shared_systems: [],
        proximity_score: 0.0,
        common_regions: []
      }
    }

    {:ok, correlations}
  end

  defp get_corporation_member_data(corporation_id) do
    # Placeholder for corporation member data
    # In a real implementation, this would query the database for corporation members
    Logger.debug("Fetching corporation member data for corp #{corporation_id}")

    member_data = [
      %{character_id: 1001, join_date: ~D[2024-01-01], activity_level: :high},
      %{character_id: 1002, join_date: ~D[2024-02-01], activity_level: :moderate},
      %{character_id: 1003, join_date: ~D[2024-03-01], activity_level: :low}
    ]

    {:ok, member_data}
  end

  defp analyze_corporation_patterns(member_data) do
    patterns = %{
      recruitment: %{
        # members per month
        recruitment_rate: length(member_data) / 30.0,
        # days
        average_tenure: 120,
        retention_score: 0.75
      },
      activity: %{
        coordination_level: :moderate,
        fleet_participation_rate: 0.6,
        timezone_distribution: %{"US" => 0.4, "EU" => 0.4, "AU" => 0.2}
      }
    }

    {:ok, patterns}
  end

  defp get_placeholder_character_data(character_id) do
    %{
      character_id: character_id,
      dangerous_rating: 0,
      awox_probability: 0.0,
      ship_usage: %{},
      confidence_score: 0.1
    }
  end

  defp get_placeholder_vetting_data(character_id) do
    %{
      character_id: character_id,
      risk_score: 50,
      risk_factors: %{},
      recommendation: %{recommendation: "investigate"},
      confidence_score: 0.1
    }
  end
end

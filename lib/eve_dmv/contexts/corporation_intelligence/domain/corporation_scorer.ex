defmodule EveDmv.Contexts.CorporationIntelligence.Domain.CorporationScorer do
  @moduledoc """
  Handles scoring and ranking operations for corporations.

  This module provides functions for:
  - Generating composite scores for corporations
  - Creating rankings based on various metrics
  - Calculating weighted scores from multiple data sources

  Scoring weights are configurable and documented to ensure transparency
  in how corporations are evaluated.
  """

  @doc """
  Generates rankings for multiple corporations based on composite scores.

  Returns a list of ranking maps sorted by score (descending), with ranks starting at 1.

  ## Parameters

    - corporations_data: Map of corporation_id => %{base_analysis: ..., performance: ...}

  ## Returns

    - List of ranking maps with :rank, :corporation_id, and :score keys
  """
  @spec generate_rankings(map()) :: [map()]
  def generate_rankings(corporations_data) do
    corporations_data
    |> Enum.map(fn {corp_id, data} ->
      score = calculate_composite_score(data)
      {corp_id, score}
    end)
    |> Enum.sort_by(fn {_, score} -> score end, :desc)
    |> Enum.with_index(1)
    |> Enum.map(fn {{corp_id, score}, rank} ->
      %{rank: rank, corporation_id: corp_id, score: Float.round(score, 1)}
    end)
  end

  @doc """
  Calculates a composite score for a corporation.

  The composite score combines:
  - Base metrics (40% weight): coordination score and member count
  - Performance metrics (60% weight): ISK efficiency and K/D ratio

  ## Parameters

    - data: Map with :base_analysis and :performance keys containing analysis data

  ## Returns

    - Float score between 0.0 and 100.0

  ## Scoring Weights

  The scoring system uses the following weights based on PvP effectiveness research:

  - **Performance (60%)**: More heavily weighted as it reflects actual combat effectiveness
    - ISK efficiency: Direct measure of resource destruction vs loss
    - K/D ratio: Normalized to 100 scale (ratio * 20, capped at 100)
  - **Base metrics (40%)**: Foundation metrics for organizational health
    - Coordination score: Measures member synergy and teamwork
    - Member count: Capped at 100 to avoid over-weighting large corps
  """
  @spec calculate_composite_score(map()) :: float()
  def calculate_composite_score(data) do
    base_score = calculate_base_score(data)
    performance_score = calculate_performance_score(data)

    # Weighted combination: 40% base, 60% performance
    base_score * 0.4 + performance_score * 0.6
  end

  @doc """
  Calculates the base score component from organization metrics.

  ## Parameters

    - data: Map with :base_analysis key containing analysis data

  ## Returns

    - Float score between 0.0 and 100.0
  """
  @spec calculate_base_score(map()) :: float()
  def calculate_base_score(data) do
    if data[:base_analysis] do
      coordination =
        get_in(data, [:base_analysis, :coordination_analysis, :coordination_score]) || 0

      # Cap member count contribution at 100
      members = min(get_in(data, [:base_analysis, :member_count]) || 0, 100)
      (coordination + members) / 2
    else
      0.0
    end
  end

  @doc """
  Calculates the performance score component from efficiency metrics.

  ## Parameters

    - data: Map with :performance key containing efficiency metrics

  ## Returns

    - Float score between 0.0 and 100.0
  """
  @spec calculate_performance_score(map()) :: float()
  def calculate_performance_score(data) do
    if data[:performance] do
      efficiency = get_in(data, [:performance, :efficiency_metrics, :isk_efficiency]) || 0

      # Normalize K/D ratio: multiply by 20, cap at 100
      # A K/D ratio of 5.0 results in a score of 100
      kd_ratio = get_in(data, [:performance, :efficiency_metrics, :kill_death_ratio]) || 0
      normalized_kd = min(kd_ratio * 20, 100)

      (efficiency + normalized_kd) / 2
    else
      0.0
    end
  end
end

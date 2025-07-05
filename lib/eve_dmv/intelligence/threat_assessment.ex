defmodule EveDmv.Intelligence.ThreatAssessment do
  @moduledoc """
  Threat assessment module for advanced intelligence analysis.

  Provides comprehensive threat evaluation capabilities including combat effectiveness,
  tactical sophistication, intelligence gathering capabilities, network influence,
  and operational security assessment with mitigation strategy recommendations.
  """

  require Logger
  require Ash.Query
  alias EveDmv.Api
  alias EveDmv.Intelligence.CharacterStats

  @doc """
  Assess combat effectiveness of a character.

  Evaluates kill efficiency and combat performance metrics.
  """
  def assess_combat_effectiveness(character_id) do
    case get_character_stats(character_id) do
      {:ok, [stats]} ->
        kill_efficiency =
          if (stats.total_losses || 0) > 0 do
            (stats.total_kills || 0) / (stats.total_losses || 0)
          else
            stats.total_kills || 0
          end

        # Normalize to 0-1 scale
        min(1.0, kill_efficiency / 3.0)

      _ ->
        0.0
    end
  end

  @doc """
  Assess tactical sophistication based on ship usage and coordination patterns.

  Evaluates ship diversity and gang coordination capabilities.
  """
  def assess_tactical_sophistication(character_id) do
    case get_character_stats(character_id) do
      {:ok, [stats]} ->
        # Based on ship diversity and gang size patterns
        ship_diversity =
          if stats.ship_usage do
            map_size(stats.ship_usage) / 10.0
          else
            0.0
          end

        gang_sophistication =
          if (stats.avg_gang_size || 1.0) > 1.0 do
            min(1.0, (stats.avg_gang_size || 1.0) / 10.0)
          else
            0.0
          end

        (ship_diversity + gang_sophistication) / 2.0

      _ ->
        0.0
    end
  end

  @doc """
  Assess intelligence gathering capabilities.

  Evaluates scanning ship usage and exploration activity patterns.
  """
  def assess_intelligence_capabilities(character_id) do
    case get_character_stats(character_id) do
      {:ok, [stats]} ->
        # Assess based on scanning ships and exploration activity
        if stats.ship_usage do
          scanning_ships = ["Astero", "Stratios", "Anathema", "Buzzard", "Cheetah", "Helios"]

          scanning_usage =
            Enum.filter(stats.ship_usage, fn {ship, _} ->
              Enum.any?(scanning_ships, &String.contains?(ship, &1))
            end)

          min(1.0, length(scanning_usage) / 3.0)
        else
          0.0
        end

      _ ->
        0.0
    end
  end

  @doc """
  Assess network influence and leadership indicators.

  Evaluates activity levels and gang leadership patterns.
  """
  def assess_network_influence(character_id) do
    case get_character_stats(character_id) do
      {:ok, [stats]} ->
        # Assess based on kill participation and leadership indicators
        activity_influence = min(1.0, (stats.total_kills || 0) / 100.0)
        gang_leadership = if (stats.avg_gang_size || 1.0) > 3.0, do: 0.3, else: 0.0

        activity_influence * 0.7 + gang_leadership

      _ ->
        0.0
    end
  end

  @doc """
  Assess operational security based on survival patterns.

  Evaluates loss patterns and ship choices for opsec indicators.
  """
  def assess_operational_security(character_id) do
    case get_character_stats(character_id) do
      {:ok, [stats]} ->
        # Assess based on loss patterns and ship choices
        survival_rate =
          if (stats.total_kills || 0) + (stats.total_losses || 0) > 0 do
            (stats.total_kills || 0) / ((stats.total_kills || 0) + (stats.total_losses || 0))
          else
            0.5
          end

        # Higher survival rate indicates better opsec
        survival_rate

      _ ->
        0.0
    end
  end

  @doc """
  Calculate composite threat score from multiple indicators.

  Applies weighted scoring to different threat aspects.
  """
  def calculate_composite_threat_score(threat_indicators) do
    # Weight different threat aspects
    weights = %{
      combat_effectiveness: 0.3,
      tactical_sophistication: 0.25,
      intelligence_gathering: 0.2,
      network_influence: 0.15,
      operational_security: 0.1
    }

    weighted_score =
      Enum.reduce(threat_indicators, 0.0, fn {indicator, score}, acc ->
        weight = Map.get(weights, indicator, 0.0)
        acc + score * weight
      end)

    Float.round(weighted_score, 2)
  end

  @doc """
  Categorize threat level based on composite score.

  Returns threat level classification.
  """
  def categorize_threat_level(threat_score) do
    cond do
      threat_score >= 0.8 -> "critical"
      threat_score >= 0.6 -> "high"
      threat_score >= 0.4 -> "medium"
      threat_score >= 0.2 -> "low"
      true -> "minimal"
    end
  end

  @doc """
  Suggest mitigation strategies based on threat level and indicators.

  Provides actionable security recommendations.
  """
  def suggest_mitigation_strategies(threat_level, threat_indicators) do
    base_strategies =
      case threat_level do
        "critical" -> ["Reject application", "Monitor all activities", "Alert security team"]
        "high" -> ["Restricted access", "Enhanced monitoring", "Regular reviews"]
        "medium" -> ["Standard monitoring", "Periodic reviews"]
        "low" -> ["Basic monitoring"]
        _ -> ["Standard procedures"]
      end

    # Add specific strategies based on indicators
    base_strategies
    |> maybe_add_strategy(
      threat_indicators.combat_effectiveness > 0.7,
      "Combat threat protocols"
    )
    |> maybe_add_strategy(
      threat_indicators.intelligence_gathering > 0.6,
      "Counter-intelligence measures"
    )
  end

  # Private helper functions

  defp maybe_add_strategy(strategies, true, strategy) do
    [strategy | strategies]
  end

  defp maybe_add_strategy(strategies, false, _strategy) do
    strategies
  end

  defp get_character_stats(character_id) do
    CharacterStats
    |> Ash.Query.filter(character_id == ^character_id)
    |> Ash.read(domain: Api)
  end
end

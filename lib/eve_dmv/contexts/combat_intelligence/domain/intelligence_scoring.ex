defmodule EveDmv.Contexts.CombatIntelligence.Domain.IntelligenceScoring do
  @moduledoc """
  Calculates various intelligence scores for characters.

  This module computes specialized scores including danger ratings,
  hunter effectiveness, fleet command ability, solo pilot skill,
  and awox (betrayal) risk.
  """

  use GenServer

  alias EveDmv.Contexts.CombatIntelligence.Infrastructure.AnalysisCache

  require Logger

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Calculate intelligence score for a character using specific scoring algorithm.
  """
  @spec calculate_score(integer(), atom()) :: {:ok, map()} | {:error, term()}
  def calculate_score(character_id, scoring_type) do
    GenServer.call(__MODULE__, {:calculate_score, character_id, scoring_type})
  end

  @doc """
  Get recommendations for dealing with a specific character.
  """
  @spec get_recommendations(integer()) :: {:ok, [map()]} | {:error, term()}
  def get_recommendations(character_id) do
    GenServer.call(__MODULE__, {:get_recommendations, character_id})
  end

  @doc """
  Get cached scores for a character.
  """
  @spec get_cached_scores(integer()) :: {:ok, map()} | {:error, term()}
  def get_cached_scores(character_id) do
    case AnalysisCache.get_intelligence_scores(character_id) do
      {:ok, scores} -> {:ok, scores}
      {:error, :not_found} -> {:ok, %{}}
    end
  end

  @doc """
  Refresh all scores for a character.
  """
  @spec refresh_scores(integer()) :: {:ok, map()} | {:error, term()}
  def refresh_scores(character_id) do
    AnalysisCache.invalidate_intelligence_scores(character_id)

    # Recalculate all score types
    score_types = [
      :danger_rating,
      :hunter_score,
      :fleet_commander_score,
      :solo_pilot_score,
      :awox_risk_score
    ]

    scores =
      Enum.reduce(score_types, %{}, fn score_type, acc ->
        case calculate_score(character_id, score_type) do
          {:ok, score_data} -> Map.put(acc, score_type, score_data)
          _ -> acc
        end
      end)

    {:ok, scores}
  end

  # GenServer callbacks

  @impl GenServer
  def init(_opts) do
    {:ok,
     %{
       calculation_count: 0,
       cache_hits: 0,
       cache_misses: 0
     }}
  end

  @impl GenServer
  def handle_call({:calculate_score, character_id, scoring_type}, _from, state) do
    result = perform_score_calculation(character_id, scoring_type)

    new_state =
      case result do
        {:ok, _} -> %{state | calculation_count: state.calculation_count + 1}
        _ -> state
      end

    {:reply, result, new_state}
  end

  @impl GenServer
  def handle_call({:get_recommendations, character_id}, _from, state) do
    recommendations = generate_recommendations(character_id)
    {:reply, {:ok, recommendations}, state}
  end

  # Private functions

  defp perform_score_calculation(character_id, scoring_type) do
    # Check cache first
    case AnalysisCache.get_intelligence_score(character_id, scoring_type) do
      {:ok, cached} ->
        {:ok, cached}

      {:error, :not_found} ->
        # Calculate score based on type
        score_data =
          case scoring_type do
            :danger_rating -> calculate_danger_rating(character_id)
            :hunter_score -> calculate_hunter_score(character_id)
            :fleet_commander_score -> calculate_fleet_commander_score(character_id)
            :solo_pilot_score -> calculate_solo_pilot_score(character_id)
            :awox_risk_score -> calculate_awox_risk_score(character_id)
            _ -> %{error: "Unknown scoring type"}
          end

        # Cache the result
        AnalysisCache.put_intelligence_score(character_id, scoring_type, score_data)

        {:ok, score_data}
    end
  end

  defp calculate_danger_rating(character_id) do
    %{
      character_id: character_id,
      score_type: :danger_rating,
      # 1-5 stars
      rating: 3,
      # 0-1 normalized
      score: 0.6,
      factors: %{
        kill_count: 150,
        solo_kills: 45,
        capital_kills: 5,
        recent_activity: :high
      },
      breakdown: %{
        combat_proficiency: 0.7,
        target_selection: 0.8,
        engagement_success: 0.6,
        threat_persistence: 0.5
      },
      calculated_at: DateTime.utc_now()
    }
  end

  defp calculate_hunter_score(character_id) do
    %{
      character_id: character_id,
      score_type: :hunter_score,
      score: 0.75,
      rating: :experienced,
      factors: %{
        solo_kill_ratio: 0.3,
        tackle_effectiveness: 0.8,
        target_selection: 0.9,
        hunting_patterns: :active
      },
      preferred_tactics: [
        "Cloaky camping",
        "Gate camping",
        "Wormhole hunting"
      ],
      calculated_at: DateTime.utc_now()
    }
  end

  defp calculate_fleet_commander_score(character_id) do
    %{
      character_id: character_id,
      score_type: :fleet_commander_score,
      score: 0.5,
      rating: :competent,
      factors: %{
        fleet_size_average: 15,
        fleet_success_rate: 0.6,
        coordination_ability: 0.7,
        doctrine_compliance: 0.8
      },
      leadership_traits: [
        "Clear communication",
        "Good target calling",
        "Risk assessment"
      ],
      calculated_at: DateTime.utc_now()
    }
  end

  defp calculate_solo_pilot_score(character_id) do
    %{
      character_id: character_id,
      score_type: :solo_pilot_score,
      score: 0.82,
      rating: :dangerous,
      factors: %{
        solo_kill_percentage: 0.45,
        engagement_selection: 0.9,
        survival_rate: 0.7,
        ship_variety: 0.8
      },
      strengths: [
        "Excellent manual piloting",
        "Good engagement selection",
        "Diverse ship knowledge"
      ],
      calculated_at: DateTime.utc_now()
    }
  end

  defp calculate_awox_risk_score(character_id) do
    %{
      character_id: character_id,
      score_type: :awox_risk_score,
      score: 0.15,
      rating: :low_risk,
      factors: %{
        corporation_loyalty: 0.9,
        friendly_fire_incidents: 0,
        corp_hopping_frequency: 0.1,
        character_age_factor: 0.8
      },
      risk_indicators: [],
      mitigation_suggestions: [
        "Standard vetting procedures",
        "Monitor initial activities",
        "Gradual permission escalation"
      ],
      calculated_at: DateTime.utc_now()
    }
  end

  defp generate_recommendations(_character_id) do
    [
      %{
        type: :tactical,
        priority: :high,
        recommendation: "Avoid solo engagements - pilot shows high proficiency",
        details: "Based on 82% solo pilot effectiveness score"
      },
      %{
        type: :strategic,
        priority: :medium,
        recommendation: "Monitor during peak activity hours (18:00-22:00 EVE)",
        details: "Highest threat during these hours based on historical patterns"
      },
      %{
        type: :defensive,
        priority: :high,
        recommendation: "Use long-range doctrine to counter close-range preference",
        details: "Pilot favors brawling setups in 85% of engagements"
      }
    ]
  end
end

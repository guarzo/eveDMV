defmodule EveDmv.Contexts.CharacterIntelligence do
  @compile {:nowarn_unused_function}
  @moduledoc """
  Context module for character intelligence and threat analysis.

  Provides the public API for character threat scoring, behavioral analysis,
  and combat effectiveness prediction.
  """

  alias EveDmv.Contexts.CharacterIntelligence.Analyzers.CharacterIntelligenceAnalyzer
  alias EveDmv.Contexts.CharacterIntelligence.Domain.ThreatScoringEngine
  alias EveDmv.Integrations.ShipIntelligenceBridge
  require Logger
  require Ash.Query

  # Type definitions
  @type character_threat_analysis :: %{
          character_id: integer(),
          threat_score: non_neg_integer(),
          threat_level: :minimal | :low | :medium | :high | :extreme,
          dimensions: map(),
          ship_specialization: map(),
          behavioral_pattern: atom(),
          recent_activity: map(),
          analysis_metadata: map(),
          analysis_timestamp: DateTime.t()
        }

  @type behavioral_pattern_analysis :: %{
          character_id: integer(),
          primary_pattern: atom(),
          patterns: [atom()],
          characteristics: [String.t()],
          confidence: float(),
          analysis_timestamp: DateTime.t()
        }

  @type threat_trend_analysis :: %{
          character_id: integer(),
          trend_direction: :rising | :falling | :stable | :insufficient_data,
          trend_strength: float(),
          historical_scores: [%{date: Date.t(), score: non_neg_integer()}],
          analysis_period_days: integer(),
          analysis_timestamp: DateTime.t()
        }

  @type intelligence_error ::
          :character_not_found
          | :insufficient_data
          | :api_error
          | :timeout
          | :invalid_character_id

  @doc """
  Analyzes a character's threat level based on their combat history.
  Returns comprehensive threat scoring including:
  - Multi-dimensional threat score (0-100)
  - Combat effectiveness metrics
  - Behavioral patterns
  - Threat trends over time
  ## Examples
      iex> CharacterIntelligence.analyze_character_threat(character_id)
      {:ok, %{
        threat_score: 85,
        dimensions: %{combat_skill: 90, ship_mastery: 80, ...},
        behavioral_pattern: :solo_hunter,
        recent_activity: %{...}
      }}
  """
  @spec analyze_character_threat(integer()) ::
          {:ok, character_threat_analysis()} | {:error, intelligence_error()}
  def analyze_character_threat(character_id) do
    case ThreatScoringEngine.calculate_threat_score(character_id) do
      {:ok, threat_data} ->
        # Enhance with ship specialization analysis
        enhanced_threat_data = enhance_with_ship_intelligence(threat_data, character_id)
        {:ok, enhanced_threat_data}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Detects behavioral patterns for a character based on their killmail history.
  Identifies patterns such as:
  - Solo hunter
  - Fleet anchor
  - Specialist
  - Opportunist
  """
  @spec detect_behavioral_patterns(integer()) ::
          {:ok, behavioral_pattern_analysis()} | {:error, intelligence_error()}
  def detect_behavioral_patterns(character_id) do
    # Since ThreatScoringEngine includes behavioral analysis in the threat score,
    # we'll extract it from there
    case analyze_character_threat(character_id) do
      {:ok, threat_data} ->
        {:ok,
         %{
           character_id: character_id,
           primary_pattern: threat_data[:behavioral_pattern] || :unknown,
           patterns: extract_behavioral_patterns(threat_data),
           characteristics: generate_behavioral_characteristics(threat_data),
           confidence: calculate_pattern_confidence(threat_data),
           analysis_timestamp: DateTime.utc_now()
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Calculates threat trends for a character over time.
  Shows how their threat level has evolved based on recent performance.
  """
  @spec calculate_threat_trends(integer(), integer()) ::
          {:ok, threat_trend_analysis()} | {:error, intelligence_error()}
  @dialyzer {:nowarn_function, calculate_threat_trends: 2}
  def calculate_threat_trends(character_id, days_back \\ 90) do
    case ThreatScoringEngine.analyze_threat_trends(character_id, analysis_window_days: days_back) do
      {:ok, trend_data} ->
        # Ensure the response matches our type spec
        {:ok,
         %{
           character_id: character_id,
           trend_direction: trend_data[:trend_direction] || :insufficient_data,
           trend_strength: trend_data[:trend_strength] || 0.0,
           historical_scores: trend_data[:historical_scores] || [],
           analysis_period_days: days_back,
           analysis_timestamp: DateTime.utc_now()
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Compares threat levels between multiple characters.
  Useful for identifying the most dangerous opponents in a group.
  """
  @spec compare_character_threats([integer()]) ::
          {:ok, [{integer(), character_threat_analysis()}]}
  def compare_character_threats(character_ids) when is_list(character_ids) do
    threat_analyses =
      character_ids
      |> Enum.map(fn id ->
        case analyze_character_threat(id) do
          {:ok, analysis} -> {id, analysis}
          {:error, _} -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.sort_by(fn {_id, analysis} -> analysis.threat_score end, :desc)

    {:ok, threat_analyses}
  end

  @doc """
  Gets a comprehensive intelligence report for a character.
  Combines threat scoring, behavioral analysis, and performance metrics.
  """
  @spec get_character_intelligence_report(integer()) ::
          {:ok, map()} | {:error, intelligence_error()}
  def get_character_intelligence_report(character_id) do
    with {:ok, threat_analysis} <- analyze_character_threat(character_id),
         {:ok, behavioral_patterns} <- detect_behavioral_patterns(character_id),
         {:ok, threat_trends} <- calculate_threat_trends(character_id),
         {:ok, character_info} <- get_character_info(character_id),
         {:ok, combat_stats} <- get_combat_statistics(character_id) do
      {:ok,
       %{
         character: character_info,
         threat_analysis: threat_analysis,
         behavioral_patterns: behavioral_patterns,
         threat_trends: threat_trends,
         combat_stats: combat_stats,
         summary: generate_intelligence_summary(threat_analysis, behavioral_patterns)
       }}
    else
      {:error, reason} = error ->
        Logger.error("Failed to get character intelligence report: #{inspect(reason)}")
        error
    end
  end

  ## Ship Intelligence Integration
  @doc """
  Get comprehensive ship intelligence for a character.
  Returns ship specialization, role preferences, and tactical insights.
  """
  @spec get_character_ship_intelligence(integer()) :: {:ok, map()}
  def get_character_ship_intelligence(character_id) do
    ShipIntelligenceBridge.calculate_ship_specialization(character_id)
  end

  @doc """
  Get ship preference summary for quick threat assessment.
  """
  @spec get_ship_preferences(integer()) :: map()
  def get_ship_preferences(character_id) do
    ShipIntelligenceBridge.get_character_ship_preferences(character_id)
  end

  @doc """
  Get detailed ship preferences for a character.
  Returns top ships used with usage counts, efficiency metrics, and ship classifications.
  """
  @spec get_detailed_ship_preferences(integer(), Date.t() | DateTime.t()) ::
          {:ok, map()} | {:error, atom()}
  def get_detailed_ship_preferences(character_id, since_date) do
    CharacterIntelligenceAnalyzer.analyze_ship_preferences(
      character_id,
      since_date
    )
  end

  @doc """
  Get weapon preferences for a character.
  Returns weapon usage patterns, categories, and effectiveness ratings.
  """
  @spec get_weapon_preferences(integer(), Date.t() | DateTime.t()) ::
          {:ok, map()} | {:error, atom()}
  def get_weapon_preferences(character_id, since_date) do
    CharacterIntelligenceAnalyzer.analyze_weapon_preferences(
      character_id,
      since_date
    )
  end

  @doc """
  Calculate ISK efficiency metrics for a character.
  Returns ISK destroyed/lost, efficiency percentage, and risk assessment.
  """
  @spec calculate_isk_efficiency(integer(), Date.t() | DateTime.t()) ::
          {:ok, map()} | {:error, atom()}
  def calculate_isk_efficiency(character_id, since_date) do
    CharacterIntelligenceAnalyzer.analyze_isk_efficiency(
      character_id,
      since_date
    )
  end

  @doc """
  Get gang size patterns for a character.
  Returns preferences for solo, small gang, medium gang, large gang, and fleet operations.
  """
  @spec get_gang_size_patterns(integer(), Date.t() | DateTime.t()) ::
          {:ok, map()} | {:error, atom()}
  def get_gang_size_patterns(character_id, since_date) do
    CharacterIntelligenceAnalyzer.analyze_gang_patterns(
      character_id,
      since_date
    )
  end

  @doc """
  Calculate activity statistics for a character.
  Returns recent activity, timezone estimates, activity consistency, and trends.
  """
  @spec calculate_activity_stats(integer(), Date.t() | DateTime.t()) ::
          {:ok, map()} | {:error, atom()}
  def calculate_activity_stats(character_id, since_date) do
    CharacterIntelligenceAnalyzer.analyze_activity_stats(
      character_id,
      since_date
    )
  end

  @doc """
  Get character intelligence summary.
  Returns peak activity times, top locations, operational preferences, and activity spread.
  """
  @spec get_intelligence_summary(integer(), Date.t() | DateTime.t()) ::
          {:ok, map()} | {:error, atom()}
  def get_intelligence_summary(character_id, since_date) do
    CharacterIntelligenceAnalyzer.analyze_intelligence_summary(
      character_id,
      since_date
    )
  end

  # Private helper functions
  @dialyzer {:nowarn_function, enhance_with_ship_intelligence: 2}
  defp enhance_with_ship_intelligence(threat_data, character_id) do
    case ShipIntelligenceBridge.calculate_ship_specialization(character_id) do
      {:ok, ship_intelligence} ->
        # Enhance ship mastery dimension with detailed analysis
        enhanced_dimensions =
          Map.update(
            threat_data.dimensions,
            :ship_mastery,
            0,
            fn base_score ->
              # Combine base score with specialization insights
              specialization_bonus = calculate_specialization_bonus(ship_intelligence)
              min(100, base_score + specialization_bonus)
            end
          )

        # Add ship intelligence to threat data
        threat_data
        |> Map.put(:ship_specialization, format_ship_specialization(ship_intelligence))
        |> Map.put(:dimensions, enhanced_dimensions)

      {:error, _reason} ->
        # Return threat_data unchanged if ship intelligence fails
        threat_data
    end
  end

  @dialyzer {:nowarn_function, calculate_specialization_bonus: 1}
  defp calculate_specialization_bonus(ship_intelligence) do
    # Calculate bonus to ship mastery based on specialization depth
    expertise_bonus =
      case ship_intelligence.expertise_level do
        :expert -> 15
        :experienced -> 10
        :competent -> 5
        :novice -> 2
        _ -> 0
      end

    # Diversity penalty (specialists get higher scores)
    diversity_penalty = ship_intelligence.specialization_diversity * 5
    max(0, expertise_bonus - diversity_penalty)
  end

  @dialyzer {:nowarn_function, format_ship_specialization: 1}
  defp format_ship_specialization(ship_intelligence) do
    %{
      preferred_roles: Enum.take(ship_intelligence.preferred_roles, 3),
      ship_mastery: ship_intelligence.ship_mastery |> Enum.take(5) |> Enum.into(%{}),
      specialization_diversity: ship_intelligence.specialization_diversity,
      expertise_level: ship_intelligence.expertise_level,
      total_killmails: ship_intelligence.total_killmails
    }
  end

  # Private helper functions - stub implementations to satisfy dialyzer

  @spec get_character_info(integer()) :: {:ok, map()} | {:error, atom()}
  defp get_character_info(character_id) do
    # Look up character from character stats view
    alias EveDmv.Database.CharacterRepository

    case CharacterRepository.get_character_stats(character_id) do
      {:ok, stats} when not is_nil(stats) ->
        {:ok, %{
          character_id: character_id,
          name: Map.get(stats, :character_name, "Unknown Character"),
          corporation_id: Map.get(stats, :corporation_id),
          alliance_id: Map.get(stats, :alliance_id)
        }}
      {:error, :not_found} ->
        {:error, :character_not_found}
      {:error, _reason} ->
        {:error, :lookup_failed}
      _ ->
        {:error, :character_not_found}
    end
  end

  @spec get_combat_statistics(integer()) :: {:ok, map()} | {:error, atom()}
  defp get_combat_statistics(character_id) do
    # Look up combat stats from character stats view
    alias EveDmv.Database.CharacterRepository

    case CharacterRepository.get_character_stats(character_id) do
      {:ok, stats} when not is_nil(stats) ->
        kills = Map.get(stats, :kills, 0)
        losses = Map.get(stats, :losses, 0)

        efficiency =
          if kills + losses > 0 do
            kills / (kills + losses) * 100.0
          else
            0.0
          end

        {:ok, %{
          character_id: character_id,
          kills: kills,
          losses: losses,
          efficiency: efficiency,
          isk_killed: Map.get(stats, :isk_killed, 0.0),
          isk_lost: Map.get(stats, :isk_lost, 0.0)
        }}
      {:error, :not_found} ->
        {:error, :stats_not_found}
      {:error, _reason} ->
        {:error, :lookup_failed}
      _ ->
        {:error, :stats_not_found}
    end
  end

  defp generate_intelligence_summary(threat_analysis, behavioral_patterns) do
    %{
      threat_level: Map.get(threat_analysis, :threat_level, :unknown),
      primary_pattern: Map.get(behavioral_patterns, :primary_pattern, :unknown),
      confidence: Map.get(behavioral_patterns, :confidence, 0.0)
    }
  end

  defp extract_behavioral_patterns(_threat_data), do: []
  defp generate_behavioral_characteristics(_threat_data), do: []
  defp calculate_pattern_confidence(_threat_data), do: 0.0
end

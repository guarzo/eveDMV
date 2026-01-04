defmodule EveDmv.Contexts.CombatIntelligence.Api do
  @moduledoc """
  Public API for the Combat Intelligence bounded context.

  This module provides the external interface for intelligence analysis,
  threat assessment, and tactical decision support.
  """

  alias EveDmv.Contexts.CombatIntelligence.Domain
  alias EveDmv.Contexts.CombatIntelligence.Domain.CharacterAnalyzer
  alias EveDmv.Contexts.CombatIntelligence.Domain.CorporationAnalyzer

  @type analysis_options :: [
          analysis_type: :full | :quick | :threat_only | :activity_only,
          time_range: map(),
          include_associates: boolean(),
          include_patterns: boolean(),
          cache_ttl: integer()
        ]

  @type intelligence_result :: %{
          character_id: integer(),
          character_name: String.t(),
          threat_level: atom(),
          analysis_summary: map(),
          detailed_metrics: map(),
          recommendations: [String.t()],
          last_updated: DateTime.t()
        }

  @type corporation_intelligence_result :: %{
          corporation_id: integer(),
          corporation_name: String.t(),
          member_count: non_neg_integer(),
          activity_patterns: map(),
          threat_distribution: map(),
          coordination_metrics: map(),
          last_updated: DateTime.t()
        }

  @type intelligence_api_error ::
          :character_not_found
          | :corporation_not_found
          | :invalid_options
          | :analysis_failed
          | :timeout
          | :cache_error
          | :not_found

  @doc """
  Perform comprehensive character intelligence analysis.

  This is the main entry point for character analysis that other
  contexts (like Wormhole Operations) can use for vetting and
  threat assessment.

  ## Options
  - `:analysis_type` - Type of analysis to perform (default: :full)
  - `:time_range` - Historical time range for analysis (default: last 90 days)
  - `:include_associates` - Include known associate analysis (default: true)
  - `:include_patterns` - Include behavioral pattern analysis (default: true)
  - `:cache_ttl` - Cache time-to-live in seconds (default: 1 hour)

  ## Examples

      iex> analyze_character(123456789, analysis_type: :threat_only)
      {:ok, %{threat_level: %ThreatLevel{level: :medium, score: 0.6}, ...}}
  """
  @spec analyze_character(integer(), analysis_options()) ::
          {:ok, intelligence_result()} | {:error, intelligence_api_error() | term()}
  def analyze_character(character_id, opts \\ []) do
    with :ok <- validate_analysis_options(opts),
         {:ok, analysis_result} <- CharacterAnalyzer.analyze(character_id, opts) do
      # Transform the analyzer result to match the API's expected structure
      transformed_result = %{
        character_id: analysis_result.character_id,
        character_name: Map.get(analysis_result, :character_name, "Unknown"),
        threat_level: Map.get(analysis_result, :threat_level, :unknown),
        analysis_summary: %{
          combat_effectiveness: Map.get(analysis_result, :combat_effectiveness, 0.0),
          analyzed_at: Map.get(analysis_result, :analyzed_at, DateTime.utc_now())
        },
        detailed_metrics:
          Map.drop(analysis_result, [
            :character_id,
            :character_name,
            :threat_level,
            :combat_effectiveness,
            :analyzed_at
          ]),
        recommendations: [],
        last_updated: Map.get(analysis_result, :analyzed_at, DateTime.utc_now())
      }

      {:ok, transformed_result}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Get cached character intelligence data.

  Returns previously analyzed intelligence data if available,
  or triggers a new analysis if cache is stale.
  """
  @spec get_character_intelligence(integer()) :: {:ok, intelligence_result()}
  def get_character_intelligence(character_id) do
    case CharacterAnalyzer.get_intelligence(character_id) do
      {:ok, analysis_result} ->
        # Transform to match intelligence_result type
        transformed_result = %{
          character_id: analysis_result.character_id,
          character_name: Map.get(analysis_result, :character_name, "Unknown"),
          threat_level: Map.get(analysis_result, :threat_level, :unknown),
          analysis_summary: %{
            combat_effectiveness: Map.get(analysis_result, :combat_effectiveness, 0.0),
            analyzed_at: Map.get(analysis_result, :analyzed_at, DateTime.utc_now())
          },
          detailed_metrics:
            Map.drop(analysis_result, [
              :character_id,
              :character_name,
              :threat_level,
              :combat_effectiveness,
              :analyzed_at
            ]),
          recommendations: [],
          last_updated: Map.get(analysis_result, :analyzed_at, DateTime.utc_now())
        }

        {:ok, transformed_result}
    end
  end

  @doc """
  Analyze corporation-wide activity patterns and metrics.

  Provides insights into corporation member activity, timezone coverage,
  and overall combat effectiveness.
  """
  @spec analyze_corporation(integer(), analysis_options()) ::
          {:ok, corporation_intelligence_result()} | {:error, intelligence_api_error() | term()}
  def analyze_corporation(corporation_id, opts \\ []) do
    with :ok <- validate_analysis_options(opts),
         {:ok, analysis_result} <- CorporationAnalyzer.analyze(corporation_id, opts) do
      # Transform the analyzer result to match the API's expected structure
      transformed_result = %{
        corporation_id: analysis_result.corporation_id,
        corporation_name: Map.get(analysis_result, :corporation_name, "Unknown"),
        member_count: Map.get(analysis_result, :member_count, 0),
        activity_patterns: Map.get(analysis_result, :activity_patterns, %{}),
        threat_distribution: Map.get(analysis_result, :threat_distribution, %{}),
        coordination_metrics: Map.get(analysis_result, :coordination_metrics, %{}),
        last_updated: Map.get(analysis_result, :analysis_timestamp, DateTime.utc_now())
      }

      {:ok, transformed_result}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Get cached corporation intelligence data.
  """
  @spec get_corporation_intelligence(integer()) :: {:ok, corporation_intelligence_result()}
  def get_corporation_intelligence(corporation_id) do
    case CorporationAnalyzer.get_intelligence(corporation_id) do
      {:ok, analysis_result} ->
        # Transform to match corporation_intelligence_result type
        transformed_result = %{
          corporation_id: analysis_result.corporation_id,
          corporation_name: Map.get(analysis_result, :corporation_name, "Unknown"),
          member_count: Map.get(analysis_result, :member_count, 0),
          activity_patterns: Map.get(analysis_result, :activity_patterns, %{}),
          threat_distribution: Map.get(analysis_result, :threat_distribution, %{}),
          coordination_metrics: Map.get(analysis_result, :coordination_metrics, %{}),
          last_updated: Map.get(analysis_result, :analysis_timestamp, DateTime.utc_now())
        }

        {:ok, transformed_result}
    end
  end

  @doc """
  Assess threat level for a specific character in a given context.

  Context affects threat calculation (e.g., wormhole vetting vs general threat).

  ## Contexts
  - `:general` - General threat assessment
  - `:recruitment` - Recruitment vetting context
  - `:wormhole_operations` - Wormhole-specific threat factors
  - `:fleet_operations` - Fleet reliability assessment

  ## Examples

      iex> assess_threat(123456789, :wormhole_operations)
      {:ok, %{threat_level: :high, factors: [...], recommendations: [...]}}
  """
  @spec assess_threat(integer(), atom()) :: {:ok, map()} | {:error, atom()}
  def assess_threat(character_id, context \\ :general) do
    with :ok <- validate_threat_context(context),
         {:ok, assessment} <- Domain.ThreatAssessor.assess_threat(character_id, context) do
      {:ok, assessment}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Get cached threat assessment data.
  """
  @spec get_threat_assessment(integer()) :: {:ok, map()}
  def get_threat_assessment(character_id) do
    Domain.ThreatAssessor.get_assessment(character_id)
  end

  @doc """
  Calculate intelligence score for a character using specific scoring algorithm.

  ## Scoring Types
  - `:danger_rating` - 1-5 star danger rating
  - `:hunter_score` - Effectiveness as a hunter
  - `:fleet_commander_score` - Leadership and coordination ability
  - `:solo_pilot_score` - Solo PvP effectiveness
  - `:awox_risk_score` - Risk of betrayal/awoxing
  """
  @spec calculate_intelligence_score(integer(), atom()) :: {:ok, map()} | {:error, atom()}
  def calculate_intelligence_score(character_id, scoring_type) do
    with :ok <- validate_scoring_type(scoring_type),
         {:ok, score_result} <-
           Domain.IntelligenceScoring.calculate_score(character_id, scoring_type) do
      {:ok, score_result}
    end
  end

  @doc """
  Get tactical recommendations for dealing with a specific character.

  Returns actionable intelligence based on the character's patterns,
  strengths, and weaknesses.
  """
  @spec get_character_recommendations(integer()) :: {:ok, [map()]}
  def get_character_recommendations(character_id) do
    Domain.IntelligenceScoring.get_recommendations(character_id)
  end

  @doc """
  Search for characters matching specific intelligence criteria.

  Useful for finding similar pilots or identifying threats based on patterns.

  ## Criteria Examples
  - `%{threat_level: :high, active_in_last_days: 30}`
  - `%{min_kills: 100, preferred_ship_class: :cruiser, timezone: "US"}`
  - `%{corporation_id: 123, hunter_score: 0.8}`
  """
  @spec search_characters_by_criteria(map()) :: {:ok, [intelligence_result()]} | {:error, atom()}
  def search_characters_by_criteria(criteria) when is_map(criteria) do
    case validate_search_criteria(criteria) do
      :ok ->
        # Domain.CharacterAnalyzer.search_by_criteria always returns {:error, :search_error}
        # Keep the function structure for future implementation
        Domain.CharacterAnalyzer.search_by_criteria(criteria)

      {:error, reason} ->
        {:error, reason}
    end
  end

  def search_characters_by_criteria(_), do: {:error, :invalid_criteria_format}

  @doc """
  Get detailed activity patterns for a character over a time range.

  Returns temporal activity patterns, timezone preferences, and behavioral trends.
  """
  @spec get_activity_patterns(integer(), keyword()) :: {:error, :analysis_failed}
  def get_activity_patterns(character_id, opts \\ []) do
    CharacterAnalyzer.get_activity_patterns(character_id, opts)
  end

  @doc """
  Compare multiple characters across key intelligence metrics.

  Useful for recruitment decisions or identifying the most dangerous
  opponents in a group.
  """
  @spec compare_characters([integer()]) :: {:ok, map()} | {:error, atom()}
  def compare_characters(character_ids) when is_list(character_ids) do
    with :ok <- validate_character_ids(character_ids),
         {:ok, comparison} <- Domain.CharacterAnalyzer.compare_characters(character_ids) do
      {:ok, comparison}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def compare_characters(_), do: {:error, :invalid_character_ids_format}

  @doc """
  Get cache statistics for monitoring and debugging.
  """
  @spec get_intelligence_cache_stats() :: map()
  def get_intelligence_cache_stats do
    # CharacterAnalyzer.get_cache_stats() returns a plain map, not a tuple
    CharacterAnalyzer.get_cache_stats()
  end

  @doc """
  Get external groups that a character has collaborated with.

  Returns corporations and alliances the character has flown with but are not part of their own.
  Useful for understanding social connections and potential allies.
  """
  @spec get_external_groups(integer(), DateTime.t()) :: list(map())
  def get_external_groups(character_id, since_date) do
    case Domain.ExternalGroupAnalyzer.analyze(character_id, since_date) do
      {:ok, groups} -> groups
      {:error, _} -> []
    end
  end

  # Private validation functions

  defp validate_analysis_options(opts) when is_list(opts) do
    with :ok <- validate_analysis_type(Keyword.get(opts, :analysis_type)),
         :ok <- validate_time_range_option(Keyword.get(opts, :time_range)),
         :ok <- validate_boolean_option(opts, :include_associates),
         :ok <- validate_boolean_option(opts, :include_patterns),
         :ok <- validate_cache_ttl(Keyword.get(opts, :cache_ttl)) do
      :ok
    end
  end

  defp validate_analysis_options(_), do: {:error, :invalid_options_format}

  defp validate_analysis_type(nil), do: :ok

  defp validate_analysis_type(type) when type in [:full, :quick, :threat_only, :activity_only],
    do: :ok

  defp validate_analysis_type(_), do: {:error, :invalid_analysis_type}

  defp validate_time_range_option(nil), do: :ok
  defp validate_time_range_option(time_range) when is_map(time_range), do: :ok
  defp validate_time_range_option(_), do: {:error, :invalid_time_range}

  defp validate_boolean_option(opts, key) do
    case Keyword.get(opts, key) do
      nil -> :ok
      value when is_boolean(value) -> :ok
      _ -> {:error, {:invalid_boolean_option, key}}
    end
  end

  defp validate_cache_ttl(nil), do: :ok
  defp validate_cache_ttl(ttl) when is_integer(ttl) and ttl > 0, do: :ok
  defp validate_cache_ttl(_), do: {:error, :invalid_cache_ttl}

  defp validate_threat_context(context)
       when context in [:general, :recruitment, :wormhole_operations, :fleet_operations],
       do: :ok

  defp validate_threat_context(_), do: {:error, :invalid_threat_context}

  defp validate_scoring_type(type)
       when type in [
              :danger_rating,
              :hunter_score,
              :fleet_commander_score,
              :solo_pilot_score,
              :awox_risk_score
            ],
       do: :ok

  defp validate_scoring_type(_), do: {:error, :invalid_scoring_type}

  defp validate_search_criteria(criteria) when is_map(criteria) and map_size(criteria) > 0,
    do: :ok

  defp validate_search_criteria(_), do: {:error, :invalid_search_criteria}

  defp validate_character_ids(character_ids)
       when is_list(character_ids) and character_ids != [] do
    if Enum.all?(character_ids, &(is_integer(&1) and &1 > 0)) do
      :ok
    else
      {:error, :invalid_character_ids}
    end
  end

  defp validate_character_ids(_), do: {:error, :invalid_character_ids_format}
end

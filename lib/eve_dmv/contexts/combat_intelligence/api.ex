defmodule EveDmv.Contexts.CombatIntelligence.Api do
  @moduledoc """
  Public API for the Combat Intelligence bounded context.

  This module provides the external interface for intelligence analysis,
  threat assessment, and tactical decision support.
  """

  alias EveDmv.Contexts.CombatIntelligence.Domain
  alias EveDmv.SharedKernel.ValueObjects.{CharacterId, CorporationId, ThreatLevel, TimeRange}
  alias EveDmv.Result

  @type analysis_options :: [
          analysis_type: :full | :quick | :threat_only | :activity_only,
          time_range: TimeRange.t(),
          include_associates: boolean(),
          include_patterns: boolean(),
          cache_ttl: integer()
        ]

  @type intelligence_result :: %{
          character_id: integer(),
          character_name: String.t(),
          threat_level: ThreatLevel.t(),
          analysis_summary: map(),
          detailed_metrics: map(),
          recommendations: [String.t()],
          last_updated: DateTime.t()
        }

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
  @spec analyze_character(integer(), analysis_options()) :: Result.t(intelligence_result())
  def analyze_character(character_id, opts \\ []) do
    with {:ok, character_id_vo} <- CharacterId.new(character_id),
         :ok <- validate_analysis_options(opts),
         {:ok, analysis_result} <- Domain.CharacterAnalyzer.analyze(character_id_vo, opts) do
      {:ok, analysis_result}
    end
  end

  @doc """
  Get cached character intelligence data.

  Returns previously analyzed intelligence data if available,
  or triggers a new analysis if cache is stale.
  """
  @spec get_character_intelligence(integer()) ::
          Result.t(intelligence_result()) | Result.t(:not_found)
  def get_character_intelligence(character_id) do
    with {:ok, character_id_vo} <- CharacterId.new(character_id),
         {:ok, intelligence} <- Domain.CharacterAnalyzer.get_intelligence(character_id_vo) do
      {:ok, intelligence}
    end
  end

  @doc """
  Analyze corporation-wide activity patterns and metrics.

  Provides insights into corporation member activity, timezone coverage,
  and overall combat effectiveness.
  """
  @spec analyze_corporation(integer(), analysis_options()) :: Result.t(map())
  def analyze_corporation(corporation_id, opts \\ []) do
    with {:ok, corporation_id_vo} <- CorporationId.new(corporation_id),
         :ok <- validate_analysis_options(opts),
         {:ok, analysis_result} <- Domain.CorporationAnalyzer.analyze(corporation_id_vo, opts) do
      {:ok, analysis_result}
    end
  end

  @doc """
  Get cached corporation intelligence data.
  """
  @spec get_corporation_intelligence(integer()) :: Result.t(map()) | Result.t(:not_found)
  def get_corporation_intelligence(corporation_id) do
    with {:ok, corporation_id_vo} <- CorporationId.new(corporation_id),
         {:ok, intelligence} <- Domain.CorporationAnalyzer.get_intelligence(corporation_id_vo) do
      {:ok, intelligence}
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
  @spec assess_threat(integer(), atom()) :: Result.t(map())
  def assess_threat(character_id, context \\ :general) do
    with {:ok, character_id_vo} <- CharacterId.new(character_id),
         :ok <- validate_threat_context(context),
         {:ok, assessment} <- Domain.ThreatAssessor.assess_threat(character_id_vo, context) do
      {:ok, assessment}
    end
  end

  @doc """
  Get cached threat assessment data.
  """
  @spec get_threat_assessment(integer()) :: Result.t(map()) | Result.t(:not_found)
  def get_threat_assessment(character_id) do
    with {:ok, character_id_vo} <- CharacterId.new(character_id),
         {:ok, assessment} <- Domain.ThreatAssessor.get_assessment(character_id_vo) do
      {:ok, assessment}
    end
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
  @spec calculate_intelligence_score(integer(), atom()) :: Result.t(map())
  def calculate_intelligence_score(character_id, scoring_type) do
    with {:ok, character_id_vo} <- CharacterId.new(character_id),
         :ok <- validate_scoring_type(scoring_type),
         {:ok, score_result} <-
           Domain.IntelligenceScoring.calculate_score(character_id_vo, scoring_type) do
      {:ok, score_result}
    end
  end

  @doc """
  Get tactical recommendations for dealing with a specific character.

  Returns actionable intelligence based on the character's patterns,
  strengths, and weaknesses.
  """
  @spec get_character_recommendations(integer()) :: Result.t([map()])
  def get_character_recommendations(character_id) do
    with {:ok, character_id_vo} <- CharacterId.new(character_id),
         {:ok, recommendations} <- Domain.IntelligenceScoring.get_recommendations(character_id_vo) do
      {:ok, recommendations}
    end
  end

  @doc """
  Search for characters matching specific intelligence criteria.

  Useful for finding similar pilots or identifying threats based on patterns.

  ## Criteria Examples
  - `%{threat_level: :high, active_in_last_days: 30}`
  - `%{min_kills: 100, preferred_ship_class: :cruiser, timezone: "US"}`
  - `%{corporation_id: 123, hunter_score: 0.8}`
  """
  @spec search_characters_by_criteria(map()) :: Result.t([intelligence_result()])
  def search_characters_by_criteria(criteria) when is_map(criteria) do
    with :ok <- validate_search_criteria(criteria),
         {:ok, matching_characters} <- Domain.CharacterAnalyzer.search_by_criteria(criteria) do
      {:ok, matching_characters}
    end
  end

  def search_characters_by_criteria(_), do: {:error, :invalid_criteria_format}

  @doc """
  Get detailed activity patterns for a character over a time range.

  Returns temporal activity patterns, timezone preferences, and behavioral trends.
  """
  @spec get_activity_patterns(integer(), TimeRange.t()) :: Result.t(map())
  def get_activity_patterns(character_id, time_range) do
    with {:ok, character_id_vo} <- CharacterId.new(character_id),
         {:ok, patterns} <-
           Domain.CharacterAnalyzer.get_activity_patterns(character_id_vo, time_range) do
      {:ok, patterns}
    end
  end

  @doc """
  Compare multiple characters across key intelligence metrics.

  Useful for recruitment decisions or identifying the most dangerous
  opponents in a group.
  """
  @spec compare_characters([integer()]) :: Result.t(map())
  def compare_characters(character_ids) when is_list(character_ids) do
    with :ok <- validate_character_ids(character_ids),
         character_id_vos <-
           Enum.map(character_ids, fn id ->
             {:ok, vo} = CharacterId.new(id)
             vo
           end),
         {:ok, comparison} <- Domain.CharacterAnalyzer.compare_characters(character_id_vos) do
      {:ok, comparison}
    end
  end

  def compare_characters(_), do: {:error, :invalid_character_ids_format}

  @doc """
  Get cache statistics for monitoring and debugging.
  """
  @spec get_intelligence_cache_stats() :: Result.t(map())
  def get_intelligence_cache_stats do
    stats = Domain.CharacterAnalyzer.get_cache_stats()
    {:ok, stats}
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
  defp validate_time_range_option(%TimeRange{}), do: :ok
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
       when is_list(character_ids) and length(character_ids) > 0 do
    if Enum.all?(character_ids, &(is_integer(&1) and &1 > 0)) do
      :ok
    else
      {:error, :invalid_character_ids}
    end
  end

  defp validate_character_ids(_), do: {:error, :invalid_character_ids_format}
end

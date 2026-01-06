defmodule EveDmv.Contexts.CombatIntelligence.Api do
  @moduledoc """
  Public API for the Combat Intelligence bounded context.

  This module provides the external interface for intelligence analysis,
  threat assessment, and tactical decision support.
  """

  alias EveDmv.Contexts.CombatIntelligence.Domain
  alias EveDmv.Contexts.CombatIntelligence.Domain.CharacterAnalyzer
  alias EveDmv.Contexts.CombatIntelligence.Domain.CorporationAnalyzer
  alias EveDmv.Contexts.CombatIntelligence.Domain.IntelligenceTransformer
  alias EveDmv.Contexts.CombatIntelligence.Domain.IntelligenceValidators
  alias EveDmv.Types

  @type analysis_options :: [
          analysis_type: :full | :quick | :threat_only | :activity_only,
          time_range: map(),
          include_associates: boolean(),
          include_patterns: boolean(),
          cache_ttl: integer()
        ]

  @type intelligence_result :: %{
          character_id: Types.character_id(),
          character_name: String.t(),
          threat_level: Types.threat_level(),
          analysis_summary: map(),
          detailed_metrics: map(),
          recommendations: [String.t()],
          last_updated: DateTime.t()
        }

  @type corporation_intelligence_result :: %{
          corporation_id: Types.corporation_id(),
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
  @spec analyze_character(Types.character_id(), analysis_options()) ::
          {:ok, intelligence_result()} | {:error, intelligence_api_error() | term()}
  def analyze_character(character_id, opts \\ []) do
    with :ok <- IntelligenceValidators.validate_analysis_options(opts),
         {:ok, analysis_result} <- CharacterAnalyzer.analyze(character_id, opts) do
      {:ok, IntelligenceTransformer.transform_character_analysis(analysis_result)}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Get cached character intelligence data.

  Returns previously analyzed intelligence data if available,
  or triggers a new analysis if cache is stale.

  ## Parameters

  - `character_id` - EVE Online character ID

  ## Returns

  - `{:ok, intelligence_result}` - Intelligence data including:
    - `:character_id` - Character identifier
    - `:character_name` - Character name
    - `:threat_level` - Assessed threat level
    - `:analysis_summary` - High-level analysis summary
    - `:detailed_metrics` - Combat and activity metrics
    - `:recommendations` - Tactical recommendations
    - `:last_updated` - When analysis was last performed

  ## Examples

      iex> get_character_intelligence(123456789)
      {:ok, %{character_id: 123456789, threat_level: :medium, ...}}
  """
  @spec get_character_intelligence(Types.character_id()) ::
          {:ok, intelligence_result()} | {:error, intelligence_api_error() | term()}
  def get_character_intelligence(character_id) do
    case CharacterAnalyzer.get_intelligence(character_id) do
      {:ok, analysis_result} ->
        {:ok, IntelligenceTransformer.transform_character_analysis(analysis_result)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Analyze corporation-wide activity patterns and metrics.

  Provides insights into corporation member activity, timezone coverage,
  and overall combat effectiveness.

  ## Parameters

  - `corporation_id` - EVE Online corporation ID
  - `opts` - Analysis options (same as `analyze_character/2`)

  ## Returns

  - `{:ok, corporation_intelligence_result}` - Corporation intelligence data including:
    - `:corporation_id` - Corporation identifier
    - `:corporation_name` - Corporation name
    - `:member_count` - Number of tracked members
    - `:activity_patterns` - Timezone and activity analysis
    - `:threat_distribution` - Threat levels of members
    - `:coordination_metrics` - Fleet coordination effectiveness
    - `:last_updated` - When analysis was performed
  - `{:error, reason}` - Analysis failure

  ## Examples

      iex> analyze_corporation(98000001, analysis_type: :full)
      {:ok, %{corporation_id: 98000001, activity_patterns: %{...}, ...}}
  """
  @spec analyze_corporation(integer(), analysis_options()) ::
          {:ok, corporation_intelligence_result()} | {:error, intelligence_api_error() | term()}
  def analyze_corporation(corporation_id, opts \\ []) do
    with :ok <- IntelligenceValidators.validate_analysis_options(opts),
         {:ok, analysis_result} <- CorporationAnalyzer.analyze(corporation_id, opts) do
      {:ok, IntelligenceTransformer.transform_corporation_analysis(analysis_result)}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Get cached corporation intelligence data.

  Returns previously analyzed corporation intelligence if available,
  or triggers a new analysis if cache is stale.

  ## Parameters

  - `corporation_id` - EVE Online corporation ID

  ## Returns

  - `{:ok, corporation_intelligence_result}` - Corporation intelligence data
    (see `analyze_corporation/2` for structure details)

  ## Examples

      iex> get_corporation_intelligence(98000001)
      {:ok, %{corporation_id: 98000001, member_count: 150, ...}}
  """
  @spec get_corporation_intelligence(integer()) ::
          {:ok, corporation_intelligence_result()} | {:error, intelligence_api_error() | term()}
  def get_corporation_intelligence(corporation_id) do
    case CorporationAnalyzer.get_intelligence(corporation_id) do
      {:ok, analysis_result} ->
        {:ok, IntelligenceTransformer.transform_corporation_analysis(analysis_result)}

      {:error, reason} ->
        {:error, reason}
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
    with :ok <- IntelligenceValidators.validate_threat_context(context),
         {:ok, assessment} <- Domain.ThreatAssessor.assess_threat(character_id, context) do
      {:ok, assessment}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Get cached threat assessment data.

  Returns the most recent threat assessment for a character.
  Assessment includes threat level, contributing factors, and recommendations.

  ## Parameters

  - `character_id` - EVE Online character ID

  ## Returns

  - `{:ok, assessment}` - Threat assessment data including:
    - `:threat_level` - Overall threat level (`:low`, `:medium`, `:high`, `:critical`)
    - `:score` - Numeric threat score (0.0 to 1.0)
    - `:factors` - Contributing factors to the threat level
    - `:recommendations` - Suggested actions
    - `:assessed_at` - When assessment was performed

  ## Examples

      iex> get_threat_assessment(123456789)
      {:ok, %{threat_level: :high, score: 0.85, factors: [...], ...}}
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
    with :ok <- IntelligenceValidators.validate_scoring_type(scoring_type),
         {:ok, score_result} <-
           Domain.IntelligenceScoring.calculate_score(character_id, scoring_type) do
      {:ok, score_result}
    end
  end

  @doc """
  Get tactical recommendations for dealing with a specific character.

  Returns actionable intelligence based on the character's patterns,
  strengths, and weaknesses. Recommendations are tailored for different
  engagement scenarios.

  ## Parameters

  - `character_id` - EVE Online character ID

  ## Returns

  - `{:ok, recommendations}` - List of recommendation maps, each containing:
    - `:type` - Recommendation type (`:engagement`, `:avoidance`, `:counter`)
    - `:priority` - Priority level (`:high`, `:medium`, `:low`)
    - `:description` - Human-readable recommendation
    - `:rationale` - Why this recommendation was generated
    - `:applicable_scenarios` - When this recommendation applies

  ## Examples

      iex> get_character_recommendations(123456789)
      {:ok, [%{type: :engagement, priority: :high, description: "Target is weakest in frigates", ...}]}
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
    case IntelligenceValidators.validate_search_criteria(criteria) do
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
  Useful for predicting when a character will be active.

  ## Parameters

  - `character_id` - EVE Online character ID
  - `opts` - Analysis options:
    - `:time_range` - Time range for analysis (default: last 90 days)
    - `:granularity` - Time granularity (`:hourly`, `:daily`, `:weekly`)

  ## Returns

  - `{:ok, patterns}` - Activity pattern data including:
    - `:timezone` - Estimated primary timezone
    - `:peak_hours` - Most active hours (UTC)
    - `:weekly_distribution` - Activity by day of week
    - `:monthly_trend` - Activity trend over time
  - `{:error, :analysis_failed}` - Insufficient data or analysis error

  ## Examples

      iex> get_activity_patterns(123456789, granularity: :hourly)
      {:ok, %{timezone: "US/Eastern", peak_hours: [22, 23, 0, 1], ...}}
  """
  @spec get_activity_patterns(integer(), keyword()) :: {:error, :analysis_failed}
  def get_activity_patterns(character_id, opts \\ []) do
    CharacterAnalyzer.get_activity_patterns(character_id, opts)
  end

  @doc """
  Compare multiple characters across key intelligence metrics.

  Useful for recruitment decisions or identifying the most dangerous
  opponents in a group. Provides side-by-side comparison of key metrics.

  ## Parameters

  - `character_ids` - List of EVE Online character IDs to compare (2-10 characters)

  ## Returns

  - `{:ok, comparison}` - Comparison data including:
    - `:characters` - List of character summaries
    - `:rankings` - Characters ranked by various metrics
    - `:threat_comparison` - Threat level comparison
    - `:skill_comparison` - Combat skill comparison
    - `:activity_comparison` - Activity level comparison
  - `{:error, :invalid_character_ids}` - Invalid character ID list
  - `{:error, :too_few_characters}` - Need at least 2 characters
  - `{:error, :too_many_characters}` - Maximum 10 characters

  ## Examples

      iex> compare_characters([123456789, 987654321])
      {:ok, %{rankings: %{threat: [987654321, 123456789], ...}, ...}}
  """
  @spec compare_characters([integer()]) :: {:ok, map()} | {:error, atom()}
  def compare_characters(character_ids) when is_list(character_ids) do
    with :ok <- IntelligenceValidators.validate_character_ids(character_ids),
         {:ok, comparison} <- Domain.CharacterAnalyzer.compare_characters(character_ids) do
      {:ok, comparison}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def compare_characters(_), do: {:error, :invalid_character_ids_format}

  @doc """
  Get cache statistics for monitoring and debugging.

  Returns statistics about the intelligence cache, useful for
  monitoring cache effectiveness and debugging performance issues.

  ## Returns

  A map containing:
  - `:hit_count` - Number of cache hits
  - `:miss_count` - Number of cache misses
  - `:hit_rate` - Cache hit rate percentage
  - `:entry_count` - Current number of cached entries
  - `:memory_usage` - Estimated memory usage in bytes
  - `:oldest_entry` - Timestamp of oldest cache entry
  - `:newest_entry` - Timestamp of newest cache entry

  ## Examples

      iex> get_intelligence_cache_stats()
      %{hit_count: 1500, miss_count: 200, hit_rate: 0.88, ...}
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

  ## Parameters

  - `character_id` - EVE Online character ID
  - `since_date` - Only analyze collaborations after this date

  ## Returns

  A list of maps, each containing:
  - `:group_type` - Type of group (`:corporation` or `:alliance`)
  - `:group_id` - EVE Online ID of the group
  - `:group_name` - Name of the group
  - `:collaboration_count` - Number of killmails together
  - `:first_seen` - First collaboration timestamp
  - `:last_seen` - Most recent collaboration timestamp
  - `:relationship_strength` - Estimated relationship strength (0.0-1.0)

  ## Examples

      iex> get_external_groups(123456789, ~U[2024-01-01 00:00:00Z])
      [%{group_type: :corporation, group_id: 98000001, collaboration_count: 25, ...}]
  """
  @spec get_external_groups(integer(), DateTime.t()) :: list(map())
  def get_external_groups(character_id, since_date) do
    # ExternalGroupAnalyzer.analyze/2 always returns {:ok, groups}
    {:ok, groups} = Domain.ExternalGroupAnalyzer.analyze(character_id, since_date)
    groups
  end
end

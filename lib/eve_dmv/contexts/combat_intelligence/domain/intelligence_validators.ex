defmodule EveDmv.Contexts.CombatIntelligence.Domain.IntelligenceValidators do
  @moduledoc """
  Validation functions for combat intelligence operations.

  Provides reusable validators for analysis options, threat contexts,
  scoring types, and search criteria. Extracted from the API module
  to follow single-responsibility principle.
  """

  import EveDmv.Core.Validation.Validators

  # Valid analysis types for character/corporation analysis
  @analysis_types [:full, :quick, :threat_only, :activity_only]

  # Valid threat assessment contexts
  @threat_contexts [:general, :recruitment, :wormhole_operations, :fleet_operations]

  # Valid scoring algorithm types
  @scoring_types [
    :danger_rating,
    :hunter_score,
    :fleet_commander_score,
    :solo_pilot_score,
    :awox_risk_score
  ]

  @doc """
  Returns the list of valid analysis types.
  """
  @spec analysis_types() :: [atom()]
  def analysis_types, do: @analysis_types

  @doc """
  Returns the list of valid threat contexts.
  """
  @spec threat_contexts() :: [atom()]
  def threat_contexts, do: @threat_contexts

  @doc """
  Returns the list of valid scoring types.
  """
  @spec scoring_types() :: [atom()]
  def scoring_types, do: @scoring_types

  @doc """
  Validates analysis options for character/corporation analysis.

  ## Supported Options
  - `:analysis_type` - Type of analysis (:full, :quick, :threat_only, :activity_only)
  - `:time_range` - Historical time range map
  - `:include_associates` - Include associate analysis (boolean)
  - `:include_patterns` - Include behavioral patterns (boolean)
  - `:cache_ttl` - Cache TTL in seconds (positive integer)

  ## Examples

      iex> validate_analysis_options(analysis_type: :quick, cache_ttl: 3600)
      :ok

      iex> validate_analysis_options(analysis_type: :invalid)
      {:error, :invalid_analysis_type}

      iex> validate_analysis_options("not a list")
      {:error, :invalid_options_format}
  """
  @spec validate_analysis_options(any()) :: :ok | {:error, atom() | {atom(), atom()}}
  def validate_analysis_options(opts) when is_list(opts) do
    with :ok <- do_validate_analysis_type(Keyword.get(opts, :analysis_type)),
         :ok <- do_validate_time_range_option(Keyword.get(opts, :time_range)),
         :ok <-
           do_validate_boolean_option(:include_associates, Keyword.get(opts, :include_associates)),
         :ok <-
           do_validate_boolean_option(:include_patterns, Keyword.get(opts, :include_patterns)),
         :ok <- do_validate_cache_ttl(Keyword.get(opts, :cache_ttl)) do
      :ok
    end
  end

  def validate_analysis_options(_), do: {:error, :invalid_options_format}

  @doc """
  Validates a threat assessment context.

  ## Valid Contexts
  - `:general` - General threat assessment
  - `:recruitment` - Recruitment vetting context
  - `:wormhole_operations` - Wormhole-specific threat factors
  - `:fleet_operations` - Fleet reliability assessment

  ## Examples

      iex> validate_threat_context(:wormhole_operations)
      :ok

      iex> validate_threat_context(:invalid_context)
      {:error, :invalid_threat_context}
  """
  @spec validate_threat_context(atom()) :: :ok | {:error, :invalid_threat_context}
  def validate_threat_context(context) do
    case validate_enum(:context, context, @threat_contexts) do
      :ok -> :ok
      {:error, _} -> {:error, :invalid_threat_context}
    end
  end

  @doc """
  Validates a scoring algorithm type.

  ## Valid Types
  - `:danger_rating` - 1-5 star danger rating
  - `:hunter_score` - Effectiveness as a hunter
  - `:fleet_commander_score` - Leadership and coordination ability
  - `:solo_pilot_score` - Solo PvP effectiveness
  - `:awox_risk_score` - Risk of betrayal/awoxing

  ## Examples

      iex> validate_scoring_type(:danger_rating)
      :ok

      iex> validate_scoring_type(:invalid_type)
      {:error, :invalid_scoring_type}
  """
  @spec validate_scoring_type(atom()) :: :ok | {:error, :invalid_scoring_type}
  def validate_scoring_type(type) do
    case validate_enum(:scoring_type, type, @scoring_types) do
      :ok -> :ok
      {:error, _} -> {:error, :invalid_scoring_type}
    end
  end

  @doc """
  Validates search criteria for character searches.

  ## Examples

      iex> validate_search_criteria(%{threat_level: :high, min_kills: 100})
      :ok

      iex> validate_search_criteria(%{})
      {:error, :invalid_search_criteria}

      iex> validate_search_criteria("not a map")
      {:error, :invalid_search_criteria}
  """
  @spec validate_search_criteria(any()) :: :ok | {:error, :invalid_search_criteria}
  def validate_search_criteria(criteria) do
    case validate_map(:criteria, criteria, allow_empty: false) do
      :ok -> :ok
      {:error, _} -> {:error, :invalid_search_criteria}
    end
  end

  @doc """
  Validates a list of character IDs for comparison operations.

  ## Examples

      iex> validate_character_ids([123, 456, 789])
      :ok

      iex> validate_character_ids([])
      {:error, :invalid_character_ids_format}

      iex> validate_character_ids([123, -1])
      {:error, :invalid_character_ids}
  """
  @spec validate_character_ids(any()) :: :ok | {:error, atom()}
  def validate_character_ids(character_ids) do
    case validate_integer_list(:character_ids, character_ids, min: 1) do
      :ok -> :ok
      {:error, {:character_ids, :invalid_type}} -> {:error, :invalid_character_ids_format}
      {:error, {:character_ids, :required}} -> {:error, :invalid_character_ids_format}
      {:error, {:character_ids, :too_few_items}} -> {:error, :invalid_character_ids_format}
      {:error, {:character_ids, :invalid_items}} -> {:error, :invalid_character_ids}
    end
  end

  # Private validation helpers

  defp do_validate_analysis_type(nil), do: :ok

  defp do_validate_analysis_type(type) do
    case validate_enum(:analysis_type, type, @analysis_types) do
      :ok -> :ok
      {:error, _} -> {:error, :invalid_analysis_type}
    end
  end

  defp do_validate_time_range_option(nil), do: :ok

  defp do_validate_time_range_option(time_range) do
    case validate_map(:time_range, time_range) do
      :ok -> :ok
      {:error, _} -> {:error, :invalid_time_range}
    end
  end

  defp do_validate_boolean_option(_key, nil), do: :ok

  defp do_validate_boolean_option(key, value) do
    case validate_boolean(key, value) do
      :ok -> :ok
      {:error, _} -> {:error, {:invalid_boolean_option, key}}
    end
  end

  defp do_validate_cache_ttl(nil), do: :ok

  defp do_validate_cache_ttl(ttl) do
    case validate_positive_integer(:cache_ttl, ttl) do
      :ok -> :ok
      {:error, _} -> {:error, :invalid_cache_ttl}
    end
  end
end

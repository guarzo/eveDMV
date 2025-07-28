defmodule EveDmv.Contexts.CombatIntelligence.Infrastructure.AnalysisCache do
  @moduledoc """
  Cache management for combat intelligence analysis results.

  Simplified cache module that provides direct cache operations without GenServer overhead.
  """

  alias EveDmv.Cache

  require Logger

  @cache_type :analysis

  @doc """
  Invalidate cached analysis for a character.
  """
  @spec invalidate_character(integer()) :: :ok
  def invalidate_character(character_id) do
    cache_key = {:character_analysis, character_id}
    Cache.delete(@cache_type, cache_key)
    Logger.debug("Invalidated character analysis cache", character_id: character_id)
    :ok
  end

  @doc """
  Store character analysis in cache.
  """
  @spec put_character_analysis(integer(), map()) :: :ok
  def put_character_analysis(character_id, analysis) do
    cache_key = {:character_analysis, character_id}
    Cache.put(@cache_type, cache_key, analysis, ttl: :timer.minutes(30))
  end

  @doc """
  Get character analysis from cache.
  """
  @spec get_character_analysis(integer()) :: {:ok, map()} | {:error, :not_found}
  def get_character_analysis(character_id) do
    cache_key = {:character_analysis, character_id}

    case Cache.get(@cache_type, cache_key) do
      {:ok, analysis} -> {:ok, analysis}
      :miss -> {:error, :not_found}
    end
  end

  @doc """
  Store corporation analysis in cache.
  """
  @spec put_corporation_analysis(integer(), map()) :: :ok
  def put_corporation_analysis(corporation_id, analysis) do
    cache_key = {:corporation_analysis, corporation_id}
    Cache.put(@cache_type, cache_key, analysis, ttl: :timer.minutes(30))
  end

  @doc """
  Get corporation analysis from cache.
  """
  @spec get_corporation_analysis(integer()) :: {:ok, map()} | {:error, :not_found}
  def get_corporation_analysis(corporation_id) do
    cache_key = {:corporation_analysis, corporation_id}

    case Cache.get(@cache_type, cache_key) do
      {:ok, analysis} -> {:ok, analysis}
      :miss -> {:error, :not_found}
    end
  end

  @doc """
  Invalidate cached analysis for a corporation.
  """
  @spec invalidate_corporation(integer()) :: :ok
  def invalidate_corporation(corporation_id) do
    cache_key = {:corporation_analysis, corporation_id}
    Cache.delete(@cache_type, cache_key)
    Logger.debug("Invalidated corporation analysis cache", corporation_id: corporation_id)
    :ok
  end

  @doc """
  Store threat assessment in cache.
  """
  @spec put_threat_assessment(integer(), map()) :: :ok
  def put_threat_assessment(character_id, assessment) do
    cache_key = {:threat_assessment, character_id}
    Cache.put(@cache_type, cache_key, assessment, ttl: :timer.minutes(20))
  end

  @doc """
  Get threat assessment from cache.
  """
  @spec get_threat_assessment(integer()) :: {:ok, map()} | {:error, :not_found}
  def get_threat_assessment(character_id) do
    cache_key = {:threat_assessment, character_id}

    case Cache.get(@cache_type, cache_key) do
      {:ok, assessment} -> {:ok, assessment}
      :miss -> {:error, :not_found}
    end
  end

  @doc """
  Invalidate cached threat assessment for a character.
  """
  @spec invalidate_threat_assessment(integer()) :: :ok
  def invalidate_threat_assessment(character_id) do
    cache_key = {:threat_assessment, character_id}
    Cache.delete(@cache_type, cache_key)
    Logger.debug("Invalidated threat assessment cache", character_id: character_id)
    :ok
  end

  @doc """
  Store intelligence score in cache.
  """
  @spec put_intelligence_score(integer(), atom(), map()) :: :ok
  def put_intelligence_score(character_id, score_type, score_data) do
    cache_key = {:intelligence_score, character_id, score_type}
    Cache.put(@cache_type, cache_key, score_data, ttl: :timer.minutes(60))
  end

  @doc """
  Get intelligence score from cache.
  """
  @spec get_intelligence_score(integer(), atom()) :: {:ok, map()} | {:error, :not_found}
  def get_intelligence_score(character_id, score_type) do
    cache_key = {:intelligence_score, character_id, score_type}

    case Cache.get(@cache_type, cache_key) do
      {:ok, score} -> {:ok, score}
      :miss -> {:error, :not_found}
    end
  end

  @doc """
  Get all intelligence scores for a character.
  """
  @spec get_intelligence_scores(integer()) ::
          {:ok, map()} | {:error, :not_found}
  def get_intelligence_scores(character_id) do
    score_types = [
      :danger_rating,
      :hunter_score,
      :fleet_commander_score,
      :solo_pilot_score,
      :awox_risk_score
    ]

    scores =
      Enum.reduce(score_types, %{}, fn score_type, acc ->
        cache_key = {:intelligence_score, character_id, score_type}

        case Cache.get(@cache_type, cache_key) do
          {:ok, score_data} -> Map.put(acc, score_type, score_data)
          :miss -> acc
        end
      end)

    if map_size(scores) == 0 do
      {:error, :not_found}
    else
      {:ok, scores}
    end
  end

  @doc """
  Invalidate all intelligence scores for a character.
  """
  @spec invalidate_intelligence_scores(integer()) :: :ok
  def invalidate_intelligence_scores(character_id) do
    score_types = [
      :danger_rating,
      :hunter_score,
      :fleet_commander_score,
      :solo_pilot_score,
      :awox_risk_score
    ]

    Enum.each(score_types, fn score_type ->
      cache_key = {:intelligence_score, character_id, score_type}
      Cache.delete(@cache_type, cache_key)
    end)

    Logger.debug("Invalidated intelligence scores cache", character_id: character_id)
    :ok
  end
end

defmodule EveDmv.Contexts.CombatIntelligence.Infrastructure.AnalysisCache do
  @moduledoc """
  Cache management for combat intelligence analysis results.
  """

  use GenServer

  alias EveDmv.Cache

  require Logger

  @cache_type :analysis

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Invalidate cached analysis for a character.
  """
  @spec invalidate_character(integer()) :: :ok
  def invalidate_character(character_id) do
    GenServer.cast(__MODULE__, {:invalidate_character, character_id})
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
    GenServer.cast(__MODULE__, {:invalidate_corporation, corporation_id})
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
    GenServer.cast(__MODULE__, {:invalidate_threat_assessment, character_id})
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
          {:ok, map()} | {:error, :not_found | :not_implemented}
  def get_intelligence_scores(_character_id) do
    # TODO: Implement fetching all score types for character
    # Original stub returned: {:ok, %{}}
    {:error, :not_implemented}
  end

  @doc """
  Invalidate all intelligence scores for a character.
  """
  @spec invalidate_intelligence_scores(integer()) :: :ok
  def invalidate_intelligence_scores(character_id) do
    GenServer.cast(__MODULE__, {:invalidate_intelligence_scores, character_id})
  end

  # GenServer callbacks

  @impl GenServer
  def init(_opts) do
    {:ok, %{invalidation_count: 0}}
  end

  @impl GenServer
  def handle_cast({:invalidate_character, character_id}, state) do
    cache_key = {:character_analysis, character_id}
    Cache.delete(@cache_type, cache_key)

    Logger.debug("Invalidated character analysis cache", character_id: character_id)

    {:noreply, %{state | invalidation_count: state.invalidation_count + 1}}
  end

  @impl GenServer
  def handle_cast({:invalidate_corporation, corporation_id}, state) do
    cache_key = {:corporation_analysis, corporation_id}
    Cache.delete(@cache_type, cache_key)

    Logger.debug("Invalidated corporation analysis cache", corporation_id: corporation_id)

    {:noreply, %{state | invalidation_count: state.invalidation_count + 1}}
  end

  @impl GenServer
  def handle_cast({:invalidate_threat_assessment, character_id}, state) do
    cache_key = {:threat_assessment, character_id}
    Cache.delete(@cache_type, cache_key)

    Logger.debug("Invalidated threat assessment cache", character_id: character_id)

    {:noreply, %{state | invalidation_count: state.invalidation_count + 1}}
  end

  @impl GenServer
  def handle_cast({:invalidate_intelligence_scores, character_id}, state) do
    # Invalidate all score types for this character
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

    {:noreply, %{state | invalidation_count: state.invalidation_count + 1}}
  end
end

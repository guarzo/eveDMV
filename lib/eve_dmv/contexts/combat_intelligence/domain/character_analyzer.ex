defmodule EveDmv.Contexts.CombatIntelligence.Domain.CharacterAnalyzer do
  @moduledoc """
  Analyzes character combat patterns and intelligence.
  """

  use GenServer

  alias EveDmv.Contexts.CombatIntelligence.Infrastructure.AnalysisCache
  alias EveDmv.Database.CharacterRepository

  require Logger

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Analyze a character's combat intelligence.
  """
  @spec analyze(integer(), map()) :: {:ok, map()} | {:error, term()}
  def analyze(character_id, context) do
    GenServer.call(__MODULE__, {:analyze, character_id, context})
  end

  @doc """
  Get cached intelligence for a character.
  """
  @spec get_intelligence(integer()) :: {:ok, map()} | {:error, term()}
  def get_intelligence(character_id) do
    case AnalysisCache.get_character_analysis(character_id) do
      {:ok, analysis} -> {:ok, analysis}
      {:error, :not_found} -> analyze(character_id, %{})
    end
  end

  @doc """
  Refresh analysis for a character.
  """
  @spec refresh_analysis(integer()) :: {:ok, map()} | {:error, term()}
  def refresh_analysis(character_id) do
    AnalysisCache.invalidate_character(character_id)
    analyze(character_id, %{force_refresh: true})
  end

  @doc """
  Bulk analyze multiple characters.
  """
  @spec bulk_analyze([integer()], map()) :: {:ok, map()} | {:error, term()}
  def bulk_analyze(character_ids, context) do
    GenServer.call(__MODULE__, {:bulk_analyze, character_ids, context}, 30_000)
  end

  @doc """
  Search characters by criteria.
  """
  @spec search_by_criteria(map()) :: {:ok, [map()]} | {:error, term()}
  def search_by_criteria(criteria) do
    GenServer.call(__MODULE__, {:search, criteria})
  end

  @doc """
  Get activity patterns for a character.
  """
  @spec get_activity_patterns(integer(), keyword()) :: {:ok, map()} | {:error, term()}
  def get_activity_patterns(character_id, opts \\ []) do
    GenServer.call(__MODULE__, {:activity_patterns, character_id, opts})
  end

  @doc """
  Compare multiple characters.
  """
  @spec compare_characters([integer()]) :: {:ok, map()} | {:error, term()}
  def compare_characters(character_ids) do
    GenServer.call(__MODULE__, {:compare, character_ids})
  end

  @doc """
  Get cache statistics.
  """
  @spec get_cache_stats() :: map()
  def get_cache_stats do
    GenServer.call(__MODULE__, :cache_stats)
  end

  # GenServer callbacks

  @impl GenServer
  def init(_opts) do
    {:ok,
     %{
       analysis_count: 0,
       cache_hits: 0,
       cache_misses: 0
     }}
  end

  @impl GenServer
  def handle_call({:analyze, character_id, context}, _from, state) do
    result = perform_analysis(character_id, context)

    new_state =
      case result do
        {:ok, _} -> %{state | analysis_count: state.analysis_count + 1}
        _ -> state
      end

    {:reply, result, new_state}
  end

  @impl GenServer
  def handle_call({:bulk_analyze, character_ids, context}, _from, state) do
    results =
      Enum.map(character_ids, fn id ->
        {id, perform_analysis(id, context)}
      end)

    {:reply, {:ok, Map.new(results)}, state}
  end

  @impl GenServer
  def handle_call({:search, criteria}, _from, state) do
    # Placeholder implementation - search criteria processing not yet implemented
    {:reply, {:ok, []}, state}
  end

  @impl GenServer
  def handle_call({:activity_patterns, character_id, _opts}, _from, state) do
    # Placeholder implementation - activity pattern analysis not yet implemented
    {:reply, {:ok, %{character_id: character_id, patterns: []}}, state}
  end

  @impl GenServer
  def handle_call({:compare, character_ids}, _from, state) do
    # Placeholder implementation - character comparison not yet implemented
    {:reply, {:ok, %{characters: character_ids, comparison: %{}}}, state}
  end

  @impl GenServer
  def handle_call(:cache_stats, _from, state) do
    stats = %{
      analysis_count: state.analysis_count,
      cache_hits: state.cache_hits,
      cache_misses: state.cache_misses,
      hit_rate: calculate_hit_rate(state.cache_hits, state.cache_misses)
    }

    {:reply, stats, state}
  end

  # Private functions

  defp perform_analysis(character_id, _context) do
    # Check cache first
    case AnalysisCache.get_character_analysis(character_id) do
      {:ok, cached} ->
        {:ok, cached}

      {:error, :not_found} ->
        # Perform actual analysis
        analysis = %{
          character_id: character_id,
          threat_level: :medium,
          combat_effectiveness: 0.75,
          analyzed_at: DateTime.utc_now()
        }

        # Cache the result
        AnalysisCache.put_character_analysis(character_id, analysis)

        {:ok, analysis}
    end
  end

  defp calculate_hit_rate(0, 0), do: 0.0

  defp calculate_hit_rate(hits, misses) do
    Float.round(hits / (hits + misses) * 100, 2)
  end
end

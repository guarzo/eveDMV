defmodule EveDmv.Contexts.CorporationAnalysis.Infrastructure.AnalysisCache do
  @moduledoc """
  Analysis cache for corporation analysis results.

  Provides caching capabilities for expensive corporation analysis operations.
  """

  use GenServer
  require Logger

  # Public API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Store corporation analysis results in cache.
  """
  def store_analysis(corporation_id, analysis_type, data) do
    GenServer.call(__MODULE__, {:store, corporation_id, analysis_type, data})
  end

  @doc """
  Retrieve corporation analysis from cache.
  """
  def get_analysis(corporation_id, analysis_type) do
    GenServer.call(__MODULE__, {:get, corporation_id, analysis_type})
  end

  @doc """
  Clear cache for a specific corporation.
  """
  def clear_corporation_cache(corporation_id) do
    GenServer.call(__MODULE__, {:clear_corporation, corporation_id})
  end

  @doc """
  Clear entire cache.
  """
  def clear_cache do
    GenServer.call(__MODULE__, :clear_all)
  end

  @doc """
  Get cache statistics.
  """
  def get_cache_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  # GenServer implementation

  @impl GenServer
  def init(_opts) do
    state = %{
      cache: %{},
      stats: %{
        hits: 0,
        misses: 0,
        stores: 0,
        evictions: 0
      },
      # Default TTL: 10 minutes
      default_ttl: 600_000
    }

    # Schedule periodic cleanup
    schedule_cleanup()

    Logger.info("CorporationAnalysis.AnalysisCache started")
    {:ok, state}
  end

  @impl GenServer
  def handle_call({:store, corporation_id, analysis_type, data}, _from, state) do
    cache_key = generate_cache_key(corporation_id, analysis_type)
    timestamp = System.monotonic_time(:millisecond)

    cache_entry = %{
      data: data,
      timestamp: timestamp,
      ttl: state.default_ttl
    }

    new_cache = Map.put(state.cache, cache_key, cache_entry)
    new_stats = %{state.stats | stores: state.stats.stores + 1}

    new_state = %{state | cache: new_cache, stats: new_stats}

    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:get, corporation_id, analysis_type}, _from, state) do
    cache_key = generate_cache_key(corporation_id, analysis_type)
    current_time = System.monotonic_time(:millisecond)

    case Map.get(state.cache, cache_key) do
      %{data: data, timestamp: timestamp, ttl: ttl} when current_time - timestamp < ttl ->
        # Cache hit
        new_stats = %{state.stats | hits: state.stats.hits + 1}
        new_state = %{state | stats: new_stats}
        {:reply, {:ok, data}, new_state}

      %{} ->
        # Cache expired
        new_cache = Map.delete(state.cache, cache_key)

        new_stats = %{
          state.stats
          | misses: state.stats.misses + 1,
            evictions: state.stats.evictions + 1
        }

        new_state = %{state | cache: new_cache, stats: new_stats}
        {:reply, {:error, :cache_expired}, new_state}

      nil ->
        # Cache miss
        new_stats = %{state.stats | misses: state.stats.misses + 1}
        new_state = %{state | stats: new_stats}
        {:reply, {:error, :not_found}, new_state}
    end
  end

  @impl GenServer
  def handle_call({:clear_corporation, corporation_id}, _from, state) do
    # Remove all cache entries for this corporation
    new_cache =
      state.cache
      |> Enum.reject(fn {key, _} ->
        String.starts_with?(key, "corp:#{corporation_id}:")
      end)
      |> Enum.into(%{})

    removed_count = map_size(state.cache) - map_size(new_cache)
    new_stats = %{state.stats | evictions: state.stats.evictions + removed_count}

    new_state = %{state | cache: new_cache, stats: new_stats}

    {:reply, {:ok, removed_count}, new_state}
  end

  @impl GenServer
  def handle_call(:clear_all, _from, state) do
    cache_size = map_size(state.cache)
    new_stats = %{state.stats | evictions: state.stats.evictions + cache_size}

    new_state = %{state | cache: %{}, stats: new_stats}

    {:reply, {:ok, cache_size}, new_state}
  end

  @impl GenServer
  def handle_call(:get_stats, _from, state) do
    stats = %{
      state.stats
      | cache_size: map_size(state.cache),
        hit_rate: calculate_hit_rate(state.stats)
    }

    {:reply, stats, state}
  end

  @impl GenServer
  def handle_info(:cleanup, state) do
    # Remove expired entries
    current_time = System.monotonic_time(:millisecond)

    {expired_entries, valid_entries} =
      Enum.split_with(state.cache, fn {_key, %{timestamp: timestamp, ttl: ttl}} ->
        current_time - timestamp >= ttl
      end)

    new_cache = Enum.into(valid_entries, %{})
    expired_count = length(expired_entries)

    new_stats = %{state.stats | evictions: state.stats.evictions + expired_count}
    new_state = %{state | cache: new_cache, stats: new_stats}

    if expired_count > 0 do
      Logger.debug("Cleaned #{expired_count} expired cache entries")
    end

    # Schedule next cleanup
    schedule_cleanup()

    {:noreply, new_state}
  end

  # Private functions

  defp generate_cache_key(corporation_id, analysis_type) do
    "corp:#{corporation_id}:#{analysis_type}"
  end

  defp calculate_hit_rate(%{hits: hits, misses: misses}) when hits + misses > 0 do
    hits / (hits + misses) * 100
  end

  defp calculate_hit_rate(_), do: 0.0

  defp schedule_cleanup do
    # Cleanup every 5 minutes
    Process.send_after(self(), :cleanup, 300_000)
  end
end

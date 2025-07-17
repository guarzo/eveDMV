defmodule EveDmv.Contexts.MarketIntelligence.Infrastructure.PriceCache do
  @moduledoc """
  Cache implementation for market price data using ETS.

  Provides efficient in-memory caching of item price data with TTL support.
  """

  use GenServer
  require Logger

  @cache_table :price_cache
  @stats_table :price_cache_stats
  @default_ttl :timer.minutes(15)
  @cleanup_interval :timer.minutes(5)

  # Public API functions

  @doc """
  Start the price cache GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Get cached price data for a type ID.
  """
  @spec get(integer()) :: {:ok, map()} | {:error, :not_found}
  def get(type_id) when is_integer(type_id) do
    case :ets.lookup(@cache_table, type_id) do
      [{^type_id, price_data, expires_at}] ->
        if System.system_time(:millisecond) < expires_at do
          increment_stat(:hits)
          {:ok, price_data}
        else
          :ets.delete(@cache_table, type_id)
          increment_stat(:misses)
          {:error, :not_found}
        end

      [] ->
        increment_stat(:misses)
        {:error, :not_found}
    end
  rescue
    _error ->
      {:error, :cache_error}
  end

  @doc """
  Store price data in cache.
  """
  @spec put(integer(), map(), keyword()) :: :ok | {:error, term()}
  def put(type_id, price_data, opts \\ []) when is_integer(type_id) and is_map(price_data) do
    try do
      ttl = Keyword.get(opts, :ttl, @default_ttl)
      expires_at = System.system_time(:millisecond) + ttl

      # Add timestamp to price data
      enriched_data = Map.put(price_data, :cached_at, DateTime.utc_now())

      :ets.insert(@cache_table, {type_id, enriched_data, expires_at})
      increment_stat(:puts)
      :ok
    rescue
      error ->
        Logger.error("Error storing price cache: #{inspect(error)}")
        {:error, :cache_error}
    end
  end

  @doc """
  Get cache statistics.
  """
  @spec stats() :: %{
          size: non_neg_integer(),
          memory_bytes: non_neg_integer(),
          hits: non_neg_integer(),
          misses: non_neg_integer(),
          puts: non_neg_integer(),
          hit_rate: float()
        }
  def stats do
    try do
      size = :ets.info(@cache_table, :size)
      memory = :ets.info(@cache_table, :memory)
      memory_bytes = memory * :erlang.system_info(:wordsize)

      hits = get_stat(:hits)
      misses = get_stat(:misses)
      puts = get_stat(:puts)

      %{
        size: size,
        memory_bytes: memory_bytes,
        hits: hits,
        misses: misses,
        puts: puts,
        hit_rate: if(hits + misses > 0, do: hits / (hits + misses), else: 0.0)
      }
    rescue
      _error ->
        %{size: 0, memory_bytes: 0, hits: 0, misses: 0, puts: 0, hit_rate: 0.0}
    end
  end

  @doc """
  Invalidate all cached price data.
  """
  @spec invalidate_all() :: :ok
  def invalidate_all do
    try do
      :ets.delete_all_objects(@cache_table)
      reset_stats()
      :ok
    rescue
      _error -> :ok
    end
  end

  @doc """
  Get hot items (frequently accessed prices).
  """
  @spec get_hot_items(pos_integer()) :: [map()]
  def get_hot_items(limit) when is_integer(limit) and limit > 0 do
    try do
      # Get all items and sort by access patterns
      # For simplicity, return recent items (would need access tracking for real hot items)
      now = System.system_time(:millisecond)

      :ets.tab2list(@cache_table)
      |> Enum.filter(fn {_type_id, _data, expires_at} -> expires_at > now end)
      |> Enum.map(fn {type_id, data, _expires_at} ->
        Map.put(data, :type_id, type_id)
      end)
      |> Enum.take(limit)
    rescue
      _error -> []
    end
  end

  # GenServer callbacks

  @impl true
  def init(_opts) do
    # Create ETS tables
    :ets.new(@cache_table, [:named_table, :set, :public, read_concurrency: true])
    :ets.new(@stats_table, [:named_table, :set, :public])

    # Initialize stats
    reset_stats()

    # Schedule periodic cleanup
    schedule_cleanup()

    Logger.info("Price cache started")
    {:ok, %{}}
  end

  @impl true
  def handle_info(:cleanup, state) do
    cleanup_expired()
    schedule_cleanup()
    {:noreply, state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # Private helper functions

  defp increment_stat(key) do
    :ets.update_counter(@stats_table, key, 1, {key, 0})
  end

  defp get_stat(key) do
    case :ets.lookup(@stats_table, key) do
      [{^key, count}] -> count
      [] -> 0
    end
  end

  defp reset_stats do
    :ets.insert(@stats_table, {:hits, 0})
    :ets.insert(@stats_table, {:misses, 0})
    :ets.insert(@stats_table, {:puts, 0})
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @cleanup_interval)
  end

  defp cleanup_expired do
    now = System.system_time(:millisecond)

    expired_keys =
      :ets.tab2list(@cache_table)
      |> Enum.filter(fn {_type_id, _data, expires_at} -> expires_at <= now end)
      |> Enum.map(fn {type_id, _data, _expires_at} -> type_id end)

    Enum.each(expired_keys, &:ets.delete(@cache_table, &1))

    if length(expired_keys) > 0 do
      Logger.debug("Cleaned up #{length(expired_keys)} expired price cache entries")
    end
  end
end

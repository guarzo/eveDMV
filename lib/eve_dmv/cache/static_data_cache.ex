defmodule EveDmv.Cache.StaticDataCache do
  @moduledoc """
  High-performance caching for static EVE data that rarely changes.

  This module provides:
  - Bulk loading of common static data at startup
  - Batch resolution of names to eliminate N+1 queries
  - In-memory caching using ETS for sub-millisecond lookups
  - Automatic cache warming for frequently accessed data
  """

  use GenServer
  import Ash.Query

  alias EveDmv.Eve.ItemType
  alias EveDmv.Eve.SolarSystem

  require Logger

  @table_name :static_data_cache
  @warm_cache_interval :timer.hours(6)

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Resolve multiple system IDs to names in a single operation.
  Returns a map of system_id => system_name.
  """
  def resolve_system_names(system_ids) when is_list(system_ids) do
    unique_ids = Enum.uniq(system_ids)

    # Check cache first
    {cached_results, missing_ids} =
      Enum.reduce(unique_ids, {[], []}, fn id, {cached, missing} ->
        case :ets.lookup(@table_name, {:system, id}) do
          [{_, name}] -> {[{id, name} | cached], missing}
          [] -> {cached, [id | missing]}
        end
      end)

    # Update stats
    if cached_results != [] do
      GenServer.cast(__MODULE__, {:record_hits, length(cached_results)})
    end

    if missing_ids != [] do
      GenServer.cast(__MODULE__, {:record_misses, length(missing_ids)})
    end

    cached_map = Map.new(cached_results)

    # Batch fetch missing
    if missing_ids == [] do
      cached_map
    else
      fetched_map = batch_fetch_systems(missing_ids)
      Map.merge(cached_map, fetched_map)
    end
  end

  @doc """
  Resolve a single system ID to name.
  """
  def resolve_system_name(system_id) when is_integer(system_id) do
    case :ets.lookup(@table_name, {:system, system_id}) do
      [{_, name}] ->
        GenServer.cast(__MODULE__, {:record_hits, 1})
        name

      [] ->
        GenServer.cast(__MODULE__, {:record_misses, 1})
        # Single fetch with caching
        case fetch_and_cache_system(system_id) do
          {:ok, name} -> name
          :error -> "Unknown System"
        end
    end
  end

  def resolve_system_name(_), do: "Unknown System"

  @doc """
  Resolve multiple ship type IDs to names in a single operation.
  """
  def resolve_ship_names(type_ids) when is_list(type_ids) do
    resolve_item_names(type_ids, :ship)
  end

  @doc """
  Resolve a single ship type ID to name.
  """
  def resolve_ship_name(type_id) when is_integer(type_id) do
    resolve_item_name(type_id, :ship)
  end

  def resolve_ship_name(_), do: "Unknown Ship"

  @doc """
  Warm the cache with commonly accessed data.
  """
  def warm_cache do
    GenServer.cast(__MODULE__, :warm_cache)
  end

  @doc """
  Clear all cached data.
  """
  def clear_cache do
    GenServer.call(__MODULE__, :clear_cache)
  end

  @doc """
  Get cache statistics.
  """
  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  # Server callbacks

  def init(_opts) do
    # Create ETS table
    :ets.new(@table_name, [:set, :public, :named_table, read_concurrency: true])

    # Only warm cache in non-test environments
    unless Application.get_env(:eve_dmv, :environment, :prod) == :test do
      # Schedule cache warming
      schedule_warm_cache()

      # Initial cache warming
      send(self(), :initial_warm_cache)
    end

    {:ok,
     %{
       hits: 0,
       misses: 0,
       last_warm: nil
     }}
  end

  def handle_call(:clear_cache, _from, state) do
    :ets.delete_all_objects(@table_name)
    {:reply, :ok, %{state | hits: 0, misses: 0}}
  end

  def handle_call(:get_stats, _from, state) do
    cache_size = :ets.info(@table_name, :size)
    memory = :ets.info(@table_name, :memory)

    stats = %{
      cache_size: cache_size,
      memory_bytes: memory * :erlang.system_info(:wordsize),
      hits: state.hits,
      misses: state.misses,
      hit_rate: calculate_hit_rate(state.hits, state.misses),
      last_warm: state.last_warm
    }

    {:reply, stats, state}
  end

  def handle_cast(:warm_cache, state) do
    Task.start(fn -> perform_cache_warming() end)
    {:noreply, %{state | last_warm: DateTime.utc_now()}}
  end

  def handle_cast({:record_hits, count}, state) do
    {:noreply, %{state | hits: state.hits + count}}
  end

  def handle_cast({:record_misses, count}, state) do
    {:noreply, %{state | misses: state.misses + count}}
  end

  def handle_info(:initial_warm_cache, state) do
    Logger.info("Performing initial static data cache warming")
    perform_cache_warming()
    {:noreply, %{state | last_warm: DateTime.utc_now()}}
  end

  def handle_info(:scheduled_warm_cache, state) do
    Logger.info("Performing scheduled static data cache warming")
    perform_cache_warming()
    schedule_warm_cache()
    {:noreply, %{state | last_warm: DateTime.utc_now()}}
  end

  # Private functions

  defp resolve_item_names(type_ids, category) when is_list(type_ids) do
    unique_ids = Enum.uniq(type_ids)

    # Check cache first
    {cached_results, missing_ids} =
      Enum.reduce(unique_ids, {[], []}, fn id, {cached, missing} ->
        case :ets.lookup(@table_name, {category, id}) do
          [{_, name}] -> {[{id, name} | cached], missing}
          [] -> {cached, [id | missing]}
        end
      end)

    # Update stats
    if cached_results != [] do
      GenServer.cast(__MODULE__, {:record_hits, length(cached_results)})
    end

    if missing_ids != [] do
      GenServer.cast(__MODULE__, {:record_misses, length(missing_ids)})
    end

    cached_map = Map.new(cached_results)

    # Batch fetch missing
    if missing_ids == [] do
      cached_map
    else
      fetched_map = batch_fetch_items(missing_ids, category)
      Map.merge(cached_map, fetched_map)
    end
  end

  defp resolve_item_name(type_id, category) when is_integer(type_id) do
    case :ets.lookup(@table_name, {category, type_id}) do
      [{_, name}] ->
        GenServer.cast(__MODULE__, {:record_hits, 1})
        name

      [] ->
        GenServer.cast(__MODULE__, {:record_misses, 1})
        # Single fetch with caching
        case fetch_and_cache_item(type_id, category) do
          {:ok, name} -> name
          :error -> "Unknown #{category |> to_string() |> String.capitalize()}"
        end
    end
  end

  defp batch_fetch_systems(system_ids) do
    Logger.debug("Batch fetching #{length(system_ids)} systems")

    query =
      SolarSystem
      |> new()
      |> filter(system_id in ^system_ids)

    case Ash.read(query, domain: EveDmv.Api) do
      {:ok, systems} ->
        # Cache all results
        result_map =
          Map.new(systems, fn system ->
            :ets.insert(@table_name, {{:system, system.system_id}, system.system_name})
            {system.system_id, system.system_name}
          end)

        # Add "Unknown" for any missing
        missing_ids = system_ids -- Map.keys(result_map)

        unknown_map =
          Map.new(missing_ids, fn id ->
            name = "Unknown System (#{id})"
            :ets.insert(@table_name, {{:system, id}, name})
            {id, name}
          end)

        Map.merge(result_map, unknown_map)

      {:error, error} ->
        Logger.error("Failed to batch fetch systems: #{inspect(error)}")
        Map.new(system_ids, fn id -> {id, "Unknown System"} end)
    end
  end

  defp batch_fetch_items(type_ids, category) do
    Logger.debug("Batch fetching #{length(type_ids)} items of category #{category}")

    query =
      ItemType
      |> new()
      |> filter(type_id in ^type_ids)

    case Ash.read(query, domain: EveDmv.Api) do
      {:ok, items} ->
        # Cache all results
        result_map =
          Map.new(items, fn item ->
            :ets.insert(@table_name, {{category, item.type_id}, item.type_name})
            {item.type_id, item.type_name}
          end)

        # Add "Unknown" for any missing
        missing_ids = type_ids -- Map.keys(result_map)

        unknown_map =
          Map.new(missing_ids, fn id ->
            name = "Unknown #{category |> to_string() |> String.capitalize()} (#{id})"
            :ets.insert(@table_name, {{category, id}, name})
            {id, name}
          end)

        Map.merge(result_map, unknown_map)

      {:error, error} ->
        Logger.error("Failed to batch fetch items: #{inspect(error)}")

        Map.new(type_ids, fn id ->
          {id, "Unknown #{category |> to_string() |> String.capitalize()}"}
        end)
    end
  end

  defp fetch_and_cache_system(system_id) do
    query =
      SolarSystem
      |> new()
      |> filter(system_id == ^system_id)
      |> limit(1)

    case Ash.read(query, domain: EveDmv.Api) do
      {:ok, [system]} ->
        :ets.insert(@table_name, {{:system, system_id}, system.system_name})
        {:ok, system.system_name}

      _ ->
        :error
    end
  end

  defp fetch_and_cache_item(type_id, category) do
    query =
      ItemType
      |> new()
      |> filter(type_id == ^type_id)
      |> limit(1)

    case Ash.read(query, domain: EveDmv.Api) do
      {:ok, [item]} ->
        :ets.insert(@table_name, {{category, type_id}, item.type_name})
        {:ok, item.type_name}

      _ ->
        :error
    end
  end

  defp perform_cache_warming do
    Logger.info("Starting static data cache warming")

    # Warm common systems (high-sec trade hubs, popular null systems)
    common_systems = [
      # Jita
      30_000_142,
      # Amarr
      30_002_187,
      # Dodixie
      30_002_659,
      # Hek
      30_002_053,
      # Rens
      30_002_510,
      # Perimeter
      30_002_718,
      # Jita 4-4 adjacent
      30_000_144,
      # Ashab
      30_002_761,
      # Common WH system from our data
      31_002_238
    ]

    # Warm common ship types
    common_ships = [
      # Frigates
      587,
      588,
      589,
      590,
      591,
      592,
      593,
      594,
      # Cruisers
      620,
      621,
      622,
      623,
      624,
      625,
      626,
      627,
      # Battleships
      638,
      639,
      640,
      641,
      642,
      643,
      644,
      645,
      # Common PvP ships
      # Interceptors
      11_993,
      11_987,
      11_985,
      11_989,
      # Assault Frigates
      22_442,
      22_444,
      22_446,
      22_448,
      # Strategic Cruisers
      29_984,
      29_986,
      29_988,
      29_990
    ]

    # Batch load all at once
    resolve_system_names(common_systems)
    resolve_ship_names(common_ships)

    Logger.info("Static data cache warming completed")
  end

  defp schedule_warm_cache do
    Process.send_after(self(), :scheduled_warm_cache, @warm_cache_interval)
  end

  defp calculate_hit_rate(0, 0), do: 0.0

  defp calculate_hit_rate(hits, misses) do
    total = hits + misses
    Float.round(hits / total * 100, 2)
  end
end

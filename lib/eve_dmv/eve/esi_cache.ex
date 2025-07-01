defmodule EveDmv.Eve.EsiCache do
  @moduledoc """
  ETS-based cache for ESI API responses.

  Caches character, corporation, and alliance data with appropriate TTLs.
  """

  use GenServer
  require Logger

  @character_table :esi_character_cache
  @corporation_table :esi_corporation_cache
  @alliance_table :esi_alliance_cache
  @universe_table :esi_universe_cache

  # Cache TTLs
  @character_ttl_minutes 10
  @corporation_ttl_minutes 60
  @alliance_ttl_minutes 60
  # 1 day for universe data
  @universe_ttl_minutes 1440
  @cleanup_interval_minutes 30

  # Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Get a character from cache.
  """
  @spec get_character(integer()) :: {:ok, map()} | :miss
  def get_character(character_id) do
    get_from_cache(@character_table, character_id)
  end

  @doc """
  Get multiple characters from cache.
  Returns {found_map, missing_list}.
  """
  @spec get_characters([integer()]) :: {map(), [integer()]}
  def get_characters(character_ids) do
    get_multiple_from_cache(@character_table, character_ids)
  end

  @doc """
  Store a character in cache.
  """
  @spec put_character(integer(), map()) :: :ok
  def put_character(character_id, character_data) do
    put_in_cache(@character_table, character_id, character_data, @character_ttl_minutes)
  end

  @doc """
  Get a corporation from cache.
  """
  @spec get_corporation(integer()) :: {:ok, map()} | :miss
  def get_corporation(corporation_id) do
    get_from_cache(@corporation_table, corporation_id)
  end

  @doc """
  Store a corporation in cache.
  """
  @spec put_corporation(integer(), map()) :: :ok
  def put_corporation(corporation_id, corporation_data) do
    put_in_cache(@corporation_table, corporation_id, corporation_data, @corporation_ttl_minutes)
  end

  @doc """
  Get an alliance from cache.
  """
  @spec get_alliance(integer()) :: {:ok, map()} | :miss
  def get_alliance(alliance_id) do
    get_from_cache(@alliance_table, alliance_id)
  end

  @doc """
  Store an alliance in cache.
  """
  @spec put_alliance(integer(), map()) :: :ok
  def put_alliance(alliance_id, alliance_data) do
    put_in_cache(@alliance_table, alliance_id, alliance_data, @alliance_ttl_minutes)
  end

  @doc """
  Get a value from the generic cache.
  """
  @spec get(String.t()) :: {:ok, any()} | {:error, :not_found}
  def get(key) do
    case get_from_cache(@character_table, key) do
      {:ok, data} -> {:ok, data}
      :miss -> {:error, :not_found}
    end
  end

  @doc """
  Store a value in the generic cache.
  """
  @spec put(String.t(), any(), keyword()) :: :ok
  def put(key, value, opts \\ []) do
    ttl_seconds = Keyword.get(opts, :ttl, 3600)
    ttl_minutes = div(ttl_seconds, 60)
    put_in_cache(@character_table, key, value, ttl_minutes)
  end

  @doc """
  Get a system from cache.
  """
  @spec get_system(integer()) :: {:ok, map()} | :miss
  def get_system(system_id) do
    get_from_cache(@universe_table, {:system, system_id})
  end

  @doc """
  Store a system in cache.
  """
  @spec put_system(integer(), map()) :: :ok
  def put_system(system_id, system_data) do
    put_in_cache(@universe_table, {:system, system_id}, system_data, @universe_ttl_minutes)
  end

  @doc """
  Get a type from cache.
  """
  @spec get_type(integer()) :: {:ok, map()} | :miss
  def get_type(type_id) do
    get_from_cache(@universe_table, {:type, type_id})
  end

  @doc """
  Store a type in cache.
  """
  @spec put_type(integer(), map()) :: :ok
  def put_type(type_id, type_data) do
    put_in_cache(@universe_table, {:type, type_id}, type_data, @universe_ttl_minutes)
  end

  @doc """
  Get a group from cache.
  """
  @spec get_group(integer()) :: {:ok, map()} | :miss
  def get_group(group_id) do
    get_from_cache(@universe_table, {:group, group_id})
  end

  @doc """
  Store a group in cache.
  """
  @spec put_group(integer(), map()) :: :ok
  def put_group(group_id, group_data) do
    put_in_cache(@universe_table, {:group, group_id}, group_data, @universe_ttl_minutes)
  end

  @doc """
  Get a category from cache.
  """
  @spec get_category(integer()) :: {:ok, map()} | :miss
  def get_category(category_id) do
    get_from_cache(@universe_table, {:category, category_id})
  end

  @doc """
  Store a category in cache.
  """
  @spec put_category(integer(), map()) :: :ok
  def put_category(category_id, category_data) do
    put_in_cache(@universe_table, {:category, category_id}, category_data, @universe_ttl_minutes)
  end

  @doc """
  Clear all caches.
  """
  @spec clear_all() :: :ok
  def clear_all do
    :ets.delete_all_objects(@character_table)
    :ets.delete_all_objects(@corporation_table)
    :ets.delete_all_objects(@alliance_table)
    :ets.delete_all_objects(@universe_table)
    :ok
  end

  @doc """
  Get cache statistics.
  """
  @spec stats() :: %{
          characters: %{size: non_neg_integer(), memory_bytes: number()},
          corporations: %{size: non_neg_integer(), memory_bytes: number()},
          alliances: %{size: non_neg_integer(), memory_bytes: number()},
          universe: %{size: non_neg_integer(), memory_bytes: number()}
        }
  def stats do
    %{
      characters: table_stats(@character_table),
      corporations: table_stats(@corporation_table),
      alliances: table_stats(@alliance_table),
      universe: table_stats(@universe_table)
    }
  end

  # Server callbacks

  @impl true
  def init(_args) do
    # Create ETS tables
    :ets.new(@character_table, [
      :set,
      :public,
      :named_table,
      read_concurrency: true,
      write_concurrency: true
    ])

    :ets.new(@corporation_table, [
      :set,
      :public,
      :named_table,
      read_concurrency: true,
      write_concurrency: true
    ])

    :ets.new(@alliance_table, [
      :set,
      :public,
      :named_table,
      read_concurrency: true,
      write_concurrency: true
    ])

    :ets.new(@universe_table, [
      :set,
      :public,
      :named_table,
      read_concurrency: true,
      write_concurrency: true
    ])

    # Schedule periodic cleanup
    schedule_cleanup()

    {:ok, %{}}
  end

  @impl true
  def handle_info(:cleanup_expired, state) do
    cleanup_expired_entries(@character_table, "character")
    cleanup_expired_entries(@corporation_table, "corporation")
    cleanup_expired_entries(@alliance_table, "alliance")
    cleanup_expired_entries(@universe_table, "universe")

    schedule_cleanup()
    {:noreply, state}
  end

  # Private functions

  defp get_from_cache(table, id) do
    case :ets.lookup(table, id) do
      [{^id, data, expires_at}] ->
        if DateTime.compare(DateTime.utc_now(), expires_at) == :lt do
          {:ok, data}
        else
          # Expired, remove it
          :ets.delete(table, id)
          :miss
        end

      [] ->
        :miss
    end
  end

  defp get_multiple_from_cache(table, ids) do
    now = DateTime.utc_now()

    Enum.reduce(ids, {%{}, []}, fn id, {found, missing} ->
      case :ets.lookup(table, id) do
        [{^id, data, expires_at}] ->
          if DateTime.compare(now, expires_at) == :lt do
            {Map.put(found, id, data), missing}
          else
            # Expired
            :ets.delete(table, id)
            {found, [id | missing]}
          end

        [] ->
          {found, [id | missing]}
      end
    end)
  end

  defp put_in_cache(table, id, data, ttl_minutes) do
    expires_at = DateTime.add(DateTime.utc_now(), ttl_minutes * 60, :second)
    :ets.insert(table, {id, data, expires_at})
    :ok
  end

  defp table_stats(table) do
    %{
      size: :ets.info(table, :size),
      memory_bytes: :ets.info(table, :memory) * :erlang.system_info(:wordsize)
    }
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup_expired, @cleanup_interval_minutes * 60 * 1000)
  end

  defp cleanup_expired_entries(table, type) do
    now = DateTime.utc_now()

    expired_count =
      :ets.foldl(
        fn {id, _data, expires_at}, count ->
          if DateTime.compare(now, expires_at) == :gt do
            :ets.delete(table, id)
            count + 1
          else
            count
          end
        end,
        0,
        table
      )

    if expired_count > 0 do
      Logger.info("Cleaned up #{expired_count} expired #{type} cache entries")
    end
  end
end

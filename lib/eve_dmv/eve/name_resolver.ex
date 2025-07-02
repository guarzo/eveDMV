defmodule EveDmv.Eve.NameResolver do
  @moduledoc """
  Helper module for resolving EVE Online IDs to friendly names.

  This module provides efficient caching and lookup functions for converting
  type IDs and system IDs to human-readable names in the UI.
  """

  require Logger

  alias EveDmv.Eve.{EsiClient, ItemType, SolarSystem}

  # ETS table for caching lookups
  @table_name :eve_name_cache
  # Different TTLs for different data types
  # Ship/item names rarely change
  @static_data_ttl :timer.hours(24)
  # Character/corp names can change
  @dynamic_data_ttl :timer.hours(4)
  # ESI data more frequent updates
  @esi_data_ttl :timer.minutes(30)

  # Configurable timeout and concurrency settings
  @task_timeout Application.compile_env(:eve_dmv, :name_resolver_task_timeout, 30_000)
  @max_concurrency Application.compile_env(:eve_dmv, :name_resolver_max_concurrency, 10)
  @esi_timeout Application.compile_env(:eve_dmv, :name_resolver_esi_timeout, 10_000)

  # ============================================================================
  # Public API
  # ============================================================================

  @doc """
  Starts the name resolver cache.
  Called during application startup.
  """
  def start_cache do
    case :ets.whereis(@table_name) do
      :undefined ->
        :ets.new(@table_name, [:set, :public, :named_table])
        Logger.info("Started EVE name resolver cache")

      _pid ->
        Logger.debug("EVE name resolver cache already started")
    end

    :ok
  end

  @doc """
  Resolves a ship type ID to a ship name.

  ## Examples

      iex> NameResolver.ship_name(587)
      "Rifter"
      
      iex> NameResolver.ship_name(999999)
      "Unknown Ship (999999)"
  """
  @spec ship_name(integer()) :: String.t()
  def ship_name(type_id) when is_integer(type_id) do
    case get_cached_or_fetch(:ship_type, type_id) do
      {:ok, name} -> name
      {:error, _} -> "Unknown Ship (#{type_id})"
    end
  end

  @doc """
  Resolves an item type ID to an item name.
  Works for ships, modules, charges, etc.

  ## Examples

      iex> NameResolver.item_name(12058)
      "Medium Shield Extender II"
      
      iex> NameResolver.item_name(999999)
      "Unknown Item (999999)"
  """
  @spec item_name(integer()) :: String.t()
  def item_name(type_id) when is_integer(type_id) do
    case get_cached_or_fetch(:item_type, type_id) do
      {:ok, name} -> name
      {:error, _} -> "Unknown Item (#{type_id})"
    end
  end

  @doc """
  Resolves a solar system ID to a system name.

  ## Examples

      iex> NameResolver.system_name(30000142)
      "Jita"
      
      iex> NameResolver.system_name(999999)
      "Unknown System (999999)"
  """
  @spec system_name(integer()) :: String.t()
  def system_name(system_id) when is_integer(system_id) do
    case get_cached_or_fetch(:solar_system, system_id) do
      {:ok, name} -> name
      {:error, _} -> "Unknown System (#{system_id})"
    end
  end

  @doc """
  Resolves multiple ship type IDs to names efficiently.

  ## Examples

      iex> NameResolver.ship_names([587, 588, 589])
      %{587 => "Rifter", 588 => "Punisher", 589 => "Tormentor"}
  """
  @spec ship_names(list(integer())) :: map()
  def ship_names(type_ids) when is_list(type_ids) do
    batch_resolve(:ship_type, type_ids, &ship_name/1)
  end

  @doc """
  Resolves multiple item type IDs to names efficiently.
  """
  @spec item_names(list(integer())) :: map()
  def item_names(type_ids) when is_list(type_ids) do
    batch_resolve(:item_type, type_ids, &item_name/1)
  end

  @doc """
  Resolves multiple solar system IDs to names efficiently.
  """
  @spec system_names(list(integer())) :: map()
  def system_names(system_ids) when is_list(system_ids) do
    batch_resolve(:solar_system, system_ids, &system_name/1)
  end

  @doc """
  Resolves a character ID to a character name using ESI.

  ## Examples

      iex> NameResolver.character_name(95465499)
      "CCP Falcon"
      
      iex> NameResolver.character_name(999999999)
      "Unknown Character (999999999)"
  """
  @spec character_name(integer()) :: String.t()
  def character_name(character_id) when is_integer(character_id) do
    case get_cached_or_fetch(:character, character_id) do
      {:ok, name} -> name
      {:error, _} -> "Unknown Character (#{character_id})"
    end
  end

  @doc """
  Resolves a corporation ID to a corporation name using ESI.

  ## Examples

      iex> NameResolver.corporation_name(98388312)
      "CCP Games"
      
      iex> NameResolver.corporation_name(999999999)
      "Unknown Corporation (999999999)"
  """
  @spec corporation_name(integer()) :: String.t()
  def corporation_name(corporation_id) when is_integer(corporation_id) do
    case get_cached_or_fetch(:corporation, corporation_id) do
      {:ok, name} -> name
      {:error, _} -> "Unknown Corporation (#{corporation_id})"
    end
  end

  @doc """
  Resolves an alliance ID to an alliance name using ESI.

  ## Examples

      iex> NameResolver.alliance_name(99005338)
      "Pandemic Horde"
      
      iex> NameResolver.alliance_name(999999999)
      "Unknown Alliance (999999999)"
  """
  @spec alliance_name(integer() | nil) :: String.t() | nil
  def alliance_name(nil), do: nil

  def alliance_name(alliance_id) when is_integer(alliance_id) do
    case get_cached_or_fetch(:alliance, alliance_id) do
      {:ok, name} -> name
      {:error, _} -> "Unknown Alliance (#{alliance_id})"
    end
  end

  @doc """
  Resolves multiple character IDs to names efficiently.
  Uses ESI bulk lookup when possible.
  """
  @spec character_names(list(integer())) :: map()
  def character_names(character_ids) when is_list(character_ids) do
    batch_resolve_with_esi(:character, character_ids, &character_name/1)
  end

  @doc """
  Resolves multiple corporation IDs to names efficiently.
  Uses ESI bulk lookup when possible.
  """
  @spec corporation_names(list(integer())) :: map()
  def corporation_names(corporation_ids) when is_list(corporation_ids) do
    batch_resolve_with_esi(:corporation, corporation_ids, &corporation_name/1)
  end

  @doc """
  Resolves multiple alliance IDs to names efficiently.
  """
  @spec alliance_names(list(integer())) :: map()
  def alliance_names(alliance_ids) when is_list(alliance_ids) do
    batch_resolve_with_esi(:alliance, alliance_ids, &alliance_name/1)
  end

  @doc """
  Gets the security class and color for a solar system.

  ## Examples

      iex> NameResolver.system_security(30000142)
      %{class: "highsec", color: "text-green-400", status: 0.946}
  """
  @spec system_security(integer()) :: %{
          class: String.t(),
          color: String.t(),
          status: number()
        }
  def system_security(system_id) when is_integer(system_id) do
    case get_cached_or_fetch(:solar_system_full, system_id) do
      {:ok, system} ->
        security_class = system.security_class || "unknown"

        color =
          case security_class do
            "highsec" -> "text-green-400"
            "lowsec" -> "text-yellow-400"
            "nullsec" -> "text-red-400"
            "wormhole" -> "text-purple-400"
            _ -> "text-gray-400"
          end

        %{
          class: security_class,
          color: color,
          status:
            case system.security_status do
              %Decimal{} = decimal -> Decimal.to_float(decimal)
              value -> value || 0.0
            end
        }

      {:error, _} ->
        %{class: "unknown", color: "text-gray-400", status: 0.0}
    end
  end

  @doc """
  Clears all cached names. Useful for development/testing.
  """
  def clear_cache do
    case :ets.whereis(@table_name) do
      :undefined ->
        :ok

      _pid ->
        :ets.delete_all_objects(@table_name)
        Logger.info("Cleared EVE name resolver cache")
    end

    :ok
  end

  @doc """
  Preloads names for killmail participants to improve UI performance.

  Takes a list of killmails and preloads all character, corporation, 
  and alliance names found in the participants.
  """
  def preload_killmail_names(killmails) when is_list(killmails) do
    Logger.debug("Preloading names for #{length(killmails)} killmails")

    # Extract all unique IDs from killmails
    {character_ids, corp_ids, alliance_ids} =
      Enum.reduce(killmails, {[], [], []}, fn km, {chars, corps, alliances} ->
        new_chars =
          [
            km.victim_character_id,
            km.final_blow_character_id
          ]
          |> Enum.reject(&is_nil/1)

        new_corps = [km.victim_corporation_id] |> Enum.reject(&is_nil/1)
        new_alliances = [km.victim_alliance_id] |> Enum.reject(&is_nil/1)

        {chars ++ new_chars, corps ++ new_corps, alliances ++ new_alliances}
      end)

    # Batch resolve all names in parallel
    tasks = [
      Task.async(fn -> character_names(Enum.uniq(character_ids)) end),
      Task.async(fn -> corporation_names(Enum.uniq(corp_ids)) end),
      Task.async(fn -> alliance_names(Enum.uniq(alliance_ids)) end)
    ]

    # Wait for all tasks to complete
    Enum.each(tasks, &Task.await(&1, @task_timeout))

    Logger.debug("Name preloading complete")
    :ok
  end

  @doc """
  Warms the cache with commonly used items.
  Should be called after static data is loaded.
  """
  def warm_cache do
    Logger.info("Warming EVE name resolver cache")

    cache_config = Application.get_env(:eve_dmv, :name_resolver_cache_warming, [])

    # Pre-load common ship types
    common_ships = Keyword.get(cache_config, :common_ships, [])

    unless Enum.empty?(common_ships) do
      ship_names(common_ships)
    end

    # Pre-load major trade hubs
    trade_hubs = Keyword.get(cache_config, :trade_hubs, [])

    unless Enum.empty?(trade_hubs) do
      system_names(trade_hubs)
    end

    # Pre-load well-known NPCs and corporations
    npc_corps = Keyword.get(cache_config, :npc_corporations, [])

    unless Enum.empty?(npc_corps) do
      corporation_names(npc_corps)
    end

    Logger.info("Cache warming complete")
    :ok
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

  defp get_cached_or_fetch(type, id) do
    cache_key = {type, id}

    case :ets.lookup(@table_name, cache_key) do
      [{^cache_key, value, expires_at}] ->
        if :os.system_time(:millisecond) < expires_at do
          {:ok, value}
        else
          # Cache expired, fetch fresh data
          :ets.delete(@table_name, cache_key)
          fetch_and_cache_atomic(type, id)
        end

      [] ->
        fetch_and_cache_atomic(type, id)
    end
  end

  # Atomic cache insertion to prevent race conditions
  defp fetch_and_cache_atomic(type, id) do
    cache_key = {type, id}

    case fetch_from_database(type, id) do
      {:ok, value} ->
        ttl = get_ttl_for_type(type)
        expires_at = :os.system_time(:millisecond) + ttl
        cache_entry = {cache_key, value, expires_at}

        # Use insert_new to atomically insert only if key doesn't exist
        case :ets.insert_new(@table_name, cache_entry) do
          true ->
            {:ok, value}

          false ->
            handle_cache_collision(cache_key, cache_entry, value)
        end

      error ->
        error
    end
  end

  defp handle_cache_collision(cache_key, cache_entry, value) do
    # Another process already inserted this key, use their value
    case :ets.lookup(@table_name, cache_key) do
      [{^cache_key, existing_value, existing_expires}] ->
        if :os.system_time(:millisecond) < existing_expires do
          {:ok, existing_value}
        else
          # Their entry expired too, replace it
          :ets.insert(@table_name, cache_entry)
          {:ok, value}
        end

      [] ->
        # Edge case: they deleted it between insert_new and lookup
        :ets.insert(@table_name, cache_entry)
        {:ok, value}
    end
  end

  defp get_ttl_for_type(type)
       when type in [:item_type, :ship_type, :solar_system, :solar_system_full] do
    @static_data_ttl
  end

  defp get_ttl_for_type(type) when type in [:character, :corporation, :alliance] do
    @esi_data_ttl
  end

  defp get_ttl_for_type(_type), do: @dynamic_data_ttl

  defp fetch_from_database(:ship_type, type_id) do
    fetch_from_database(:item_type, type_id)
  end

  defp fetch_from_database(:item_type, type_id) do
    case Ash.get(ItemType, type_id, domain: EveDmv.Api, authorize?: false) do
      {:ok, item} -> {:ok, item.type_name}
      {:error, _} -> {:error, :not_found}
    end
  rescue
    error ->
      Logger.warning("Failed to fetch item type #{type_id}: #{inspect(error)}")
      {:error, :database_error}
  end

  defp fetch_from_database(:solar_system, system_id) do
    case Ash.get(SolarSystem, system_id, domain: EveDmv.Api, authorize?: false) do
      {:ok, system} -> {:ok, system.system_name}
      {:error, _} -> {:error, :not_found}
    end
  rescue
    error ->
      Logger.warning("Failed to fetch solar system #{system_id}: #{inspect(error)}")
      {:error, :database_error}
  end

  defp fetch_from_database(:solar_system_full, system_id) do
    case Ash.get(SolarSystem, system_id, domain: EveDmv.Api, authorize?: false) do
      {:ok, system} -> {:ok, system}
      {:error, _} -> {:error, :not_found}
    end
  rescue
    error ->
      Logger.warning("Failed to fetch solar system #{system_id}: #{inspect(error)}")
      {:error, :database_error}
  end

  defp fetch_from_database(:character, character_id) do
    case EsiClient.get_character(character_id) do
      {:ok, character} -> {:ok, character.name}
      {:error, _} -> {:error, :not_found}
    end
  rescue
    error ->
      Logger.warning("Failed to fetch character #{character_id} from ESI: #{inspect(error)}")
      {:error, :esi_error}
  end

  defp fetch_from_database(:corporation, corporation_id) do
    case EsiClient.get_corporation(corporation_id) do
      {:ok, corporation} -> {:ok, corporation.name}
      {:error, _} -> {:error, :not_found}
    end
  rescue
    error ->
      Logger.warning("Failed to fetch corporation #{corporation_id} from ESI: #{inspect(error)}")
      {:error, :esi_error}
  end

  defp fetch_from_database(:alliance, alliance_id) do
    case EsiClient.get_alliance(alliance_id) do
      {:ok, alliance} -> {:ok, alliance.name}
      {:error, _} -> {:error, :not_found}
    end
  rescue
    error ->
      Logger.warning("Failed to fetch alliance #{alliance_id} from ESI: #{inspect(error)}")
      {:error, :esi_error}
  end

  defp batch_resolve(type, ids, fallback_fn) do
    unique_ids = Enum.uniq(ids)

    # Split cached and missing IDs to prevent N+1 queries
    {cached, missing} = split_cached_and_missing(unique_ids, type)

    # Batch load missing names from database to prevent N+1
    missing_results =
      if length(missing) > 0 do
        batch_fetch_from_database(type, missing)
      else
        %{}
      end

    # Combine cached and fresh results
    all_results = Map.merge(cached, missing_results)

    # Fill in any remaining missing with fallback
    Enum.into(unique_ids, %{}, fn id ->
      case Map.get(all_results, id) do
        nil -> {id, fallback_fn.(id)}
        name -> {id, name}
      end
    end)
  end

  defp split_cached_and_missing(ids, type) do
    Enum.reduce(ids, {%{}, []}, fn id, {cached, missing} ->
      case get_from_cache(type, id) do
        {:ok, name} -> {Map.put(cached, id, name), missing}
        :miss -> {cached, [id | missing]}
      end
    end)
  end

  defp get_from_cache(type, id) do
    cache_key = {type, id}
    current_time = :os.system_time(:millisecond)

    case :ets.lookup(@table_name, cache_key) do
      [{^cache_key, value, expires_at}] when expires_at > current_time ->
        {:ok, value}

      _ ->
        :miss
    end
  end

  defp batch_fetch_from_database(type, ids) when type in [:item_type, :ship_type] do
    case Ash.read(ItemType,
           filter: [type_id: [in: ids]],
           domain: EveDmv.Api,
           authorize?: false
         ) do
      {:ok, items} ->
        results = Enum.into(items, %{}, fn item -> {item.type_id, item.type_name} end)
        cache_batch_results(type, results)
        results

      {:error, _} ->
        Logger.warning("Failed to batch fetch #{type} for IDs: #{inspect(ids)}")
        %{}
    end
  rescue
    error ->
      Logger.warning("Error in batch fetch #{type}: #{inspect(error)}")
      %{}
  end

  defp batch_fetch_from_database(:solar_system, ids) do
    case Ash.read(SolarSystem,
           filter: [system_id: [in: ids]],
           domain: EveDmv.Api,
           authorize?: false
         ) do
      {:ok, systems} ->
        results = Enum.into(systems, %{}, fn system -> {system.system_id, system.system_name} end)
        cache_batch_results(:solar_system, results)
        results

      {:error, _} ->
        Logger.warning("Failed to batch fetch solar systems for IDs: #{inspect(ids)}")
        %{}
    end
  rescue
    error ->
      Logger.warning("Error in batch fetch solar systems: #{inspect(error)}")
      %{}
  end

  defp batch_fetch_from_database(_type, _ids), do: %{}

  defp cache_batch_results(type, results) do
    ttl = get_ttl_for_type(type)
    expires_at = :os.system_time(:millisecond) + ttl

    Enum.each(results, fn {id, name} ->
      cache_key = {type, id}
      :ets.insert(@table_name, {cache_key, name, expires_at})
    end)
  end

  defp batch_resolve_with_esi(type, ids, fallback_fn)
       when type in [:character, :corporation, :alliance] do
    unique_ids = Enum.uniq(ids)

    # Check cache first, separate cached from uncached
    {cached, uncached} =
      Enum.reduce(unique_ids, {%{}, []}, fn id, {cached_acc, uncached_acc} ->
        case get_cached_or_fetch(type, id) do
          {:ok, name} -> {Map.put(cached_acc, id, name), uncached_acc}
          {:error, _} -> {cached_acc, [id | uncached_acc]}
        end
      end)

    # If we have uncached IDs, try ESI bulk lookup
    esi_results =
      if length(uncached) > 0 do
        case bulk_esi_lookup(type, uncached) do
          {:ok, results} ->
            # Cache the successful lookups
            Enum.each(results, fn {id, name} ->
              ttl = get_ttl_for_type(type)
              expires_at = :os.system_time(:millisecond) + ttl
              :ets.insert(@table_name, {{type, id}, name, expires_at})
            end)

            results

          {:error, _} ->
            # Fall back to individual lookups
            Map.new(uncached, fn id -> {id, fallback_fn.(id)} end)
        end
      else
        %{}
      end

    Map.merge(cached, esi_results)
  end

  # For non-ESI types, use regular batch resolve
  defp batch_resolve_with_esi(type, ids, fallback_fn) do
    batch_resolve(type, ids, fallback_fn)
  end

  defp bulk_esi_lookup(:character, character_ids) when length(character_ids) <= 1000 do
    case EsiClient.get_characters(character_ids) do
      {:ok, characters_map} ->
        results = Map.new(characters_map, fn {id, char} -> {id, char.name} end)
        {:ok, results}
    end
  end

  defp bulk_esi_lookup(:corporation, corporation_ids) when length(corporation_ids) <= 50 do
    # ESI doesn't have bulk corp lookup, so we'll use Task.async_stream for parallel requests
    results =
      corporation_ids
      |> Task.async_stream(
        fn id ->
          case EsiClient.get_corporation(id) do
            {:ok, corp} -> {id, corp.name}
            {:error, _} -> {id, "Unknown Corporation (#{id})"}
          end
        end,
        max_concurrency: @max_concurrency,
        timeout: @esi_timeout
      )
      |> Enum.reduce(%{}, fn
        {:ok, {id, name}}, acc -> Map.put(acc, id, name)
        {:exit, _reason}, acc -> acc
      end)

    {:ok, results}
  rescue
    _ -> {:error, :parallel_fetch_failed}
  end

  defp bulk_esi_lookup(:alliance, alliance_ids) when length(alliance_ids) <= 50 do
    # ESI doesn't have bulk alliance lookup, so we'll use Task.async_stream for parallel requests
    results =
      alliance_ids
      |> Task.async_stream(
        fn id ->
          case EsiClient.get_alliance(id) do
            {:ok, alliance} -> {id, alliance.name}
            {:error, _} -> {id, "Unknown Alliance (#{id})"}
          end
        end,
        max_concurrency: @max_concurrency,
        timeout: @esi_timeout
      )
      |> Enum.reduce(%{}, fn
        {:ok, {id, name}}, acc -> Map.put(acc, id, name)
        {:exit, _reason}, acc -> acc
      end)

    {:ok, results}
  rescue
    _ -> {:error, :parallel_fetch_failed}
  end

  # If too many IDs, chunk them appropriately
  defp bulk_esi_lookup(type, ids) when type == :character and length(ids) > 1000 do
    ids
    |> Enum.chunk_every(1000)
    |> Enum.reduce_while({:ok, %{}}, fn chunk, {:ok, acc} ->
      case bulk_esi_lookup(type, chunk) do
        {:ok, results} -> {:cont, {:ok, Map.merge(acc, results)}}
        error -> {:halt, error}
      end
    end)
  end

  defp bulk_esi_lookup(type, ids) when type in [:corporation, :alliance] and length(ids) > 50 do
    ids
    |> Enum.chunk_every(50)
    |> Enum.reduce_while({:ok, %{}}, fn chunk, {:ok, acc} ->
      case bulk_esi_lookup(type, chunk) do
        {:ok, results} -> {:cont, {:ok, Map.merge(acc, results)}}
        error -> {:halt, error}
      end
    end)
  end

  defp bulk_esi_lookup(_type, _ids), do: {:error, :unsupported_type}
end

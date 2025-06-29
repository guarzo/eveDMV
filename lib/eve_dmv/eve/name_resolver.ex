defmodule EveDmv.Eve.NameResolver do
  @moduledoc """
  Helper module for resolving EVE Online IDs to friendly names.

  This module provides efficient caching and lookup functions for converting
  type IDs and system IDs to human-readable names in the UI.
  """

  require Logger

  alias EveDmv.Eve.{ItemType, SolarSystem}

  # ETS table for caching lookups
  @table_name :eve_name_cache
  # 1 hour TTL
  @cache_ttl :timer.minutes(60)

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
          status: system.security_status || 0.0
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
  Warms the cache with commonly used items.
  Should be called after static data is loaded.
  """
  def warm_cache do
    Logger.info("Warming EVE name resolver cache")

    # Pre-load common ship types
    # T1 frigates
    common_ships = [587, 588, 589, 590, 591, 592, 593, 594]
    ship_names(common_ships)

    # Pre-load major trade hubs
    # Jita, Amarr, Dodixie, Rens
    trade_hubs = [30_000_142, 30_002_187, 30_002_659, 30_002_510]
    system_names(trade_hubs)

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
          fetch_and_cache(type, id)
        end

      [] ->
        fetch_and_cache(type, id)
    end
  end

  defp fetch_and_cache(type, id) do
    case fetch_from_database(type, id) do
      {:ok, value} ->
        expires_at = :os.system_time(:millisecond) + @cache_ttl
        :ets.insert(@table_name, {{type, id}, value, expires_at})
        {:ok, value}

      error ->
        error
    end
  end

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

  defp batch_resolve(type, ids, fallback_fn) do
    ids
    |> Enum.uniq()
    |> Enum.into(%{}, fn id ->
      case get_cached_or_fetch(type, id) do
        {:ok, name} -> {id, name}
        {:error, _} -> {id, fallback_fn.(id)}
      end
    end)
  end
end

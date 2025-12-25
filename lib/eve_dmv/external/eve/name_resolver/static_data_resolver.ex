defmodule EveDmv.Eve.NameResolver.StaticDataResolver do
  @moduledoc """
  Static data resolution module for EVE name resolution.

  Handles resolution of ship types, item types, and solar systems from
  static EVE database data. These entities have stable names that rarely change.
  """

  alias EveDmv.Eve.ItemType
  alias EveDmv.Eve.NameResolver.CacheManager
  alias EveDmv.Eve.SolarSystem
  alias EveDmv.Platform.Cache.StaticDataCache

  require Ash.Query
  require Logger

  @doc """
  Resolves a ship type ID to a ship name.

  ## Examples

      iex> StaticDataResolver.ship_name(587)
      "Rifter"

      iex> StaticDataResolver.ship_name(999_999)
      "Unknown Ship (999_999)"
  """
  @spec ship_name(integer() | nil) :: String.t()
  def ship_name(nil), do: "Unknown Ship"

  def ship_name(type_id) when is_integer(type_id) do
    # Use StaticDataCache for ship names
    StaticDataCache.resolve_ship_name(type_id)
  end

  @doc """
  Resolves an item type ID to an item name.
  Works for ships, modules, charges, etc.

  ## Examples

      iex> StaticDataResolver.item_name(12_058)
      "Medium Shield Extender II"

      iex> StaticDataResolver.item_name(999_999)
      "Unknown Item (999_999)"
  """
  @spec item_name(integer()) :: String.t()
  def item_name(type_id) when is_integer(type_id) do
    # Use StaticDataCache for item names (same as ship for now)
    StaticDataCache.resolve_ship_name(type_id)
  end

  @doc """
  Resolves a solar system ID to a system name.

  ## Examples

      iex> StaticDataResolver.system_name(30_000_142)
      "Jita"

      iex> StaticDataResolver.system_name(999_999)
      "Unknown System (999_999)"
  """
  @spec system_name(integer()) :: String.t()
  def system_name(system_id) when is_integer(system_id) do
    # Use StaticDataCache for system names
    StaticDataCache.resolve_system_name(system_id)
  end

  @doc """
  Resolves multiple ship type IDs to names efficiently.

  ## Examples

      iex> StaticDataResolver.ship_names([587, 588, 589])
      %{587 => "Rifter", 588 => "Punisher", 589 => "Tormentor"}
  """
  @spec ship_names(list(integer())) :: map()
  def ship_names(type_ids) when is_list(type_ids) do
    # Use StaticDataCache for batch ship name resolution
    StaticDataCache.resolve_ship_names(type_ids)
  end

  @doc """
  Resolves multiple item type IDs to names efficiently.
  """
  @spec item_names(list(integer())) :: map()
  def item_names(type_ids) when is_list(type_ids) do
    # Use StaticDataCache for batch item name resolution (same as ship for now)
    StaticDataCache.resolve_ship_names(type_ids)
  end

  @doc """
  Resolves multiple solar system IDs to names efficiently.
  """
  @spec system_names(list(integer())) :: map()
  def system_names(system_ids) when is_list(system_ids) do
    # Use StaticDataCache for batch system name resolution
    StaticDataCache.resolve_system_names(system_ids)
  end

  @doc """
  Gets the security class and color for a solar system.

  ## Examples

      iex> StaticDataResolver.system_security(30_000_142)
      %{class: "highsec", color: "text-green-400", status: 0.946}
  """
  @spec system_security(integer()) :: %{
          class: String.t(),
          color: String.t(),
          status: number()
        }
  def system_security(system_id) when is_integer(system_id) do
    # Use StaticDataCache for system security (handles caching internally)
    StaticDataCache.resolve_system_security(system_id)
  end

  @doc """
  Gets the security class and color for multiple solar systems efficiently.

  ## Examples

      iex> StaticDataResolver.system_securities([30_000_142, 30_002_187])
      %{30_000_142 => %{class: "highsec", ...}, 30_002_187 => %{class: "highsec", ...}}
  """
  @spec system_securities(list(integer())) :: map()
  def system_securities(system_ids) when is_list(system_ids) do
    # Use StaticDataCache for batch system security resolution
    StaticDataCache.resolve_system_securities(system_ids)
  end

  @doc """
  Batch fetches static data from the database for multiple IDs.
  """
  def batch_fetch_from_database(type, ids) when type in [:item_type, :ship_type] do
    case ItemType
         |> Ash.Query.filter(type_id: [in: ids])
         |> Ash.read(domain: EveDmv.Api, authorize?: false) do
      {:ok, items} ->
        results = Enum.into(items, %{}, fn item -> {item.type_id, item.type_name} end)

        CacheManager.cache_batch_results(type, results)
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

  def batch_fetch_from_database(:solar_system, ids) do
    case SolarSystem
         |> Ash.Query.filter(system_id: [in: ids])
         |> Ash.read(domain: EveDmv.Api, authorize?: false) do
      {:ok, systems} ->
        results = Enum.into(systems, %{}, fn system -> {system.system_id, system.system_name} end)

        CacheManager.cache_batch_results(:solar_system, results)
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

  def batch_fetch_from_database(_type, _ids), do: %{}
end

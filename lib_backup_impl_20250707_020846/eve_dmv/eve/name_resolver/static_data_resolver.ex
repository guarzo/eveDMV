defmodule EveDmv.Eve.NameResolver.StaticDataResolver do
  @moduledoc """
  Static data resolution module for EVE name resolution.

  Handles resolution of ship types, item types, and solar systems from
  static EVE database data. These entities have stable names that rarely change.
  """

  require Logger
  require Ash.Query
    alias EveDmv.Eve.ItemType
    alias EveDmv.Eve.NameResolver.CacheManager
  alias EveDmv.Eve.NameResolver.BatchProcessor
  alias EveDmv.Eve.SolarSystem

  @doc """
  Resolves a ship type ID to a ship name.

  ## Examples

      iex> StaticDataResolver.ship_name(587)
      "Rifter"

      iex> StaticDataResolver.ship_name(999999)
      "Unknown Ship (999999)"
  """
  @spec ship_name(integer()) :: String.t()
  def ship_name(type_id) when is_integer(type_id) do
    case CacheManager.get_cached_or_fetch(:ship_type, type_id, fn ->
           fetch_from_database(:item_type, type_id)
         end) do
      {:ok, name} -> name
      {:error, _} -> "Unknown Ship (#{type_id})"
    end
  end

  @doc """
  Resolves an item type ID to an item name.
  Works for ships, modules, charges, etc.

  ## Examples

      iex> StaticDataResolver.item_name(12058)
      "Medium Shield Extender II"

      iex> StaticDataResolver.item_name(999999)
      "Unknown Item (999999)"
  """
  @spec item_name(integer()) :: String.t()
  def item_name(type_id) when is_integer(type_id) do
    case CacheManager.get_cached_or_fetch(:item_type, type_id, fn ->
           fetch_from_database(:item_type, type_id)
         end) do
      {:ok, name} -> name
      {:error, _} -> "Unknown Item (#{type_id})"
    end
  end

  @doc """
  Resolves a solar system ID to a system name.

  ## Examples

      iex> StaticDataResolver.system_name(30000142)
      "Jita"

      iex> StaticDataResolver.system_name(999999)
      "Unknown System (999999)"
  """
  @spec system_name(integer()) :: String.t()
  def system_name(system_id) when is_integer(system_id) do
    case CacheManager.get_cached_or_fetch(:solar_system, system_id, fn ->
           fetch_from_database(:solar_system, system_id)
         end) do
      {:ok, name} -> name
      {:error, _} -> "Unknown System (#{system_id})"
    end
  end

  @doc """
  Resolves multiple ship type IDs to names efficiently.

  ## Examples

      iex> StaticDataResolver.ship_names([587, 588, 589])
      %{587 => "Rifter", 588 => "Punisher", 589 => "Tormentor"}
  """
  @spec ship_names(list(integer())) :: map()
  def ship_names(type_ids) when is_list(type_ids) do
    BatchProcessor.batch_resolve(:ship_type, type_ids, &ship_name/1)
  end

  @doc """
  Resolves multiple item type IDs to names efficiently.
  """
  @spec item_names(list(integer())) :: map()
  def item_names(type_ids) when is_list(type_ids) do
    BatchProcessor.batch_resolve(:item_type, type_ids, &item_name/1)
  end

  @doc """
  Resolves multiple solar system IDs to names efficiently.
  """
  @spec system_names(list(integer())) :: map()
  def system_names(system_ids) when is_list(system_ids) do
    BatchProcessor.batch_resolve(:solar_system, system_ids, &system_name/1)
  end

  @doc """
  Gets the security class and color for a solar system.

  ## Examples

      iex> StaticDataResolver.system_security(30000142)
      %{class: "highsec", color: "text-green-400", status: 0.946}
  """
  @spec system_security(integer()) :: %{
          class: String.t(),
          color: String.t(),
          status: number()
        }
  def system_security(system_id) when is_integer(system_id) do
    case CacheManager.get_cached_or_fetch(:solar_system_full, system_id, fn ->
           fetch_from_database(:solar_system_full, system_id)
         end) do
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

  # Private helper functions

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
end

defmodule EveDmv.Eve.StaticDataLoader do
  @moduledoc """
  EVE Online static data loading system.

  This module handles downloading, parsing, and loading EVE Static Data Export (SDE)
  files into the database. It supports ship types and solar system data.

  ## Usage

  ```elixir
  # Load all static data
  {:ok, results} = StaticDataLoader.load_all_static_data()

  # Load specific data types
  {:ok, count} = StaticDataLoader.load_ship_types()
  {:ok, count} = StaticDataLoader.load_solar_systems()
  ```
  """

  require Logger

  alias EveDmv.Eve.{ItemType, SolarSystem}
  alias EveDmv.Eve.StaticDataLoader.FileManager
  alias EveDmv.Eve.StaticDataLoader.ItemTypeProcessor
  alias EveDmv.Eve.StaticDataLoader.SolarSystemProcessor
  alias EveDmv.Eve.StaticDataLoader.DataPersistence

  # ============================================================================
  # Public API
  # ============================================================================

  @doc """
  Loads all static data (ship types and solar systems).
  """
  @spec load_all_static_data() ::
          {:ok, %{item_types: non_neg_integer(), solar_systems: non_neg_integer()}}
          | {:error, term()}
  def load_all_static_data do
    Logger.info("Loading all EVE static data")

    with {:ok, item_count} <- load_item_types(),
         {:ok, system_count} <- load_solar_systems() do
      results = %{
        item_types: item_count,
        solar_systems: system_count
      }

      Logger.info("Static data loading complete", results)
      {:ok, results}
    else
      {:error, reason} = error ->
        Logger.error("Failed to load static data: #{inspect(reason)}")
        error
    end
  end

  @doc """
  Loads all item type data from EVE SDE (ships, modules, charges, etc.).
  """
  @spec load_ship_types() :: {:ok, non_neg_integer()} | {:error, term()}
  def load_ship_types do
    load_item_types()
  end

  @doc """
  Loads all item type data from EVE SDE (ships, modules, charges, etc.).
  """
  @spec load_item_types() :: {:ok, non_neg_integer()} | {:error, term()}
  def load_item_types do
    Logger.info("Loading all item types from EVE SDE")

    with {:ok, file_paths} <-
           FileManager.ensure_csv_files([:item_types, :item_groups, :item_categories]),
         {:ok, item_data} <- ItemTypeProcessor.process_item_data(file_paths),
         {:ok, count} <- DataPersistence.bulk_create_item_types(item_data) do
      Logger.info("Loaded #{count} item types")
      {:ok, count}
    end
  end

  @doc """
  Loads solar system data from EVE SDE.
  """
  @spec load_solar_systems() :: {:ok, non_neg_integer()} | {:error, term()}
  def load_solar_systems do
    Logger.info("Loading solar systems from EVE SDE")

    with {:ok, file_paths} <-
           FileManager.ensure_csv_files([:solar_systems, :regions, :constellations]),
         {:ok, system_data} <- SolarSystemProcessor.process_system_data(file_paths),
         {:ok, count} <- DataPersistence.bulk_create_solar_systems(system_data) do
      Logger.info("Loaded #{count} solar systems")
      {:ok, count}
    end
  end

  @doc """
  Checks if static data is loaded.
  """
  @spec static_data_loaded?() :: %{item_types: boolean(), solar_systems: boolean()}
  def static_data_loaded? do
    item_count = DataPersistence.count_records(ItemType)
    system_count = DataPersistence.count_records(SolarSystem)

    %{
      item_types: item_count > 0,
      solar_systems: system_count > 0
    }
  end

  # Delegation to specialized modules
  defdelegate get_data_directory(), to: FileManager
  defdelegate clear_cache(), to: FileManager
  defdelegate get_cache_info(), to: FileManager
  defdelegate get_statistics(), to: DataPersistence
  defdelegate validate_data_freshness(), to: DataPersistence
end

defmodule EveDmv.Eve.StaticDataLoader do
  @moduledoc """
  EVE Online static data loading system.

  This module handles downloading, parsing, and loading EVE Static Data Export (SDE)
  files into the database. It supports ship types and solar system data.

  ## Data Source

  Uses CCP's official Static Data Export (JSONL format) from the CCP developer portal.

  ## Category Filtering

  Only killmail-relevant items are imported:
  - Ships, Modules, Charges, Drones, Implants, Deployables, Structures, Fighters

  This reduces import from ~49,906 items to ~5,000-8,000 items.

  ## Usage

  ```elixir
  # Load all static data
  {:ok, results} = StaticDataLoader.load_all_static_data()

  # Load specific data types
  {:ok, count} = StaticDataLoader.load_ship_types()
  {:ok, count} = StaticDataLoader.load_solar_systems()
  ```
  """

  alias EveDmv.Eve.ItemType
  alias EveDmv.Eve.SolarSystem
  alias EveDmv.Eve.StaticDataLoader.CcpSdeClient
  alias EveDmv.Eve.StaticDataLoader.DataPersistence
  alias EveDmv.Eve.StaticDataLoader.FileManager
  alias EveDmv.Eve.StaticDataLoader.ItemTypeProcessor
  alias EveDmv.Eve.StaticDataLoader.SolarSystemProcessor

  require Logger

  # ============================================================================
  # Public API
  # ============================================================================

  @doc """
  Loads all static data (ship types and solar systems).

  Downloads from CCP's official JSONL format and filters to killmail-relevant items.
  """
  @spec load_all_static_data() ::
          {:ok,
           %{item_types: non_neg_integer(), solar_systems: non_neg_integer(), source: atom()}}
          | {:error, term()}
  def load_all_static_data do
    Logger.info("Loading all EVE static data from CCP SDE")

    with {:ok, item_count} <- load_item_types(),
         {:ok, system_count} <- load_solar_systems() do
      results = %{
        item_types: item_count,
        solar_systems: system_count,
        source: :ccp
      }

      Logger.info("Static data loading complete: #{item_count} items, #{system_count} systems")
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

  Uses CCP's official JSONL format and only imports killmail-relevant categories:
  - Ships (6), Modules (7), Charges (8), Drones (18), Implants (20),
    Deployables (22), Structures (65), Fighters (87)
  """
  @spec load_item_types() :: {:ok, non_neg_integer()} | {:error, term()}
  def load_item_types do
    Logger.info("Loading item types from CCP JSONL...")

    with {:ok, version_info} <- get_sde_version_string(),
         {:ok, %{file_paths: file_paths}} <-
           FileManager.ensure_ccp_files([:item_types, :item_groups, :item_categories]),
         {:ok, item_data} <-
           ItemTypeProcessor.process_item_data_jsonl(file_paths,
             filter_categories: true,
             sde_version: version_info
           ),
         {:ok, count} <- DataPersistence.bulk_create_item_types(item_data) do
      Logger.info("Loaded #{count} item types from CCP SDE (version: #{version_info})")
      {:ok, count}
    end
  end

  @doc """
  Loads solar system data from EVE SDE.

  Uses CCP's official JSONL format.
  """
  @spec load_solar_systems() :: {:ok, non_neg_integer()} | {:error, term()}
  def load_solar_systems do
    Logger.info("Loading solar systems from CCP JSONL...")

    with {:ok, version_info} <- get_sde_version_string(),
         {:ok, %{file_paths: file_paths}} <-
           FileManager.ensure_ccp_files([:solar_systems, :regions, :constellations]),
         {:ok, system_data} <-
           SolarSystemProcessor.process_system_data_jsonl(file_paths, sde_version: version_info),
         {:ok, count} <- DataPersistence.bulk_create_solar_systems(system_data) do
      Logger.info("Loaded #{count} solar systems from CCP SDE (version: #{version_info})")
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

  # ============================================================================
  # Private Functions
  # ============================================================================

  # Gets SDE version string for tracking
  # Fetches build number from CCP API
  defp get_sde_version_string do
    case CcpSdeClient.get_latest_build_number() do
      {:ok, %{build_number: build}} ->
        {:ok, "build-#{build}"}

      {:error, reason} ->
        Logger.warning("Failed to get CCP build number: #{inspect(reason)}, using 'latest'")
        {:ok, "latest"}
    end
  end
end

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
  alias NimbleCSV.RFC4180, as: CSVParser

  @required_files %{
    item_types: "invTypes.csv",
    item_groups: "invGroups.csv",
    item_categories: "invCategories.csv",
    solar_systems: "mapSolarSystems.csv",
    regions: "mapRegions.csv",
    constellations: "mapConstellations.csv"
  }

  @ship_group_ids [
    # Ship category group IDs from EVE SDE
    # Frigate
    25,
    # Cruiser
    26,
    # Battleship
    27,
    # Industrial
    28,
    # Capsule
    29,
    # Titan
    30,
    # Covert Ops
    237,
    # Assault Frigate
    324,
    # Heavy Assault Cruiser
    358,
    # Deep Space Transport
    380,
    # Elite Battleship
    381,
    # Combat Battlecruiser
    419,
    # Destroyer
    420,
    # Mining Barge
    463,
    # Dreadnought
    485,
    # Freighter
    513,
    # Command Ship
    540,
    # Interdictor
    541,
    # Exhumer
    543,
    # Carrier
    547,
    # Supercarrier
    659,
    # Covert Ops
    830,
    # Interceptor
    831,
    # Logistics
    832,
    # Force Recon Ship
    833,
    # Stealth Bomber
    834,
    # Capital Industrial Ship
    883,
    # Electronic Attack Ship
    893,
    # Heavy Interdictor
    894,
    # Black Ops
    898,
    # Marauder
    900,
    # Jump Freighter
    902,
    # Combat Recon Ship
    906,
    # Strategic Cruiser
    963,
    # Prototype Exploration Ship
    1022,
    # Attack Battlecruiser
    1201,
    # Blockade Runner
    1202,
    # Exhumer
    1283,
    # Tactical Destroyer
    1305,
    # Logistics Frigate
    1527,
    # Command Destroyer
    1534,
    # Force Auxiliary
    1538,
    # Flag Cruiser
    1972,
    # Precursor Frigate
    2016,
    # Precursor Destroyer
    2017,
    # Precursor Cruiser
    2018,
    # Precursor Battleship
    2019
  ]

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

    with {:ok, file_paths} <- ensure_csv_files([:item_types, :item_groups, :item_categories]),
         {:ok, item_data} <- process_item_data(file_paths),
         {:ok, count} <- bulk_create_item_types(item_data) do
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

    with {:ok, file_paths} <- ensure_csv_files([:solar_systems, :regions, :constellations]),
         {:ok, system_data} <- process_system_data(file_paths),
         {:ok, count} <- bulk_create_solar_systems(system_data) do
      Logger.info("Loaded #{count} solar systems")
      {:ok, count}
    end
  end

  @doc """
  Checks if static data is loaded.
  """
  @spec static_data_loaded?() :: %{item_types: boolean(), solar_systems: boolean()}
  def static_data_loaded? do
    item_count = count_records(ItemType)
    system_count = count_records(SolarSystem)

    %{
      item_types: item_count > 0,
      solar_systems: system_count > 0
    }
  end

  # ============================================================================
  # File Management
  # ============================================================================

  @spec ensure_csv_files(list(atom())) :: {:ok, map()} | {:error, term()}
  defp ensure_csv_files(required_keys) do
    data_dir = get_data_directory()
    File.mkdir_p!(data_dir)

    required_files = Map.take(@required_files, required_keys)
    missing_files = get_missing_files(data_dir, required_files)

    case missing_files do
      [] ->
        {:ok, get_file_paths(data_dir, required_files)}

      missing ->
        Logger.info("Missing CSV files: #{inspect(missing)}")

        case download_files(missing, data_dir) do
          :ok -> {:ok, get_file_paths(data_dir, required_files)}
          error -> error
        end
    end
  end

  defp get_data_directory do
    Path.join([:code.priv_dir(:eve_dmv), "static_data"])
  end

  defp get_missing_files(data_dir, required_files) do
    required_files
    |> Map.values()
    |> Enum.reject(fn file_name ->
      data_dir
      |> Path.join(file_name)
      |> File.exists?()
    end)
  end

  defp get_file_paths(data_dir, required_files) do
    required_files
    |> Enum.into(%{}, fn {key, filename} ->
      {key, Path.join(data_dir, filename)}
    end)
  end

  defp download_files(file_names, data_dir) do
    Logger.info("Downloading missing CSV files from fuzzwork.co.uk")

    results =
      file_names
      |> Enum.map(&download_single_file(&1, data_dir))

    case Enum.find(results, &match?({:error, _}, &1)) do
      nil -> :ok
      error -> error
    end
  end

  defp download_single_file(file_name, data_dir) do
    url = "https://www.fuzzwork.co.uk/dump/latest/#{file_name}.bz2"
    output_path = Path.join(data_dir, file_name)

    Logger.info("Downloading #{file_name} from #{url}")

    with {:ok, compressed_data} <- download_file(url),
         {:ok, decompressed} <- decompress_bz2(compressed_data),
         :ok <- File.write(output_path, decompressed) do
      Logger.info("Successfully downloaded and saved #{file_name}")
      :ok
    else
      error ->
        Logger.error("Failed to download #{file_name}: #{inspect(error)}")
        {:error, "Failed to download #{file_name}: #{inspect(error)}"}
    end
  end

  defp download_file(url) do
    case Finch.build(:get, url) |> Finch.request(EveDmv.Finch, receive_timeout: 30_000) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status: status}} ->
        {:error, "HTTP #{status}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp decompress_bz2(compressed_data) do
    case System.find_executable("bzip2") do
      nil ->
        {:error, "bzip2 command not found - please install bzip2 to decompress files"}

      _path ->
        case write_temp_file(compressed_data, ".bz2") do
          {:ok, temp_path} ->
            try do
              case System.cmd("bzip2", ["-dc", temp_path], stderr_to_stdout: true) do
                {output, 0} -> {:ok, output}
                {error, _} -> {:error, "bzip2 decompression failed: #{error}"}
              end
            after
              File.rm(temp_path)
            end

          error ->
            error
        end
    end
  end

  defp write_temp_file(data, extension) do
    uuid = :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)
    temp_path = Path.join(System.tmp_dir!(), "eve_dmv_#{uuid}#{extension}")

    case File.write(temp_path, data) do
      :ok -> {:ok, temp_path}
      error -> error
    end
  end

  # ============================================================================
  # Ship Type Processing
  # ============================================================================

  # Main function for processing all item types
  defp process_item_data(file_paths) do
    case file_paths do
      %{item_types: types_path, item_groups: groups_path, item_categories: categories_path} ->
        with {:ok, categories} <- parse_categories_file(categories_path),
             {:ok, groups} <- parse_groups_file(groups_path),
             {:ok, types} <- parse_types_file(types_path) do
          item_types = build_item_types(types, groups, categories)
          {:ok, item_types}
        end

      # Fallback for legacy ship-only processing
      %{ship_types: types_path, ship_groups: groups_path} ->
        process_ship_data(%{ship_types: types_path, ship_groups: groups_path})
    end
  end

  # Legacy function for backward compatibility
  defp process_ship_data(%{ship_types: types_path, ship_groups: groups_path}) do
    with {:ok, groups} <- parse_groups_file(groups_path),
         {:ok, types} <- parse_types_file(types_path) do
      ship_types = build_ship_types(types, groups)
      {:ok, ship_types}
    end
  end

  defp parse_categories_file(categories_path) do
    with {:ok, content} <- File.read(categories_path),
         categories <- parse_csv_content(content, &parse_category_row/1) do
      categories_map = Enum.into(categories, %{}, fn c -> {c.category_id, c} end)
      {:ok, categories_map}
    end
  end

  defp parse_groups_file(groups_path) do
    with {:ok, content} <- File.read(groups_path),
         groups <- parse_csv_content(content, &parse_group_row/1) do
      groups_map = Enum.into(groups, %{}, fn g -> {g.group_id, g} end)
      {:ok, groups_map}
    end
  end

  defp parse_types_file(types_path) do
    with {:ok, content} <- File.read(types_path),
         types <- parse_csv_content(content, &parse_type_row/1) do
      {:ok, types}
    end
  end

  defp build_item_types(types, groups_map, categories_map) do
    types
    |> Enum.filter(fn type -> type.published end)
    |> Enum.map(fn type ->
      group = Map.get(groups_map, type.group_id, %{})
      category = Map.get(categories_map, group[:category_id], %{})

      # Determine item classifications
      is_ship = type.group_id in @ship_group_ids
      is_module = category[:name] in ["Module", "Subsystem"]
      is_charge = category[:name] in ["Charge", "Ammunition & Charges"]
      is_deployable = category[:name] in ["Deployable", "Structure"]
      is_blueprint = category[:name] == "Blueprint"

      %{
        type_id: type.type_id,
        type_name: type.name,
        group_id: type.group_id,
        group_name: group[:name] || "Unknown",
        category_id: group[:category_id],
        category_name: category[:name] || "Unknown",
        mass: type.mass,
        volume: type.volume,
        capacity: type.capacity,
        base_price: type.base_price,
        published: type.published,
        is_ship: is_ship,
        is_module: is_module,
        is_charge: is_charge,
        is_deployable: is_deployable,
        is_blueprint: is_blueprint,
        sde_version: "latest"
      }
    end)
  end

  # Legacy function for ship-only processing
  defp build_ship_types(types, groups_map) do
    types
    |> Enum.filter(fn type ->
      type.group_id in @ship_group_ids and type.published
    end)
    |> Enum.map(fn type ->
      %{
        type_id: type.type_id,
        type_name: type.name,
        group_id: type.group_id,
        group_name: Map.get(groups_map, type.group_id, "Unknown"),
        mass: type.mass,
        volume: type.volume,
        capacity: type.capacity,
        base_price: type.base_price,
        published: type.published,
        is_ship: true,
        sde_version: "latest"
      }
    end)
  end

  # ============================================================================
  # Solar System Processing
  # ============================================================================

  defp process_system_data(%{
         solar_systems: systems_path,
         regions: regions_path,
         constellations: constellations_path
       }) do
    with {:ok, regions} <- parse_regions_file(regions_path),
         {:ok, constellations} <- parse_constellations_file(constellations_path),
         {:ok, systems} <- parse_systems_file(systems_path) do
      system_data = build_system_data(systems, regions, constellations)
      {:ok, system_data}
    end
  end

  defp parse_regions_file(regions_path) do
    with {:ok, content} <- File.read(regions_path),
         regions <- parse_csv_content(content, &parse_region_row/1) do
      regions_map = Enum.into(regions, %{}, fn r -> {r.region_id, r.name} end)
      {:ok, regions_map}
    end
  end

  defp parse_constellations_file(constellations_path) do
    with {:ok, content} <- File.read(constellations_path),
         constellations <- parse_csv_content(content, &parse_constellation_row/1) do
      constellations_map = Enum.into(constellations, %{}, fn c -> {c.constellation_id, c} end)
      {:ok, constellations_map}
    end
  end

  defp parse_systems_file(systems_path) do
    with {:ok, content} <- File.read(systems_path),
         systems <- parse_csv_content(content, &parse_system_row/1) do
      {:ok, systems}
    end
  end

  defp build_system_data(systems, regions_map, constellations_map) do
    systems
    |> Enum.map(fn system ->
      constellation = Map.get(constellations_map, system.constellation_id, %{})
      region_name = Map.get(regions_map, constellation[:region_id])

      security_class =
        cond do
          system.security >= 0.45 -> "highsec"
          system.security >= 0.05 -> "lowsec"
          system.security < 0.05 -> "nullsec"
          true -> "unknown"
        end

      %{
        system_id: system.system_id,
        system_name: system.name,
        region_id: constellation[:region_id],
        region_name: region_name,
        constellation_id: system.constellation_id,
        constellation_name: constellation[:name],
        security_status: system.security,
        security_class: security_class,
        x: system.x,
        y: system.y,
        z: system.z,
        sde_version: "latest"
      }
    end)
  end

  # ============================================================================
  # CSV Parsing Helpers
  # ============================================================================

  defp parse_csv_content(content, parser_fn) do
    parsed_data = CSVParser.parse_string(content, skip_headers: false)

    case parsed_data do
      [] ->
        []

      [headers | data_rows] ->
        headers = Enum.map(headers, &String.trim/1)

        data_rows
        |> Enum.map(fn row ->
          row_map = headers |> Enum.zip(row) |> Map.new()
          parser_fn.(row_map)
        end)
        |> Enum.reject(&is_nil/1)
    end
  end

  # Row parsers adapted from sample code
  defp parse_type_row(row) do
    %{
      type_id: parse_integer(row["typeID"]),
      name: Map.get(row, "typeName", ""),
      group_id: parse_integer(row["groupID"]),
      mass: parse_float(row["mass"]),
      volume: parse_float(row["volume"]),
      capacity: parse_float(row["capacity"]),
      base_price: parse_float(row["basePrice"]),
      published: parse_boolean(row["published"])
    }
  end

  defp parse_category_row(row) do
    %{
      category_id: parse_integer(row["categoryID"]),
      name: Map.get(row, "categoryName", "")
    }
  end

  defp parse_group_row(row) do
    %{
      group_id: parse_integer(row["groupID"]),
      category_id: parse_integer(row["categoryID"]),
      name: Map.get(row, "groupName", "")
    }
  end

  defp parse_system_row(row) do
    %{
      system_id: parse_integer(row["solarSystemID"]),
      name: Map.get(row, "solarSystemName", ""),
      constellation_id: parse_integer(row["constellationID"]),
      security: parse_float(row["security"]),
      x: parse_float(row["x"]),
      y: parse_float(row["y"]),
      z: parse_float(row["z"])
    }
  end

  defp parse_region_row(row) do
    %{
      region_id: parse_integer(row["regionID"]),
      name: Map.get(row, "regionName", "")
    }
  end

  defp parse_constellation_row(row) do
    %{
      constellation_id: parse_integer(row["constellationID"]),
      name: Map.get(row, "constellationName", ""),
      region_id: parse_integer(row["regionID"])
    }
  end

  # Helper function to count records
  defp count_records(resource) do
    case Ash.count(resource, domain: EveDmv.Api, authorize?: false) do
      {:ok, count} -> count
      {:error, _} -> 0
    end
  end

  # Helper functions for type conversion
  defp parse_integer(value) when is_binary(value) and value != "" do
    case Integer.parse(value) do
      {int, ""} -> int
      _ -> 0
    end
  end

  defp parse_integer(_), do: 0

  defp parse_float(value) when is_binary(value) and value != "" do
    case Float.parse(value) do
      {float, ""} ->
        # Cap extremely large values to avoid database overflow
        # (precision 15, scale 4 means max value ~10^11)
        max_value = 99_999_999_999.0
        min(float, max_value)

      _ ->
        0.0
    end
  end

  defp parse_float(_), do: 0.0

  defp parse_boolean(value) when value in ["1", "true", "True", "TRUE"], do: true
  defp parse_boolean(_), do: false

  # ============================================================================
  # Database Operations
  # ============================================================================

  defp bulk_create_item_types(item_data) do
    # Use individual creates for now until we get the bulk API right
    records =
      Enum.map(item_data, fn item ->
        case Ash.create(ItemType, item, action: :create, domain: EveDmv.Api, authorize?: false) do
          {:ok, record} ->
            record

          {:error, error} ->
            Logger.warning("Failed to create item #{item.type_id}: #{inspect(error)}")
            nil
        end
      end)

    created_count = records |> Enum.reject(&is_nil/1) |> length()
    {:ok, created_count}
  rescue
    error ->
      Logger.error("Failed to bulk create item types: #{inspect(error)}")
      {:error, error}
  end

  defp bulk_create_solar_systems(system_data) do
    # Use individual creates for now until we get the bulk API right
    records =
      Enum.map(system_data, fn system ->
        case Ash.create(SolarSystem, system,
               action: :create,
               domain: EveDmv.Api,
               authorize?: false
             ) do
          {:ok, record} ->
            record

          {:error, error} ->
            Logger.warning("Failed to create system #{system.system_id}: #{inspect(error)}")
            nil
        end
      end)

    created_count = records |> Enum.reject(&is_nil/1) |> length()
    {:ok, created_count}
  rescue
    error ->
      Logger.error("Failed to bulk create solar systems: #{inspect(error)}")
      {:error, error}
  end
end

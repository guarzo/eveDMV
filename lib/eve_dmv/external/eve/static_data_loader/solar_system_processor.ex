defmodule EveDmv.Eve.StaticDataLoader.SolarSystemProcessor do
  @moduledoc """
  Processes EVE solar system data from CCP's official SDE JSONL files.

  Handles parsing and processing of solar systems, regions, and constellations,
  including security classification and spatial coordinates.
  """

  alias EveDmv.Eve.StaticDataLoader.JsonlParser
  require Logger

  @doc """
  Classifies a system's security status based on security value.

  Note: This does NOT detect wormholes. Wormhole detection is handled during
  SDE import by checking the region's wormhole_class_id field, which is the
  authoritative source from CCP's SDE data.
  """
  def classify_security(security_status) when is_number(security_status) do
    cond do
      security_status >= 0.45 -> "highsec"
      security_status >= 0.05 -> "lowsec"
      true -> "nullsec"
    end
  end

  def classify_security(_), do: "unknown"

  @doc """
  Filters systems by security class.
  """
  def filter_by_security_class(systems, security_class) do
    Enum.filter(systems, &(&1.security_class == security_class))
  end

  @doc """
  Filters systems by region.
  """
  def filter_by_region(systems, region_name) do
    Enum.filter(systems, &(&1.region_name == region_name))
  end

  @doc """
  Gets systems within a certain distance from coordinates.
  """
  def find_systems_within_range(systems, x, y, z, max_distance) do
    systems
    |> Enum.map(fn system ->
      distance =
        calculate_distance(
          {x, y, z},
          {system.x, system.y, system.z}
        )

      {system, distance}
    end)
    |> Enum.filter(fn {_system, distance} -> distance <= max_distance end)
    |> Enum.sort_by(fn {_system, distance} -> distance end)
    |> Enum.map(fn {system, _distance} -> system end)
  end

  @doc """
  Analyzes solar system data for statistics.
  """
  def analyze_system_data(systems) do
    security_distribution =
      systems
      |> Enum.group_by(& &1.security_class)
      |> Enum.map(fn {class, systems} -> {class, length(systems)} end)
      |> Map.new()

    region_count =
      systems
      |> Enum.map(& &1.region_name)
      |> Enum.uniq()
      |> length()

    constellation_count =
      systems
      |> Enum.map(& &1.constellation_name)
      |> Enum.uniq()
      |> length()

    %{
      total_systems: length(systems),
      regions: region_count,
      constellations: constellation_count,
      security_distribution: security_distribution,
      highsec_count: Map.get(security_distribution, "highsec", 0),
      lowsec_count: Map.get(security_distribution, "lowsec", 0),
      nullsec_count: Map.get(security_distribution, "nullsec", 0)
    }
  end

  # ============================================================================
  # JSONL Processing (CCP SDE)
  # ============================================================================

  @doc """
  Processes solar system data from CCP SDE JSONL files.

  This is the main method for importing SDE data. It:
  - Reads from the official CCP JSONL format
  - Uses streaming for memory efficiency

  ## Parameters

  - `file_paths` - Map with paths to JSONL files:
    - `:solar_systems` - Path to mapSolarSystems.jsonl
    - `:regions` - Path to mapRegions.jsonl
    - `:constellations` - Path to mapConstellations.jsonl

  ## Options

  - `:sde_version` - Version string to set on records (default: "latest")
  - `:sde_build_number` - CCP SDE build number (integer) for version tracking

  ## Returns

  - `{:ok, systems}` - List of processed solar system maps
  - `{:error, reason}` - If processing fails
  """
  @spec process_system_data_jsonl(map(), keyword()) :: {:ok, list(map())} | {:error, term()}
  def process_system_data_jsonl(file_paths, opts \\ []) do
    sde_version = Keyword.get(opts, :sde_version, "latest")
    sde_build_number = Keyword.get(opts, :sde_build_number)

    with {:ok, regions_map} <- load_regions_jsonl(file_paths.regions),
         {:ok, constellations_map} <- load_constellations_jsonl(file_paths.constellations),
         {:ok, systems_stream} <- JsonlParser.parse_solar_systems(file_paths.solar_systems) do
      systems =
        systems_stream
        |> Stream.map(fn system ->
          build_system_from_jsonl(
            system,
            regions_map,
            constellations_map,
            sde_version,
            sde_build_number
          )
        end)
        |> Enum.to_list()

      Logger.info("Processed #{length(systems)} solar systems from CCP JSONL")
      {:ok, systems}
    end
  end

  # Private JSONL processing functions

  defp load_regions_jsonl(regions_path) do
    # Use parse_regions to get properly transformed data with snake_case keys
    case JsonlParser.parse_regions(regions_path) do
      {:ok, stream} ->
        regions =
          stream
          |> Enum.reduce(%{}, fn region, acc ->
            if region.region_id, do: Map.put(acc, region.region_id, region), else: acc
          end)

        Logger.debug("Loaded #{map_size(regions)} regions from JSONL")
        {:ok, regions}

      {:error, _} = error ->
        error
    end
  end

  defp load_constellations_jsonl(constellations_path) do
    # Use parse_constellations to get properly transformed data with snake_case keys
    case JsonlParser.parse_constellations(constellations_path) do
      {:ok, stream} ->
        constellations =
          stream
          |> Enum.reduce(%{}, fn constellation, acc ->
            if constellation.constellation_id,
              do: Map.put(acc, constellation.constellation_id, constellation),
              else: acc
          end)

        Logger.debug("Loaded #{map_size(constellations)} constellations from JSONL")
        {:ok, constellations}

      {:error, _} = error ->
        error
    end
  end

  defp build_system_from_jsonl(
         system,
         regions_map,
         constellations_map,
         sde_version,
         sde_build_number
       ) do
    constellation = Map.get(constellations_map, system.constellation_id, %{})
    region_id = system.region_id || constellation[:region_id]
    region = Map.get(regions_map, region_id, %{})

    security_class = classify_security(system.security)

    # Determine if this is a wormhole system using region_id range
    # Wormhole regions are in the 11000000-12000000 range
    # Note: CCP assigns wormholeClassID to ALL regions (7=highsec static, 9=nullsec static, etc.)
    # so we can't use wormholeClassID alone to detect wormholes
    is_wormhole_region = region_id != nil and region_id >= 11_000_000 and region_id < 12_000_000

    final_security_class =
      if is_wormhole_region do
        "wormhole"
      else
        security_class
      end

    # Only store wormhole_class_id for actual wormhole systems
    # For k-space, the wormholeClassID indicates static connection type, not wormhole class
    wh_class_id =
      if is_wormhole_region do
        region[:wormhole_class_id]
      else
        nil
      end

    base_map = %{
      system_id: system.system_id,
      system_name: system.name,
      region_id: region_id,
      region_name: region[:name],
      constellation_id: system.constellation_id,
      constellation_name: constellation[:name],
      security_status: system.security,
      security_class: final_security_class,
      x: system.x || 0.0,
      y: system.y || 0.0,
      z: system.z || 0.0,
      wormhole_class_id: wh_class_id,
      sde_version: sde_version
    }

    # Add build number if provided
    if sde_build_number do
      Map.put(base_map, :sde_build_number, sde_build_number)
    else
      base_map
    end
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

  defp calculate_distance({x1, y1, z1}, {x2, y2, z2}) do
    dx = x2 - x1
    dy = y2 - y1
    dz = z2 - z1
    :math.sqrt(dx * dx + dy * dy + dz * dz)
  end

  @doc """
  Groups systems by region.
  """
  def group_by_region(systems) do
    Enum.group_by(systems, & &1.region_name)
  end

  @doc """
  Groups systems by constellation.
  """
  def group_by_constellation(systems) do
    Enum.group_by(systems, & &1.constellation_name)
  end

  @doc """
  Finds a system by ID.
  """
  def find_system_by_id(systems, system_id) do
    Enum.find(systems, &(&1.system_id == system_id))
  end

  @doc """
  Finds a system by name (case insensitive).
  """
  def find_system_by_name(systems, system_name) do
    normalized_name = String.downcase(system_name)

    Enum.find(systems, fn system ->
      String.downcase(system.system_name) == normalized_name
    end)
  end

  @doc """
  Gets neighboring systems within a jump range.
  """
  def get_neighbors(systems, system_id, max_light_years \\ 10) do
    case find_system_by_id(systems, system_id) do
      nil ->
        []

      system ->
        # Convert light years to meters (EVE uses meters for coordinates)
        max_distance = max_light_years * 9.461e15

        find_systems_within_range(
          systems,
          system.x,
          system.y,
          system.z,
          max_distance
        )
        |> Enum.reject(&(&1.system_id == system_id))
    end
  end
end

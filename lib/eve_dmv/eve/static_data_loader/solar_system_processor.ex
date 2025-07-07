defmodule EveDmv.Eve.StaticDataLoader.SolarSystemProcessor do
  @moduledoc """
  Processes EVE solar system data from SDE CSV files.

  Handles parsing and processing of solar systems, regions, and constellations,
  including security classification and spatial coordinates.
  """

  alias EveDmv.Eve.StaticDataLoader.CsvParser
  require Logger

  @doc """
  Processes solar system data from CSV files.
  """
  def process_system_data(%{
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

  @doc """
  Classifies a system's security status.
  """
  def classify_security(security_status) when is_number(security_status) do
    cond do
      security_status >= 0.45 -> "highsec"
      security_status >= 0.05 -> "lowsec"
      security_status < 0.05 -> "nullsec"
      true -> "unknown"
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

  # Private functions

  defp parse_regions_file(regions_path) do
    CsvParser.read_and_parse_csv_to_map(
      regions_path,
      &CsvParser.parse_region_row/1,
      :region_id
    )
  end

  defp parse_constellations_file(constellations_path) do
    CsvParser.read_and_parse_csv_to_map(
      constellations_path,
      &CsvParser.parse_constellation_row/1,
      :constellation_id
    )
  end

  defp parse_systems_file(systems_path) do
    CsvParser.read_and_parse_csv(systems_path, &CsvParser.parse_system_row/1)
  end

  defp build_system_data(systems, regions_map, constellations_map) do
    Enum.map(systems, fn system ->
      constellation = Map.get(constellations_map, system.constellation_id, %{})
      region_id = constellation[:region_id]
      region_name = Map.get(regions_map, region_id, %{})[:name]

      security_class = classify_security(system.security)

      %{
        system_id: system.system_id,
        system_name: system.name,
        region_id: region_id,
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

        systems
        |> find_systems_within_range(
          system.x,
          system.y,
          system.z,
          max_distance
        )
        |> Enum.reject(&(&1.system_id == system_id))
    end
  end
end

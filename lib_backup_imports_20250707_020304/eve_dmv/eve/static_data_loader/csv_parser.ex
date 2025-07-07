defmodule EveDmv.Eve.StaticDataLoader.CsvParser do
  alias NimbleCSV.RFC4180, as: CSVParser
  @moduledoc """
  Generic CSV parsing utilities for EVE SDE data.

  Provides common parsing functions for different CSV file types and
  type conversion utilities.
  """


  @doc """
  Parses CSV content with a row parser function.
  """
  def parse_csv_content(content, parser_fn) do
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

  @doc """
  Parses an item type row from invTypes.csv.
  """
  def parse_type_row(row) do
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

  @doc """
  Parses a category row from invCategories.csv.
  """
  def parse_category_row(row) do
    %{
      category_id: parse_integer(row["categoryID"]),
      name: Map.get(row, "categoryName", "")
    }
  end

  @doc """
  Parses a group row from invGroups.csv.
  """
  def parse_group_row(row) do
    %{
      group_id: parse_integer(row["groupID"]),
      category_id: parse_integer(row["categoryID"]),
      name: Map.get(row, "groupName", "")
    }
  end

  @doc """
  Parses a solar system row from mapSolarSystems.csv.
  """
  def parse_system_row(row) do
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

  @doc """
  Parses a region row from mapRegions.csv.
  """
  def parse_region_row(row) do
    %{
      region_id: parse_integer(row["regionID"]),
      name: Map.get(row, "regionName", "")
    }
  end

  @doc """
  Parses a constellation row from mapConstellations.csv.
  """
  def parse_constellation_row(row) do
    %{
      constellation_id: parse_integer(row["constellationID"]),
      name: Map.get(row, "constellationName", ""),
      region_id: parse_integer(row["regionID"])
    }
  end

  @doc """
  Parses an integer value from CSV data.
  """
  def parse_integer(value) when is_binary(value) and value != "" do
    case Integer.parse(value) do
      {int, ""} -> int
      _ -> 0
    end
  end

  def parse_integer(_), do: 0

  @doc """
  Parses a float value from CSV data with overflow protection.
  """
  def parse_float(value) when is_binary(value) and value != "" do
    case Float.parse(value) do
      {float, ""} ->
        # Cap extremely large coordinate values to avoid database overflow
        # For coordinates: precision 25, scale 2 means max value ~10^23
        # For other values: precision 15, scale 4 means max value ~10^11
        cond do
          abs(float) > 1.0e22 ->
            # Cap coordinate values
            if float > 0, do: 1.0e22, else: -1.0e22

          abs(float) > 99_999_999_999.0 ->
            # Cap other numeric values
            if float > 0, do: 99_999_999_999.0, else: -99_999_999_999.0

          true ->
            float
        end

      _ ->
        0.0
    end
  end

  def parse_float(_), do: 0.0

  @doc """
  Parses a boolean value from CSV data.
  """
  def parse_boolean(value) when value in ["1", "true", "True", "TRUE"], do: true
  def parse_boolean(_), do: false

  @doc """
  Reads and parses a CSV file.
  """
  def read_and_parse_csv(file_path, parser_fn) do
    with {:ok, content} <- File.read(file_path) do
      parsed_data = parse_csv_content(content, parser_fn)
      {:ok, parsed_data}
    end
  end

  @doc """
  Reads and parses a CSV file into a map by ID.
  """
  def read_and_parse_csv_to_map(file_path, parser_fn, id_key) do
    with {:ok, data} <- read_and_parse_csv(file_path, parser_fn) do
      data_map = Enum.into(data, %{}, fn item -> {Map.get(item, id_key), item} end)
      {:ok, data_map}
    end
  end
end

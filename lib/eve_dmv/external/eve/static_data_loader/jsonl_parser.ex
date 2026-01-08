defmodule EveDmv.Eve.StaticDataLoader.JsonlParser do
  @moduledoc """
  Streaming parser for CCP SDE JSON Lines format.

  Handles the CCP JSONL format where integer keys are converted to
  objects with _key and _value fields.

  ## JSONL Format Notes

  - Each line is a valid JSON object
  - Integer keys are wrapped: `{"_key": 123, "_value": {...}}`
  - Files can be large (types.jsonl is ~50MB)
  - Uses streaming to avoid memory issues

  ## Example Usage

      {:ok, types_stream} = JsonlParser.stream_file("/path/to/types.jsonl")
      Enum.each(types_stream, fn item -> process_item(item) end)

      # Typed parsers also return streams with schema-normalized keys
      {:ok, systems_stream} = JsonlParser.parse_solar_systems("/path/to/mapSolarSystems.jsonl")
      Enum.each(systems_stream, fn system -> process_system(system) end)

      # Use parse_file/2 to load all items into a list at once
      {:ok, items_list} = JsonlParser.parse_file("/path/to/file.jsonl")
  """

  require Logger

  @type parsed_item :: map()
  @type parse_result :: {:ok, [parsed_item()]} | {:error, term()}
  @type stream_result :: {:ok, Enumerable.t()} | {:error, term()}

  # ============================================================================
  # Public API - Streaming
  # ============================================================================

  @doc """
  Creates a stream that parses a JSONL file line by line.

  This is memory-efficient for large files as it doesn't load the entire
  file into memory at once.

  Options:
  - `:transform` - Function to transform each parsed object
  - `:filter` - Function to filter objects (returns true to keep)

  Returns a stream that yields parsed JSON objects.
  """
  @spec stream_file(String.t(), keyword()) :: {:ok, Enumerable.t()} | {:error, term()}
  def stream_file(file_path, opts \\ []) do
    transform_fn = Keyword.get(opts, :transform, & &1)
    filter_fn = Keyword.get(opts, :filter, fn _ -> true end)

    if File.exists?(file_path) do
      stream =
        file_path
        |> File.stream!([], :line)
        |> Stream.map(&String.trim/1)
        |> Stream.reject(&(&1 == ""))
        |> Stream.map(&parse_line/1)
        |> Stream.filter(fn
          {:ok, _} ->
            true

          {:error, reason} ->
            Logger.warning("Skipping invalid JSONL line: #{inspect(reason)}")
            false
        end)
        |> Stream.map(fn {:ok, data} -> unwrap_keyed_object(data) end)
        |> Stream.map(transform_fn)
        |> Stream.filter(filter_fn)

      {:ok, stream}
    else
      {:error, {:file_not_found, file_path}}
    end
  end

  @doc """
  Parses an entire JSONL file into a list.

  Use this for smaller files where loading everything into memory is acceptable.
  For large files like types.jsonl, prefer `stream_file/2`.
  """
  @spec parse_file(String.t(), keyword()) :: parse_result()
  def parse_file(file_path, opts \\ []) do
    case stream_file(file_path, opts) do
      {:ok, stream} -> {:ok, Enum.to_list(stream)}
      error -> error
    end
  end

  # ============================================================================
  # Public API - Typed Parsers
  # ============================================================================

  @doc """
  Parses types.jsonl file into item type records.

  Returns a stream of maps with normalized keys matching the ItemType schema.
  """
  @spec parse_types(String.t()) :: stream_result()
  def parse_types(file_path) do
    stream_file(file_path, transform: &transform_type/1)
  end

  @doc """
  Parses groups.jsonl file into item group records.
  """
  @spec parse_groups(String.t()) :: stream_result()
  def parse_groups(file_path) do
    stream_file(file_path, transform: &transform_group/1)
  end

  @doc """
  Parses categories.jsonl file into item category records.
  """
  @spec parse_categories(String.t()) :: stream_result()
  def parse_categories(file_path) do
    stream_file(file_path, transform: &transform_category/1)
  end

  @doc """
  Parses mapSolarSystems.jsonl file into solar system records.
  """
  @spec parse_solar_systems(String.t()) :: stream_result()
  def parse_solar_systems(file_path) do
    stream_file(file_path, transform: &transform_solar_system/1)
  end

  @doc """
  Parses mapRegions.jsonl file into region records.
  """
  @spec parse_regions(String.t()) :: stream_result()
  def parse_regions(file_path) do
    stream_file(file_path, transform: &transform_region/1)
  end

  @doc """
  Parses mapConstellations.jsonl file into constellation records.
  """
  @spec parse_constellations(String.t()) :: stream_result()
  def parse_constellations(file_path) do
    stream_file(file_path, transform: &transform_constellation/1)
  end

  @doc """
  Parses mapStargates.jsonl file into stargate records.
  """
  @spec parse_stargates(String.t()) :: stream_result()
  def parse_stargates(file_path) do
    stream_file(file_path, transform: &transform_stargate/1)
  end

  # ============================================================================
  # Public API - Map Loading
  # ============================================================================

  @doc """
  Parses a JSONL file and returns a map keyed by the specified field.

  Useful for creating lookup maps (e.g., groups by group_id).
  """
  @spec parse_to_map(String.t(), atom(), keyword()) :: {:ok, map()} | {:error, term()}
  def parse_to_map(file_path, key_field, opts \\ []) do
    case parse_file(file_path, opts) do
      {:ok, items} ->
        map =
          items
          |> Enum.reduce(%{}, fn item, acc ->
            key = Map.get(item, key_field)
            if key, do: Map.put(acc, key, item), else: acc
          end)

        {:ok, map}

      error ->
        error
    end
  end

  # ============================================================================
  # Private - Line Parsing
  # ============================================================================

  defp parse_line(line) when is_binary(line) do
    case Jason.decode(line) do
      {:ok, data} -> {:ok, data}
      {:error, reason} -> {:error, {:json_decode_error, reason, line}}
    end
  end

  defp unwrap_keyed_object(%{"_key" => key, "_value" => value}) do
    # Old CCP format wraps integer-keyed objects in a _value field
    Map.put(value, "_id", key)
  end

  defp unwrap_keyed_object(%{"_key" => key} = data) do
    # Current CCP format has _key directly at top level with other fields
    Map.put(data, "_id", key)
  end

  defp unwrap_keyed_object(data), do: data

  # ============================================================================
  # Private - Type Transformations
  # ============================================================================

  defp transform_type(data) do
    %{
      type_id: get_id(data),
      name: get_localized_name(data),
      description: get_localized_description(data),
      group_id: Map.get(data, "groupID"),
      mass: to_float(Map.get(data, "mass")),
      volume: to_float(Map.get(data, "volume")),
      capacity: to_float(Map.get(data, "capacity")),
      base_price: to_float(Map.get(data, "basePrice")),
      published: Map.get(data, "published", false),
      portion_size: Map.get(data, "portionSize", 1),
      race_id: Map.get(data, "raceID"),
      graphic_id: Map.get(data, "graphicID"),
      market_group_id: Map.get(data, "marketGroupID"),
      icon_id: Map.get(data, "iconID"),
      sof_faction_name: Map.get(data, "sofFactionName"),
      traits: Map.get(data, "traits"),
      masteries: Map.get(data, "masteries")
    }
  end

  defp transform_group(data) do
    %{
      group_id: get_id(data),
      name: get_localized_name(data),
      category_id: Map.get(data, "categoryID"),
      published: Map.get(data, "published", false),
      anchorable: Map.get(data, "anchorable", false),
      anchored: Map.get(data, "anchored", false),
      fittable_non_singleton: Map.get(data, "fittableNonSingleton", false),
      use_base_price: Map.get(data, "useBasePrice", false)
    }
  end

  defp transform_category(data) do
    %{
      category_id: get_id(data),
      name: get_localized_name(data),
      published: Map.get(data, "published", false)
    }
  end

  defp transform_solar_system(data) do
    %{
      system_id: get_id(data),
      name: get_localized_name(data),
      constellation_id: Map.get(data, "constellationID"),
      region_id: Map.get(data, "regionID"),
      security: to_float(Map.get(data, "security")),
      security_class: Map.get(data, "securityClass"),
      x: to_float(Map.get(data, "x")),
      y: to_float(Map.get(data, "y")),
      z: to_float(Map.get(data, "z")),
      sun_type_id: Map.get(data, "sunTypeID"),
      is_border: Map.get(data, "border", false),
      is_corridor: Map.get(data, "corridor", false),
      is_fringe: Map.get(data, "fringe", false),
      is_hub: Map.get(data, "hub", false),
      is_international: Map.get(data, "international", false),
      is_regional: Map.get(data, "regional", false),
      stargate_ids: Map.get(data, "stargates", [])
    }
  end

  defp transform_region(data) do
    %{
      region_id: get_id(data),
      name: get_localized_name(data),
      description: get_localized_description(data),
      x: to_float(Map.get(data, "x")),
      y: to_float(Map.get(data, "y")),
      z: to_float(Map.get(data, "z")),
      faction_id: Map.get(data, "factionID"),
      nebula: Map.get(data, "nebula"),
      wormhole_class_id: Map.get(data, "wormholeClassID")
    }
  end

  defp transform_constellation(data) do
    %{
      constellation_id: get_id(data),
      name: get_localized_name(data),
      region_id: Map.get(data, "regionID"),
      x: to_float(Map.get(data, "x")),
      y: to_float(Map.get(data, "y")),
      z: to_float(Map.get(data, "z")),
      faction_id: Map.get(data, "factionID"),
      radius: to_float(Map.get(data, "radius"))
    }
  end

  defp transform_stargate(data) do
    %{
      stargate_id: get_id(data),
      name: get_localized_name(data),
      system_id: Map.get(data, "solarSystemID"),
      type_id: Map.get(data, "typeID"),
      destination_stargate_id: get_in(data, ["destination", "stargateID"]),
      destination_system_id: get_in(data, ["destination", "systemID"]),
      x: to_float(Map.get(data, "x")),
      y: to_float(Map.get(data, "y")),
      z: to_float(Map.get(data, "z"))
    }
  end

  # ============================================================================
  # Private - Data Extraction Helpers
  # ============================================================================

  defp get_id(data) do
    # Try multiple possible ID fields
    data["_id"] ||
      data["typeID"] ||
      data["groupID"] ||
      data["categoryID"] ||
      data["solarSystemID"] ||
      data["regionID"] ||
      data["constellationID"] ||
      data["stargateID"]
  end

  defp get_localized_name(data) do
    # CCP SDE has localized names in a "name" object with language keys
    case Map.get(data, "name") do
      %{"en" => name} -> name
      name when is_binary(name) -> name
      _ -> nil
    end
  end

  defp get_localized_description(data) do
    case Map.get(data, "description") do
      %{"en" => desc} -> desc
      desc when is_binary(desc) -> desc
      _ -> nil
    end
  end

  defp to_float(nil), do: 0.0

  defp to_float(value) when is_float(value), do: value
  defp to_float(value) when is_integer(value), do: value * 1.0

  defp to_float(value) when is_binary(value) do
    case Float.parse(value) do
      {f, _} ->
        f

      :error ->
        Logger.warning(
          "to_float failed to parse binary value: #{inspect(value)}, defaulting to 0.0"
        )

        0.0
    end
  end

  defp to_float(value) do
    Logger.warning("to_float received unexpected type: #{inspect(value)}, defaulting to 0.0")
    0.0
  end
end

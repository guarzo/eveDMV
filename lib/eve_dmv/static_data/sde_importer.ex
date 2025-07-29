defmodule EveDmv.StaticData.SdeImporter do
  @moduledoc """
  Imports EVE Online Static Data Export (SDE) from Fuzzwork.
  Downloads and processes ship attributes and other static data.
  """

  alias EveDmv.Repo

  require Logger

  @fuzzwork_base_url "https://www.fuzzwork.co.uk/dump/latest"

  # Known attribute IDs for ship statistics
  @shield_capacity_id 263
  @armor_hp_id 265
  @structure_hp_id 9
  @shield_em_resist_id 271
  @shield_thermal_resist_id 272
  @shield_kinetic_resist_id 273
  @shield_explosive_resist_id 274
  @armor_em_resist_id 267
  @armor_thermal_resist_id 268
  @armor_kinetic_resist_id 269
  @armor_explosive_resist_id 270

  def import_ship_attributes do
    Logger.info("Starting SDE ship attributes import from Fuzzwork")

    with {:ok, dgm_types} <- download_and_parse_csv("dgmTypeAttributes.csv.bz2"),
         {:ok, dgm_attributes} <- download_and_parse_csv("dgmAttributeTypes.csv.bz2"),
         {:ok, inv_types} <- download_and_parse_csv("invTypes.csv.bz2") do
      Logger.info("Downloaded SDE data, processing ship attributes")
      process_ship_attributes(dgm_types, dgm_attributes, inv_types)
    else
      error ->
        Logger.error("Failed to import SDE data: #{inspect(error)}")
        error
    end
  end

  defp download_and_parse_csv(filename) do
    url = "#{@fuzzwork_base_url}/#{filename}"
    Logger.info("Downloading #{filename} from #{url}")

    case HTTPoison.get(url, [], timeout: 300_000, recv_timeout: 300_000) do
      {:ok, %HTTPoison.Response{status_code: 200, body: compressed_data}} ->
        Logger.info("Successfully downloaded #{filename}, decompressing...")

        case decompress_bz2(compressed_data) do
          {:ok, csv_data} ->
            Logger.info("Decompressed #{filename}, parsing CSV...")
            parse_csv(csv_data)

          error ->
            error
        end

      {:ok, %HTTPoison.Response{status_code: status}} ->
        {:error, "HTTP #{status} when downloading #{filename}"}

      {:error, reason} ->
        {:error, "Failed to download #{filename}: #{inspect(reason)}"}
    end
  end

  defp decompress_bz2(compressed_data) do
    # Write to temp file and use system bunzip2
    temp_file = "/tmp/sde_temp_#{:rand.uniform(99999)}.bz2"
    _temp_output = "/tmp/sde_temp_#{:rand.uniform(99999)}.csv"

    try do
      File.write!(temp_file, compressed_data)

      case System.cmd("bunzip2", ["-c", temp_file], env: []) do
        {decompressed, 0} ->
          File.rm(temp_file)
          {:ok, decompressed}

        {error, _} ->
          File.rm(temp_file)
          {:error, "Failed to decompress bz2 data: #{error}"}
      end
    rescue
      error ->
        File.rm(temp_file)
        {:error, "Failed to decompress bz2 data: #{inspect(error)}"}
    end
  end

  defp parse_csv(csv_data) do
    try do
      lines = String.split(csv_data, "\n", trim: true)
      [header | rows] = lines

      headers = String.split(header, ",") |> Enum.map(&String.trim/1)

      parsed_rows =
        rows
        |> Enum.map(fn line ->
          values = parse_csv_line(line)
          Enum.zip(headers, values) |> Map.new()
        end)

      {:ok, parsed_rows}
    rescue
      error ->
        {:error, "Failed to parse CSV: #{inspect(error)}"}
    end
  end

  defp parse_csv_line(line) do
    # Simple CSV parser - handles quoted fields
    line
    |> String.split(",")
    |> Enum.map(fn field ->
      field
      |> String.trim()
      |> String.trim("\"")
    end)
  end

  defp process_ship_attributes(dgm_types, _dgm_attributes, inv_types) do
    Logger.info("Processing ship attributes from SDE data")

    # Get all ship types
    ships =
      Enum.filter(inv_types, fn type ->
        String.contains?(type["categoryName"] || "", "Ship") ||
          String.contains?(type["groupName"] || "", [
            "Frigate",
            "Destroyer",
            "Cruiser",
            "Battleship",
            "Carrier",
            "Dreadnought",
            "Titan",
            "Supercarrier"
          ])
      end)

    Logger.info("Found #{length(ships)} ships in SDE data")

    # Process each ship
    ship_attributes =
      ships
      |> Enum.map(fn ship ->
        type_id = parse_int(ship["typeID"])
        calculate_real_ship_attributes(type_id, ship, dgm_types)
      end)
      |> Enum.reject(&is_nil/1)

    Logger.info("Calculated attributes for #{length(ship_attributes)} ships")

    # Insert into database
    insert_ship_attributes(ship_attributes)
  end

  defp calculate_real_ship_attributes(type_id, ship, dgm_types) when is_integer(type_id) do
    # Get all attributes for this ship type
    ship_attrs =
      Enum.filter(dgm_types, fn attr ->
        parse_int(attr["typeID"]) == type_id
      end)

    # Extract specific attributes we need
    shield_hp = get_attribute_value(ship_attrs, @shield_capacity_id)
    armor_hp = get_attribute_value(ship_attrs, @armor_hp_id)
    structure_hp = get_attribute_value(ship_attrs, @structure_hp_id)

    # Only process ships with complete HP data
    if shield_hp && armor_hp && structure_hp do
      %{
        type_id: type_id,
        type_name: ship["typeName"],
        group_name: ship["groupName"],
        shield_hp: shield_hp,
        armor_hp: armor_hp,
        structure_hp: structure_hp,
        shield_em_resist: get_attribute_value(ship_attrs, @shield_em_resist_id) || 0.0,
        shield_thermal_resist: get_attribute_value(ship_attrs, @shield_thermal_resist_id) || 0.0,
        shield_kinetic_resist: get_attribute_value(ship_attrs, @shield_kinetic_resist_id) || 0.0,
        shield_explosive_resist:
          get_attribute_value(ship_attrs, @shield_explosive_resist_id) || 0.0,
        armor_em_resist: get_attribute_value(ship_attrs, @armor_em_resist_id) || 0.0,
        armor_thermal_resist: get_attribute_value(ship_attrs, @armor_thermal_resist_id) || 0.0,
        armor_kinetic_resist: get_attribute_value(ship_attrs, @armor_kinetic_resist_id) || 0.0,
        armor_explosive_resist:
          get_attribute_value(ship_attrs, @armor_explosive_resist_id) || 0.0,
        data_source: "sde_import",
        last_updated: DateTime.utc_now()
      }
    else
      nil
    end
  end

  defp calculate_real_ship_attributes(_, _, _), do: nil

  defp get_attribute_value(ship_attrs, attribute_id) do
    case Enum.find(ship_attrs, fn attr ->
           parse_int(attr["attributeID"]) == attribute_id
         end) do
      %{"valueFloat" => value} when value != "" -> parse_float(value)
      %{"valueInt" => value} when value != "" -> parse_int(value) |> to_float()
      _ -> nil
    end
  end

  defp parse_int(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> nil
    end
  end

  defp parse_int(value) when is_integer(value), do: value
  defp parse_int(_), do: nil

  defp parse_float(value) when is_binary(value) do
    case Float.parse(value) do
      {float, _} -> float
      :error -> nil
    end
  end

  defp parse_float(value) when is_float(value), do: value
  defp parse_float(value) when is_integer(value), do: value * 1.0
  defp parse_float(_), do: nil

  defp to_float(nil), do: nil
  defp to_float(int) when is_integer(int), do: int * 1.0
  defp to_float(float), do: float

  defp insert_ship_attributes(ship_attributes) do
    Logger.info("Inserting #{length(ship_attributes)} ship attributes into database")

    # Clear existing SDE data
    Repo.query!("DELETE FROM ship_attributes WHERE data_source = 'sde_import'")

    # Insert new data in batches
    ship_attributes
    |> Enum.chunk_every(100)
    |> Enum.each(fn batch ->
      insert_batch(batch)
    end)

    Logger.info("Successfully imported ship attributes from SDE")
    {:ok, length(ship_attributes)}
  end

  defp insert_batch(batch) do
    values =
      batch
      |> Enum.map(fn attrs ->
        "(#{attrs.type_id}, #{attrs.shield_hp}, #{attrs.armor_hp}, #{attrs.structure_hp}, " <>
          "#{attrs.shield_em_resist}, #{attrs.shield_thermal_resist}, #{attrs.shield_kinetic_resist}, #{attrs.shield_explosive_resist}, " <>
          "#{attrs.armor_em_resist}, #{attrs.armor_thermal_resist}, #{attrs.armor_kinetic_resist}, #{attrs.armor_explosive_resist}, " <>
          "'#{attrs.data_source}', '#{DateTime.to_iso8601(attrs.last_updated)}')"
      end)
      |> Enum.join(", ")

    query = """
    INSERT INTO ship_attributes 
    (type_id, shield_hp, armor_hp, structure_hp, 
     shield_em_resist, shield_thermal_resist, shield_kinetic_resist, shield_explosive_resist,
     armor_em_resist, armor_thermal_resist, armor_kinetic_resist, armor_explosive_resist,
     data_source, last_updated)
    VALUES #{values}
    ON CONFLICT (type_id) DO UPDATE SET
      shield_hp = EXCLUDED.shield_hp,
      armor_hp = EXCLUDED.armor_hp,
      structure_hp = EXCLUDED.structure_hp,
      shield_em_resist = EXCLUDED.shield_em_resist,
      shield_thermal_resist = EXCLUDED.shield_thermal_resist,
      shield_kinetic_resist = EXCLUDED.shield_kinetic_resist,
      shield_explosive_resist = EXCLUDED.shield_explosive_resist,
      armor_em_resist = EXCLUDED.armor_em_resist,
      armor_thermal_resist = EXCLUDED.armor_thermal_resist,
      armor_kinetic_resist = EXCLUDED.armor_kinetic_resist,
      armor_explosive_resist = EXCLUDED.armor_explosive_resist,
      data_source = EXCLUDED.data_source,
      last_updated = EXCLUDED.last_updated
    """

    Repo.query!(query)
  end
end

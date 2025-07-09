defmodule EveDmv.Eve.StaticDataLoader.ItemTypeProcessor do
  @moduledoc """
  Processes EVE item type data from SDE CSV files.

  Handles parsing and processing of item types, groups, and categories,
  including ship classification and other item type categorization.
  """

  alias EveDmv.Eve.StaticDataLoader.CsvParser
  require Logger

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

  @doc """
  Processes item type data from CSV files.
  """
  def process_item_data(file_paths) do
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

  @doc """
  Processes ship-only data (legacy support).
  """
  def process_ship_data(%{ship_types: types_path, ship_groups: groups_path}) do
    with {:ok, groups} <- parse_groups_file(groups_path),
         {:ok, types} <- parse_types_file(types_path) do
      ship_types = build_ship_types(types, groups)
      {:ok, ship_types}
    end
  end

  @doc """
  Gets the list of ship group IDs.
  """
  def get_ship_group_ids, do: @ship_group_ids

  @doc """
  Checks if a group ID represents a ship.
  """
  def ship_group?(group_id), do: group_id in @ship_group_ids

  # Private functions

  defp parse_categories_file(categories_path) do
    CsvParser.read_and_parse_csv_to_map(
      categories_path,
      &CsvParser.parse_category_row/1,
      :category_id
    )
  end

  defp parse_groups_file(groups_path) do
    CsvParser.read_and_parse_csv_to_map(
      groups_path,
      &CsvParser.parse_group_row/1,
      :group_id
    )
  end

  defp parse_types_file(types_path) do
    CsvParser.read_and_parse_csv(types_path, &CsvParser.parse_type_row/1)
  end

  defp build_item_types(types, groups_map, categories_map) do
    # Process all types, not just published ones
    types
    |> Enum.filter(&safe_for_bulk_insert?/1)
    |> Enum.map(fn type ->
      group = Map.get(groups_map, type.group_id, %{})
      category = Map.get(categories_map, group[:category_id], %{})

      # Determine item classifications
      is_ship = type.group_id in @ship_group_ids
      is_module = category[:name] in ["Module", "Subsystem"]
      is_charge = category[:name] in ["Charge", "Ammunition & Charges"]
      is_deployable = category[:name] in ["Deployable", "Structure"]
      is_blueprint = category[:name] == "Blueprint"

      # Build search keywords
      search_keywords = build_search_keywords(type.name, group[:name], category[:name])

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
        search_keywords: search_keywords,
        sde_version: "latest"
      }
    end)
  end

  defp build_ship_types(types, groups_map) do
    ship_types =
      Enum.filter(types, fn type ->
        type.group_id in @ship_group_ids and type.published
      end)

    Enum.map(ship_types, fn type ->
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

  @doc """
  Filters item types by category.
  """
  def filter_by_category(item_types, category_name) do
    Enum.filter(item_types, &(&1.category_name == category_name))
  end

  @doc """
  Filters item types by group.
  """
  def filter_by_group(item_types, group_name) do
    Enum.filter(item_types, &(&1.group_name == group_name))
  end

  @doc """
  Gets all ship types from item type data.
  """
  def get_ship_types(item_types) do
    Enum.filter(item_types, & &1.is_ship)
  end

  @doc """
  Gets all module types from item type data.
  """
  def get_module_types(item_types) do
    Enum.filter(item_types, & &1.is_module)
  end

  @doc """
  Analyzes item type data for statistics.
  """
  def analyze_item_types(item_types) do
    %{
      total_count: length(item_types),
      ships: Enum.count(item_types, & &1.is_ship),
      modules: Enum.count(item_types, & &1.is_module),
      charges: Enum.count(item_types, & &1.is_charge),
      deployables: Enum.count(item_types, & &1.is_deployable),
      blueprints: Enum.count(item_types, & &1.is_blueprint),
      categories: item_types |> Enum.map(& &1.category_name) |> Enum.uniq() |> length(),
      groups: item_types |> Enum.map(& &1.group_name) |> Enum.uniq() |> length()
    }
  end

  defp build_search_keywords(name, group_name, category_name) do
    # Extract words from the name
    name_words = String.split(String.downcase(name || ""), ~r/\s+/)

    # Add group and category if present
    keywords = name_words
    keywords = if group_name, do: keywords ++ [String.downcase(group_name)], else: keywords
    keywords = if category_name, do: keywords ++ [String.downcase(category_name)], else: keywords

    # Remove duplicates and empty strings
    keywords
    |> Enum.uniq()
    |> Enum.reject(&(&1 == ""))
  end

  defp safe_for_bulk_insert?(type) do
    # Maximum safe value for numeric(15,4) is 99,999,999,999.9999
    max_safe_value = 99_999_999_999.0

    # Check if all numeric values are within safe bounds
    mass_safe = is_nil(type.mass) or type.mass <= max_safe_value
    volume_safe = is_nil(type.volume) or type.volume <= max_safe_value
    capacity_safe = is_nil(type.capacity) or type.capacity <= max_safe_value
    base_price_safe = is_nil(type.base_price) or type.base_price <= max_safe_value

    # Skip items with astronomical values (typically celestial objects)
    if not (mass_safe and volume_safe and capacity_safe and base_price_safe) do
      Logger.debug("Skipping type_id #{type.type_id} (#{type.name}) due to numeric overflow")
      false
    else
      true
    end
  end
end

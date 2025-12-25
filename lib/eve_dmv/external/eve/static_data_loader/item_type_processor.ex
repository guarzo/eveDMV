defmodule EveDmv.Eve.StaticDataLoader.ItemTypeProcessor do
  @moduledoc """
  Processes EVE item type data from CCP's official SDE JSONL files.

  Handles parsing and processing of item types, groups, and categories,
  including ship classification and other item type categorization.

  ## Category Filtering

  Only killmail-relevant items are imported:
  - Ships (category 6)
  - Modules (category 7)
  - Charges (category 8)
  - Drones (category 18)
  - Implants (category 20)
  - Deployables (category 22)
  - Structures (category 65) - for structure killmails
  - Fighters (category 87)

  This reduces the import from ~49,906 items to ~5,000-8,000 items.
  """

  alias EveDmv.Eve.StaticDataLoader.JsonlParser
  require Logger

  # Category IDs for killmail-relevant items
  # These are the only categories we need to import from the SDE
  @killmail_category_ids [
    # Ship
    6,
    # Module
    7,
    # Charge
    8,
    # Drone
    18,
    # Implant
    20,
    # Deployable
    22,
    # Structure (citadels, etc.)
    65,
    # Fighter
    87
  ]

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
  Gets the list of ship group IDs.
  """
  def get_ship_group_ids, do: @ship_group_ids

  @doc """
  Checks if a group ID represents a ship.
  """
  def ship_group?(group_id), do: group_id in @ship_group_ids

  @doc """
  Gets the list of killmail-relevant category IDs.

  These are the categories that are imported:
  - 6: Ship
  - 7: Module
  - 8: Charge
  - 18: Drone
  - 20: Implant
  - 22: Deployable
  - 65: Structure
  - 87: Fighter
  """
  @spec get_killmail_category_ids() :: [integer()]
  def get_killmail_category_ids, do: @killmail_category_ids

  @doc """
  Checks if a category ID is killmail-relevant.
  """
  @spec killmail_category?(integer()) :: boolean()
  def killmail_category?(category_id), do: category_id in @killmail_category_ids

  @doc """
  Processes item type data from CCP SDE JSONL files.

  This is the main method for importing SDE data. It:
  - Reads from the official CCP JSONL format
  - Filters to only killmail-relevant categories
  - Uses streaming for memory efficiency

  ## Parameters

  - `file_paths` - Map with paths to JSONL files:
    - `:item_types` - Path to types.jsonl
    - `:item_groups` - Path to groups.jsonl
    - `:item_categories` - Path to categories.jsonl

  ## Options

  - `:filter_categories` - Whether to filter by killmail categories (default: true)
  - `:sde_version` - Version string to set on records (default: "latest")
  - `:sde_build_number` - CCP SDE build number (integer) for version tracking

  ## Returns

  - `{:ok, item_types}` - List of processed item type maps
  - `{:error, reason}` - If processing fails
  """
  @spec process_item_data_jsonl(map(), keyword()) :: {:ok, list(map())} | {:error, term()}
  def process_item_data_jsonl(file_paths, opts \\ []) do
    filter_categories = Keyword.get(opts, :filter_categories, true)
    sde_version = Keyword.get(opts, :sde_version, "latest")
    sde_build_number = Keyword.get(opts, :sde_build_number)

    with {:ok, categories_map} <- load_categories_jsonl(file_paths.item_categories),
         {:ok, groups_map} <- load_groups_jsonl(file_paths.item_groups, categories_map),
         {:ok, types_stream} <- JsonlParser.parse_types(file_paths.item_types) do
      # Build the group->category lookup for filtering
      group_category_map = build_group_category_map(groups_map)

      item_types =
        types_stream
        |> Stream.filter(fn type ->
          category_id = group_category_map[type.group_id]
          should_import_type?(type, category_id, filter_categories)
        end)
        |> Stream.map(fn type ->
          build_item_type_from_jsonl(
            type,
            groups_map,
            categories_map,
            sde_version,
            sde_build_number
          )
        end)
        |> Stream.filter(&safe_for_bulk_insert?/1)
        |> Enum.to_list()

      Logger.info("Processed #{length(item_types)} item types from CCP JSONL")
      {:ok, item_types}
    end
  end

  @doc """
  Determines if an item type should be imported based on category filtering.

  Items are imported if:
  - They are published (or `filter_categories` is false)
  - Their category is in the killmail-relevant list (or `filter_categories` is false)
  """
  @spec should_import_type?(map(), integer() | nil, boolean()) :: boolean()
  def should_import_type?(type, category_id, filter_categories) do
    if filter_categories do
      # Must be published and in a killmail-relevant category
      type.published == true and category_id in @killmail_category_ids
    else
      # Import all types when not filtering
      true
    end
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

  # ============================================================================
  # Private JSONL Processing Functions
  # ============================================================================

  defp load_categories_jsonl(categories_path) do
    # Use parse_categories which applies the transform_category function
    case JsonlParser.parse_categories(categories_path) do
      {:ok, stream} ->
        # Convert stream to a map keyed by category_id
        categories =
          stream
          |> Enum.reduce(%{}, fn cat, acc ->
            Map.put(acc, cat.category_id, cat)
          end)

        Logger.debug("Loaded #{map_size(categories)} categories from JSONL")
        {:ok, categories}

      {:error, _} = error ->
        error
    end
  end

  defp load_groups_jsonl(groups_path, categories_map) do
    # Use parse_groups which applies the transform_group function
    case JsonlParser.parse_groups(groups_path) do
      {:ok, stream} ->
        # Convert stream to a map keyed by group_id and enrich with category names
        groups =
          stream
          |> Enum.reduce(%{}, fn group, acc ->
            category = Map.get(categories_map, group.category_id, %{})
            enriched = Map.put(group, :category_name, category[:name])
            Map.put(acc, group.group_id, enriched)
          end)

        Logger.debug("Loaded #{map_size(groups)} groups from JSONL")
        {:ok, groups}

      {:error, _} = error ->
        error
    end
  end

  defp build_group_category_map(groups_map) do
    Map.new(groups_map, fn {group_id, group} ->
      {group_id, group.category_id}
    end)
  end

  defp build_item_type_from_jsonl(type, groups_map, categories_map, sde_version, sde_build_number) do
    group = Map.get(groups_map, type.group_id, %{})
    category_id = group[:category_id]
    category = Map.get(categories_map, category_id, %{})

    # Determine item classifications
    # Note: Only classifications that have corresponding attributes in ItemType resource
    is_ship = type.group_id in @ship_group_ids
    is_module = category[:name] in ["Module", "Subsystem"]
    is_charge = category[:name] in ["Charge"]
    is_deployable = category[:name] in ["Deployable", "Structure"]
    is_blueprint = category[:name] == "Blueprint"

    # Build search keywords
    search_keywords = build_search_keywords(type.name, group[:name], category[:name])

    base_map = %{
      type_id: type.type_id,
      type_name: type.name,
      group_id: type.group_id,
      group_name: group[:name] || "Unknown",
      category_id: category_id,
      category_name: category[:name] || "Unknown",
      mass: type.mass || 0.0,
      volume: type.volume || 0.0,
      capacity: type.capacity || 0.0,
      base_price: type.base_price || 0.0,
      published: type.published,
      is_ship: is_ship,
      is_module: is_module,
      is_charge: is_charge,
      is_deployable: is_deployable,
      is_blueprint: is_blueprint,
      search_keywords: search_keywords,
      sde_version: sde_version
    }

    # Add build number if provided
    if sde_build_number do
      Map.put(base_map, :sde_build_number, sde_build_number)
    else
      base_map
    end
  end

  defp build_search_keywords(name, group_name, category_name) do
    # Extract words from the name
    name_words = String.split(String.downcase(name || ""), ~r/\s+/)

    # Add group and category if present
    keywords_with_group =
      if group_name, do: [String.downcase(group_name) | name_words], else: name_words

    keywords_with_category =
      if category_name,
        do: [String.downcase(category_name) | keywords_with_group],
        else: keywords_with_group

    # Remove duplicates and empty strings
    keywords_with_category
    |> Enum.uniq()
    |> Enum.reject(&(&1 == ""))
  end

  defp safe_for_bulk_insert?(type) do
    # Maximum safe value for numeric(15,4) is 99,999,999,999.9999
    max_safe_value = 99_999_999_999.0

    mass_safe = is_nil(type.mass) or type.mass <= max_safe_value
    volume_safe = is_nil(type.volume) or type.volume <= max_safe_value
    capacity_safe = is_nil(type.capacity) or type.capacity <= max_safe_value
    base_price_safe = is_nil(type.base_price) or type.base_price <= max_safe_value

    if mass_safe and volume_safe and capacity_safe and base_price_safe do
      true
    else
      Logger.debug("Skipping type_id #{type.type_id} (#{type.type_name}) due to numeric overflow")
      false
    end
  end
end

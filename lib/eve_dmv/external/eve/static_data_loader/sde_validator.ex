defmodule EveDmv.Eve.StaticDataLoader.SdeValidator do
  @moduledoc """
  Validates SDE data imports from CCP's official SDE.

  This module verifies:
  1. Record counts and category breakdown
  2. All killmail-relevant items exist
  3. Version update detection works correctly
  4. Performance of filtered vs unfiltered imports

  ## Usage

      # Validate killmail coverage
      {:ok, coverage} = SdeValidator.validate_essential_items()

      # Full validation report
      {:ok, report} = SdeValidator.generate_validation_report()
  """

  alias EveDmv.Api
  alias EveDmv.Eve.ItemType
  alias EveDmv.Eve.SolarSystem
  alias EveDmv.Eve.StaticDataLoader.ItemTypeProcessor

  require Logger
  require Ash.Query

  # Common EVE ships that should always be present
  @essential_ships [
    # Frigates
    587,
    # Rifter
    584,
    # Atron
    589,
    # Slasher
    # Cruisers
    622,
    # Caracal
    628,
    # Moa
    620,
    # Stabber
    # Battleships
    638,
    # Raven
    639,
    # Megathron
    640,
    # Tempest
    # Capitals
    23_757,
    # Archon
    23_911,
    # Nidhoggur
    23_913
    # Thanatos
  ]

  # Common modules that should always be present
  @essential_modules [
    2048,
    # Damage Control I
    1_999,
    # 1MN Afterburner I
    3170,
    # Small Shield Extender I
    31_366
    # Small Armor Repairer I
  ]

  # Common drones
  @essential_drones [
    2456,
    # Hobgoblin I
    2454,
    # Warrior I
    2193
    # Hammerhead I
  ]

  @type validation_result :: {:ok, map()} | {:error, term()}
  @type comparison_result :: {:ok, map()} | {:error, term()}

  # ============================================================================
  # Public API
  # ============================================================================

  @doc """
  Generates a comprehensive validation report.

  This is the main entry point for Phase 7 validation.
  """
  @spec generate_validation_report() :: validation_result()
  def generate_validation_report do
    Logger.info("Generating SDE validation report...")

    with {:ok, db_counts} <- get_database_counts(),
         {:ok, category_breakdown} <- get_category_breakdown(),
         {:ok, essential_coverage} <- validate_essential_items(),
         {:ok, version_info} <- get_version_info() do
      report = %{
        timestamp: DateTime.utc_now(),
        database_counts: db_counts,
        category_breakdown: category_breakdown,
        essential_item_coverage: essential_coverage,
        version_info: version_info,
        summary: build_summary(db_counts, category_breakdown, essential_coverage)
      }

      Logger.info("Validation report generated successfully")
      {:ok, report}
    end
  end

  @doc """
  Gets current item counts from the database.
  """
  @spec get_database_counts() :: {:ok, map()} | {:error, term()}
  def get_database_counts do
    Logger.info("Counting database records...")

    with {:ok, total_items} <- count_items(),
         {:ok, published_items} <- count_items(published: true),
         {:ok, solar_systems} <- count_solar_systems() do
      counts = %{
        total_item_types: total_items,
        published_item_types: published_items,
        solar_systems: solar_systems
      }

      Logger.info("Database counts: #{inspect(counts)}")
      {:ok, counts}
    end
  end

  @doc """
  Gets breakdown of items by category.
  """
  @spec get_category_breakdown() :: {:ok, map()} | {:error, term()}
  def get_category_breakdown do
    Logger.info("Getting category breakdown...")

    killmail_categories = ItemTypeProcessor.get_killmail_category_ids()

    case Ash.Query.new(ItemType)
         |> Ash.read(domain: Api) do
      {:ok, items} ->
        breakdown =
          items
          |> Enum.group_by(& &1.category_id)
          |> Enum.map(fn {cat_id, items} ->
            {cat_id,
             %{
               count: length(items),
               category_name: List.first(items).category_name,
               is_killmail_relevant: cat_id in killmail_categories
             }}
          end)
          |> Enum.into(%{})

        killmail_relevant_count =
          breakdown
          |> Enum.filter(fn {_id, data} -> data.is_killmail_relevant end)
          |> Enum.map(fn {_id, data} -> data.count end)
          |> Enum.sum()

        result = %{
          by_category: breakdown,
          killmail_relevant_count: killmail_relevant_count,
          total_categories: map_size(breakdown)
        }

        Logger.info("Category breakdown: #{killmail_relevant_count} killmail-relevant items")
        {:ok, result}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Validates that essential items (ships, modules, drones) exist in the database.
  """
  @spec validate_essential_items() :: {:ok, map()} | {:error, term()}
  def validate_essential_items do
    Logger.info("Validating essential items...")

    with {:ok, ship_coverage} <- check_essential_items(@essential_ships, "ships"),
         {:ok, module_coverage} <- check_essential_items(@essential_modules, "modules"),
         {:ok, drone_coverage} <- check_essential_items(@essential_drones, "drones") do
      coverage = %{
        ships: ship_coverage,
        modules: module_coverage,
        drones: drone_coverage,
        total_checked:
          length(@essential_ships) + length(@essential_modules) + length(@essential_drones),
        total_found: ship_coverage.found + module_coverage.found + drone_coverage.found,
        all_present:
          ship_coverage.missing == [] and module_coverage.missing == [] and
            drone_coverage.missing == []
      }

      Logger.info("Essential items: #{coverage.total_found}/#{coverage.total_checked} found")
      {:ok, coverage}
    end
  end

  @doc """
  Gets current SDE version information from the database.
  """
  @spec get_version_info() :: {:ok, map()} | {:error, term()}
  def get_version_info do
    Logger.info("Getting SDE version info...")

    case Ash.Query.new(SolarSystem)
         |> Ash.Query.filter(not is_nil(sde_version))
         |> Ash.Query.sort([{:last_updated, :desc}])
         |> Ash.Query.limit(1)
         |> Ash.read(domain: Api) do
      {:ok, [system | _]} ->
        version_info = %{
          sde_version: system.sde_version,
          sde_build_number: Map.get(system, :sde_build_number),
          last_updated: system.last_updated
        }

        Logger.info("Current SDE version: #{version_info.sde_version}")
        {:ok, version_info}

      {:ok, []} ->
        Logger.warning("No SDE version info found in database")
        {:ok, %{sde_version: nil, sde_build_number: nil, last_updated: nil}}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Compares record counts between JSONL files (if available) and database.
  """
  @spec compare_with_jsonl_files(String.t()) :: comparison_result()
  def compare_with_jsonl_files(extracted_dir) do
    Logger.info("Comparing database with JSONL files in #{extracted_dir}...")

    types_path = find_file(extracted_dir, "types.jsonl")
    groups_path = find_file(extracted_dir, "groups.jsonl")
    categories_path = find_file(extracted_dir, "categories.jsonl")
    systems_path = find_file(extracted_dir, "mapSolarSystems.jsonl")

    with {:ok, jsonl_types} <- count_jsonl_lines(types_path),
         {:ok, jsonl_systems} <- count_jsonl_lines(systems_path),
         {:ok, db_counts} <- get_database_counts() do
      # Count filtered types (killmail-relevant only)
      {:ok, filtered_count} = count_filtered_types(types_path, groups_path, categories_path)

      comparison = %{
        jsonl_total_types: jsonl_types,
        jsonl_filtered_types: filtered_count,
        jsonl_systems: jsonl_systems,
        db_item_types: db_counts.total_item_types,
        db_solar_systems: db_counts.solar_systems,
        types_reduction_pct: calculate_reduction_pct(jsonl_types, filtered_count),
        types_match: db_counts.total_item_types == filtered_count,
        systems_match: db_counts.solar_systems == jsonl_systems
      }

      Logger.info(
        "Comparison complete: JSONL has #{jsonl_types} types, filtered to #{filtered_count}"
      )

      {:ok, comparison}
    else
      {:error, :file_not_found} ->
        Logger.warning("JSONL files not found in #{extracted_dir}")
        {:error, :jsonl_files_not_found}

      error ->
        error
    end
  end

  @doc """
  Validates that a ship with the given type_id exists and returns its details.
  """
  @spec validate_ship_exists(integer()) :: {:ok, map()} | {:error, :not_found}
  def validate_ship_exists(type_id) do
    case Ash.Query.new(ItemType)
         |> Ash.Query.filter(type_id == ^type_id and is_ship == true)
         |> Ash.read_one(domain: Api) do
      {:ok, nil} ->
        {:error, :not_found}

      {:ok, item} ->
        {:ok,
         %{
           type_id: item.type_id,
           type_name: item.type_name,
           group_name: item.group_name,
           category_name: item.category_name
         }}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Runs performance test comparing filtered vs unfiltered import.

  This is a simulation test - it doesn't actually import data.
  """
  @spec performance_comparison(String.t()) :: {:ok, map()} | {:error, term()}
  def performance_comparison(extracted_dir) do
    Logger.info("Running performance comparison...")

    types_path = find_file(extracted_dir, "types.jsonl")
    groups_path = find_file(extracted_dir, "groups.jsonl")
    categories_path = find_file(extracted_dir, "categories.jsonl")

    file_paths = %{
      item_types: types_path,
      item_groups: groups_path,
      item_categories: categories_path
    }

    # Time unfiltered processing
    {unfiltered_time, {:ok, unfiltered_items}} =
      :timer.tc(fn ->
        ItemTypeProcessor.process_item_data_jsonl(file_paths, filter_categories: false)
      end)

    # Time filtered processing
    {filtered_time, {:ok, filtered_items}} =
      :timer.tc(fn ->
        ItemTypeProcessor.process_item_data_jsonl(file_paths, filter_categories: true)
      end)

    result = %{
      unfiltered: %{
        count: length(unfiltered_items),
        time_ms: unfiltered_time / 1000
      },
      filtered: %{
        count: length(filtered_items),
        time_ms: filtered_time / 1000
      },
      speedup_pct: calculate_speedup_pct(unfiltered_time, filtered_time),
      reduction_pct: calculate_reduction_pct(length(unfiltered_items), length(filtered_items))
    }

    Logger.info(
      "Performance: Filtered is #{result.speedup_pct}% faster with #{result.reduction_pct}% fewer items"
    )

    {:ok, result}
  rescue
    error ->
      {:error, {:performance_test_failed, error}}
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

  defp count_items(filters \\ []) do
    base_query = Ash.Query.new(ItemType)

    final_query =
      if Keyword.get(filters, :published) do
        Ash.Query.filter(base_query, published == true)
      else
        base_query
      end

    case Ash.count(final_query, domain: Api) do
      {:ok, count} -> {:ok, count}
      error -> error
    end
  end

  defp count_solar_systems do
    Ash.Query.new(SolarSystem)
    |> Ash.count(domain: Api)
  end

  defp check_essential_items(type_ids, category_name) do
    case Ash.Query.new(ItemType)
         |> Ash.Query.filter(type_id in ^type_ids)
         |> Ash.read(domain: Api) do
      {:ok, items} ->
        found_ids = Enum.map(items, & &1.type_id)
        missing_ids = type_ids -- found_ids

        {:ok,
         %{
           category: category_name,
           expected: length(type_ids),
           found: length(items),
           missing: missing_ids
         }}

      {:error, error} ->
        {:error, error}
    end
  end

  defp find_file(dir, filename) do
    case Path.wildcard(Path.join([dir, "**", filename])) do
      [path | _] -> path
      [] -> nil
    end
  end

  defp count_jsonl_lines(nil), do: {:error, :file_not_found}

  defp count_jsonl_lines(path) do
    if File.exists?(path) do
      count =
        path
        |> File.stream!([], :line)
        |> Stream.reject(&(String.trim(&1) == ""))
        |> Enum.count()

      {:ok, count}
    else
      {:error, :file_not_found}
    end
  end

  defp count_filtered_types(types_path, groups_path, categories_path) do
    if types_path && groups_path && categories_path do
      file_paths = %{
        item_types: types_path,
        item_groups: groups_path,
        item_categories: categories_path
      }

      case ItemTypeProcessor.process_item_data_jsonl(file_paths, filter_categories: true) do
        {:ok, items} -> {:ok, length(items)}
        error -> error
      end
    else
      {:error, :file_not_found}
    end
  end

  defp calculate_reduction_pct(original, filtered) when original > 0 do
    Float.round((1 - filtered / original) * 100, 1)
  end

  defp calculate_reduction_pct(_, _), do: 0.0

  defp calculate_speedup_pct(unfiltered_time, filtered_time) when filtered_time > 0 do
    Float.round((1 - filtered_time / unfiltered_time) * 100, 1)
  end

  defp calculate_speedup_pct(_, _), do: 0.0

  defp build_summary(db_counts, category_breakdown, essential_coverage) do
    %{
      total_items: db_counts.total_item_types,
      killmail_relevant_items: category_breakdown.killmail_relevant_count,
      solar_systems: db_counts.solar_systems,
      essential_items_complete: essential_coverage.all_present,
      validation_passed:
        db_counts.total_item_types > 0 and
          db_counts.solar_systems > 0 and
          essential_coverage.all_present
    }
  end
end

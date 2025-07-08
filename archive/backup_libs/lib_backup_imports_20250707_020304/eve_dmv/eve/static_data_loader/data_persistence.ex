defmodule EveDmv.Eve.StaticDataLoader.DataPersistence do
    alias EveDmv.Eve.ItemType
  alias EveDmv.Eve.SolarSystem

  require Logger
  @moduledoc """
  Handles bulk database operations for static data loading.

  Provides optimized bulk creation operations for item types and solar systems
  with error handling and progress reporting.
  """


  @doc """
  Bulk creates item types in the database.
  """
  def bulk_create_item_types(item_data) do
    Logger.info("Bulk creating #{length(item_data)} item types")

    case Ash.bulk_create(item_data, ItemType, :create,
           domain: EveDmv.Api,
           return_records?: false,
           return_errors?: true,
           stop_on_error?: false,
           authorize?: false,
           batch_size: 500
         ) do
      %{records: _records, errors: []} ->
        {:ok, length(item_data)}

      %{records: records, errors: errors} when errors != [] ->
        created_count = length(records || [])
        Logger.warning("Created #{created_count} item types, #{length(errors)} failed")

        # Log first few errors for debugging
        log_creation_errors(errors, "item type", :type_id)

        {:ok, created_count}
    end
  rescue
    error ->
      Logger.error("Failed to bulk create item types: #{inspect(error)}")
      {:error, error}
  end

  @doc """
  Bulk creates solar systems in the database.
  """
  def bulk_create_solar_systems(system_data) do
    Logger.info("Bulk creating #{length(system_data)} solar systems")

    case Ash.bulk_create(system_data, SolarSystem, :create,
           domain: EveDmv.Api,
           return_records?: false,
           return_errors?: true,
           stop_on_error?: false,
           authorize?: false,
           batch_size: 500
         ) do
      %{records: _records, errors: []} ->
        {:ok, length(system_data)}

      %{records: records, errors: errors} when errors != [] ->
        created_count = length(records || [])
        Logger.warning("Created #{created_count} solar systems, #{length(errors)} failed")

        # Log first few errors for debugging
        log_creation_errors(errors, "solar system", :system_id)

        {:ok, created_count}
    end
  rescue
    error ->
      Logger.error("Failed to bulk create solar systems: #{inspect(error)}")
      {:error, error}
  end

  @doc """
  Counts records in a resource.
  """
  def count_records(resource) do
    case Ash.count(resource, domain: EveDmv.Api, authorize?: false) do
      {:ok, count} -> count
      {:error, _} -> 0
    end
  end

  @doc """
  Updates existing item types with new data.
  """
  def bulk_update_item_types(item_data) do
    Logger.info("Bulk updating #{length(item_data)} item types")

    case Ash.bulk_update(item_data, ItemType, :update,
           domain: EveDmv.Api,
           return_records?: false,
           return_errors?: true,
           stop_on_error?: false,
           authorize?: false,
           batch_size: 500
         ) do
      %{records: _records, errors: []} ->
        {:ok, length(item_data)}

      %{records: records, errors: errors} when errors != [] ->
        updated_count = length(records || [])
        Logger.warning("Updated #{updated_count} item types, #{length(errors)} failed")

        log_creation_errors(errors, "item type update", :type_id)

        {:ok, updated_count}
    end
  rescue
    error ->
      Logger.error("Failed to bulk update item types: #{inspect(error)}")
      {:error, error}
  end

  @doc """
  Updates existing solar systems with new data.
  """
  def bulk_update_solar_systems(system_data) do
    Logger.info("Bulk updating #{length(system_data)} solar systems")

    case Ash.bulk_update(system_data, SolarSystem, :update,
           domain: EveDmv.Api,
           return_records?: false,
           return_errors?: true,
           stop_on_error?: false,
           authorize?: false,
           batch_size: 500
         ) do
      %{records: _records, errors: []} ->
        {:ok, length(system_data)}

      %{records: records, errors: errors} when errors != [] ->
        updated_count = length(records || [])
        Logger.warning("Updated #{updated_count} solar systems, #{length(errors)} failed")

        log_creation_errors(errors, "solar system update", :system_id)

        {:ok, updated_count}
    end
  rescue
    error ->
      Logger.error("Failed to bulk update solar systems: #{inspect(error)}")
      {:error, error}
  end

  @doc """
  Upserts item types (insert or update).
  """
  def upsert_item_types(item_data) do
    Logger.info("Upserting #{length(item_data)} item types")

    case Ash.bulk_create(item_data, ItemType, :upsert,
           domain: EveDmv.Api,
           return_records?: false,
           return_errors?: true,
           stop_on_error?: false,
           authorize?: false,
           batch_size: 500,
           upsert?: true,
           upsert_identity: :primary_key
         ) do
      %{records: _records, errors: []} ->
        {:ok, length(item_data)}

      %{records: records, errors: errors} when errors != [] ->
        processed_count = length(records || [])
        Logger.warning("Processed #{processed_count} item types, #{length(errors)} failed")

        log_creation_errors(errors, "item type upsert", :type_id)

        {:ok, processed_count}
    end
  rescue
    error ->
      Logger.error("Failed to upsert item types: #{inspect(error)}")
      {:error, error}
  end

  @doc """
  Deletes all records from a resource.
  """
  def truncate_resource(resource) do
    Logger.info("Truncating all records from #{inspect(resource)}")

    case Ash.bulk_destroy(resource, :destroy,
           domain: EveDmv.Api,
           return_records?: false,
           return_errors?: true,
           authorize?: false
         ) do
      %{records: _records, errors: []} ->
        Logger.info("Successfully truncated #{inspect(resource)}")
        :ok

      %{records: records, errors: errors} when errors != [] ->
        deleted_count = length(records || [])
        Logger.warning("Deleted #{deleted_count} records, #{length(errors)} failed")
        :ok
    end
  rescue
    error ->
      Logger.error("Failed to truncate #{inspect(resource)}: #{inspect(error)}")
      {:error, error}
  end

  @doc """
  Gets database statistics for loaded static data.
  """
  def get_statistics do
    %{
      item_types: %{
        total: count_records(ItemType),
        ships: count_ships(),
        modules: count_modules()
      },
      solar_systems: %{
        total: count_records(SolarSystem),
        highsec: count_systems_by_security("highsec"),
        lowsec: count_systems_by_security("lowsec"),
        nullsec: count_systems_by_security("nullsec")
      }
    }
  end

  # Private functions

  defp log_creation_errors(errors, type, id_field) do
    Enum.take(errors, 5)
    |> Enum.each(fn {changeset, _error} ->
      id = Ash.Changeset.get_attribute(changeset, id_field)
      Logger.warning("Failed to create #{type} #{id}")
    end)

    if length(errors) > 5 do
      Logger.warning("... and #{length(errors) - 5} more #{type} errors")
    end
  end

  defp count_ships do
    case Ash.count(ItemType,
           query: Ash.Query.filter(ItemType, is_ship: true),
           domain: EveDmv.Api,
           authorize?: false
         ) do
      {:ok, count} -> count
      {:error, _} -> 0
    end
  end

  defp count_modules do
    case Ash.count(ItemType,
           query: Ash.Query.filter(ItemType, is_module: true),
           domain: EveDmv.Api,
           authorize?: false
         ) do
      {:ok, count} -> count
      {:error, _} -> 0
    end
  end

  defp count_systems_by_security(security_class) do
    case Ash.count(SolarSystem,
           query: Ash.Query.filter(SolarSystem, security_class: security_class),
           domain: EveDmv.Api,
           authorize?: false
         ) do
      {:ok, count} -> count
      {:error, _} -> 0
    end
  end

  @doc """
  Checks if static data exists and is recent.
  """
  def validate_data_freshness do
    item_count = count_records(ItemType)
    system_count = count_records(SolarSystem)

    # Basic validation - should have reasonable amounts of data
    %{
      item_types: %{
        loaded: item_count > 0,
        count: item_count,
        # Expect at least 1k types
        sufficient: item_count > 1000
      },
      solar_systems: %{
        loaded: system_count > 0,
        count: system_count,
        # Expect at least 5k systems
        sufficient: system_count > 5000
      }
    }
  end
end

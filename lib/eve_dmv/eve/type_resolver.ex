defmodule EveDmv.Eve.TypeResolver do
  @moduledoc """
  Service for resolving missing item types from ESI and adding them to the database.

  When we encounter a ship_type_id or item_type_id that doesn't exist in our local
  eve_item_types table, this module fetches the type information from ESI and
  creates the necessary records.
  """

  require Logger
  require Ash.Query
  import Ash.Expr
  alias EveDmv.Api
  alias EveDmv.Eve.{EsiClient, ItemType}

  @doc """
  Resolve a missing item type by fetching from ESI and adding to database.

  ## Examples

      iex> TypeResolver.resolve_item_type(23378)
      {:ok, %ItemType{type_id: 23378, type_name: "Machariel", ...}}
      
      iex> TypeResolver.resolve_item_type(999999)
      {:error, :not_found}
  """
  @spec resolve_item_type(integer()) :: {:ok, ItemType.t()} | {:error, term()}
  def resolve_item_type(type_id) when is_integer(type_id) do
    # First check if it already exists (could be a race condition)
    case Ash.get(ItemType, type_id, domain: Api, authorize?: false) do
      {:ok, item_type} ->
        {:ok, item_type}

      {:error, _} ->
        # Not found, fetch from ESI and create
        fetch_and_create_item_type(type_id)
    end
  end

  @doc """
  Resolve multiple missing item types efficiently.

  ## Examples

      iex> TypeResolver.resolve_item_types([23378, 32970, 79520])
      {:ok, [%ItemType{...}, %ItemType{...}, %ItemType{...}]}
  """
  @spec resolve_item_types([integer()]) :: {:ok, [ItemType.t()]}
  def resolve_item_types(type_ids) when is_list(type_ids) do
    # Check which ones already exist
    unique_type_ids = Enum.uniq(type_ids)
    existing_types = get_existing_types(unique_type_ids)
    existing_ids = Enum.map(existing_types, & &1.type_id)
    missing_ids = unique_type_ids -- existing_ids

    if Enum.empty?(missing_ids) do
      {:ok, existing_types}
    else
      # Fetch missing types from ESI
      {:ok, new_types} = fetch_and_create_item_types(missing_ids)
      all_types = existing_types ++ new_types
      {:ok, all_types}
    end
  end

  @doc """
  Ensures an item type exists, creating it if necessary.

  This is the main function to call when you need to ensure a type exists
  before creating a record that references it.
  """
  @spec ensure_item_type(integer()) :: :ok | {:error, :not_found | String.t() | map()}
  def ensure_item_type(type_id) when is_integer(type_id) do
    case resolve_item_type(type_id) do
      {:ok, _item_type} -> :ok
      error -> error
    end
  end

  # Private functions

  defp get_existing_types(type_ids) do
    # Use bulk query with filtering instead of N+1 individual queries
    ItemType
    |> Ash.Query.filter(expr(type_id in ^type_ids))
    |> Ash.read!(domain: Api, authorize?: false)
  rescue
    error ->
      Logger.error("Failed to bulk query item types: #{inspect(error)}")
      []
  end

  defp fetch_and_create_item_type(type_id) do
    Logger.info("Fetching missing item type #{type_id} from ESI")

    with {:ok, type_data} <- EsiClient.get_type(type_id),
         {:ok, group_data} <- EsiClient.get_group(type_data.group_id),
         {:ok, category_data} <- EsiClient.get_category(group_data.category_id) do
      # Create the item type record
      item_type_data = %{
        type_id: type_id,
        type_name: type_data.name,
        description: type_data.description,
        group_id: type_data.group_id,
        group_name: group_data.name,
        category_id: group_data.category_id,
        category_name: category_data.name,
        market_group_id: type_data.market_group_id,
        mass: type_data.mass,
        volume: type_data.volume,
        capacity: type_data.capacity,
        published: type_data.published
      }

      case Ash.create(ItemType, item_type_data, domain: Api, authorize?: false) do
        {:ok, item_type} ->
          Logger.info("Successfully created item type #{type_id}: #{type_data.name}")
          {:ok, item_type}

        {:error, error} ->
          Logger.error("Failed to create item type #{type_id}: #{inspect(error)}")
          {:error, error}
      end
    else
      {:error, error} ->
        Logger.error("Failed to fetch item type #{type_id} from ESI: #{inspect(error)}")
        {:error, error}
    end
  end

  defp fetch_and_create_item_types(type_ids) do
    Logger.info("Fetching #{length(type_ids)} missing item types from ESI")

    # First, try to fetch all the data efficiently
    # Process types in parallel with rate limiting
    fetch_results =
      type_ids
      |> Task.async_stream(
        &fetch_item_type_data/1,
        max_concurrency: 5,
        timeout: 30_000
      )
      |> Enum.map(fn
        {:ok, {:ok, item_data}} -> {:ok, item_data}
        {:ok, error} -> error
        {:exit, reason} -> {:error, {:timeout, reason}}
      end)

    # Separate successful and failed fetch results
    {successful_fetches, _fetch_failures} =
      Enum.split_with(fetch_results, fn
        {:ok, _} -> true
        _ -> false
      end)

    successful_data = Enum.map(successful_fetches, fn {:ok, data} -> data end)

    # Use bulk create for better performance
    case bulk_create_item_types(successful_data) do
      {:ok, created_types} ->
        Logger.info("Successfully resolved #{length(created_types)} item types")
        {:ok, created_types}

      {:error, error} ->
        Logger.error("Failed to bulk create item types: #{inspect(error)}")
        # Fallback to individual creation
        fallback_create_item_types(successful_data)
    end
  end

  # Fetch item type data from ESI without creating the record
  defp fetch_item_type_data(type_id) do
    Logger.debug("Fetching item type data for #{type_id} from ESI")

    with {:ok, type_data} <- EsiClient.get_type(type_id),
         {:ok, group_data} <- EsiClient.get_group(type_data.group_id),
         {:ok, category_data} <- EsiClient.get_category(group_data.category_id) do
      item_type_data = %{
        type_id: type_id,
        type_name: type_data.name,
        description: type_data.description,
        group_id: type_data.group_id,
        group_name: group_data.name,
        category_id: group_data.category_id,
        category_name: category_data.name,
        market_group_id: type_data.market_group_id,
        mass: type_data.mass,
        volume: type_data.volume,
        capacity: type_data.capacity,
        published: type_data.published
      }

      {:ok, item_type_data}
    else
      {:error, error} ->
        Logger.error("Failed to fetch item type #{type_id} from ESI: #{inspect(error)}")
        {:error, error}
    end
  end

  # Use Ash bulk_create for better performance
  defp bulk_create_item_types(item_data_list)
       when is_list(item_data_list) and length(item_data_list) > 0 do
    Logger.info("Bulk creating #{length(item_data_list)} item types")

    try do
      # Use Ash.bulk_create for efficient batch insertion
      case Ash.bulk_create(item_data_list, ItemType, :create,
             domain: Api,
             authorize?: false,
             return_records?: true,
             return_errors?: true
           ) do
        %Ash.BulkResult{records: records, errors: []} ->
          {:ok, records}

        %Ash.BulkResult{records: records, errors: errors} ->
          Logger.warning("Bulk create had some errors: #{inspect(errors)}")
          # If we have significant errors, fallback to individual creation
          if length(errors) > length(records) do
            {:error, :too_many_errors}
          else
            {:ok, records}
          end

        error ->
          Logger.error("Bulk create failed entirely: #{inspect(error)}")
          {:error, error}
      end
    rescue
      error ->
        Logger.error("Exception during bulk create: #{inspect(error)}")
        {:error, error}
    end
  end

  defp bulk_create_item_types([]), do: {:ok, []}

  # Fallback to individual creation if bulk fails
  defp fallback_create_item_types(item_data_list) do
    Logger.info("Falling back to individual creation for #{length(item_data_list)} item types")

    results =
      Enum.map(item_data_list, fn item_data ->
        case Ash.create(ItemType, item_data, domain: Api, authorize?: false) do
          {:ok, item_type} -> {:ok, item_type}
          {:error, error} -> {:error, error}
        end
      end)

    successful_types =
      results
      |> Enum.filter(&match?({:ok, _}, &1))
      |> Enum.map(fn {:ok, item_type} -> item_type end)

    {:ok, successful_types}
  end
end

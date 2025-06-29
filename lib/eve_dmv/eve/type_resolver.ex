defmodule EveDmv.Eve.TypeResolver do
  @moduledoc """
  Service for resolving missing item types from ESI and adding them to the database.

  When we encounter a ship_type_id or item_type_id that doesn't exist in our local
  eve_item_types table, this module fetches the type information from ESI and
  creates the necessary records.
  """

  require Logger
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
  @spec resolve_item_types([integer()]) :: {:ok, [ItemType.t()]} | {:error, term()}
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
      case fetch_and_create_item_types(missing_ids) do
        {:ok, new_types} ->
          all_types = existing_types ++ new_types
          {:ok, all_types}

        error ->
          error
      end
    end
  end

  @doc """
  Ensures an item type exists, creating it if necessary.

  This is the main function to call when you need to ensure a type exists
  before creating a record that references it.
  """
  @spec ensure_item_type(integer()) :: :ok | {:error, term()}
  def ensure_item_type(type_id) when is_integer(type_id) do
    case resolve_item_type(type_id) do
      {:ok, _item_type} -> :ok
      error -> error
    end
  end

  # Private functions

  defp get_existing_types(type_ids) do
    type_ids
    |> Enum.map(fn type_id ->
      case Ash.get(ItemType, type_id, domain: Api, authorize?: false) do
        {:ok, item_type} -> item_type
        {:error, _} -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
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
      {:error, :not_found} ->
        Logger.warning("Item type #{type_id} not found in ESI")
        {:error, :not_found}

      {:error, error} ->
        Logger.error("Failed to fetch item type #{type_id} from ESI: #{inspect(error)}")
        {:error, error}
    end
  end

  defp fetch_and_create_item_types(type_ids) do
    Logger.info("Fetching #{length(type_ids)} missing item types from ESI")

    # Process types in parallel with rate limiting
    results =
      type_ids
      |> Task.async_stream(
        &fetch_and_create_item_type/1,
        max_concurrency: 5,
        timeout: 30_000
      )
      |> Enum.map(fn
        {:ok, {:ok, item_type}} -> {:ok, item_type}
        {:ok, error} -> error
        {:exit, reason} -> {:error, {:timeout, reason}}
      end)

    # Separate successful and failed results
    {successes, failures} =
      Enum.split_with(results, fn
        {:ok, _} -> true
        _ -> false
      end)

    successful_types = Enum.map(successes, fn {:ok, item_type} -> item_type end)

    if Enum.empty?(failures) do
      Logger.info("Successfully resolved #{length(successful_types)} item types")
      {:ok, successful_types}
    else
      Logger.error("Failed to resolve some item types: #{inspect(failures)}")
      # Return partial success
      {:ok, successful_types}
    end
  end
end

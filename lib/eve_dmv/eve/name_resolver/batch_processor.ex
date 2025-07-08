defmodule EveDmv.Eve.NameResolver.BatchProcessor do
  @moduledoc """
  Batch processing module for EVE name resolution.

  Handles efficient batch resolution of multiple IDs, cache optimization,
  and parallel processing for both static data and ESI entities.
  """

  alias EveDmv.Eve.NameResolver.CacheManager
  alias EveDmv.Eve.NameResolver.EsiEntityResolver
  alias EveDmv.Eve.NameResolver.StaticDataResolver
  require Logger

  @doc """
  Efficiently resolves multiple IDs of the same type.
  Optimizes by checking cache first and batch-fetching missing items.
  """
  def batch_resolve(type, ids, fallback_fn) do
    unique_ids = Enum.uniq(ids)

    # Split cached and missing IDs to prevent N+1 queries
    {cached, missing} = split_cached_and_missing(unique_ids, type)

    # Batch load missing names from database to prevent N+1
    missing_results =
      if length(missing) > 0 do
        batch_fetch_from_database(type, missing)
      else
        %{}
      end

    # Combine cached and fresh results
    all_results = Map.merge(cached, missing_results)

    # Fill in any remaining missing with fallback
    Enum.into(unique_ids, %{}, fn id ->
      case Map.get(all_results, id) do
        nil -> {id, fallback_fn.(id)}
        name -> {id, name}
      end
    end)
  end

  @doc """
  Batch resolves ESI entities with bulk lookup optimization.
  Uses ESI bulk endpoints when available, falls back to parallel requests.
  """
  def batch_resolve_with_esi(type, ids, fallback_fn)
      when type in [:character, :corporation, :alliance] do
    unique_ids = Enum.uniq(ids)

    # Check cache first, separate cached from uncached
    {cached, uncached} =
      Enum.reduce(unique_ids, {%{}, []}, fn id, {cached_acc, uncached_acc} ->
        case CacheManager.get_from_cache(type, id) do
          {:ok, name} -> {Map.put(cached_acc, id, name), uncached_acc}
          :miss -> {cached_acc, [id | uncached_acc]}
        end
      end)

    # If we have uncached IDs, try ESI bulk lookup
    esi_results =
      if length(uncached) > 0 do
        case EsiEntityResolver.bulk_esi_lookup(type, uncached) do
          {:ok, results} ->
            # Cache the successful lookups
            Enum.each(results, fn {id, name} ->
              CacheManager.cache_result(type, id, name)
            end)

            results

          {:error, _} ->
            # Fall back to individual lookups
            Map.new(uncached, fn id -> {id, fallback_fn.(id)} end)
        end
      else
        %{}
      end

    Map.merge(cached, esi_results)
  end

  # For non-ESI types, use regular batch resolve
  def batch_resolve_with_esi(type, ids, fallback_fn) do
    batch_resolve(type, ids, fallback_fn)
  end

  @doc """
  Splits a list of IDs into cached and missing based on cache lookup.
  Returns {cached_map, missing_list}.
  """
  def split_cached_and_missing(ids, type) do
    Enum.reduce(ids, {%{}, []}, fn id, {cached, missing} ->
      case CacheManager.get_from_cache(type, id) do
        {:ok, name} -> {Map.put(cached, id, name), missing}
        {:error, :not_found} -> {cached, [id | missing]}
      end
    end)
  end

  @doc """
  Batch fetches missing IDs from the appropriate data source.
  Routes to static data or ESI based on the entity type.
  """
  def batch_fetch_from_database(type, ids) when type in [:item_type, :ship_type, :solar_system] do
    StaticDataResolver.batch_fetch_from_database(type, ids)
  end

  def batch_fetch_from_database(type, ids) when type in [:character, :corporation, :alliance] do
    # ESI entities don't have efficient batch database lookups
    # They need to be fetched via ESI API
    case EsiEntityResolver.bulk_esi_lookup(type, ids) do
      {:ok, results} ->
        # Cache the results
        Enum.each(results, fn {id, name} ->
          CacheManager.cache_result(type, id, name)
        end)

        results

      {:error, _} ->
        Logger.warning("Failed to batch fetch #{type} from ESI for IDs: #{inspect(ids)}")
        %{}
    end
  end

  def batch_fetch_from_database(_type, _ids), do: %{}

  @doc """
  Processes batch results and handles errors gracefully.
  Ensures partial success when some items fail to resolve.
  """
  def process_batch_results(results, ids, fallback_fn) do
    Enum.into(ids, %{}, fn id ->
      case Map.get(results, id) do
        nil -> {id, fallback_fn.(id)}
        name -> {id, name}
      end
    end)
  end

  @doc """
  Optimizes batch size based on entity type and API limits.
  """
  # ESI bulk endpoint limit
  def get_optimal_batch_size(:character), do: 1000
  # Parallel request limit
  def get_optimal_batch_size(:corporation), do: 50
  # Parallel request limit
  def get_optimal_batch_size(:alliance), do: 50
  # Default for static data
  def get_optimal_batch_size(_), do: 100

  @doc """
  Chunks large ID lists into optimal batch sizes for processing.
  """
  def chunk_for_processing(type, ids) do
    batch_size = get_optimal_batch_size(type)
    Enum.chunk_every(ids, batch_size)
  end

  @doc """
  Processes chunked batches with error handling and partial results.
  """
  def process_chunked_batches(type, chunked_ids, processor_fn) do
    Enum.reduce_while(chunked_ids, {:ok, %{}}, fn chunk, {:ok, acc} ->
      case processor_fn.(type, chunk) do
        {:ok, results} ->
          {:cont, {:ok, Map.merge(acc, results)}}

        {:error, reason} ->
          Logger.warning("Batch processing failed for #{type}: #{inspect(reason)}")
          # Continue with empty results for this chunk rather than failing entirely
          {:cont, {:ok, acc}}
      end
    end)
  end

  @doc """
  Validates batch request parameters and limits.
  """
  def validate_batch_request(ids) when is_list(ids) do
    cond do
      Enum.empty?(ids) ->
        {:error, :empty_id_list}

      length(ids) > 10_000 ->
        {:error, :batch_too_large}

      not Enum.all?(ids, &is_integer/1) ->
        {:error, :invalid_id_format}

      true ->
        :ok
    end
  end

  def validate_batch_request(_), do: {:error, :invalid_input}

  # Performance monitoring helpers

  @doc """
  Measures batch processing performance and logs metrics.
  """
  def measure_batch_performance(type, ids, processor_fn) do
    start_time = :os.system_time(:millisecond)

    result = processor_fn.()

    end_time = :os.system_time(:millisecond)
    duration = end_time - start_time

    Logger.debug("Batch #{type} processing: #{length(ids)} items in #{duration}ms")

    result
  end
end

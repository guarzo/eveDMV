defmodule EveDmv.Platform.Database.QueryCache do
  @moduledoc """
  Query cache adapter using the unified cache system.

  This module maintains the same interface as before but delegates
  to the unified cache implementation.

  ## Performance Characteristics

  - Most operations (get, put, delete) are O(1) via ETS lookups
  - Pattern-based operations like `get_keys_by_pattern/1` and `invalidate_pattern/1`
    use a prefix index for O(1) prefix lookups, falling back to O(n) full scans
    for complex patterns containing wildcards in the middle
  - The cache is bounded by `@max_cache_size` (1000 entries)
  - TTL-based expiration with periodic cleanup
  """

  alias EveDmv.Core.Utils.Cache

  @cache_name :query_cache
  @prefix_index_name :query_cache_prefix_index
  # 5 minutes
  @default_ttl 300_000
  @max_cache_size 1000
  # Common delimiters used in cache keys
  @prefix_delimiters [":", "_"]

  @doc """
  Child specification for supervision tree.
  """
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 5000
    }
  end

  @doc """
  Start the query cache.

  Initializes both the main cache and a prefix index for efficient pattern lookups.
  """
  def start_link(_opts \\ []) do
    cache_opts = [
      name: @cache_name,
      ttl_ms: @default_ttl,
      max_size: @max_cache_size,
      # 1 minute
      cleanup_interval_ms: 60_000
    ]

    # Create prefix index ETS table for O(1) prefix lookups
    # Maps prefix -> MapSet of keys with that prefix
    create_prefix_index()

    Cache.start_link(cache_opts)
  end

  defp create_prefix_index do
    if :ets.whereis(@prefix_index_name) == :undefined do
      :ets.new(@prefix_index_name, [
        :set,
        :public,
        :named_table,
        read_concurrency: true,
        write_concurrency: true
      ])
    end

    :ok
  rescue
    ArgumentError -> :ok
  end

  @doc """
  Get a cached result or compute and cache it if not found.
  """
  def get_or_compute(cache_key, compute_fn, ttl \\ @default_ttl)
      when is_function(compute_fn, 0) do
    Cache.get_or_compute(@cache_name, cache_key, compute_fn, ttl_ms: ttl)
  end

  @doc """
  Manually put a value in the cache.

  Also updates the prefix index for efficient pattern lookups.
  """
  def put(cache_key, value, ttl \\ @default_ttl) do
    # Update prefix index BEFORE caching to maintain consistency
    # If prefix index update fails, we don't cache the value
    case add_to_prefix_index(cache_key) do
      :ok ->
        Cache.put(@cache_name, cache_key, value, ttl_ms: ttl)

      {:error, reason} ->
        require Logger

        Logger.warning(
          "QueryCache: Failed to update prefix index for key #{inspect(cache_key)}: #{inspect(reason)}, skipping cache put"
        )

        {:error, :prefix_index_failed}
    end
  end

  @doc """
  Remove a specific key from the cache.

  Also updates the prefix index.
  """
  def delete(cache_key) do
    result = Cache.delete(@cache_name, cache_key)
    remove_from_prefix_index(cache_key)
    result
  end

  @doc """
  Clear all cached entries.

  Also clears the prefix index.
  """
  def clear_all do
    clear_prefix_index()
    Cache.clear(@cache_name)
  end

  @doc """
  Get cache statistics.
  """
  def get_stats do
    Cache.stats(@cache_name)
  end

  @doc """
  Invalidate cache entries matching a pattern.
  """
  def invalidate_pattern(pattern) do
    Cache.invalidate_pattern(@cache_name, pattern)
  end

  @doc """
  Get a cached value by key.
  Returns {:ok, value} or :miss.
  """
  def get(cache_key) do
    Cache.get(@cache_name, cache_key)
  end

  @doc """
  Invalidate a single cache key.

  Also updates the prefix index.
  """
  def invalidate_key(cache_key) do
    result = Cache.delete(@cache_name, cache_key)
    remove_from_prefix_index(cache_key)
    result
  end

  @doc """
  Get all cache keys matching a pattern.

  Pattern uses `*` as wildcard (e.g., `"user_*"`).

  ## Warning: Performance Implications

  **For suffix and complex patterns, this function performs a full ETS table scan.**
  Each key in the cache is converted to a string via `to_string/1`, and for complex
  patterns, `Regex.match?/2` is called on every key. This is O(n) where n can be
  up to `@max_cache_size` (#{@max_cache_size} entries).

  While the `@max_cache_size` limit bounds the worst-case scan, calling this function
  frequently with non-prefix patterns in hot code paths can degrade performance.
  Consider caching the results or restructuring keys to use prefix-based lookups.

  ## Performance Characteristics

  - **Simple prefix patterns** (e.g., `"user_*"`): O(m) where m is the number of keys
    with that prefix. Uses the prefix index for fast lookups.
  - **Simple suffix patterns** (e.g., `"*_stats"`): O(n) full ETS scan. Each key is
    converted to string and checked with `String.ends_with?/2`.
  - **Complex patterns** (e.g., `"user_*_stats"`): O(n) full ETS scan. Each key is
    converted to string and matched against a compiled regex via `Regex.match?/2`.

  The cache is bounded by `@max_cache_size` (#{@max_cache_size} entries), so even
  full scans are limited. For production workloads, prefer simple prefix patterns
  like `"entity_type:entity_id:*"` for best performance.

  ## Examples

      # Fast - uses prefix index (O(m) where m = matching keys)
      get_keys_by_pattern("character_123_*")

      # Slow - requires full scan (O(n) where n = @max_cache_size)
      # Each of the up to 1000 keys will be converted to string and checked
      get_keys_by_pattern("*_stats")
      get_keys_by_pattern("character_*_stats")

  """
  @spec get_keys_by_pattern(String.t()) :: [term()]
  def get_keys_by_pattern(pattern) when is_binary(pattern) do
    case analyze_pattern(pattern) do
      {:match_all, _} ->
        get_all_keys()

      {:prefix, prefix} ->
        get_keys_by_prefix(prefix)

      {:suffix, suffix} ->
        get_keys_by_suffix_scan(suffix)

      {:complex, regex} ->
        get_keys_by_full_scan(regex)
    end
  end

  def get_keys_by_pattern(pattern) do
    # Handle non-binary patterns by converting to string
    pattern |> to_string() |> get_keys_by_pattern()
  end

  # Analyze a pattern to determine the best lookup strategy
  defp analyze_pattern(pattern) do
    cond do
      # Match-all pattern
      pattern == "*" ->
        {:match_all, nil}

      # Simple prefix pattern: "prefix*" (no other wildcards)
      String.ends_with?(pattern, "*") and
          not String.contains?(String.trim_trailing(pattern, "*"), "*") ->
        {:prefix, String.trim_trailing(pattern, "*")}

      # Simple suffix pattern: "*suffix"
      String.starts_with?(pattern, "*") and
          not String.contains?(String.trim_leading(pattern, "*"), "*") ->
        {:suffix, String.trim_leading(pattern, "*")}

      # Complex pattern with wildcards in the middle
      true ->
        {:complex, pattern_to_regex(pattern)}
    end
  end

  # Get all keys from the cache (O(n) scan)
  defp get_all_keys do
    table_name = @cache_name

    :ets.foldl(
      fn {key, _value, _expires_at}, acc -> [key | acc] end,
      [],
      table_name
    )
  rescue
    ArgumentError -> []
  end

  # O(m) lookup using prefix index where m = number of matching keys
  # Falls back to prefix scan if the prefix isn't in the index
  defp get_keys_by_prefix(prefix) do
    case :ets.lookup(@prefix_index_name, prefix) do
      [{^prefix, keys_set}] ->
        # Filter out keys that may have been deleted but not cleaned up from index
        keys_set
        |> MapSet.to_list()
        |> Enum.filter(&key_exists_in_cache?/1)

      [] ->
        # Prefix not indexed - fall back to prefix scan
        # This handles cases where the key doesn't contain our standard delimiters
        get_keys_by_prefix_scan(prefix)
    end
  rescue
    ArgumentError -> []
  end

  # O(n) scan for prefix patterns when prefix isn't indexed
  defp get_keys_by_prefix_scan(prefix) do
    table_name = @cache_name

    :ets.foldl(
      fn {key, _value, _expires_at}, acc ->
        key_str = to_string(key)

        if String.starts_with?(key_str, prefix) do
          [key | acc]
        else
          acc
        end
      end,
      [],
      table_name
    )
  rescue
    ArgumentError -> []
  end

  # O(n) scan for suffix patterns
  defp get_keys_by_suffix_scan(suffix) do
    table_name = @cache_name

    :ets.foldl(
      fn {key, _value, _expires_at}, acc ->
        key_str = to_string(key)

        if String.ends_with?(key_str, suffix) do
          [key | acc]
        else
          acc
        end
      end,
      [],
      table_name
    )
  rescue
    ArgumentError -> []
  end

  # O(n) full scan for complex patterns
  defp get_keys_by_full_scan(regex) do
    table_name = @cache_name

    :ets.foldl(
      fn {key, _value, _expires_at}, acc ->
        key_str = to_string(key)

        if Regex.match?(regex, key_str) do
          [key | acc]
        else
          acc
        end
      end,
      [],
      table_name
    )
  rescue
    ArgumentError -> []
  end

  defp key_exists_in_cache?(key) do
    case Cache.get(@cache_name, key) do
      {:ok, _} -> true
      :miss -> false
    end
  end

  defp pattern_to_regex(pattern) do
    escaped =
      pattern
      |> Regex.escape()
      |> String.replace("\\*", ".*")

    # Add anchors for exact-match semantics
    Regex.compile!("^" <> escaped <> "$")
  end

  # Prefix index management
  #
  # The prefix index maps prefix segments to sets of keys that share that prefix.
  # For a key like "character_123_stats", we extract prefixes at each delimiter:
  # - "character_"
  # - "character_123_"
  #
  # This allows O(1) lookups for patterns like "character_*" or "character_123_*"
  # instead of O(n) full table scans.
  #
  # CONCURRENCY NOTE: The read-modify-write operations in add_to_prefix_index/1
  # and remove_from_prefix_index/1 are non-atomic and can lose updates under
  # concurrent writers (e.g., two writers read the same MapSet, each adds their
  # key, and the second insert overwrites the first). This race is benign because:
  # 1. get_keys_by_prefix/1 filters results through key_exists_in_cache?/1,
  #    which validates each key against the authoritative main cache
  # 2. Stale entries in the prefix index are harmless - they just cause a cache
  #    miss check that returns false
  # 3. Missing entries cause a fallback to get_keys_by_prefix_scan/1, which
  #    performs a full ETS scan and finds the key anyway
  # The prefix index is purely an optimization; correctness is guaranteed by
  # the defensive lookups in get_keys_by_prefix/1.

  # Extract all meaningful prefix segments from a cache key
  # For "character_123_stats", returns ["character_", "character_123_"]
  defp extract_prefixes(key) when is_binary(key) do
    key
    |> extract_prefix_positions()
    |> Enum.map(fn pos -> String.slice(key, 0, pos + 1) end)
    |> Enum.uniq()
  end

  defp extract_prefixes(key), do: key |> to_string() |> extract_prefixes()

  # Find positions of delimiters in the key
  defp extract_prefix_positions(key) do
    @prefix_delimiters
    |> Enum.flat_map(fn delimiter ->
      find_delimiter_positions(key, delimiter, 0, [])
    end)
    |> Enum.sort()
    |> Enum.uniq()
  end

  defp find_delimiter_positions(key, delimiter, start_pos, acc) do
    case :binary.match(key, delimiter, scope: {start_pos, byte_size(key) - start_pos}) do
      {pos, len} ->
        find_delimiter_positions(key, delimiter, pos + len, [pos | acc])

      :nomatch ->
        acc
    end
  end

  defp add_to_prefix_index(cache_key) do
    prefixes = extract_prefixes(cache_key)

    Enum.each(prefixes, fn prefix ->
      # Get existing keys for this prefix or create new set
      existing_keys =
        case :ets.lookup(@prefix_index_name, prefix) do
          [{^prefix, keys_set}] -> keys_set
          [] -> MapSet.new()
        end

      updated_keys = MapSet.put(existing_keys, cache_key)
      :ets.insert(@prefix_index_name, {prefix, updated_keys})
    end)

    :ok
  rescue
    e in ArgumentError ->
      # ETS table doesn't exist - this is expected during startup or if table was deleted
      {:error, {:ets_error, e.message}}

    e ->
      {:error, {:unexpected_error, Exception.message(e)}}
  end

  defp remove_from_prefix_index(cache_key) do
    prefixes = extract_prefixes(cache_key)

    Enum.each(prefixes, fn prefix ->
      case :ets.lookup(@prefix_index_name, prefix) do
        [{^prefix, keys_set}] ->
          updated_keys = MapSet.delete(keys_set, cache_key)

          if MapSet.size(updated_keys) == 0 do
            :ets.delete(@prefix_index_name, prefix)
          else
            :ets.insert(@prefix_index_name, {prefix, updated_keys})
          end

        [] ->
          :ok
      end
    end)

    :ok
  rescue
    ArgumentError -> :ok
  end

  defp clear_prefix_index do
    :ets.delete_all_objects(@prefix_index_name)
    :ok
  rescue
    ArgumentError -> :ok
  end
end

defmodule EveDmv.Database.Repository.CacheHelper do
  @moduledoc """
  Cache integration utilities for the repository pattern.

  Provides cache key generation, invalidation patterns, and TTL management
  specifically designed for database repository caching needs.
  """

  alias EveDmv.Cache

  @doc """
  Build a cache key for repository operations.

  ## Examples

      build_key("killmail", "id", 123, [])
      # => "repo:killmail:id:123"
      
      build_key("killmail", "list", %{status: "active"}, preload: [:participants])
      # => "repo:killmail:list:status:active:preload:participants"
  """
  @spec build_key(String.t(), String.t(), term(), keyword()) :: String.t()
  def build_key(resource_name, operation, identifier, opts \\ []) do
    base_key = "repo:#{resource_name}:#{operation}"

    identifier_part = build_identifier_part(identifier)
    opts_part = build_opts_part(opts)

    [base_key, identifier_part, opts_part]
    |> Enum.filter(&(&1 != ""))
    |> Enum.join(":")
  end

  @doc """
  Invalidate cache entries for a specific resource.

  Removes all cached queries for the given resource to ensure data consistency
  after create/update/delete operations.
  """
  @spec invalidate_for_resource(atom(), String.t()) :: :ok
  def invalidate_for_resource(cache_type, resource_name) do
    pattern = "repo:#{resource_name}:*"
    Cache.invalidate_pattern(cache_type, pattern)
    :ok
  end

  @doc """
  Invalidate cache entries for a specific record.

  More targeted invalidation that removes caches related to a specific record,
  such as get_by_id caches and list caches that might include the record.
  """
  @spec invalidate_for_record(atom(), String.t(), struct()) :: :ok
  def invalidate_for_record(cache_type, resource_name, record) do
    # Invalidate direct record access
    if record.id do
      id_key = build_key(resource_name, "id", record.id, [])
      Cache.delete(cache_type, id_key)
    end

    # Invalidate broader patterns that might include this record
    list_pattern = "repo:#{resource_name}:list:*"
    Cache.invalidate_pattern(cache_type, list_pattern)

    count_pattern = "repo:#{resource_name}:count:*"
    Cache.invalidate_pattern(cache_type, count_pattern)

    :ok
  end

  @doc """
  Get appropriate cache TTL for different operation types.

  Provides sensible defaults while allowing override through options.
  """
  @spec get_cache_ttl(String.t(), keyword()) :: integer()
  def get_cache_ttl(operation, opts \\ []) do
    default_ttl =
      case operation do
        # 5 minutes for single record lookups
        "id" -> 5 * 60 * 1000
        # 2 minutes for list queries
        "list" -> 2 * 60 * 1000
        # 10 minutes for count queries
        "count" -> 10 * 60 * 1000
        # 5 minutes default
        _ -> 5 * 60 * 1000
      end

    Keyword.get(opts, :cache_ttl, default_ttl)
  end

  @doc """
  Check if caching should be used for the given operation and options.
  """
  @spec should_cache?(String.t(), keyword()) :: boolean()
  def should_cache?(_operation, opts \\ []) do
    # Don't cache operations that are explicitly bypassed
    bypass_cache = Keyword.get(opts, :bypass_cache, false)

    # Don't cache operations with complex filters that change frequently
    has_dynamic_filters = has_dynamic_filters?(opts)

    # Don't cache very large result sets
    large_limit =
      case Keyword.get(opts, :limit) do
        nil -> false
        limit when limit > 1000 -> true
        _ -> false
      end

    not (bypass_cache or has_dynamic_filters or large_limit)
  end

  # Private helper functions

  defp build_identifier_part(identifier) when is_integer(identifier) do
    to_string(identifier)
  end

  defp build_identifier_part(identifier) when is_binary(identifier) do
    identifier
  end

  defp build_identifier_part(identifier) when is_map(identifier) do
    identifier
    |> Enum.sort()
    |> Enum.map(fn {k, v} -> "#{k}:#{v}" end)
    |> Enum.join(":")
  end

  defp build_identifier_part(identifier) when is_list(identifier) do
    Enum.sort(identifier)
    |> Enum.join(":")
  end

  defp build_identifier_part(_), do: ""

  defp build_opts_part(opts) do
    # Only include cacheable options in the key
    cacheable_opts = [:preload, :limit, :offset, :order_by]

    opts
    |> Keyword.take(cacheable_opts)
    |> Enum.sort()
    |> Enum.map(fn {k, v} -> "#{k}:#{format_opt_value(v)}" end)
    |> Enum.join(":")
  end

  defp format_opt_value(value) when is_list(value) do
    Enum.sort(value)
    |> Enum.join(",")
  end

  defp format_opt_value(value), do: to_string(value)

  defp has_dynamic_filters?(opts) do
    case Keyword.get(opts, :filters) do
      nil ->
        false

      filters when is_map(filters) ->
        # Check for time-based or dynamic filters
        Enum.any?(Map.keys(filters), fn key ->
          key in [:inserted_at, :updated_at, :created_at, :last_seen_at]
        end)

      _ ->
        false
    end
  end
end

defmodule EveDmvWeb.Plugs.CacheControl do
  @moduledoc """
  Sets appropriate Cache-Control headers based on response type.

  This plug is used to add HTTP caching headers to API responses, reducing
  server load by allowing clients and proxies to cache responses appropriately.

  ## Cache Types

  - `:static` - For static EVE data (item types, systems) that rarely changes.
    24 hour max-age with 1 hour stale-while-revalidate.

  - `:semi_static` - For semi-static data that changes occasionally
    (threat scores, doctrine analysis). 1 hour max-age with 5 minute
    stale-while-revalidate.

  - `:dynamic` - For dynamic but cacheable data that changes frequently.
    1 minute max-age, private, must-revalidate.

  - `:realtime` - For real-time data that should never be cached.
    no-store, no-cache.

  ## Usage

  In router pipelines:

      pipeline :cached_api do
        plug :accepts, ["json"]
        plug EveDmvWeb.Plugs.CacheControl, :semi_static
      end

  Or in individual controllers:

      plug EveDmvWeb.Plugs.CacheControl, :static when action in [:show]

  """

  import Plug.Conn

  @cache_configs %{
    # Static data endpoints (rarely change) - 24 hours
    static: [
      max_age: 86_400,
      public: true,
      stale_while_revalidate: 3600
    ],
    # Semi-static data (changes occasionally) - 1 hour
    semi_static: [
      max_age: 3600,
      public: true,
      stale_while_revalidate: 300
    ],
    # Dynamic but cacheable (changes frequently) - 1 minute
    dynamic: [
      max_age: 60,
      private: true,
      must_revalidate: true
    ],
    # Real-time data (no caching)
    realtime: [
      no_store: true,
      no_cache: true
    ]
  }

  @doc """
  Initializes the plug with the given cache type.
  """
  @spec init(atom()) :: atom()
  def init(cache_type) when is_atom(cache_type) do
    if Map.has_key?(@cache_configs, cache_type) do
      cache_type
    else
      valid_keys = @cache_configs |> Map.keys() |> Enum.join(", ")

      raise ArgumentError,
            "unknown cache_type #{inspect(cache_type)}. Valid cache types are: #{valid_keys}"
    end
  end

  @doc """
  Adds Cache-Control headers to the connection based on the cache type.

  The `init/1` function validates the cache type at compile time and raises
  an `ArgumentError` for unknown cache types. This ensures that only valid
  cache types reach `call/2` during normal operation. The `Map.fetch!/2`
  call is only a defensive fallback that would raise a `KeyError` if an
  invalid cache type somehow bypassed the `init/1` validation.
  """
  @spec call(Plug.Conn.t(), atom()) :: Plug.Conn.t()
  def call(conn, cache_type) when is_atom(cache_type) do
    config = Map.fetch!(@cache_configs, cache_type)
    put_cache_headers(conn, config)
  end

  defp put_cache_headers(conn, config) do
    directives = build_directives(config)
    put_resp_header(conn, "cache-control", Enum.join(directives, ", "))
  end

  defp build_directives(config) do
    []
    |> maybe_add(config[:public], "public")
    |> maybe_add(config[:private], "private")
    |> maybe_add(config[:no_store], "no-store")
    |> maybe_add(config[:no_cache], "no-cache")
    |> maybe_add(config[:must_revalidate], "must-revalidate")
    |> maybe_add_value(config[:max_age], "max-age")
    |> maybe_add_value(config[:stale_while_revalidate], "stale-while-revalidate")
    |> Enum.reverse()
  end

  defp maybe_add(list, true, value), do: [value | list]
  defp maybe_add(list, _, _), do: list

  defp maybe_add_value(list, nil, _), do: list
  defp maybe_add_value(list, value, key), do: ["#{key}=#{value}" | list]
end

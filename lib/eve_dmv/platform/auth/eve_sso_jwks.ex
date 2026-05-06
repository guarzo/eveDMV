defmodule EveDmv.Auth.EveSsoJwks do
  @moduledoc """
  Fetches and caches the EVE SSO JSON Web Key Set used to verify v2
  access tokens.

  CCP retired the legacy `https://esi.evetech.net/verify/` endpoint, so
  character identification now comes from validating the JWT access token
  against the public keys published at `https://login.eveonline.com/oauth/jwks`.

  Keys are cached in `:persistent_term` for one hour. Callers can pass
  `refresh?: true` to bypass the cache (used after a `kid` lookup miss so
  key rotations recover automatically).
  """

  alias Assent.HTTPAdapter.HTTPResponse

  require Logger

  @jwks_url "https://login.eveonline.com/oauth/jwks"
  @cache_key {__MODULE__, :jwks_cache}
  @cache_ttl_ms :timer.hours(1)

  @doc """
  Returns the current JWKS key list, fetching and caching it if needed.
  """
  @spec get_keys(keyword()) :: {:ok, [map()]} | {:error, term()}
  def get_keys(opts \\ []) do
    refresh? = Keyword.get(opts, :refresh?, false)

    case :persistent_term.get(@cache_key, :miss) do
      {expires_at, keys} when not refresh? ->
        if System.monotonic_time(:millisecond) < expires_at do
          {:ok, keys}
        else
          fetch_and_cache()
        end

      _ ->
        fetch_and_cache()
    end
  end

  defp fetch_and_cache do
    case Assent.Strategy.http_request(:get, @jwks_url, nil, [], []) do
      {:ok, %HTTPResponse{status: 200, body: %{"keys" => keys}}} when is_list(keys) ->
        expires_at = System.monotonic_time(:millisecond) + @cache_ttl_ms
        :persistent_term.put(@cache_key, {expires_at, keys})
        {:ok, keys}

      {:ok, %HTTPResponse{status: status, body: body}} ->
        Logger.error("EVE SSO JWKS fetch returned #{status}: #{inspect(body)}")
        {:error, "Unexpected JWKS response (status #{status})"}

      {:error, reason} ->
        Logger.error("EVE SSO JWKS fetch failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc false
  # Test-only: drop the cached value so the next fetch hits the network.
  def reset_cache, do: :persistent_term.erase(@cache_key)
end

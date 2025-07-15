defmodule EveDmv.Utils.DnsResolver do
  @moduledoc """
  DNS resolution utilities with fallback mechanisms.

  Handles DNS resolution issues by providing alternative URLs
  and checking connectivity before making requests.
  """

  require Logger

  @doc """
  Resolve a hostname with fallbacks.

  ## Examples

      iex> DnsResolver.resolve_hostname("host.docker.internal")
      {:ok, "127.0.0.1"}
      
      iex> DnsResolver.resolve_hostname("invalid.domain")
      {:error, :nxdomain}
  """
  def resolve_hostname(hostname) do
    case :inet.gethostbyname(String.to_charlist(hostname)) do
      {:ok, {:hostent, _name, _aliases, :inet, _length, [address | _]}} ->
        ip_string = address |> :inet.ntoa() |> to_string()
        {:ok, ip_string}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Get the best available URL for a service with fallbacks.

  ## Examples

      iex> DnsResolver.get_service_url(:wanderer)
      "http://127.0.0.1:4004"
      
      iex> DnsResolver.get_service_url(:esi)
      "https://esi.evetech.net"
  """
  def get_service_url(service) do
    case service do
      :wanderer -> get_wanderer_url()
      :esi -> get_esi_url()
      :zkillboard -> get_zkillboard_url()
      _ -> {:error, :unknown_service}
    end
  end

  @doc """
  Test connectivity to a URL.
  """
  def test_connectivity(url, timeout \\ 5000) do
    case HTTPoison.head(url, [], timeout: timeout, recv_timeout: timeout) do
      {:ok, %HTTPoison.Response{}} ->
        {:ok, :reachable}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Get working URL with automatic fallback testing.
  """
  def get_working_url(urls) when is_list(urls) do
    get_working_url_impl(urls, [])
  end

  defp get_working_url_impl([], tested_urls) do
    Logger.error("No working URLs found. Tested: #{inspect(tested_urls)}")
    {:error, :no_working_urls}
  end

  defp get_working_url_impl([url | rest], tested_urls) do
    Logger.debug("Testing connectivity to: #{url}")

    case test_connectivity(url, 3000) do
      {:ok, :reachable} ->
        Logger.info("Found working URL: #{url}")
        {:ok, url}

      {:error, reason} ->
        Logger.debug("URL #{url} failed: #{inspect(reason)}")
        get_working_url_impl(rest, [url | tested_urls])
    end
  end

  # Private helpers for specific services

  defp get_wanderer_url do
    base_url =
      Application.get_env(:eve_dmv, :wanderer_base_url, "http://host.docker.internal:4004")

    # Try multiple fallback options
    fallback_urls =
      [
        base_url,
        # Replace docker hostname with localhost
        String.replace(base_url, "host.docker.internal", "localhost"),
        # Try 127.0.0.1
        String.replace(base_url, "host.docker.internal", "127.0.0.1"),
        # Try environment-specific fallback
        System.get_env("WANDERER_FALLBACK_URL", "http://localhost:4004")
      ]
      |> Enum.uniq()

    case get_working_url(fallback_urls) do
      {:ok, working_url} ->
        working_url

      {:error, _} ->
        Logger.warning("No working Wanderer URL found, using default")
        base_url
    end
  end

  defp get_esi_url do
    # ESI should always work, but provide fallback just in case
    base_url = Application.get_env(:eve_dmv, :esi_base_url, "https://esi.evetech.net")

    # Test primary URL
    case test_connectivity(base_url) do
      {:ok, :reachable} ->
        base_url

      {:error, reason} ->
        Logger.warning("ESI primary URL failed: #{inspect(reason)}")
        # ESI doesn't have good fallbacks, so return original URL
        base_url
    end
  end

  defp get_zkillboard_url do
    "https://zkillboard.com"
  end

  @doc """
  Update application environment with working URLs.
  """
  def update_environment_urls do
    # Update Wanderer URL
    case get_service_url(:wanderer) do
      working_url when is_binary(working_url) ->
        Application.put_env(:eve_dmv, :wanderer_base_url, working_url)

        # Also update SSE URL
        sse_url = working_url <> "/api/v1/kills/stream"
        Application.put_env(:eve_dmv, :wanderer_kills_sse_url, sse_url)

        # Update WebSocket URL  
        ws_url = String.replace(working_url, "http://", "ws://") <> "/socket"
        Application.put_env(:eve_dmv, :wanderer_kills_ws_url, ws_url)

        Logger.info("Updated Wanderer URLs: base=#{working_url}, sse=#{sse_url}, ws=#{ws_url}")

      error ->
        Logger.error("Failed to resolve Wanderer URL: #{inspect(error)}")
    end

    :ok
  end

  @doc """
  Initialize DNS resolution at application startup.
  """
  def initialize do
    Logger.info("Initializing DNS resolution...")

    # Test core services
    services = [:esi, :wanderer]

    for service <- services do
      case get_service_url(service) do
        url when is_binary(url) ->
          Logger.info("Service #{service} resolved to: #{url}")

        error ->
          Logger.warning("Service #{service} resolution failed: #{inspect(error)}")
      end
    end

    # Update environment with working URLs
    update_environment_urls()

    :ok
  end
end

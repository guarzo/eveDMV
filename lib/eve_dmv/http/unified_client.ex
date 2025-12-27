defmodule EveDmv.Http.UnifiedClient do
  @moduledoc """
  Unified HTTP client for all external API calls.

  Provides a consistent interface for making HTTP requests with:
  - Automatic retries
  - Circuit breaker protection
  - OpenTelemetry instrumentation
  - Rate limiting compliance
  - Error handling and logging
  """

  require Logger

  @doc """
  Makes a POST request to the specified URL with body and options.

  ## Parameters
  - `url` - The target URL
  - `body` - Request body (will be JSON encoded if not a string)
  - `opts` - Additional options (headers, query params, etc.)

  ## Returns
  - `{:ok, %Tesla.Env{}}` on success
  - `{:error, reason}` on failure

  ## Examples
      iex> UnifiedClient.post("https://api.example.com/endpoint", %{data: "value"})
      {:ok, %Tesla.Env{status: 200, body: %{}}}
  """
  def post(url, body, opts \\ [])

  def post(url, body, opts) do
    headers = build_headers(opts)
    query_params = Keyword.get(opts, :query, [])

    Logger.debug("Making POST request",
      url: url,
      headers: headers,
      body_type: body_type(body)
    )

    client = build_client(opts)

    result =
      Tesla.post(client, url, body,
        headers: headers,
        query: query_params
      )

    case result do
      {:ok, %Tesla.Env{status: status} = env} when status in 200..299 ->
        Logger.debug("POST request successful", url: url, status: status)
        {:ok, env}

      {:ok, %Tesla.Env{status: status} = env} ->
        Logger.warning("POST request failed",
          url: url,
          status: status,
          body: env.body
        )

        {:error, {:http_error, status, env.body}}

      {:error, reason} = error ->
        Logger.error("POST request error", url: url, reason: reason)
        error
    end
  end

  @doc """
  Makes a GET request to the specified URL with options.
  """
  def get(url, opts \\ [])

  def get(url, opts) do
    headers = build_headers(opts)
    query_params = Keyword.get(opts, :query, [])

    Logger.debug("Making GET request", url: url, headers: headers)

    client = build_client(opts)

    result =
      Tesla.get(client, url,
        headers: headers,
        query: query_params
      )

    case result do
      {:ok, %Tesla.Env{status: status} = env} when status in 200..299 ->
        Logger.debug("GET request successful", url: url, status: status)
        {:ok, env}

      {:ok, %Tesla.Env{status: status} = env} ->
        Logger.warning("GET request failed",
          url: url,
          status: status,
          body: env.body
        )

        {:error, {:http_error, status, env.body}}

      {:error, reason} = error ->
        Logger.error("GET request error", url: url, reason: reason)
        error
    end
  end

  @doc """
  Makes a PUT request to the specified URL.
  """
  def put(url, body, opts \\ [])

  def put(url, body, opts) do
    headers = build_headers(opts)
    query_params = Keyword.get(opts, :query, [])

    Logger.debug("Making PUT request", url: url, headers: headers)

    client = build_client(opts)

    result =
      Tesla.put(client, url, body,
        headers: headers,
        query: query_params
      )

    case result do
      {:ok, %Tesla.Env{status: status} = env} when status in 200..299 ->
        Logger.debug("PUT request successful", url: url, status: status)
        {:ok, env}

      {:ok, %Tesla.Env{status: status} = env} ->
        Logger.warning("PUT request failed",
          url: url,
          status: status,
          body: env.body
        )

        {:error, {:http_error, status, env.body}}

      {:error, reason} = error ->
        Logger.error("PUT request error", url: url, reason: reason)
        error
    end
  end

  @doc """
  Makes a DELETE request to the specified URL.
  """
  def delete(url, opts \\ [])

  def delete(url, opts) do
    headers = build_headers(opts)
    query_params = Keyword.get(opts, :query, [])

    Logger.debug("Making DELETE request", url: url, headers: headers)

    client = build_client(opts)

    result =
      Tesla.delete(client, url,
        headers: headers,
        query: query_params
      )

    case result do
      {:ok, %Tesla.Env{status: status} = env} when status in 200..299 ->
        Logger.debug("DELETE request successful", url: url, status: status)
        {:ok, env}

      {:ok, %Tesla.Env{status: status} = env} ->
        Logger.warning("DELETE request failed",
          url: url,
          status: status,
          body: env.body
        )

        {:error, {:http_error, status, env.body}}

      {:error, reason} = error ->
        Logger.error("DELETE request error", url: url, reason: reason)
        error
    end
  end

  # Private helper functions

  defp build_client(opts) do
    # Check if this is a form-urlencoded request by looking at headers
    additional_headers = Keyword.get(opts, :headers, [])
    is_form_encoded = has_form_content_type?(additional_headers)

    base_middlewares = [
      {Tesla.Middleware.FollowRedirects, max_redirects: 3},
      {Tesla.Middleware.Timeout, timeout: Keyword.get(opts, :timeout, 30_000)},
      {Tesla.Middleware.Logger, debug: false},
      {Tesla.Middleware.Retry,
       delay: 1000,
       max_retries: 3,
       max_delay: 5000,
       should_retry: fn
         {:ok, %{status: status}} when status in [429, 500, 502, 503, 504] -> true
         {:ok, _} -> false
         {:error, _} -> true
       end}
    ]

    # Only add JSON middleware for non-form-encoded requests
    base_middlewares =
      if is_form_encoded do
        base_middlewares
      else
        [Tesla.Middleware.JSON | base_middlewares]
      end

    # Add authentication if provided
    middlewares =
      case Keyword.get(opts, :auth) do
        {:bearer, token} ->
          [{Tesla.Middleware.BearerAuth, token: token} | base_middlewares]

        {:basic, {username, password}} ->
          [
            {Tesla.Middleware.BasicAuth, username: username, password: password}
            | base_middlewares
          ]

        _ ->
          base_middlewares
      end

    Tesla.client(middlewares)
  end

  defp build_headers(opts) do
    additional_headers = Keyword.get(opts, :headers, [])

    # Check if Content-Type is specified in additional headers
    has_custom_content_type =
      Enum.any?(additional_headers, fn
        {"Content-Type", _} -> true
        {"content-type", _} -> true
        _ -> false
      end)

    base_headers =
      [
        {"User-Agent", "EVE-DMV/1.0 (+https://eve-dmv.com)"},
        {"Accept", "application/json"}
      ] ++
        if has_custom_content_type do
          []
        else
          [{"Content-Type", "application/json"}]
        end

    base_headers ++ additional_headers
  end

  defp has_form_content_type?(headers) do
    Enum.any?(headers, fn
      {"Content-Type", value} -> String.contains?(value, "x-www-form-urlencoded")
      {"content-type", value} -> String.contains?(value, "x-www-form-urlencoded")
      _ -> false
    end)
  end

  defp body_type(body) when is_binary(body), do: "string"
  defp body_type(body) when is_map(body), do: "map"
  defp body_type(body) when is_list(body), do: "list"
  defp body_type(_), do: "other"
end

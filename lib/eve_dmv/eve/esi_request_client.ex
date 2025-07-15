# credo:disable-for-this-file Credo.Check.Refactor.ModuleDependencies
defmodule EveDmv.Eve.EsiRequestClient do
  @moduledoc """
  Enhanced HTTP request utilities for EVE ESI API with reliability features.

  This module handles all low-level HTTP communication with ESI,
  including circuit breakers, intelligent retries, rate limiting,
  error classification, and fallback strategies.
  """

  alias EveDmv.Eve.CircuitBreaker
  alias EveDmv.Eve.ErrorClassifier
  alias EveDmv.Eve.FallbackStrategy
  alias EveDmv.Eve.ReliabilityConfig
  alias EveDmv.Telemetry.PerformanceMonitor
  alias EveDmv.Telemetry.RequestMonitor
  require Logger

  @default_base_url "https://esi.evetech.net"
  @default_datasource "tranquility"
  @service_name :esi_api

  @doc """
  Make an authenticated GET request to ESI API with reliability features.
  """
  @spec get_authenticated_request(String.t(), String.t(), map(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def get_authenticated_request(path, auth_token, params \\ %{}, opts \\ []) do
    operation_type = Keyword.get(opts, :operation_type, :default)
    cache_key = Keyword.get(opts, :cache_key)

    request_fn = fn ->
      PerformanceMonitor.track_api_call("esi", path, fn ->
        execute_authenticated_request(path, auth_token, params, operation_type)
      end)
    end

    # Use circuit breaker if enabled
    if ReliabilityConfig.circuit_breaker_enabled?(@service_name) do
      case CircuitBreaker.call(@service_name, request_fn,
             timeout: ReliabilityConfig.get_timeout(operation_type)
           ) do
        {:ok, result} ->
          {:ok, result}

        {:error, :circuit_open} ->
          Logger.warning("Circuit breaker open for ESI API", %{path: path})
          try_fallback_request(path, cache_key, opts)

        {:error, error} ->
          classification = ErrorClassifier.classify(error)
          handle_request_error(error, classification, path, cache_key, opts)
      end
    else
      case request_fn.() do
        {:ok, result} ->
          {:ok, result}

        {:error, error} ->
          classification = ErrorClassifier.classify(error)
          handle_request_error(error, classification, path, cache_key, opts)
      end
    end
  end

  @doc """
  Make a public request to ESI API with reliability features.
  """
  @spec public_request(String.t(), String.t(), map()) :: {:ok, map()} | {:error, term()}
  def public_request(_method, path, params \\ %{}) do
    result = get_request(path, params, [])

    if String.contains?(path, "/markets/") do
      Logger.debug(
        "EsiRequestClient.public_request for #{path} returning: #{inspect(elem(result, 0))}, type: #{inspect(elem(result, 0))}"
      )

      case result do
        {:ok, response} ->
          Logger.debug(
            "Response is map: #{inspect(is_map(response))}, keys: #{inspect(if is_map(response), do: Map.keys(response), else: "N/A")}"
          )

        {:error, _} ->
          Logger.debug("Result is error")

        other ->
          Logger.debug("Unexpected result type: #{inspect(other)}")
      end
    end

    result
  end

  @doc """
  Make an authenticated request to ESI API with reliability features.
  """
  @spec authenticated_request(String.t(), String.t(), String.t()) ::
          {:ok, map()} | {:error, term()}
  def authenticated_request(_method, path, auth_token) do
    get_authenticated_request(path, auth_token, %{}, [])
  end

  @doc """
  Make a public GET request to ESI API with reliability features.
  """
  @spec get_request(String.t(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def get_request(path, params \\ %{}, opts \\ []) do
    operation_type = Keyword.get(opts, :operation_type, :default)
    cache_key = Keyword.get(opts, :cache_key)

    request_fn = fn ->
      PerformanceMonitor.track_api_call("esi", path, fn ->
        execute_public_request(path, params, operation_type)
      end)
    end

    # Use circuit breaker if enabled
    if ReliabilityConfig.circuit_breaker_enabled?(@service_name) do
      case CircuitBreaker.call(@service_name, request_fn,
             timeout: ReliabilityConfig.get_timeout(operation_type)
           ) do
        {:ok, result} ->
          {:ok, result}

        {:error, :circuit_open} ->
          Logger.warning("Circuit breaker open for ESI API", %{path: path})
          try_fallback_request(path, cache_key, opts)

        {:error, error} ->
          classification = ErrorClassifier.classify(error)
          handle_request_error(error, classification, path, cache_key, opts)
      end
    else
      case request_fn.() do
        {:ok, result} ->
          {:ok, result}

        {:error, error} ->
          classification = ErrorClassifier.classify(error)
          handle_request_error(error, classification, path, cache_key, opts)
      end
    end
  end

  # Private implementation functions

  defp execute_authenticated_request(path, auth_token, params, operation_type) do
    headers = build_authenticated_headers(auth_token)
    params = Map.put(params, "datasource", @default_datasource)
    timeout = ReliabilityConfig.get_timeout(operation_type)

    execute_http_request(path, headers, params, timeout)
  end

  defp execute_public_request(path, params, operation_type) do
    headers = build_headers()
    params = Map.put(params, "datasource", @default_datasource)
    timeout = ReliabilityConfig.get_timeout(operation_type)

    execute_http_request(path, headers, params, timeout)
  end

  defp execute_http_request(path, headers, params, timeout) do
    start_time = System.monotonic_time(:microsecond)
    service = detect_service_from_path(path)

    result =
      case HTTPoison.get(build_url(path), headers,
             timeout: timeout,
             recv_timeout: timeout,
             params: params
           ) do
        {:ok, %HTTPoison.Response{status_code: status_code, body: body, headers: resp_headers}}
        when status_code in 200..299 ->
          case Jason.decode(body) do
            {:ok, data} ->
              {:ok, %{body: data, status_code: status_code, headers: Map.new(resp_headers)}}

            {:error, reason} ->
              {:error, {:json_error, reason}}
          end

        {:ok, %HTTPoison.Response{status_code: status_code}} ->
          {:error, {:http_error, status_code}}

        {:error, %HTTPoison.Error{reason: reason}} ->
          {:error, {:connection_error, reason}}
      end

    # Track request metrics
    duration = System.monotonic_time(:microsecond) - start_time

    status =
      case result do
        {:ok, _} -> :success
        {:error, {:http_error, code}} when code in [420, 429] -> :rate_limited
        {:error, {:connection_error, :timeout}} -> :timeout
        _ -> :failure
      end

    RequestMonitor.track_request(service, duration, status)

    result
  end

  defp handle_request_error(error, classification, path, cache_key, opts) do
    Logger.warning("ESI request failed", %{
      path: path,
      error: error,
      classification: classification
    })

    # Emit telemetry for monitoring
    :telemetry.execute(
      [:eve_dmv, :esi, :request_failed],
      %{count: 1},
      %{path: path, error_category: classification.category}
    )

    # Try retry if appropriate
    if should_retry?(classification, opts) do
      attempt_retry(path, cache_key, opts, error)
    else
      try_fallback_request(path, cache_key, opts)
    end
  end

  defp should_retry?(classification, opts) do
    attempt = Keyword.get(opts, :attempt, 1)
    max_attempts = ReliabilityConfig.get_retry_config().max_attempts

    attempt < max_attempts and classification.retry_strategy != :not_retryable
  end

  defp attempt_retry(path, _cache_key, opts, error) do
    attempt = Keyword.get(opts, :attempt, 1)
    retry_config = ReliabilityConfig.get_retry_config()
    delay = ReliabilityConfig.calculate_retry_delay(attempt + 1, retry_config)

    Logger.info("Retrying ESI request after #{delay}ms", %{
      path: path,
      attempt: attempt + 1,
      error: sanitize_error_for_logging(error)
    })

    :timer.sleep(delay)

    # Retry with incremented attempt count
    new_opts = Keyword.put(opts, :attempt, attempt + 1)

    case Keyword.get(opts, :auth_token) do
      nil ->
        get_request(path, Keyword.get(opts, :params, %{}), new_opts)

      auth_token ->
        get_authenticated_request(path, auth_token, Keyword.get(opts, :params, %{}), new_opts)
    end
  end

  defp try_fallback_request(path, cache_key, opts) do
    fallback_config = ReliabilityConfig.get_fallback_config()

    if cache_key and fallback_config.use_stale_cache do
      execute_stale_cache_fallback(path, cache_key, opts)
    else
      try_placeholder_fallback(path, opts)
    end
  end

  defp execute_stale_cache_fallback(path, cache_key, opts) do
    cache_key_str = if is_binary(cache_key), do: cache_key, else: to_string(cache_key)

    case FallbackStrategy.execute_with_stale_cache(
           fn -> execute_esi_request(path, opts) end,
           cache_key_str
         ) do
      {:ok, data} ->
        Logger.info("Using stale cache data for ESI request", %{path: path})
        {:ok, data}

      _ ->
        try_placeholder_fallback(path, opts)
    end
  end

  defp execute_esi_request(path, opts) do
    case Keyword.get(opts, :auth_token) do
      nil ->
        get_request(path, Keyword.get(opts, :params, %{}), opts)

      auth_token ->
        get_authenticated_request(
          path,
          auth_token,
          Keyword.get(opts, :params, %{}),
          opts
        )
    end
  end

  defp try_placeholder_fallback(path, opts) do
    fallback_config = ReliabilityConfig.get_fallback_config()

    if fallback_config.use_placeholder_data do
      data_type = detect_data_type(path)
      context = Keyword.get(opts, :fallback_context)

      case FallbackStrategy.generate_placeholder_data(data_type, context) do
        {:ok, placeholder, :placeholder} ->
          Logger.warning("Using placeholder data for ESI request", %{
            path: path,
            data_type: data_type
          })

          {:ok, placeholder}

        {:error, :no_placeholder} ->
          {:error, :service_unavailable}
      end
    else
      {:error, :service_unavailable}
    end
  end

  defp detect_data_type(path) do
    cond do
      String.contains?(path, "/characters/") -> :character
      String.contains?(path, "/corporations/") -> :corporation
      String.contains?(path, "/alliances/") -> :alliance
      String.contains?(path, "/killmails/") -> :killmail
      String.contains?(path, "/universe/") -> :universe
      true -> :unknown
    end
  end

  defp detect_service_from_path(path) do
    # Same as detect_data_type but also includes market and search
    cond do
      String.contains?(path, "/characters/") -> :character
      String.contains?(path, "/corporations/") -> :corporation
      String.contains?(path, "/alliances/") -> :alliance
      String.contains?(path, "/killmails/") -> :killmail
      String.contains?(path, "/universe/") -> :universe
      String.contains?(path, "/markets/") -> :market
      String.contains?(path, "/search/") -> :search
      true -> :unknown
    end
  end

  # Helper functions

  defp build_url(path) do
    base_url = get_config(:base_url, @default_base_url)
    "#{base_url}#{path}"
  end

  defp build_headers do
    [
      {"User-Agent", "EVE-DMV/1.0 (https://github.com/wanderer-industries/eve_dmv)"},
      {"Accept", "application/json"},
      {"Content-Type", "application/json"}
    ]
  end

  defp build_authenticated_headers(auth_token) do
    [{"Authorization", "Bearer #{auth_token}"} | build_headers()]
  end

  defp get_config(key, default) do
    :eve_dmv
    |> Application.get_env(:esi, [])
    |> Keyword.get(key, default)
  end

  # Remove auth_token from error data before logging
  defp sanitize_error_for_logging(error) do
    case error do
      %{auth_token: _} = error_map ->
        Map.delete(error_map, :auth_token)

      tuple when is_tuple(tuple) ->
        # Handle tuples that might contain sensitive data
        tuple |> Tuple.to_list() |> sanitize_list_for_logging() |> List.to_tuple()

      list when is_list(list) ->
        sanitize_list_for_logging(list)

      _ ->
        error
    end
  end

  defp sanitize_list_for_logging(list) do
    Enum.map(list, fn item ->
      case item do
        %{auth_token: _} = map -> Map.delete(map, :auth_token)
        other -> other
      end
    end)
  end
end

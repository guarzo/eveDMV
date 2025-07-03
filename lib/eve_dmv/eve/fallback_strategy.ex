defmodule EveDmv.Eve.FallbackStrategy do
  @moduledoc """
  Implements graceful degradation strategies for ESI API failures.

  Provides multiple fallback mechanisms:
  - Stale cache data
  - Placeholder/default data
  - Partial data with warnings
  - Service degradation modes
  """

  require Logger
  alias EveDmv.Eve.{ErrorClassifier, EsiCache, ReliabilityConfig}

  @type fallback_result ::
          {:ok, any()}
          | {:ok, any(), :stale}
          | {:ok, any(), :partial}
          | {:ok, any(), :placeholder}
          | {:error, any()}

  @doc """
  Execute function with comprehensive fallback strategies.
  """
  @spec execute_with_fallback(function(), keyword()) :: fallback_result()
  def execute_with_fallback(primary_fn, opts \\ []) do
    service = Keyword.get(opts, :service, :default)
    cache_key = Keyword.get(opts, :cache_key)
    fallback_data_fn = Keyword.get(opts, :fallback_data_fn)
    allow_stale = Keyword.get(opts, :allow_stale, true)
    allow_placeholder = Keyword.get(opts, :allow_placeholder, false)

    # Try primary function
    case safe_execute(primary_fn) do
      {:ok, result} ->
        # Cache successful result if cache key provided
        if cache_key, do: cache_result(cache_key, result)
        {:ok, result}

      {:error, error} ->
        # Classify error to determine fallback strategy
        classification = ErrorClassifier.classify(error)

        Logger.warning("Primary function failed, attempting fallback", %{
          service: service,
          error: error,
          classification: classification
        })

        execute_fallback_strategy(error, classification, %{
          service: service,
          cache_key: cache_key,
          fallback_data_fn: fallback_data_fn,
          allow_stale: allow_stale,
          allow_placeholder: allow_placeholder
        })
    end
  end

  @doc """
  Execute function with stale cache fallback only.
  """
  @spec execute_with_stale_cache(function(), String.t(), keyword()) ::
          {:error, any()} | {:ok, any()}
  def execute_with_stale_cache(primary_fn, cache_key, opts \\ []) do
    # 1 hour default
    max_stale_age = Keyword.get(opts, :max_stale_age, 3_600_000)

    case safe_execute(primary_fn) do
      {:ok, result} ->
        cache_result(cache_key, result)
        {:ok, result}

      {:error, error} ->
        case get_stale_cache_data(cache_key, max_stale_age) do
          {:ok, stale_data, :stale} ->
            Logger.info("Using stale cache data due to error", %{
              cache_key: cache_key,
              error: error
            })

            {:ok, stale_data}

          :miss ->
            {:error, error}
        end
    end
  end

  @doc """
  Execute multiple functions in parallel with fallback.
  """
  @spec execute_parallel_with_fallback([{function(), keyword()}], keyword()) ::
          {:ok, [any()]} | {:ok, [any()], :partial} | {:error, any()}
  def execute_parallel_with_fallback(function_specs, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 10_000)
    min_success_ratio = Keyword.get(opts, :min_success_ratio, 0.5)

    tasks =
      Enum.map(function_specs, fn {fn_spec, fn_opts} ->
        Task.async(fn -> execute_with_fallback(fn_spec, fn_opts) end)
      end)

    # Wait for all tasks with timeout
    results = Task.await_many(tasks, timeout)

    # Analyze results
    {successes, failures} =
      Enum.split_with(results, fn
        {:ok, _} -> true
        # Stale/partial data counts as success
        {:ok, _, _} -> true
        _ -> false
      end)

    success_ratio = length(successes) / length(results)

    cond do
      success_ratio >= 1.0 ->
        {:ok, extract_data(results)}

      success_ratio >= min_success_ratio ->
        Logger.warning("Partial success in parallel execution", %{
          successes: length(successes),
          failures: length(failures),
          success_ratio: success_ratio
        })

        {:ok, extract_data(results), :partial}

      true ->
        # Too many failures
        first_error = failures |> List.first() |> elem(1)
        {:error, {:parallel_failure, first_error}}
    end
  end

  @doc """
  Get degraded service mode based on system health.
  """
  @spec get_service_mode(atom()) :: :normal | :degraded
  def get_service_mode(service) do
    # Check circuit breaker state
    case EveDmv.Eve.CircuitBreaker.get_state(service) do
      :open ->
        :degraded

      :half_open ->
        :degraded

      :closed ->
        # Check other health indicators
        check_service_health(service)
    end
  end

  @doc """
  Generate placeholder data when no fallback is available.
  """
  @spec generate_placeholder_data(atom(), any()) ::
          {:ok, any(), :placeholder} | {:error, :no_placeholder}
  def generate_placeholder_data(data_type, context \\ nil)

  def generate_placeholder_data(:character, character_id) when is_integer(character_id) do
    placeholder = %{
      character_id: character_id,
      name: "Unknown Pilot",
      # CCP Corp ID
      corporation_id: 1_000_001,
      alliance_id: nil,
      security_status: 0.0,
      # EVE launch date
      birthday: ~U[2003-05-06 00:00:00Z]
    }

    {:ok, placeholder, :placeholder}
  end

  def generate_placeholder_data(:corporation, corporation_id) when is_integer(corporation_id) do
    placeholder = %{
      corporation_id: corporation_id,
      name: "Unknown Corporation",
      ticker: "????",
      member_count: 0,
      alliance_id: nil,
      ceo_id: nil,
      creator_id: nil,
      date_founded: ~U[2003-05-06 00:00:00Z],
      description: "",
      faction_id: nil,
      home_station_id: nil,
      shares: 1000,
      tax_rate: 0.0,
      url: "",
      war_eligible: false
    }

    {:ok, placeholder, :placeholder}
  end

  def generate_placeholder_data(:alliance, alliance_id) when is_integer(alliance_id) do
    placeholder = %{
      alliance_id: alliance_id,
      name: "Unknown Alliance",
      ticker: "?????",
      creator_corporation_id: nil,
      creator_id: nil,
      date_founded: ~U[2003-05-06 00:00:00Z],
      executor_corporation_id: nil,
      faction_id: nil
    }

    {:ok, placeholder, :placeholder}
  end

  def generate_placeholder_data(:killmail, _context) do
    # No meaningful placeholder for killmails
    {:error, :no_placeholder}
  end

  def generate_placeholder_data(_, _) do
    {:error, :no_placeholder}
  end

  # Private functions

  defp safe_execute(fun) do
    case fun.() do
      {:ok, result} -> {:ok, result}
      {:error, reason} -> {:error, reason}
      # Assume bare values are successful
      result -> {:ok, result}
    end
  rescue
    error -> {:error, {:exception, error}}
  catch
    :exit, reason -> {:error, {:exit, reason}}
    kind, reason -> {:error, {kind, reason}}
  end

  defp execute_fallback_strategy(error, classification, opts) do
    %{
      service: _service,
      cache_key: cache_key,
      fallback_data_fn: fallback_data_fn,
      allow_stale: allow_stale,
      allow_placeholder: _allow_placeholder
    } = opts

    # Try fallback strategies in order of preference
    cond do
      # 1. Try stale cache if available and allowed
      allow_stale and cache_key ->
        case try_stale_cache(cache_key) do
          {:ok, stale_data, :stale} -> {:ok, stale_data, :stale}
          :miss -> try_next_fallback(error, classification, opts)
        end

      # 2. Try custom fallback function
      fallback_data_fn ->
        case safe_execute(fallback_data_fn) do
          {:ok, fallback_data} -> {:ok, fallback_data, :fallback}
          {:error, _} -> try_next_fallback(error, classification, opts)
        end

      # 3. Continue to next strategy
      true ->
        try_next_fallback(error, classification, opts)
    end
  end

  defp try_next_fallback(error, classification, opts) do
    %{service: service, allow_placeholder: allow_placeholder} = opts

    if allow_placeholder and classification.category in [:permanent, :transient] do
      # Try placeholder data for certain error types
      case generate_placeholder_data(service, nil) do
        {:ok, placeholder, :placeholder} -> {:ok, placeholder, :placeholder}
        {:error, :no_placeholder} -> {:error, error}
      end
    else
      # No more fallback options
      {:error, error}
    end
  end

  defp try_stale_cache(cache_key) do
    config = ReliabilityConfig.get_fallback_config()
    max_stale_age = config[:stale_cache_ttl] || 3_600_000

    get_stale_cache_data(cache_key, max_stale_age)
  end

  defp get_stale_cache_data(cache_key, max_stale_age) do
    # Check for expired cache entries that are still within the acceptable stale period
    case get_cache_with_timestamp(cache_key) do
      {:ok, data, timestamp} ->
        age_seconds = DateTime.diff(DateTime.utc_now(), timestamp, :second)

        if age_seconds <= max_stale_age do
          {:ok, data, :stale}
        else
          :miss
        end

      :miss ->
        :miss
    end
  end

  defp get_cache_with_timestamp(cache_key) do
    # Look for cache entry directly in ETS to get timestamp info
    # This accesses the character cache table since EsiCache.get/1 uses it for generic keys
    case :ets.lookup(:esi_character_cache, cache_key) do
      [{^cache_key, data, expires_at}] ->
        {:ok, data, expires_at}

      [] ->
        :miss
    end
  end

  defp cache_result(cache_key, result) do
    # 1 hour TTL
    EsiCache.put(cache_key, result, ttl: 3600)
  rescue
    error ->
      Logger.warning("Failed to cache result", %{
        cache_key: cache_key,
        error: error
      })
  end

  defp extract_data(results) do
    Enum.map(results, fn
      {:ok, data} -> data
      {:ok, data, _type} -> data
      {:error, _} -> nil
    end)
  end

  defp check_service_health(_service) do
    # Could check metrics, error rates, response times, etc.
    # For now, default to normal
    :normal
  end
end

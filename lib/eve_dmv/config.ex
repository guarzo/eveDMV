defmodule EveDmv.Config do
  @moduledoc """
  Unified configuration interface for EVE DMV.

  This module consolidates all configuration access patterns into a single,
  consistent API. It replaces the scattered config modules with a unified
  approach that uses the UnifiedConfig system.

  ## Usage

      # Get basic configuration
      Config.get(:database, :pool_size)
      Config.get([:api, :esi, :timeout_ms])

      # Get cache configuration
      Config.cache_ttl(:character_analysis)
      Config.cache_ttl(:threat_analysis, :timer.hours(8))

      # Get API configuration
      Config.api_config(:janice)
      Config.api_config(:esi)

      # Get pipeline configuration
      Config.pipeline_config()
      Config.pipeline_enabled?()

      # Get rate limiting configuration
      Config.rate_limit(:janice)
      Config.rate_limit(:auth)

  ## Migration from Legacy Modules

  This module replaces:
  - EveDmv.Config.Cache
  - EveDmv.Config.Api
  - EveDmv.Config.Pipeline
  - EveDmv.Config.RateLimit
  - EveDmv.Config.Http
  - EveDmv.Config.CircuitBreaker

  All functions maintain backward compatibility while using the unified
  configuration system internally.
  """

  alias EveDmv.Config.UnifiedConfig

  # Cache TTL mappings to unified config
  @cache_ttl_mappings %{
    character_analysis: [:intelligence, :cache, :character_analysis_ttl_ms],
    vetting_analysis: [:intelligence, :cache, :vetting_analysis_ttl_ms],
    correlation_analysis: [:intelligence, :cache, :correlation_analysis_ttl_ms],
    threat_analysis: [:intelligence, :cache, :threat_analysis_ttl_ms],
    member_activity: [:intelligence, :cache, :member_activity_ttl_ms],
    home_defense: [:intelligence, :cache, :home_defense_ttl_ms],
    general: [:cache, :default_ttl_ms],
    query: [:cache, :default_ttl_ms],
    hot_data: [:cache, :hot_data_ttl_ms],
    api_responses: [:cache, :api_response_ttl_ms],
    analysis: [:cache, :analysis_ttl_ms]
  }

  # API service configurations
  @api_services %{
    janice: [:api, :janice],
    mutamarket: [:api, :mutamarket],
    esi: [:api, :esi],
    wanderer: [:api, :wanderer]
  }

  @doc """
  Get configuration value with optional default.
  Delegates to UnifiedConfig for consistent behavior.
  """
  @spec get(atom() | [atom()], term()) :: term()
  def get(key, default \\ nil) do
    UnifiedConfig.get(key, default)
  end

  @doc """
  Get a configuration value with fallback to default (legacy compatibility).
  """
  @spec get(atom(), atom(), any()) :: any()
  def get(app, key, default) do
    Application.get_env(app, key, default)
  end

  @doc """
  Get environment variable with fallback to configuration.
  """
  @spec env(String.t(), atom() | [atom()], term()) :: term()
  def env(env_var, fallback_key, default \\ nil) do
    UnifiedConfig.env(env_var, fallback_key, default)
  end

  # Cache Configuration

  @doc """
  Get cache TTL for a specific cache type.
  """
  @spec cache_ttl(atom(), integer()) :: integer()
  def cache_ttl(cache_type, default \\ nil) do
    case Map.get(@cache_ttl_mappings, cache_type) do
      nil -> default || UnifiedConfig.get([:cache, :default_ttl_ms])
      key_path -> UnifiedConfig.get(key_path, default)
    end
  end

  @doc """
  Get cache max size configuration.
  """
  @spec cache_max_size(atom()) :: integer()
  def cache_max_size(cache_type) do
    case cache_type do
      :general -> UnifiedConfig.get([:cache, :max_memory_mb], 512) * 1024 * 1024
      :intelligence -> UnifiedConfig.get([:legacy, :cache_intelligence_max_size], 10_000)
      :analysis -> UnifiedConfig.get([:legacy, :cache_analysis_max_size], 50_000)
      :hot_data -> UnifiedConfig.get([:legacy, :cache_hot_data_max_size], 50_000)
      :api_responses -> UnifiedConfig.get([:legacy, :cache_api_responses_max_size], 25_000)
      _ -> UnifiedConfig.get([:cache, :max_memory_mb], 512) * 1024 * 1024
    end
  end

  @doc """
  Get cache cleanup interval.
  """
  @spec cache_cleanup_interval(atom()) :: integer()
  def cache_cleanup_interval(cache_type \\ :general) do
    case cache_type do
      :general ->
        UnifiedConfig.get([:cache, :cleanup_interval_ms])

      :intelligence ->
        minutes = UnifiedConfig.get([:legacy, :cache_intelligence_cleanup_interval_minutes], 30)
        :timer.minutes(minutes)

      :analysis ->
        minutes = UnifiedConfig.get([:legacy, :cache_analysis_cleanup_interval_minutes], 5)
        :timer.minutes(minutes)

      _ ->
        UnifiedConfig.get([:cache, :cleanup_interval_ms])
    end
  end

  @doc """
  Check if cache warm-up on startup is enabled.
  """
  @spec cache_warm_on_startup?() :: boolean()
  def cache_warm_on_startup? do
    UnifiedConfig.get([:legacy, :cache_warm_on_startup], true)
  end

  # API Configuration

  @doc """
  Get complete API configuration for a service.
  """
  @spec api_config(atom()) :: keyword()
  def api_config(service) do
    case Map.get(@api_services, service) do
      nil ->
        []

      base_path ->
        base_config = UnifiedConfig.get_category(:api)
        service_config = get_in(base_config, tl(base_path)) || %{}

        # Add computed values
        enhanced_config =
          Map.merge(service_config, %{
            timeout: api_timeout(service),
            rate_limit: rate_limit(service)
          })

        # Convert to keyword list for backward compatibility
        Enum.into(enhanced_config, [])
    end
  end

  @doc """
  Get API base URL for a service.
  """
  @spec api_base_url(atom()) :: String.t()
  def api_base_url(service) do
    case service do
      :janice -> UnifiedConfig.env("JANICE_BASE_URL", [:api, :janice, :base_url])
      :mutamarket -> UnifiedConfig.env("MUTAMARKET_BASE_URL", [:api, :mutamarket, :base_url])
      :esi -> UnifiedConfig.get([:api, :esi, :base_url])
      :wanderer -> UnifiedConfig.env("WANDERER_KILLS_BASE_URL", [:api, :wanderer, :base_url])
      _ -> nil
    end
  end

  @doc """
  Get API timeout for a service.
  """
  @spec api_timeout(atom()) :: integer()
  def api_timeout(service) do
    case service do
      :janice -> UnifiedConfig.get([:api, :janice, :timeout_ms], 15_000)
      :mutamarket -> UnifiedConfig.get([:api, :mutamarket, :timeout_ms], 10_000)
      :esi -> UnifiedConfig.get([:api, :esi, :timeout_ms], 30_000)
      :wanderer -> UnifiedConfig.get([:api, :wanderer, :timeout_ms], 30_000)
      _ -> UnifiedConfig.get([:api, :default_timeout_ms], 15_000)
    end
  end

  # Pipeline Configuration

  @doc """
  Get complete pipeline configuration.
  """
  @spec pipeline_config() :: keyword()
  def pipeline_config do
    [
      enabled: pipeline_enabled?(),
      concurrency: pipeline_concurrency(),
      batch_size: pipeline_batch_size(),
      batch_timeout: pipeline_batch_timeout(),
      task_timeout: pipeline_task_timeout()
    ]
  end

  @doc """
  Check if pipeline is enabled.
  """
  @spec pipeline_enabled?() :: boolean()
  def pipeline_enabled? do
    UnifiedConfig.feature_enabled?(:pipeline_enabled)
  end

  @doc """
  Get pipeline concurrency setting.
  """
  @spec pipeline_concurrency() :: integer()
  def pipeline_concurrency do
    UnifiedConfig.get([:pipeline, :concurrency], 4)
  end

  @doc """
  Get pipeline batch size.
  """
  @spec pipeline_batch_size() :: integer()
  def pipeline_batch_size do
    UnifiedConfig.get([:pipeline, :batch_size], 10)
  end

  @doc """
  Get pipeline batch timeout.
  """
  @spec pipeline_batch_timeout() :: integer()
  def pipeline_batch_timeout do
    UnifiedConfig.get([:pipeline, :batch_timeout_ms], 5_000)
  end

  @doc """
  Get pipeline task timeout.
  """
  @spec pipeline_task_timeout() :: integer()
  def pipeline_task_timeout do
    UnifiedConfig.get([:intelligence, :analysis, :timeout_ms], 30_000)
  end

  @doc """
  Get Broadway producer configuration.
  """
  @spec broadway_producer_config() :: keyword()
  def broadway_producer_config do
    [
      concurrency: pipeline_concurrency(),
      max_demand: pipeline_batch_size()
    ]
  end

  @doc """
  Get Broadway processor configuration.
  """
  @spec broadway_processor_config() :: keyword()
  def broadway_processor_config do
    [
      concurrency: pipeline_concurrency(),
      max_demand: pipeline_batch_size(),
      timeout: pipeline_task_timeout()
    ]
  end

  @doc """
  Get Broadway batcher configuration.
  """
  @spec broadway_batcher_config() :: keyword()
  def broadway_batcher_config do
    [
      concurrency: pipeline_concurrency(),
      batch_size: pipeline_batch_size(),
      batch_timeout: pipeline_batch_timeout()
    ]
  end

  # Rate Limiting Configuration

  @doc """
  Get rate limiting configuration for a service or feature.
  """
  @spec rate_limit(atom()) :: keyword()
  def rate_limit(service) do
    case service do
      :janice ->
        [
          max_tokens: UnifiedConfig.get([:api, :janice, :rate_limit, :max_tokens], 5),
          refill_rate: UnifiedConfig.get([:api, :janice, :rate_limit, :refill_rate], 5)
        ]

      :auth ->
        [
          max_attempts: UnifiedConfig.get([:security, :rate_limit, :max_attempts], 5),
          window_ms: UnifiedConfig.get([:security, :rate_limit, :window_ms], 60_000),
          block_duration_ms:
            UnifiedConfig.get([:security, :rate_limit, :block_duration_ms], 1_800_000)
        ]

      _ ->
        [
          max_tokens: UnifiedConfig.get([:security, :rate_limit, :max_requests], 100),
          refill_rate: UnifiedConfig.get([:security, :rate_limit, :refill_rate], 10)
        ]
    end
  end

  # HTTP Configuration

  @doc """
  Get HTTP client configuration.
  """
  @spec http_config() :: keyword()
  def http_config do
    [
      timeout: UnifiedConfig.get([:api, :default_timeout_ms], 15_000),
      retry_attempts: UnifiedConfig.get([:http, :retry_attempts], 3),
      retry_delay: UnifiedConfig.get([:http, :retry_delay_ms], 1_000),
      pool_size: UnifiedConfig.get([:http, :pool_size], 25),
      pool_timeout: UnifiedConfig.get([:http, :pool_timeout_ms], 5_000)
    ]
  end

  # Circuit Breaker Configuration

  @doc """
  Get circuit breaker configuration.
  """
  @spec circuit_breaker_config() :: keyword()
  def circuit_breaker_config do
    [
      failure_threshold: UnifiedConfig.get([:circuit_breaker, :failure_threshold], 5),
      recovery_timeout: UnifiedConfig.get([:circuit_breaker, :recovery_timeout_ms], 30_000),
      timeout: UnifiedConfig.get([:circuit_breaker, :timeout_ms], 10_000)
    ]
  end

  # Feature Flags

  @doc """
  Check if a feature is enabled.
  """
  @spec feature_enabled?(atom()) :: boolean()
  def feature_enabled?(feature_name) do
    UnifiedConfig.feature_enabled?(feature_name)
  end

  # Configuration Validation

  @doc """
  Validate configuration and return any issues.
  """
  @spec validate() :: {:ok, :valid} | {:error, [String.t()]}
  def validate do
    UnifiedConfig.validate_config()
  end

  @doc """
  Get configuration summary for debugging.
  """
  @spec summary() :: map()
  def summary do
    UnifiedConfig.config_summary()
  end

  # Legacy Functions (for backward compatibility)

  @doc """
  Get a nested configuration value (legacy compatibility).
  """
  @spec get_nested_config([atom()], any()) :: any()
  def get_nested_config(keys, default \\ nil) do
    case keys do
      [app | rest] ->
        app
        |> Application.get_env(List.first(rest), %{})
        |> get_nested(Enum.drop(rest, 1), default)

      [] ->
        default
    end
  end

  defp get_nested(config, [], _default) when is_map(config), do: config
  defp get_nested(config, [key], default) when is_map(config), do: Map.get(config, key, default)

  defp get_nested(config, [key | rest], default) when is_map(config) do
    case Map.get(config, key) do
      nil -> default
      nested -> get_nested(nested, rest, default)
    end
  end

  defp get_nested(_config, _keys, default), do: default
end

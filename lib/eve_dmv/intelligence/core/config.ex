defmodule EveDmv.Intelligence.Core.Config do
  @moduledoc """
  Centralized configuration for intelligence analyzers.

  Provides consistent configuration patterns, environment-specific settings,
  and shared constants used across the intelligence system.
  """

  @doc """
  Get cache TTL for different analysis types.
  """
  @spec get_cache_ttl(atom()) :: pos_integer()
  def get_cache_ttl(analysis_type) do
    default_ttls = %{
      # 1 hour - character data changes frequently
      character: 3600,
      # 2 hours - corp data is more stable
      corporation: 7200,
      # 4 hours - alliance data changes rarely
      alliance: 14400,
      # 30 minutes - threat analysis needs frequent updates
      threat: 1800,
      # 1 hour - activity patterns change regularly
      member_activity: 3600,
      # 30 minutes - fleet analysis is time-sensitive
      wh_fleet: 1800,
      # 2 hours - vetting results are relatively stable
      vetting: 7200,
      # 15 minutes - market data changes frequently
      market: 900,
      # 1 hour - statistical calculations
      statistics: 3600
    }

    # Allow environment-specific overrides
    env_override = get_env_cache_ttl(analysis_type)
    env_override || Map.get(default_ttls, analysis_type, 3600)
  end

  @doc """
  Get timeout configuration for different operation types.
  """
  @spec get_timeout(atom()) :: pos_integer()
  def get_timeout(operation_type) do
    default_timeouts = %{
      # 10 seconds for database queries
      query: 10_000,
      # 15 seconds for API calls
      api: 15_000,
      # 30 seconds for complex analysis
      analysis: 30_000,
      # 1 minute for batch operations
      batch: 60_000,
      # 2 minutes for cache warming
      cache_warm: 120_000,
      # 3 minutes for very heavy analysis
      heavy_analysis: 180_000
    }

    env_override = get_env_timeout(operation_type)
    env_override || Map.get(default_timeouts, operation_type, 30_000)
  end

  @doc """
  Get batch size limits for different operations.
  """
  @spec get_batch_limit(atom()) :: pos_integer()
  def get_batch_limit(operation_type) do
    default_limits = %{
      character_analysis: 50,
      corporation_analysis: 25,
      alliance_analysis: 10,
      killmail_processing: 1000,
      cache_warming: 100,
      concurrent_tasks: 10
    }

    env_override = get_env_batch_limit(operation_type)
    env_override || Map.get(default_limits, operation_type, 50)
  end

  @doc """
  Get analysis quality settings.
  """
  @spec get_analysis_quality() :: atom()
  def get_analysis_quality do
    env_quality = System.get_env("INTELLIGENCE_ANALYSIS_QUALITY")

    case env_quality do
      # Reduced analysis depth for speed
      "fast" -> :fast
      # Default analysis depth
      "balanced" -> :balanced
      # Maximum analysis depth
      "comprehensive" -> :comprehensive
      _ -> :balanced
    end
  end

  @doc """
  Get feature flags for experimental features.
  """
  @spec feature_enabled?(atom()) :: boolean()
  def feature_enabled?(feature_name) do
    case feature_name do
      :advanced_threat_detection ->
        get_env_boolean("INTELLIGENCE_ADVANCED_THREAT", false)

      :machine_learning_insights ->
        get_env_boolean("INTELLIGENCE_ML_INSIGHTS", false)

      :real_time_analysis ->
        get_env_boolean("INTELLIGENCE_REALTIME", true)

      :parallel_analysis ->
        get_env_boolean("INTELLIGENCE_PARALLEL", true)

      :cache_warming ->
        get_env_boolean("INTELLIGENCE_CACHE_WARMING", true)

      _ ->
        false
    end
  end

  @doc """
  Get default analysis parameters for different entity types.
  """
  @spec get_default_params(atom()) :: map()
  def get_default_params(entity_type) do
    base_params = %{
      days_back: 90,
      limit: 1000,
      include: [:killmails, :statistics],
      timeout: get_timeout(:analysis)
    }

    case entity_type do
      :character ->
        Map.merge(base_params, %{
          include: [:killmails, :corporations, :alliances, :statistics],
          days_back: 90
        })

      :corporation ->
        Map.merge(base_params, %{
          include: [:killmails, :members, :statistics],
          days_back: 30,
          limit: 2000
        })

      :alliance ->
        Map.merge(base_params, %{
          include: [:killmails, :corporations, :statistics],
          days_back: 30,
          limit: 5000
        })

      _ ->
        base_params
    end
  end

  @doc """
  Get resource limits for analysis operations.
  """
  @spec get_resource_limits() :: map()
  def get_resource_limits do
    %{
      max_memory_mb: get_env_integer("INTELLIGENCE_MAX_MEMORY_MB", 1024),
      max_cpu_percent: get_env_integer("INTELLIGENCE_MAX_CPU_PERCENT", 50),
      max_concurrent_analyses: get_env_integer("INTELLIGENCE_MAX_CONCURRENT", 5),
      max_cache_size_mb: get_env_integer("INTELLIGENCE_MAX_CACHE_MB", 512)
    }
  end

  @doc """
  Get database connection configuration for intelligence operations.
  """
  @spec get_db_config() :: map()
  def get_db_config do
    %{
      pool_size: get_env_integer("INTELLIGENCE_DB_POOL_SIZE", 10),
      timeout: get_env_integer("INTELLIGENCE_DB_TIMEOUT", 15_000),
      queue_target: get_env_integer("INTELLIGENCE_DB_QUEUE_TARGET", 50),
      queue_interval: get_env_integer("INTELLIGENCE_DB_QUEUE_INTERVAL", 1000)
    }
  end

  # Private helper functions

  defp get_env_cache_ttl(analysis_type) do
    env_key = "INTELLIGENCE_CACHE_TTL_#{String.upcase(to_string(analysis_type))}"
    get_env_integer(env_key, nil)
  end

  defp get_env_timeout(operation_type) do
    env_key = "INTELLIGENCE_TIMEOUT_#{String.upcase(to_string(operation_type))}"
    get_env_integer(env_key, nil)
  end

  defp get_env_batch_limit(operation_type) do
    env_key = "INTELLIGENCE_BATCH_LIMIT_#{String.upcase(to_string(operation_type))}"
    get_env_integer(env_key, nil)
  end

  defp get_env_integer(key, default) do
    case System.get_env(key) do
      nil ->
        default

      value ->
        case Integer.parse(value) do
          {parsed, ""} -> parsed
          _ -> default
        end
    end
  end

  defp get_env_boolean(key, default) do
    case System.get_env(key) do
      nil -> default
      "true" -> true
      "false" -> false
      "1" -> true
      "0" -> false
      _ -> default
    end
  end
end

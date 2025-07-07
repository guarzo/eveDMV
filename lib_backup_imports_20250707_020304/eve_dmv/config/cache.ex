defmodule EveDmv.Config.Cache do
  alias EveDmv.Config.UnifiedConfig
  @moduledoc """
  Cache configuration management with environment overrides.

  Centralizes all cache-related configuration including TTL values,
  size limits, and cleanup intervals across the application.

  This module now uses the unified configuration system for consistent
  cache configuration access and environment variable handling.
  """


  @doc """
  Get character analysis cache TTL in milliseconds.

  Environment: EVE_DMV_CACHE_CHARACTER_ANALYSIS_TTL_MS
  """
  @spec character_analysis_ttl() :: pos_integer()
  def character_analysis_ttl do
    UnifiedConfig.get([:intelligence, :cache, :character_analysis_ttl_ms])
  end

  @doc """
  Get vetting analysis cache TTL in milliseconds.

  Environment: EVE_DMV_CACHE_VETTING_ANALYSIS_TTL_MS
  """
  @spec vetting_analysis_ttl() :: pos_integer()
  def vetting_analysis_ttl do
    UnifiedConfig.get([:intelligence, :cache, :vetting_analysis_ttl_ms], :timer.hours(24))
  end

  @doc """
  Get correlation analysis cache TTL in milliseconds.

  Environment: EVE_DMV_CACHE_CORRELATION_ANALYSIS_TTL_MS
  """
  @spec correlation_analysis_ttl() :: pos_integer()
  def correlation_analysis_ttl do
    UnifiedConfig.get([:intelligence, :cache, :correlation_analysis_ttl_ms])
  end

  @doc """
  Get threat analysis cache TTL in milliseconds.

  Environment: EVE_DMV_CACHE_THREAT_ANALYSIS_TTL_MS
  """
  @spec threat_analysis_ttl() :: pos_integer()
  def threat_analysis_ttl do
    UnifiedConfig.get([:intelligence, :cache, :threat_analysis_ttl_ms], :timer.hours(8))
  end

  @doc """
  Get member activity analysis cache TTL in milliseconds.

  Environment: EVE_DMV_CACHE_MEMBER_ACTIVITY_TTL_MS
  """
  @spec member_activity_ttl() :: pos_integer()
  def member_activity_ttl do
    UnifiedConfig.get([:intelligence, :cache, :member_activity_ttl_ms], :timer.hours(6))
  end

  @doc """
  Get home defense analysis cache TTL in milliseconds.

  Environment: EVE_DMV_CACHE_HOME_DEFENSE_TTL_MS
  """
  @spec home_defense_ttl() :: pos_integer()
  def home_defense_ttl do
    UnifiedConfig.get([:intelligence, :cache, :home_defense_ttl_ms], :timer.hours(2))
  end

  @doc """
  Get general cache TTL in milliseconds.

  Environment: EVE_DMV_CACHE_DEFAULT_TTL_MS
  """
  @spec general_ttl() :: pos_integer()
  def general_ttl do
    UnifiedConfig.get([:cache, :default_ttl_ms])
  end

  @doc """
  Get query cache TTL in milliseconds.

  Environment: EVE_DMV_CACHE_DEFAULT_TTL_MS
  """
  @spec query_ttl() :: pos_integer()
  def query_ttl do
    UnifiedConfig.get([:cache, :default_ttl_ms])
  end

  @doc """
  Get default cache max size.

  Environment: EVE_DMV_CACHE_MAX_MEMORY_MB
  """
  @spec max_size() :: pos_integer()
  def max_size do
    UnifiedConfig.get([:cache, :max_memory_mb], 512) * 1024 * 1024
  end

  @doc """
  Get intelligence cache max size.

  Environment: EVE_DMV_CACHE_INTELLIGENCE_MAX_SIZE (default: 10000)
  """
  @spec intelligence_cache_size() :: pos_integer()
  def intelligence_cache_size do
    UnifiedConfig.get([:legacy, :cache_intelligence_max_size], 10_000)
  end

  @doc """
  Get analysis cache max size.

  Environment: EVE_DMV_CACHE_ANALYSIS_MAX_SIZE (default: 50000)
  """
  @spec analysis_cache_size() :: pos_integer()
  def analysis_cache_size do
    UnifiedConfig.get([:legacy, :cache_analysis_max_size], 50_000)
  end

  @doc """
  Get cache cleanup interval in milliseconds.

  Environment: EVE_DMV_CACHE_CLEANUP_INTERVAL_MINUTES (default: 1)
  """
  @spec cleanup_interval() :: pos_integer()
  def cleanup_interval do
    UnifiedConfig.get([:cache, :cleanup_interval_ms])
  end

  @doc """
  Get intelligence cache cleanup interval in milliseconds.

  Environment: EVE_DMV_CACHE_INTELLIGENCE_CLEANUP_INTERVAL_MINUTES (default: 30)
  """
  @spec intelligence_cleanup_interval() :: pos_integer()
  def intelligence_cleanup_interval do
    minutes = UnifiedConfig.get([:legacy, :cache_intelligence_cleanup_interval_minutes], 30)
    :timer.minutes(minutes)
  end

  @doc """
  Get analysis cache cleanup interval in milliseconds.

  Environment: EVE_DMV_CACHE_ANALYSIS_CLEANUP_INTERVAL_MINUTES (default: 5)
  """
  @spec analysis_cleanup_interval() :: pos_integer()
  def analysis_cleanup_interval do
    minutes = UnifiedConfig.get([:legacy, :cache_analysis_cleanup_interval_minutes], 5)
    :timer.minutes(minutes)
  end

  @doc """
  Get cache warm-up on startup setting.

  Environment: EVE_DMV_CACHE_WARM_ON_STARTUP (default: true)
  """
  @spec warm_on_startup?() :: boolean()
  def warm_on_startup? do
    UnifiedConfig.get([:legacy, :cache_warm_on_startup], true)
  end

  # Unified cache type configurations

  @doc """
  Get hot data cache TTL in milliseconds.

  For frequently accessed data like characters, systems, items.
  Environment: EVE_DMV_CACHE_HOT_DATA_TTL_MINUTES (default: 30)
  """
  @spec hot_data_ttl() :: pos_integer()
  def hot_data_ttl do
    minutes = UnifiedConfig.get([:legacy, :cache_hot_data_ttl_minutes], 30)
    :timer.minutes(minutes)
  end

  @doc """
  Get API responses cache TTL in milliseconds.

  For external API responses (ESI, Janice, Mutamarket).
  Environment: EVE_DMV_CACHE_API_RESPONSES_TTL_HOURS (default: 24)
  """
  @spec api_responses_ttl() :: pos_integer()
  def api_responses_ttl do
    hours = UnifiedConfig.get([:legacy, :cache_api_responses_ttl_hours], 24)
    :timer.hours(hours)
  end

  @doc """
  Get analysis cache TTL in milliseconds.

  For intelligence analysis results.
  Environment: EVE_DMV_CACHE_ANALYSIS_TTL_HOURS (default: 12)
  """
  @spec analysis_ttl() :: pos_integer()
  def analysis_ttl do
    hours = UnifiedConfig.get([:legacy, :cache_analysis_ttl_hours], 12)
    :timer.hours(hours)
  end

  @doc """
  Get hot data cache max size.

  Environment: EVE_DMV_CACHE_HOT_DATA_MAX_SIZE (default: 50000)
  """
  @spec hot_data_max_size() :: pos_integer()
  def hot_data_max_size do
    UnifiedConfig.get([:legacy, :cache_hot_data_max_size], 50_000)
  end

  @doc """
  Get API responses cache max size.

  Environment: EVE_DMV_CACHE_API_RESPONSES_MAX_SIZE (default: 25000)
  """
  @spec api_responses_max_size() :: pos_integer()
  def api_responses_max_size do
    UnifiedConfig.get([:legacy, :cache_api_responses_max_size], 25_000)
  end

  @doc """
  Get analysis cache max size.

  Environment: EVE_DMV_CACHE_ANALYSIS_MAX_SIZE (default: 10000)
  """
  @spec analysis_max_size() :: pos_integer()
  def analysis_max_size do
    UnifiedConfig.get([:legacy, :cache_analysis_max_size], 10_000)
  end
end

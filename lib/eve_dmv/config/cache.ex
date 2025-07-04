defmodule EveDmv.Config.Cache do
  @moduledoc """
  Cache configuration management with environment overrides.

  Centralizes all cache-related configuration including TTL values,
  size limits, and cleanup intervals across the application.
  """

  alias EveDmv.Config

  # Default cache size and cleanup settings
  @default_max_size 1000

  # Intelligence cache specific defaults
  @default_intelligence_cache_size 10_000
  @default_analysis_cache_size 50_000

  @doc """
  Get character analysis cache TTL in milliseconds.

  Environment: EVE_DMV_CACHE_CHARACTER_ANALYSIS_TTL_HOURS (default: 12)
  """
  @spec character_analysis_ttl() :: pos_integer()
  def character_analysis_ttl do
    hours = Config.get(:eve_dmv, :cache_character_analysis_ttl_hours, 12)
    :timer.hours(hours)
  end

  @doc """
  Get vetting analysis cache TTL in milliseconds.

  Environment: EVE_DMV_CACHE_VETTING_ANALYSIS_TTL_HOURS (default: 24)
  """
  @spec vetting_analysis_ttl() :: pos_integer()
  def vetting_analysis_ttl do
    hours = Config.get(:eve_dmv, :cache_vetting_analysis_ttl_hours, 24)
    :timer.hours(hours)
  end

  @doc """
  Get correlation analysis cache TTL in milliseconds.

  Environment: EVE_DMV_CACHE_CORRELATION_ANALYSIS_TTL_HOURS (default: 4)
  """
  @spec correlation_analysis_ttl() :: pos_integer()
  def correlation_analysis_ttl do
    hours = Config.get(:eve_dmv, :cache_correlation_analysis_ttl_hours, 4)
    :timer.hours(hours)
  end

  @doc """
  Get threat analysis cache TTL in milliseconds.

  Environment: EVE_DMV_CACHE_THREAT_ANALYSIS_TTL_HOURS (default: 8)
  """
  @spec threat_analysis_ttl() :: pos_integer()
  def threat_analysis_ttl do
    hours = Config.get(:eve_dmv, :cache_threat_analysis_ttl_hours, 8)
    :timer.hours(hours)
  end

  @doc """
  Get member activity analysis cache TTL in milliseconds.

  Environment: EVE_DMV_CACHE_MEMBER_ACTIVITY_TTL_HOURS (default: 6)
  """
  @spec member_activity_ttl() :: pos_integer()
  def member_activity_ttl do
    hours = Config.get(:eve_dmv, :cache_member_activity_ttl_hours, 6)
    :timer.hours(hours)
  end

  @doc """
  Get home defense analysis cache TTL in milliseconds.

  Environment: EVE_DMV_CACHE_HOME_DEFENSE_TTL_HOURS (default: 2)
  """
  @spec home_defense_ttl() :: pos_integer()
  def home_defense_ttl do
    hours = Config.get(:eve_dmv, :cache_home_defense_ttl_hours, 2)
    :timer.hours(hours)
  end

  @doc """
  Get general cache TTL in milliseconds.

  Environment: EVE_DMV_CACHE_GENERAL_TTL_MINUTES (default: 5)
  """
  @spec general_ttl() :: pos_integer()
  def general_ttl do
    minutes = Config.get(:eve_dmv, :cache_general_ttl_minutes, 5)
    :timer.minutes(minutes)
  end

  @doc """
  Get query cache TTL in milliseconds.

  Environment: EVE_DMV_CACHE_QUERY_TTL_MINUTES (default: 5)
  """
  @spec query_ttl() :: pos_integer()
  def query_ttl do
    minutes = Config.get(:eve_dmv, :cache_query_ttl_minutes, 5)
    :timer.minutes(minutes)
  end

  @doc """
  Get default cache max size.

  Environment: EVE_DMV_CACHE_MAX_SIZE (default: 1000)
  """
  @spec max_size() :: pos_integer()
  def max_size do
    Config.get(:eve_dmv, :cache_max_size, @default_max_size)
  end

  @doc """
  Get intelligence cache max size.

  Environment: EVE_DMV_CACHE_INTELLIGENCE_MAX_SIZE (default: 10000)
  """
  @spec intelligence_cache_size() :: pos_integer()
  def intelligence_cache_size do
    Config.get(:eve_dmv, :cache_intelligence_max_size, @default_intelligence_cache_size)
  end

  @doc """
  Get analysis cache max size.

  Environment: EVE_DMV_CACHE_ANALYSIS_MAX_SIZE (default: 50000)
  """
  @spec analysis_cache_size() :: pos_integer()
  def analysis_cache_size do
    Config.get(:eve_dmv, :cache_analysis_max_size, @default_analysis_cache_size)
  end

  @doc """
  Get cache cleanup interval in milliseconds.

  Environment: EVE_DMV_CACHE_CLEANUP_INTERVAL_MINUTES (default: 1)
  """
  @spec cleanup_interval() :: pos_integer()
  def cleanup_interval do
    minutes = Config.get(:eve_dmv, :cache_cleanup_interval_minutes, 1)
    :timer.minutes(minutes)
  end

  @doc """
  Get intelligence cache cleanup interval in milliseconds.

  Environment: EVE_DMV_CACHE_INTELLIGENCE_CLEANUP_INTERVAL_MINUTES (default: 30)
  """
  @spec intelligence_cleanup_interval() :: pos_integer()
  def intelligence_cleanup_interval do
    minutes = Config.get(:eve_dmv, :cache_intelligence_cleanup_interval_minutes, 30)
    :timer.minutes(minutes)
  end

  @doc """
  Get analysis cache cleanup interval in milliseconds.

  Environment: EVE_DMV_CACHE_ANALYSIS_CLEANUP_INTERVAL_MINUTES (default: 5)
  """
  @spec analysis_cleanup_interval() :: pos_integer()
  def analysis_cleanup_interval do
    minutes = Config.get(:eve_dmv, :cache_analysis_cleanup_interval_minutes, 5)
    :timer.minutes(minutes)
  end

  @doc """
  Get cache warm-up on startup setting.

  Environment: EVE_DMV_CACHE_WARM_ON_STARTUP (default: true)
  """
  @spec warm_on_startup?() :: boolean()
  def warm_on_startup? do
    Config.get(:eve_dmv, :cache_warm_on_startup, true)
  end
end

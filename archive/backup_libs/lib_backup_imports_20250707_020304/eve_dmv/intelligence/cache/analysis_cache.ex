defmodule EveDmv.Intelligence.Cache.AnalysisCache do
  alias EveDmv.Cache
  alias EveDmv.Config.Cache, as: CacheConfig

  require Logger
  @moduledoc """
  Unified cache layer for intelligence analysis results.

  This module has been migrated from Cachex to use the unified EveDmv.Cache system
  for better consistency and reduced complexity.
  """



  @doc """
  Get character analysis from cache or compute if missing.
  """
  @spec get_character_analysis(integer()) :: {:ok, any()} | {:error, any()}
  def get_character_analysis(character_id) do
    cache_key = {:character_analysis, character_id}

    case Cache.get_or_compute(
           :analysis,
           cache_key,
           fn ->
             # Use Intelligence Engine for character analysis
             case EveDmv.IntelligenceEngine.analyze(:character, character_id, scope: :standard) do
               {:ok, result} -> result
               {:error, _} = error -> error
             end
           end,
           ttl: CacheConfig.character_analysis_ttl()
         ) do
      {:error, _} = error -> error
      result -> {:ok, result}
    end
  end

  @doc """
  Get vetting analysis from cache or compute if missing.
  """
  @spec get_vetting_analysis(integer()) :: {:ok, any()} | {:error, any()}
  def get_vetting_analysis(character_id) do
    cache_key = {:vetting_analysis, character_id}

    case Cache.get_or_compute(
           :analysis,
           cache_key,
           fn ->
             # Use Intelligence Engine for vetting analysis - return default result since :wh_vetting not available
             {:error, :analysis_type_not_available}
           end,
           ttl: CacheConfig.vetting_analysis_ttl()
         ) do
      {:error, _} = error -> error
      result -> {:ok, result}
    end
  end

  @doc """
  Get correlation analysis from cache or compute if missing.
  """
  @spec get_correlation_analysis(integer()) :: {:ok, any()} | {:error, any()}
  def get_correlation_analysis(character_id) do
    cache_key = {:correlation_analysis, character_id}

    case Cache.get_or_compute(
           :analysis,
           cache_key,
           fn ->
             # Use Intelligence Engine for correlation analysis - return default result since :correlation not available
             {:error, :analysis_type_not_available}
           end,
           ttl: CacheConfig.correlation_analysis_ttl()
         ) do
      {:error, _} = error -> error
      result -> {:ok, result}
    end
  end

  @doc """
  Get member activity analysis from cache or compute if missing.
  """
  @spec get_member_activity_analysis(integer()) :: {:ok, any()} | {:error, any()}
  def get_member_activity_analysis(character_id) do
    cache_key = {:member_activity, character_id}

    case Cache.get_or_compute(
           :analysis,
           cache_key,
           fn ->
             # Member activity analysis - return default result since :member_activity not available
             {:error, :analysis_type_not_available}
           end,
           ttl: CacheConfig.member_activity_ttl()
         ) do
      {:error, _} = error -> error
      result -> {:ok, result}
    end
  end

  @doc """
  Get home defense analysis from cache or compute if missing.
  """
  @spec get_home_defense_analysis(integer()) :: {:ok, any()} | {:error, any()}
  def get_home_defense_analysis(system_id) do
    cache_key = {:home_defense, system_id}

    case Cache.get_or_compute(
           :analysis,
           cache_key,
           fn ->
             # Home defense analysis - return default result since :home_defense not available
             {:error, :analysis_type_not_available}
           end,
           ttl: CacheConfig.home_defense_ttl()
         ) do
      {:error, _} = error -> error
      result -> {:ok, result}
    end
  end

  @doc """
  Invalidate all analysis cache entries for a character.
  """
  @spec invalidate_character_cache(integer()) :: :ok
  def invalidate_character_cache(character_id) do
    patterns = [
      {:character_analysis, character_id},
      {:vetting_analysis, character_id},
      {:correlation_analysis, character_id},
      {:member_activity, character_id}
    ]

    Enum.each(patterns, fn pattern ->
      Cache.delete(:analysis, pattern)
    end)

    :ok
  end

  @doc """
  Invalidate home defense cache for a system.
  """
  @spec invalidate_system_cache(integer()) :: :ok
  def invalidate_system_cache(system_id) do
    Cache.delete(:analysis, {:home_defense, system_id})
    :ok
  end

  @doc """
  Get cache statistics for monitoring.
  """
  @spec get_cache_stats() :: map()
  def get_cache_stats do
    Cache.stats(:analysis)
  end

  @doc """
  Warm the cache with frequently accessed data.
  """
  @spec warm_cache([integer()]) :: :ok
  def warm_cache(character_ids) when is_list(character_ids) do
    Logger.info("Warming analysis cache for #{length(character_ids)} characters")

    Enum.each(character_ids, fn character_id ->
      # Fire and forget cache warming
      Task.start(fn ->
        get_character_analysis(character_id)
      end)
    end)

    :ok
  end

  @doc """
  Clear all analysis cache entries.
  """
  @spec clear_cache() :: :ok
  def clear_cache do
    Cache.clear(:analysis)
    :ok
  end
end

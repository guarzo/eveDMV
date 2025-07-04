defmodule EveDmv.Intelligence.IntelligenceCache do
  @moduledoc """
  Intelligence cache adapter using the unified cache system.

  This module maintains the same interface as before but delegates
  to the unified cache implementation, removing unnecessary complexity
  like cache warming and access tracking.
  """

  require Logger
  alias EveDmv.Config.Cache, as: CacheConfig
  alias EveDmv.Utils.Cache

  @cache_name :intelligence_cache

  @doc """
  Start the intelligence cache.
  """
  def start_link(_opts \\ []) do
    cache_opts = [
      name: @cache_name,
      # Default TTL
      ttl_ms: CacheConfig.character_analysis_ttl(),
      # Cache for up to 10k analyses
      max_size: CacheConfig.intelligence_cache_size(),
      # Cleanup interval
      cleanup_interval_ms: CacheConfig.intelligence_cleanup_interval()
    ]

    Cache.start_link(cache_opts)
  end

  @doc """
  Get character analysis from cache or generate if not cached.
  """
  def get_character_analysis(character_id) do
    cache_key = {:character_analysis, character_id}

    Cache.get_or_compute(
      @cache_name,
      cache_key,
      fn -> generate_character_analysis(character_id) end,
      ttl_ms: CacheConfig.character_analysis_ttl()
    )
  end

  @doc """
  Get vetting analysis from cache or generate if not cached.
  """
  def get_vetting_analysis(character_id) do
    cache_key = {:vetting_analysis, character_id}

    Cache.get_or_compute(
      @cache_name,
      cache_key,
      fn -> generate_vetting_analysis(character_id) end,
      ttl_ms: CacheConfig.vetting_analysis_ttl()
    )
  end

  @doc """
  Get correlation analysis from cache or generate if not cached.
  """
  def get_correlation_analysis(character_id) do
    cache_key = {:correlation_analysis, character_id}

    Cache.get_or_compute(
      @cache_name,
      cache_key,
      fn -> generate_correlation_analysis(character_id) end,
      ttl_ms: CacheConfig.correlation_analysis_ttl()
    )
  end

  @doc """
  Invalidate cache for a specific character.

  Useful when new data is available that would change analysis results.
  """
  def invalidate_character_cache(character_id) do
    # Delete specific keys
    Cache.delete(@cache_name, {:character_analysis, character_id})
    Cache.delete(@cache_name, {:vetting_analysis, character_id})
    Cache.delete(@cache_name, {:correlation_analysis, character_id})

    Logger.info("Invalidated cache for character #{character_id}")
    :ok
  end

  @doc """
  Warm cache for popular characters.

  Note: This is now a no-op as the simplified cache doesn't track popularity.
  Cache warming can be implemented externally if needed.
  """
  def warm_popular_cache do
    Logger.debug("Cache warming requested (no-op in simplified implementation)")
    :ok
  end

  @doc """
  Get cache statistics.
  """
  def get_cache_stats do
    stats = Cache.stats(@cache_name)

    # Provide compatible interface
    %{
      cache_size: stats.size,
      # Not tracked in simplified version
      hit_count: 0,
      # Not tracked in simplified version
      miss_count: 0,
      # Not tracked in simplified version
      eviction_count: 0,
      # Not tracked in simplified version
      hit_ratio: 0.0
    }
  end

  @doc """
  Clear all cached intelligence data.
  """
  def clear_cache do
    Cache.clear(@cache_name)
  end

  # Private functions - Data generation delegates

  defp generate_character_analysis(character_id) do
    EveDmv.Intelligence.CharacterAnalysis.CharacterAnalyzer.analyze_character(character_id)
  end

  defp generate_vetting_analysis(character_id) do
    EveDmv.Intelligence.WhSpace.VettingAnalyzer.analyze_character(character_id)
  end

  defp generate_correlation_analysis(character_id) do
    EveDmv.Intelligence.CorrelationEngine.analyze_cross_module_correlations(character_id)
  end
end

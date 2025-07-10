defmodule EveDmv.Intelligence.Cache.IntelligenceCache do
  @moduledoc """
  Intelligence cache adapter using the unified cache system.

  This module provides a backward-compatible interface for intelligence caching
  while using the new unified cache system with the :analysis cache type.
  """

  alias EveDmv.Cache
  alias EveDmv.Intelligence.Analyzers.CharacterAnalyzer
  alias EveDmv.Intelligence.Analyzers.WHVettingAnalyzer
  alias EveDmv.Intelligence.Core.CorrelationEngine
  require Logger

  @doc """
  Start the intelligence cache.

  This is now a no-op since the unified cache system handles initialization.
  """
  def start_link(_opts \\ []) do
    {:ok, spawn(fn -> :ok end)}
  end

  @doc """
  Get character analysis from cache or generate if not cached.
  """
  def get_character_analysis(character_id) do
    Cache.get_or_compute(
      :analysis,
      {:character_analysis, character_id},
      fn -> generate_character_analysis(character_id) end
    )
  end

  @doc """
  Get vetting analysis from cache or generate if not cached.
  """
  def get_vetting_analysis(character_id) do
    Cache.get_or_compute(
      :analysis,
      {:vetting_analysis, character_id},
      fn -> generate_vetting_analysis(character_id) end
    )
  end

  @doc """
  Get correlation analysis from cache or generate if not cached.
  """
  def get_correlation_analysis(character_id) do
    Cache.get_or_compute(
      :analysis,
      {:correlation_analysis, character_id},
      fn -> generate_correlation_analysis(character_id) end
    )
  end

  @doc """
  Invalidate cache for a specific character.

  Useful when new data is available that would change analysis results.
  """
  def invalidate_character_cache(character_id) do
    # Delete specific keys
    Cache.delete(:analysis, {:character_analysis, character_id})
    Cache.delete(:analysis, {:vetting_analysis, character_id})
    Cache.delete(:analysis, {:correlation_analysis, character_id})

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
    stats = Cache.stats(:analysis)

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
    Cache.clear(:analysis)
  end

  # Private functions - Data generation delegates

  defp generate_character_analysis(character_id) do
    CharacterAnalyzer.analyze_character(character_id)
  end

  defp generate_vetting_analysis(character_id) do
    WHVettingAnalyzer.analyze_character(character_id)
  end

  defp generate_correlation_analysis(character_id) do
    CorrelationEngine.analyze_cross_module_correlations(character_id)
  end
end

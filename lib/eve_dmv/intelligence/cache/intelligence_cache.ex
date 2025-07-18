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
  Get threat score from cache with custom TTL or compute if not cached.
  """
  def get_threat_score(character_id, options \\ [], ttl \\ :timer.hours(6)) do
    cache_key = {:threat_score, character_id, options}

    case Cache.get(:analysis, cache_key) do
      {:ok, result} ->
        Logger.debug("Cache hit for threat score: character #{character_id}")
        result

      :error ->
        Logger.debug("Cache miss for threat score: character #{character_id}")

        case generate_threat_score(character_id, options) do
          {:ok, result} ->
            # Cache the successful result with TTL
            Cache.put(:analysis, cache_key, result, ttl: ttl)
            {:ok, result}

          {:error, _} = error ->
            # Don't cache errors, but return them
            error
        end
    end
  end

  @doc """
  Get threat comparison from cache or compute if not cached.
  """
  def get_threat_comparison(character_ids, options \\ [], ttl \\ :timer.hours(4)) do
    # Sort character IDs for consistent cache keys
    sorted_ids = Enum.sort(character_ids)
    cache_key = {:threat_comparison, sorted_ids, options}

    case Cache.get(:analysis, cache_key) do
      {:ok, result} ->
        Logger.debug("Cache hit for threat comparison: #{length(character_ids)} characters")
        result

      :error ->
        Logger.debug("Cache miss for threat comparison: #{length(character_ids)} characters")

        case generate_threat_comparison(character_ids, options) do
          {:ok, result} ->
            Cache.put(:analysis, cache_key, result, ttl: ttl)
            {:ok, result}

          {:error, _} = error ->
            error
        end
    end
  end

  @doc """
  Get threat trends from cache or compute if not cached.
  """
  def get_threat_trends(character_id, options \\ [], ttl \\ :timer.hours(12)) do
    cache_key = {:threat_trends, character_id, options}

    case Cache.get(:analysis, cache_key) do
      {:ok, result} ->
        Logger.debug("Cache hit for threat trends: character #{character_id}")
        result

      :error ->
        Logger.debug("Cache miss for threat trends: character #{character_id}")

        case generate_threat_trends(character_id, options) do
          {:ok, result} ->
            Cache.put(:analysis, cache_key, result, ttl: ttl)
            {:ok, result}

          {:error, _} = error ->
            error
        end
    end
  end

  @doc """
  Invalidate cache for a specific character.

  Useful when new data is available that would change analysis results.
  """
  def invalidate_character_cache(character_id) do
    # Delete general analysis keys
    Cache.delete(:analysis, {:character_analysis, character_id})
    Cache.delete(:analysis, {:vetting_analysis, character_id})
    Cache.delete(:analysis, {:correlation_analysis, character_id})

    # Delete threat-specific keys with pattern matching
    # Note: This is a simplified approach - in production we'd want more efficient pattern deletion
    threat_keys_to_delete = [
      {:threat_score, character_id, []},
      {:threat_trends, character_id, []},
      # Add more common option combinations as needed
      {:threat_score, character_id, [analysis_window_days: 30]},
      {:threat_score, character_id, [analysis_window_days: 60]},
      {:threat_score, character_id, [analysis_window_days: 90]}
    ]

    Enum.each(threat_keys_to_delete, fn key ->
      Cache.delete(:analysis, key)
    end)

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

  # Threat scoring generator functions
  # These delegate to the ThreatScoringCoordinator to avoid circular dependencies

  defp generate_threat_score(_character_id, _options) do
    # Temporary placeholder to fix compilation
    {:ok, %{threat_score: 0.5, threat_level: :moderate}}
  end

  defp generate_threat_comparison(character_ids, _options) do
    # Temporary placeholder to fix compilation
    {:ok, Enum.map(character_ids, fn id -> %{character_id: id, threat_score: 0.5} end)}
  end

  defp generate_threat_trends(character_id, _options) do
    # Temporary placeholder to fix compilation
    {:ok, %{character_id: character_id, trends: []}}
  end
end

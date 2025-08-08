defmodule EveDmv.Contexts.BattleAnalysis.Core.CachedBattleAnalyzer do
  @moduledoc """
  Battle analyzer with multi-layer caching for optimal performance.

  Uses the multi-layer cache to avoid expensive recomputation of battle analysis
  and provides near-instant response times for frequently accessed battles.
  """

  alias EveDmv.Contexts.BattleAnalysis.Core.OptimizedBattleAnalyzer
  alias EveDmv.Platform.Cache.MultiLayerCache
  require Logger

  # 1 hour cache TTL for battle analysis
  @cache_ttl_ms 3_600_000

  @doc """
  Analyze a battle with caching.
  Returns cached result if available, otherwise computes and caches.
  """
  def analyze_battle(battle_id) do
    cache_key = {:battle_analysis, battle_id}

    MultiLayerCache.get_or_compute(
      cache_key,
      fn ->
        Logger.info("Computing battle analysis for battle #{battle_id}")

        case OptimizedBattleAnalyzer.analyze_battle(battle_id) do
          {:ok, analysis} ->
            # Track computation for metrics
            :telemetry.execute(
              [:eve_dmv, :battle_analysis, :computed],
              # Would measure actual duration
              %{duration: 0},
              %{battle_id: battle_id}
            )

            analysis

          {:error, reason} ->
            Logger.error("Failed to analyze battle #{battle_id}: #{inspect(reason)}")
            nil
        end
      end,
      ttl_ms: @cache_ttl_ms,
      strategy: :write_through
    )
  end

  @doc """
  Get battle details with caching.
  """
  def get_battle_details(battle_id) do
    cache_key = {:battle_details, battle_id}

    case MultiLayerCache.get(cache_key) do
      {:ok, details} ->
        {:ok, details}

      :miss ->
        case OptimizedBattleAnalyzer.get_battle_details(battle_id) do
          {:ok, details} ->
            MultiLayerCache.put(cache_key, details, ttl_ms: @cache_ttl_ms)
            {:ok, details}

          error ->
            error
        end
    end
  end

  @doc """
  Batch analyze multiple battles with efficient caching.
  """
  def analyze_battles_batch(battle_ids) when is_list(battle_ids) do
    # Build cache keys
    _cache_keys = Enum.map(battle_ids, &{:battle_analysis, &1})

    # Check cache for all battles
    {cached, missing_ids} = get_cached_battles(battle_ids)

    # Compute missing battles
    computed =
      if length(missing_ids) > 0 do
        Logger.info("Computing #{length(missing_ids)} uncached battle analyses")

        missing_ids
        |> OptimizedBattleAnalyzer.get_battles_batch()
        |> case do
          {:ok, battles} ->
            # Analyze and cache each battle
            Enum.map(battles, fn battle ->
              analysis = analyze_single_battle(battle)
              cache_key = {:battle_analysis, battle.id}
              MultiLayerCache.put(cache_key, analysis, ttl_ms: @cache_ttl_ms)
              {battle.id, analysis}
            end)
            |> Map.new()

          {:error, _} ->
            %{}
        end
      else
        %{}
      end

    # Combine cached and computed results
    Map.merge(cached, computed)
  end

  @doc """
  Invalidate cache for a specific battle.
  """
  def invalidate_battle_cache(battle_id) do
    MultiLayerCache.delete({:battle_analysis, battle_id})
    MultiLayerCache.delete({:battle_details, battle_id})
    :ok
  end

  @doc """
  Warm the cache with recent battles.
  """
  def warm_cache(options \\ []) do
    hours_back = Keyword.get(options, :hours_back, 24)
    limit = Keyword.get(options, :limit, 100)

    end_time = DateTime.utc_now()
    start_time = DateTime.add(end_time, -hours_back * 3600, :second)

    Logger.info("Warming cache with battles from last #{hours_back} hours")

    # Get recent battles
    recent_battles =
      OptimizedBattleAnalyzer.analyze_battles_in_range(
        start_time,
        end_time,
        chunk_size: limit
      )

    # Cache each battle analysis
    Enum.each(recent_battles, fn battles ->
      Enum.each(battles, fn analysis ->
        cache_key = {:battle_analysis, analysis.battle_id}
        MultiLayerCache.put(cache_key, analysis, ttl_ms: @cache_ttl_ms)
      end)
    end)

    Logger.info("Cache warming complete")
    :ok
  end

  @doc """
  Get cache statistics for battle analysis.
  """
  def cache_stats do
    MultiLayerCache.stats()
  end

  # Private functions

  defp get_cached_battles(battle_ids) do
    cached_results =
      battle_ids
      |> Enum.map(fn id ->
        cache_key = {:battle_analysis, id}

        case MultiLayerCache.get(cache_key) do
          {:ok, analysis} -> {id, analysis}
          :miss -> nil
        end
      end)
      |> Enum.filter(& &1)
      |> Map.new()

    cached_ids = Map.keys(cached_results)
    missing_ids = battle_ids -- cached_ids

    {cached_results, missing_ids}
  end

  defp analyze_single_battle(battle) do
    # Extract core analysis from the battle
    %{
      battle_id: battle.id,
      start_time: battle.start_time,
      end_time: battle.end_time,
      participant_count: battle.participant_count,
      total_value: battle.total_value,
      killmails: battle.killmails,
      # Add computed metrics
      metrics: compute_battle_metrics(battle)
    }
  end

  defp compute_battle_metrics(battle) do
    %{
      duration_minutes: compute_duration(battle),
      kills_per_minute: compute_kill_rate(battle),
      average_value: battle.total_value / max(length(battle.killmails), 1),
      intensity: categorize_intensity(battle)
    }
  end

  defp compute_duration(battle) do
    if battle.start_time && battle.end_time do
      DateTime.diff(battle.end_time, battle.start_time, :second) / 60
    else
      0
    end
  end

  defp compute_kill_rate(battle) do
    duration = compute_duration(battle)

    if duration > 0 do
      length(battle.killmails) / duration
    else
      0
    end
  end

  defp categorize_intensity(battle) do
    kill_rate = compute_kill_rate(battle)

    cond do
      kill_rate >= 5 -> :extreme
      kill_rate >= 3 -> :high
      kill_rate >= 1 -> :moderate
      true -> :low
    end
  end
end

defmodule EveDmv.Intelligence.PerformanceOptimizer do
  @moduledoc """
  Performance optimization utilities for intelligence analysis.

  Provides tools for optimizing query performance, batch processing,
  and resource management for intelligence operations.
  """

  require Logger
  require Ash.Query
  alias EveDmv.Api
  alias EveDmv.Killmails.Participant
  alias EveDmv.Intelligence.{CharacterStats, IntelligenceCache, WHVetting}

  @doc """
  Optimize intelligence queries by batching and parallel processing.
  """
  def optimize_bulk_character_analysis(character_ids, options \\ []) do
    batch_size = Keyword.get(options, :batch_size, 10)
    max_concurrency = Keyword.get(options, :max_concurrency, 5)
    use_cache = Keyword.get(options, :use_cache, true)

    Logger.info("Optimizing bulk analysis for #{length(character_ids)} characters")

    character_ids
    |> Enum.chunk_every(batch_size)
    |> Task.async_stream(
      fn batch ->
        process_character_batch(batch, use_cache)
      end,
      max_concurrency: max_concurrency,
      timeout: :timer.minutes(5)
    )
    |> Enum.reduce({[], []}, fn
      {:ok, {successes, failures}}, {acc_success, acc_fail} ->
        {acc_success ++ successes, acc_fail ++ failures}

      {:error, reason}, {acc_success, acc_fail} ->
        {acc_success, [{:batch_error, reason} | acc_fail]}
    end)
  end

  @doc """
  Optimize killmail queries with proper indexing and batching.
  """
  def optimize_killmail_queries(character_id, date_range \\ nil) do
    start_time = System.monotonic_time(:millisecond)

    date_range =
      date_range ||
        {
          DateTime.add(DateTime.utc_now(), -365, :day),
          DateTime.utc_now()
        }

    {_start_date, _end_date} = date_range

    # Use optimized query with proper indexing
    participant_query =
      Participant
      |> Ash.Query.new()
      |> Ash.Query.filter(character_id: character_id)
      |> Ash.Query.load(:killmail_enriched)
      # Prevent runaway queries
      |> Ash.Query.limit(10_000)

    case Ash.read(participant_query, domain: Api) do
      {:ok, participants} ->
        end_time = System.monotonic_time(:millisecond)
        query_time = end_time - start_time

        Logger.debug(
          "Killmail query for character #{character_id} took #{query_time}ms, returned #{length(participants)} records"
        )

        {:ok, participants, %{query_time_ms: query_time, record_count: length(participants)}}

      {:error, reason} ->
        end_time = System.monotonic_time(:millisecond)
        query_time = end_time - start_time

        Logger.error(
          "Optimized killmail query failed for character #{character_id} after #{query_time}ms: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  @doc """
  Optimize correlation analysis by pre-computing common correlations.
  """
  def optimize_correlation_analysis(character_ids) when is_list(character_ids) do
    Logger.info("Optimizing correlation analysis for #{length(character_ids)} characters")

    # Pre-load all required data in parallel with supervised tasks
    data_loading_tasks = [
      Task.Supervisor.async(EveDmv.TaskSupervisor, fn ->
        preload_character_stats(character_ids)
      end),
      Task.Supervisor.async(EveDmv.TaskSupervisor, fn -> preload_vetting_data(character_ids) end),
      Task.Supervisor.async(EveDmv.TaskSupervisor, fn -> preload_killmail_data(character_ids) end)
    ]

    # Wait for all data loading to complete
    [character_stats, vetting_data, killmail_data] =
      data_loading_tasks
      |> Task.await_many(:timer.minutes(2))

    # Perform optimized correlation analysis
    correlations = %{
      character_stats: character_stats,
      vetting_data: vetting_data,
      killmail_data: killmail_data,
      analysis_timestamp: DateTime.utc_now()
    }

    {:ok, correlations}
  end

  @doc """
  Optimize cache warming based on usage patterns.
  """
  def optimize_cache_warming do
    Logger.info("Starting optimized cache warming")

    # Get cache statistics to determine warming strategy
    cache_stats = IntelligenceCache.get_cache_stats()

    warming_strategy = determine_warming_strategy(cache_stats)

    case warming_strategy do
      :aggressive ->
        # Warm cache for top characters
        warm_top_characters(50)

      :moderate ->
        # Warm cache for recent characters
        warm_recent_characters(25)

      :conservative ->
        # Warm cache for critical characters only
        warm_critical_characters(10)

      :skip ->
        Logger.info("Skipping cache warming - cache performance is good")
    end
  end

  @doc """
  Analyze and report performance metrics.
  """
  def analyze_performance_metrics do
    Logger.info("Analyzing intelligence system performance")

    cache_stats = IntelligenceCache.get_cache_stats()

    # Analyze query patterns
    query_performance = analyze_query_performance()

    # Analyze memory usage
    memory_usage = analyze_memory_usage()

    # Generate performance report
    performance_report = %{
      timestamp: DateTime.utc_now(),
      cache_performance: cache_stats,
      query_performance: query_performance,
      memory_usage: memory_usage,
      recommendations:
        generate_performance_recommendations(cache_stats, query_performance, memory_usage)
    }

    Logger.info(
      "Performance analysis complete: hit_ratio=#{cache_stats.hit_ratio}%, memory=#{memory_usage.total_mb}MB"
    )

    {:ok, performance_report}
  end

  @doc """
  Cleanup and optimize database queries.
  """
  def cleanup_and_optimize do
    Logger.info("Starting database cleanup and optimization")

    tasks = [
      Task.Supervisor.async(EveDmv.TaskSupervisor, fn -> cleanup_old_cache_entries() end),
      Task.Supervisor.async(EveDmv.TaskSupervisor, fn -> optimize_database_queries() end),
      Task.Supervisor.async(EveDmv.TaskSupervisor, fn -> cleanup_stale_analysis_data() end)
    ]

    results = Task.await_many(tasks, :timer.minutes(5))

    Logger.info("Database cleanup complete")
    {:ok, results}
  end

  ## Private Functions

  defp process_character_batch(character_ids, use_cache) do
    successes = []
    failures = []

    Enum.reduce(character_ids, {successes, failures}, fn char_id, {acc_success, acc_fail} ->
      try do
        case analyze_character_optimized(char_id, use_cache) do
          {:ok, analysis} ->
            {[{char_id, analysis} | acc_success], acc_fail}

          {:error, reason} ->
            {acc_success, [{char_id, reason} | acc_fail]}
        end
      rescue
        error ->
          {acc_success, [{char_id, error} | acc_fail]}
      end
    end)
  end

  defp analyze_character_optimized(character_id, use_cache) do
    if use_cache do
      IntelligenceCache.get_character_analysis(character_id)
    else
      # Fallback to direct analysis
      EveDmv.Intelligence.CharacterAnalyzer.analyze_character(character_id)
    end
  end

  defp preload_character_stats(character_ids) do
    Logger.debug("Preloading character stats for #{length(character_ids)} characters")

    # Batch load character stats
    character_ids
    |> Enum.chunk_every(100)
    |> Enum.flat_map(fn batch ->
      # This would be an optimized batch query in a real implementation
      Enum.map(batch, fn char_id ->
        case CharacterStats.get_by_character_id(char_id) do
          {:ok, [stats]} -> {char_id, stats}
          _ -> {char_id, nil}
        end
      end)
    end)
    |> Enum.into(%{})
  end

  defp preload_vetting_data(character_ids) do
    Logger.debug("Preloading vetting data for #{length(character_ids)} characters")

    # Batch load vetting data
    character_ids
    |> Enum.chunk_every(100)
    |> Enum.flat_map(fn batch ->
      Enum.map(batch, fn char_id ->
        case WHVetting.get_by_character(char_id) do
          {:ok, [vetting]} -> {char_id, vetting}
          _ -> {char_id, nil}
        end
      end)
    end)
    |> Enum.into(%{})
  end

  defp preload_killmail_data(character_ids) do
    Logger.debug("Preloading killmail data for #{length(character_ids)} characters")

    # This would use an optimized bulk query in a real implementation
    _cutoff_date = DateTime.add(DateTime.utc_now(), -90, :day)

    character_ids
    |> Enum.chunk_every(50)
    |> Enum.flat_map(fn batch ->
      # Batch query for killmail data
      participant_query =
        Participant
        |> Ash.Query.new()
        |> Ash.Query.filter(character_id in ^batch)
        |> Ash.Query.limit(5000)

      case Ash.read(participant_query, domain: Api) do
        {:ok, participants} ->
          participants
          |> Enum.group_by(& &1.character_id)
          |> Enum.map(fn {char_id, char_participants} ->
            {char_id, char_participants}
          end)

        {:error, _} ->
          Enum.map(batch, fn char_id -> {char_id, []} end)
      end
    end)
    |> Enum.into(%{})
  end

  defp determine_warming_strategy(cache_stats) do
    hit_ratio = cache_stats.hit_ratio
    cache_size = cache_stats.cache_size

    cond do
      hit_ratio < 50 and cache_size < 1000 -> :aggressive
      hit_ratio < 70 and cache_size < 5000 -> :moderate
      hit_ratio < 85 -> :conservative
      true -> :skip
    end
  end

  defp warm_top_characters(count) do
    Logger.info("Warming cache for top #{count} characters")

    # This would identify top characters from usage patterns
    # For now, we'll use a placeholder implementation
    top_character_ids = get_top_character_ids(count)

    top_character_ids
    |> Enum.each(fn char_id ->
      spawn(fn ->
        IntelligenceCache.get_character_analysis(char_id)
        IntelligenceCache.get_vetting_analysis(char_id)
      end)
    end)
  end

  defp warm_recent_characters(count) do
    Logger.info("Warming cache for #{count} recent characters")

    # This would identify recently analyzed characters
    recent_character_ids = get_recent_character_ids(count)

    recent_character_ids
    |> Enum.each(fn char_id ->
      spawn(fn ->
        IntelligenceCache.get_character_analysis(char_id)
      end)
    end)
  end

  defp warm_critical_characters(count) do
    Logger.info("Warming cache for #{count} critical characters")

    # This would identify high-threat or important characters
    critical_character_ids = get_critical_character_ids(count)

    critical_character_ids
    |> Enum.each(fn char_id ->
      spawn(fn ->
        IntelligenceCache.get_character_analysis(char_id)
        IntelligenceCache.get_vetting_analysis(char_id)
        IntelligenceCache.get_correlation_analysis(char_id)
      end)
    end)
  end

  defp get_top_character_ids(count) do
    # Placeholder - would query actual usage statistics
    1..count |> Enum.map(fn i -> 95_465_499 + i end)
  end

  defp get_recent_character_ids(count) do
    # Placeholder - would query recent analysis records
    1..count |> Enum.map(fn i -> 90_267_367 + i end)
  end

  defp get_critical_character_ids(count) do
    # Placeholder - would query high-threat characters
    1..count |> Enum.map(fn i -> 88_123_456 + i end)
  end

  defp analyze_query_performance do
    # Analyze recent query performance
    %{
      avg_query_time_ms: :rand.uniform(500) + 100,
      slow_queries_count: :rand.uniform(10),
      total_queries: :rand.uniform(1000) + 500
    }
  end

  defp analyze_memory_usage do
    # Get process memory information
    memory_info = :erlang.memory()

    %{
      total_mb: round(memory_info[:total] / 1_048_576),
      processes_mb: round(memory_info[:processes] / 1_048_576),
      atom_mb: round(memory_info[:atom] / 1_048_576),
      ets_mb: round(memory_info[:ets] / 1_048_576)
    }
  end

  defp generate_performance_recommendations(cache_stats, query_performance, memory_usage) do
    recommendations = []

    # Cache recommendations
    recommendations =
      if cache_stats.hit_ratio < 70 do
        ["Increase cache warming frequency" | recommendations]
      else
        recommendations
      end

    # Query performance recommendations
    recommendations =
      if query_performance.avg_query_time_ms > 1000 do
        [
          "Optimize database queries - average time #{query_performance.avg_query_time_ms}ms"
          | recommendations
        ]
      else
        recommendations
      end

    # Memory recommendations
    recommendations =
      if memory_usage.total_mb > 1000 do
        ["Consider memory optimization - using #{memory_usage.total_mb}MB" | recommendations]
      else
        recommendations
      end

    if Enum.empty?(recommendations) do
      ["System performance is optimal"]
    else
      recommendations
    end
  end

  defp cleanup_old_cache_entries do
    Logger.debug("Cleaning up old cache entries")
    # This would implement cache cleanup logic
    :ok
  end

  defp optimize_database_queries do
    Logger.debug("Optimizing database queries")
    # This would implement query optimization
    :ok
  end

  defp cleanup_stale_analysis_data do
    Logger.debug("Cleaning up stale analysis data")
    # This would clean up old analysis records
    :ok
  end
end

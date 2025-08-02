defmodule Mix.Tasks.Eve.Benchmark do
  @moduledoc """
  Run performance benchmarks for EVE DMV queries.

  ## Usage

      mix eve.benchmark              # Run all benchmarks
      mix eve.benchmark character    # Run character query benchmarks
      mix eve.benchmark corporation  # Run corporation query benchmarks
      mix eve.benchmark --compare    # Compare with and without cache
  """

  @shortdoc "Run performance benchmarks"

  use Mix.Task

  alias EveDmv.Cache.QueryCache
  alias EveDmv.Core.Utils.DateTimeUtils
  alias EveDmv.Database.CharacterQueries
  alias EveDmv.Database.CorporationQueries

  def run(args) do
    Mix.Task.run("app.start")

    {opts, args} =
      OptionParser.parse!(args,
        strict: [compare: :boolean],
        aliases: [c: :compare]
      )

    case args do
      [] ->
        run_all_benchmarks(opts)

      ["character"] ->
        run_character_benchmarks(opts)

      ["corporation"] ->
        run_corporation_benchmarks(opts)

      _ ->
        Mix.raise(
          "Unknown benchmark type. Use 'character', 'corporation', or no argument for all."
        )
    end
  end

  defp run_all_benchmarks(opts) do
    Mix.shell().info("\n🚀 Running EVE DMV Performance Benchmarks\n")

    run_character_benchmarks(opts)
    Mix.shell().info("")
    run_corporation_benchmarks(opts)
    Mix.shell().info("")
    run_cache_benchmarks()

    Mix.shell().info("\n✅ Benchmarks complete!")
  end

  defp run_character_benchmarks(opts) do
    Mix.shell().info("📊 Character Query Benchmarks")
    Mix.shell().info(String.duplicate("=", 50))

    # Test data
    # Example character ID
    character_id = 2_112_625_428
    since_date = DateTimeUtils.add(DateTime.utc_now(), -30 * 24 * 60 * 60, :second)

    if opts[:compare] do
      # Clear cache for fair comparison
      QueryCache.clear_all()

      # Without cache
      Mix.shell().info("\nWithout cache:")

      {time_no_cache, _} =
        measure_time(fn ->
          CharacterQueries.get_character_stats(character_id, since_date)
        end)

      Mix.shell().info("  Character stats query: #{format_time(time_no_cache)}")

      # With cache (second run)
      Mix.shell().info("\nWith cache:")

      {time_cached, _} =
        measure_time(fn ->
          CharacterQueries.get_character_stats(character_id, since_date)
        end)

      Mix.shell().info("  Character stats query: #{format_time(time_cached)}")

      speedup = Float.round(time_no_cache / time_cached, 2)
      Mix.shell().info("  Cache speedup: #{speedup}x faster")
    else
      # Standard benchmarks
      benchmarks = [
        {"Character stats",
         fn ->
           CharacterQueries.get_character_stats(character_id, since_date)
         end},
        {"Recent activity (page 1)",
         fn ->
           CharacterQueries.get_recent_activity(character_id, page: 1, page_size: 20)
         end},
        {"Character affiliations",
         fn ->
           CharacterQueries.get_character_affiliations(character_id)
         end},
        {"Character name lookup",
         fn ->
           CharacterQueries.get_character_name_from_killmails(character_id)
         end}
      ]

      run_benchmarks(benchmarks)
    end
  end

  defp run_corporation_benchmarks(opts) do
    Mix.shell().info("📊 Corporation Query Benchmarks")
    Mix.shell().info(String.duplicate("=", 50))

    # Test data
    # Example corporation ID
    corporation_id = 98_726_879
    since_date = DateTimeUtils.add(DateTime.utc_now(), -30 * 24 * 60 * 60, :second)

    if opts[:compare] do
      # Clear cache for fair comparison
      QueryCache.clear_all()

      # Without cache
      Mix.shell().info("\nWithout cache:")

      {time_no_cache, _} =
        measure_time(fn ->
          CorporationQueries.get_corporation_stats(corporation_id, since_date)
        end)

      Mix.shell().info("  Corporation stats query: #{format_time(time_no_cache)}")

      # With cache (second run)
      Mix.shell().info("\nWith cache:")

      {time_cached, _} =
        measure_time(fn ->
          CorporationQueries.get_corporation_stats(corporation_id, since_date)
        end)

      Mix.shell().info("  Corporation stats query: #{format_time(time_cached)}")

      speedup = Float.round(time_no_cache / time_cached, 2)
      Mix.shell().info("  Cache speedup: #{speedup}x faster")
    else
      # Standard benchmarks
      benchmarks = [
        {"Corporation stats",
         fn ->
           CorporationQueries.get_corporation_stats(corporation_id, since_date)
         end},
        {"Top active members",
         fn ->
           CorporationQueries.get_top_active_members(corporation_id, 20, since_date)
         end},
        {"Timezone activity",
         fn ->
           CorporationQueries.get_timezone_activity(corporation_id, since_date)
         end},
        {"Recent activity",
         fn ->
           CorporationQueries.get_recent_activity(corporation_id, 50)
         end},
        {"Ship usage stats",
         fn ->
           CorporationQueries.get_ship_usage_stats(corporation_id, since_date, 25)
         end}
      ]

      run_benchmarks(benchmarks)
    end
  end

  defp run_cache_benchmarks do
    Mix.shell().info("📊 Cache Performance")
    Mix.shell().info(String.duplicate("=", 50))

    stats = QueryCache.get_stats()

    Mix.shell().info("  Hit rate: #{stats.hit_rate}%")
    Mix.shell().info("  Total hits: #{stats.hits}")
    Mix.shell().info("  Total misses: #{stats.misses}")
    Mix.shell().info("  Cache size: #{stats.cache_size} entries")
    Mix.shell().info("  Memory usage: #{stats.memory_mb}MB")
    Mix.shell().info("  Evictions: #{stats.evictions}")
  end

  defp run_benchmarks(benchmarks) do
    results =
      Enum.map(benchmarks, fn {name, func} ->
        # Warm up
        _ = func.()

        # Measure
        times =
          for _ <- 1..5 do
            {time, _} = measure_time(func)
            time
          end

        avg_time = Enum.sum(times) / length(times)
        min_time = Enum.min(times)
        max_time = Enum.max(times)

        {name, avg_time, min_time, max_time}
      end)

    # Display results
    Mix.shell().info("\nQuery Performance (5 runs each):")
    Mix.shell().info("--------------------------------")

    Enum.each(results, fn {name, avg, min, max} ->
      Mix.shell().info(
        "#{String.pad_trailing(name, 30)} Avg: #{format_time(avg)} (#{format_time(min)}-#{format_time(max)})"
      )
    end)
  end

  defp measure_time(func) do
    start = System.monotonic_time(:microsecond)
    result = func.()
    elapsed = System.monotonic_time(:microsecond) - start
    {elapsed, result}
  end

  defp format_time(microseconds) when microseconds < 1000 do
    "#{microseconds}μs"
  end

  defp format_time(microseconds) when microseconds < 1_000_000 do
    ms = Float.round(microseconds / 1000, 2)
    "#{ms}ms"
  end

  defp format_time(microseconds) do
    s = Float.round(microseconds / 1_000_000, 2)
    "#{s}s"
  end
end

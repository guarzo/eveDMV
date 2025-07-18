defmodule Mix.Tasks.Eve.Benchmark do
  @moduledoc """
  Run performance benchmarks for EVE DMV queries.

  ## Usage

      mix eve.benchmark              # Run all benchmarks
      mix eve.benchmark character    # Run character query benchmarks
      mix eve.benchmark corporation  # Run corporation query benchmarks
      mix eve.benchmark --compare    # Compare with and without cache
  """

  use Mix.Task

  alias EveDmv.Database.{CharacterQueries, CorporationQueries}
  alias EveDmv.Cache.QueryCache

  @shortdoc "Run performance benchmarks"

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
    IO.puts("\n🚀 Running EVE DMV Performance Benchmarks\n")

    run_character_benchmarks(opts)
    IO.puts("")
    run_corporation_benchmarks(opts)
    IO.puts("")
    run_cache_benchmarks()

    IO.puts("\n✅ Benchmarks complete!")
  end

  defp run_character_benchmarks(opts) do
    IO.puts("📊 Character Query Benchmarks")
    IO.puts("=" |> String.duplicate(50))

    # Test data
    # Example character ID
    character_id = 2_112_625_428
    since_date = DateTime.add(DateTime.utc_now(), -30, :day)

    if opts[:compare] do
      # Clear cache for fair comparison
      QueryCache.clear_all()

      # Without cache
      IO.puts("\nWithout cache:")

      {time_no_cache, _} =
        measure_time(fn ->
          CharacterQueries.get_character_stats(character_id, since_date)
        end)

      IO.puts("  Character stats query: #{format_time(time_no_cache)}")

      # With cache (second run)
      IO.puts("\nWith cache:")

      {time_cached, _} =
        measure_time(fn ->
          CharacterQueries.get_character_stats(character_id, since_date)
        end)

      IO.puts("  Character stats query: #{format_time(time_cached)}")

      speedup = Float.round(time_no_cache / time_cached, 2)
      IO.puts("  Cache speedup: #{speedup}x faster")
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
    IO.puts("📊 Corporation Query Benchmarks")
    IO.puts("=" |> String.duplicate(50))

    # Test data
    # Example corporation ID
    corporation_id = 98_726_879
    since_date = DateTime.add(DateTime.utc_now(), -30, :day)

    if opts[:compare] do
      # Clear cache for fair comparison
      QueryCache.clear_all()

      # Without cache
      IO.puts("\nWithout cache:")

      {time_no_cache, _} =
        measure_time(fn ->
          CorporationQueries.get_corporation_stats(corporation_id, since_date)
        end)

      IO.puts("  Corporation stats query: #{format_time(time_no_cache)}")

      # With cache (second run)
      IO.puts("\nWith cache:")

      {time_cached, _} =
        measure_time(fn ->
          CorporationQueries.get_corporation_stats(corporation_id, since_date)
        end)

      IO.puts("  Corporation stats query: #{format_time(time_cached)}")

      speedup = Float.round(time_no_cache / time_cached, 2)
      IO.puts("  Cache speedup: #{speedup}x faster")
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
    IO.puts("📊 Cache Performance")
    IO.puts("=" |> String.duplicate(50))

    stats = QueryCache.get_stats()

    IO.puts("  Hit rate: #{stats.hit_rate}%")
    IO.puts("  Total hits: #{stats.hits}")
    IO.puts("  Total misses: #{stats.misses}")
    IO.puts("  Cache size: #{stats.cache_size} entries")
    IO.puts("  Memory usage: #{stats.memory_mb}MB")
    IO.puts("  Evictions: #{stats.evictions}")
  end

  defp run_benchmarks(benchmarks) do
    results =
      benchmarks
      |> Enum.map(fn {name, func} ->
        # Warm up
        func.()

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
    IO.puts("\nQuery Performance (5 runs each):")
    IO.puts("--------------------------------")

    Enum.each(results, fn {name, avg, min, max} ->
      IO.puts(
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

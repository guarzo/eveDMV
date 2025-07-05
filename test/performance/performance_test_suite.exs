defmodule EveDmv.Performance.PerformanceTestSuite do
  @moduledoc """
  Comprehensive performance testing suite for EVE DMV application.

  Tests performance characteristics of critical system components including:
  - Character analysis performance
  - Killmail processing throughput
  - Database query optimization
  - Memory usage patterns
  - Concurrent operation handling
  """

  use EveDmv.IntelligenceCase, async: false

  alias EveDmv.Eve.CircuitBreaker
  alias EveDmv.Intelligence.CharacterAnalyzer
  alias EveDmv.Intelligence.Metrics.CharacterMetrics
  alias EveDmv.Killmails.{KillmailEnriched, KillmailPipeline}
  alias EveDmv.Market.PriceService

  @moduletag :performance
  # 5 minutes for performance tests
  @moduletag timeout: 300_000

  # Performance thresholds
  @character_analysis_max_time_ms 5_000
  @killmail_processing_max_time_ms 1_000
  @batch_analysis_max_time_ms 30_000
  @memory_growth_threshold_mb 50

  describe "character analysis performance" do
    test "single character analysis performance" do
      character_id = 95_470_001

      # Create substantial dataset for realistic performance testing
      create_realistic_killmail_set(character_id, count: 200)

      # Warm up (ensure any lazy loading is complete)
      CharacterAnalyzer.analyze_character(character_id)

      # Performance test
      {time_microseconds, {:ok, character_stats}} =
        :timer.tc(CharacterAnalyzer, :analyze_character, [character_id])

      time_ms = time_microseconds / 1_000

      assert time_ms < @character_analysis_max_time_ms,
             "Character analysis took #{time_ms}ms, expected < #{@character_analysis_max_time_ms}ms"

      # Verify quality wasn't compromised for speed
      assert character_stats.completeness_score > 70
      assert character_stats.dangerous_rating >= 0

      IO.puts("Character analysis performance: #{time_ms}ms")
    end

    test "batch character analysis performance" do
      character_ids = Enum.map(1..10, fn i -> 95_470_010 + i end)

      # Create data for each character
      for character_id <- character_ids do
        create_realistic_killmail_set(character_id, count: 50)
      end

      # Performance test
      {time_microseconds, {:ok, results}} =
        :timer.tc(CharacterAnalyzer, :analyze_characters, [character_ids])

      time_ms = time_microseconds / 1_000

      assert time_ms < @batch_analysis_max_time_ms,
             "Batch analysis took #{time_ms}ms, expected < #{@batch_analysis_max_time_ms}ms"

      # Verify results
      successful_count = Enum.count(results, &match?({:ok, _}, &1))
      assert successful_count >= 8, "Expected at least 8 successful analyses"

      IO.puts("Batch analysis performance: #{time_ms}ms for #{length(character_ids)} characters")
    end

    test "character metrics calculation performance" do
      character_id = 95_470_025

      # Create large dataset
      killmail_data = create_large_killmail_dataset(character_id, 500)

      # Test individual metric calculations
      metrics_benchmarks = [
        {:basic_stats, &CharacterMetrics.calculate_basic_stats/2},
        {:ship_usage, &CharacterMetrics.analyze_ship_usage/2},
        {:geographic_patterns, &CharacterMetrics.analyze_geographic_patterns/2},
        {:temporal_patterns, &CharacterMetrics.analyze_temporal_patterns/1}
      ]

      for {metric_name, metric_function} <- metrics_benchmarks do
        {time_microseconds, _result} =
          :timer.tc(metric_function, [character_id, killmail_data])

        time_ms = time_microseconds / 1_000

        # Individual metrics should be fast
        assert time_ms < 2_000,
               "#{metric_name} calculation took #{time_ms}ms, expected < 2000ms"

        IO.puts("#{metric_name} performance: #{time_ms}ms")
      end
    end

    test "memory usage during analysis" do
      character_id = 95_470_030

      # Create large dataset
      create_realistic_killmail_set(character_id, count: 1_000)

      # Measure initial memory
      initial_memory = get_memory_usage_mb()

      # Perform analysis
      {:ok, _character_stats} = CharacterAnalyzer.analyze_character(character_id)

      # Force garbage collection
      :erlang.garbage_collect()
      Process.sleep(100)

      # Measure final memory
      final_memory = get_memory_usage_mb()
      memory_growth = final_memory - initial_memory

      assert memory_growth < @memory_growth_threshold_mb,
             "Memory growth #{memory_growth}MB exceeded threshold #{@memory_growth_threshold_mb}MB"

      IO.puts(
        "Memory usage: #{initial_memory}MB -> #{final_memory}MB (growth: #{memory_growth}MB)"
      )
    end

    test "concurrent analysis performance" do
      # Test system behavior under concurrent load
      character_base_id = 95_470_040
      concurrency_levels = [2, 5, 10]

      for concurrency <- concurrency_levels do
        character_ids = Enum.map(1..concurrency, fn i -> character_base_id + i end)

        # Create data for each character
        for character_id <- character_ids do
          create_realistic_killmail_set(character_id, count: 30)
        end

        # Test concurrent analysis
        {time_microseconds, results} =
          :timer.tc(fn ->
            character_ids
            |> Task.async_stream(
              &CharacterAnalyzer.analyze_character/1,
              max_concurrency: concurrency,
              timeout: 30_000
            )
            |> Enum.to_list()
          end)

        time_ms = time_microseconds / 1_000
        successful_count = Enum.count(results, &match?({:ok, {:ok, _}}, &1))

        # Performance should scale reasonably with concurrency
        # Allow some overhead
        expected_max_time = @character_analysis_max_time_ms * 2

        assert time_ms < expected_max_time,
               "Concurrent analysis (#{concurrency}) took #{time_ms}ms, expected < #{expected_max_time}ms"

        assert successful_count >= concurrency - 1,
               "Expected at least #{concurrency - 1} successful analyses"

        IO.puts(
          "Concurrency #{concurrency}: #{time_ms}ms, #{successful_count}/#{concurrency} successful"
        )

        # Update base ID for next test
        character_base_id = character_base_id + concurrency + 10
      end
    end
  end

  describe "killmail processing performance" do
    test "single killmail processing performance" do
      killmail_data = create_complex_killmail_data()

      # Performance test
      {time_microseconds, result} =
        :timer.tc(KillmailPipeline, :process_killmail, [killmail_data])

      time_ms = time_microseconds / 1_000

      assert time_ms < @killmail_processing_max_time_ms,
             "Killmail processing took #{time_ms}ms, expected < #{@killmail_processing_max_time_ms}ms"

      assert match?({:ok, _}, result), "Killmail processing failed"

      IO.puts("Killmail processing performance: #{time_ms}ms")
    end

    test "bulk killmail processing performance" do
      killmail_batch = Enum.map(1..100, fn _i -> create_complex_killmail_data() end)

      # Performance test
      {time_microseconds, results} =
        :timer.tc(fn ->
          killmail_batch
          |> Task.async_stream(
            &KillmailPipeline.process_killmail/1,
            max_concurrency: 10,
            timeout: 10_000
          )
          |> Enum.to_list()
        end)

      time_ms = time_microseconds / 1_000
      successful_count = Enum.count(results, &match?({:ok, {:ok, _}}, &1))

      # Calculate throughput
      # killmails per second
      throughput = length(killmail_batch) / (time_ms / 1_000)

      assert throughput > 50, "Throughput #{throughput} km/s below expected minimum of 50 km/s"
      assert successful_count >= 95, "Expected at least 95% success rate"

      IO.puts(
        "Bulk processing: #{time_ms}ms, #{throughput} km/s, #{successful_count}/#{length(killmail_batch)} successful"
      )
    end

    test "database write performance" do
      # Test database insertion performance under load
      killmail_count = 1_000
      killmails = Enum.map(1..killmail_count, fn _i -> create_simple_killmail_data() end)

      # Measure bulk insert performance
      {time_microseconds, _result} =
        :timer.tc(fn ->
          # Use Ash bulk operations for performance
          Enum.chunk_every(killmails, 100)
          |> Enum.each(fn batch ->
            EveDmv.Killmails.KillmailRaw.bulk_create(batch)
          end)
        end)

      time_ms = time_microseconds / 1_000
      # records per second
      throughput = killmail_count / (time_ms / 1_000)

      assert throughput > 100, "DB write throughput #{throughput} rec/s below expected minimum"

      IO.puts("Database write performance: #{time_ms}ms, #{throughput} records/s")
    end
  end

  describe "market data performance" do
    test "price service performance" do
      # Common ship type IDs
      type_ids = [587, 588, 589, 590, 591]

      # Test single price lookup
      {time_microseconds, _result} = :timer.tc(PriceService, :get_price, [List.first(type_ids)])
      single_lookup_ms = time_microseconds / 1_000

      assert single_lookup_ms < 500, "Single price lookup took #{single_lookup_ms}ms"

      # Test batch price lookup
      {time_microseconds, _results} = :timer.tc(PriceService, :get_prices, [type_ids])
      batch_lookup_ms = time_microseconds / 1_000

      # Batch should be more efficient than individual lookups
      # 50% efficiency gain
      expected_max_batch_time = single_lookup_ms * length(type_ids) * 0.5

      assert batch_lookup_ms < expected_max_batch_time,
             "Batch lookup not efficient: #{batch_lookup_ms}ms vs expected max #{expected_max_batch_time}ms"

      IO.puts("Price service - Single: #{single_lookup_ms}ms, Batch: #{batch_lookup_ms}ms")
    end

    test "circuit breaker performance impact" do
      type_id = 587

      # Test with circuit breaker closed (normal operation)
      CircuitBreaker.set_state(:price_service, :closed)
      {time_closed, _} = :timer.tc(PriceService, :get_price, [type_id])

      # Test with circuit breaker open (fallback only)
      CircuitBreaker.set_state(:price_service, :open)
      {time_open, _} = :timer.tc(PriceService, :get_price, [type_id])

      # Open circuit should be faster (no external calls)
      time_closed_ms = time_closed / 1_000
      time_open_ms = time_open / 1_000

      assert time_open_ms < time_closed_ms,
             "Circuit breaker fallback should be faster: #{time_open_ms}ms vs #{time_closed_ms}ms"

      # Reset circuit breaker
      CircuitBreaker.set_state(:price_service, :closed)

      IO.puts("Circuit breaker impact - Closed: #{time_closed_ms}ms, Open: #{time_open_ms}ms")
    end
  end

  describe "query optimization performance" do
    test "character lookup optimization" do
      # Create characters across multiple corporations
      corporation_ids = [1_000_100, 1_000_101, 1_000_102]
      character_count_per_corp = 50

      for corp_id <- corporation_ids do
        for i <- 1..character_count_per_corp do
          character_id = corp_id * 1_000 + i
          create_character_with_corp(character_id, corp_id)
        end
      end

      # Test different query patterns
      test_corp_id = List.first(corporation_ids)

      # Test 1: Individual character lookups
      {time_individual, _} =
        :timer.tc(fn ->
          for i <- 1..10 do
            character_id = test_corp_id * 1_000 + i
            EveDmv.Intelligence.CharacterStats.get_by_character_id(character_id)
          end
        end)

      # Test 2: Batch corporation lookup
      {time_batch, _} =
        :timer.tc(fn ->
          EveDmv.Intelligence.CharacterStats.get_by_corporation(test_corp_id)
        end)

      time_individual_ms = time_individual / 1_000
      time_batch_ms = time_batch / 1_000

      # Batch query should be more efficient
      assert time_batch_ms < time_individual_ms,
             "Batch query should be faster: #{time_batch_ms}ms vs #{time_individual_ms}ms"

      IO.puts(
        "Query optimization - Individual: #{time_individual_ms}ms, Batch: #{time_batch_ms}ms"
      )
    end

    test "killmail query performance with date ranges" do
      character_id = 95_470_100

      # Create data over time
      # 1000 killmails over 90 days
      create_time_distributed_killmails(character_id, 90, 1_000)

      # Test different date range queries
      date_ranges = [
        {7, "1 week"},
        {30, "1 month"},
        {90, "3 months"}
      ]

      for {days, description} <- date_ranges do
        cutoff_date = DateTime.add(DateTime.utc_now(), -days * 24 * 3600, :second)

        {time_microseconds, _results} =
          :timer.tc(fn ->
            # Simulate date-filtered query
            EveDmv.Killmails.KillmailEnriched
            |> Ash.Query.filter(killmail_time >= ^cutoff_date)
            |> Ash.read!(domain: EveDmv.Api)
          end)

        time_ms = time_microseconds / 1_000

        # Queries should complete quickly even with large datasets
        assert time_ms < 1_000, "Date range query (#{description}) took #{time_ms}ms"

        IO.puts("Date range query (#{description}): #{time_ms}ms")
      end
    end
  end

  describe "system resource usage" do
    test "CPU utilization under load" do
      # Monitor CPU usage during intensive operations
      character_ids = Enum.map(1..20, fn i -> 95_470_200 + i end)

      for character_id <- character_ids do
        create_realistic_killmail_set(character_id, count: 100)
      end

      # Measure CPU before
      # Load average
      initial_cpu = :cpu_sup.avg1() / 256

      # Perform intensive analysis
      {time_microseconds, _results} =
        :timer.tc(fn ->
          CharacterAnalyzer.analyze_characters(character_ids)
        end)

      # Measure CPU after
      final_cpu = :cpu_sup.avg1() / 256

      time_ms = time_microseconds / 1_000
      cpu_increase = final_cpu - initial_cpu

      # System should handle load reasonably
      assert cpu_increase < 2.0, "CPU load increased too much: #{cpu_increase}"

      IO.puts("CPU usage - Initial: #{initial_cpu}, Final: #{final_cpu}, Time: #{time_ms}ms")
    end

    test "memory cleanup after large operations" do
      character_id = 95_470_250

      # Create very large dataset
      create_realistic_killmail_set(character_id, count: 2_000)

      # Measure memory before operation
      initial_memory = get_memory_usage_mb()

      # Perform large analysis
      {:ok, _stats} = CharacterAnalyzer.analyze_character(character_id)

      # Measure memory after operation
      peak_memory = get_memory_usage_mb()

      # Force cleanup
      :erlang.garbage_collect()
      Process.sleep(500)

      # Measure memory after cleanup
      final_memory = get_memory_usage_mb()

      memory_growth = peak_memory - initial_memory
      memory_retained = final_memory - initial_memory

      # Most memory should be cleaned up
      cleanup_ratio = (memory_growth - memory_retained) / memory_growth
      assert cleanup_ratio > 0.7, "Insufficient memory cleanup: #{cleanup_ratio * 100}%"

      IO.puts(
        "Memory cleanup - Growth: #{memory_growth}MB, Retained: #{memory_retained}MB, Cleanup: #{cleanup_ratio * 100}%"
      )
    end
  end

  # Helper functions for performance testing

  defp get_memory_usage_mb do
    :erlang.memory(:total) / (1024 * 1024)
  end

  defp create_large_killmail_dataset(character_id, count) do
    Enum.map(1..count, fn _i ->
      %{
        "killmail_id" => System.unique_integer([:positive]),
        "killmail_time" => random_datetime_in_past(90) |> DateTime.to_iso8601(),
        "solar_system_id" => Enum.random([30_000_142, 30_001_158, 31_000_005]),
        "participants" => [
          %{
            "character_id" => character_id,
            "is_victim" => Enum.random([true, false]),
            "ship_type_id" => Enum.random([587, 588, 589, 590])
          }
        ]
      }
    end)
  end

  defp create_complex_killmail_data do
    %{
      "killmail_id" => System.unique_integer([:positive]),
      "killmail_time" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "solar_system_id" => 30_000_142,
      # Large fleet fight
      "participants" =>
        Enum.map(1..20, fn i ->
          %{
            "character_id" => 95_000_000 + i,
            "character_name" => "Character #{i}",
            "corporation_id" => 1_000_000 + rem(i, 5),
            "ship_type_id" => Enum.random([587, 588, 589, 590, 591]),
            "is_victim" => i == 1,
            "damage_done" => if(i == 1, do: 0, else: Enum.random(100..2000))
          }
        end),
      "zkb" => %{
        "totalValue" => Enum.random(10_000_000..100_000_000)
      }
    }
  end

  defp create_simple_killmail_data do
    %{
      "killmail_id" => System.unique_integer([:positive]),
      "killmail_time" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "solar_system_id" => 30_000_142,
      "participants" => [
        %{
          "character_id" => Enum.random(95_000_000..96_000_000),
          "is_victim" => false
        },
        %{
          "character_id" => Enum.random(96_000_000..97_000_000),
          "is_victim" => true
        }
      ]
    }
  end

  defp create_character_with_corp(character_id, corporation_id) do
    create(:character_stats, %{
      character_id: character_id,
      corporation_id: corporation_id,
      corporation_name: "Test Corp #{corporation_id}",
      kill_count: Enum.random(10..100),
      loss_count: Enum.random(5..50)
    })
  end

  defp create_time_distributed_killmails(character_id, days_back, total_count) do
    for _i <- 1..total_count do
      days_ago = Enum.random(0..days_back)
      kill_time = DateTime.add(DateTime.utc_now(), -days_ago * 24 * 3600, :second)

      create(:killmail_raw, %{
        raw_data: %{
          "killmail_time" => DateTime.to_iso8601(kill_time),
          "participants" => [
            %{
              "character_id" => character_id,
              "is_victim" => Enum.random([true, false])
            }
          ]
        }
      })
    end
  end

  defp random_datetime_in_past(max_days_ago) do
    seconds_ago = Enum.random(0..(max_days_ago * 24 * 3600))
    DateTime.add(DateTime.utc_now(), -seconds_ago, :second)
  end
end

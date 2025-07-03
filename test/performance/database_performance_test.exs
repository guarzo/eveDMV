defmodule EveDmv.Performance.DatabasePerformanceTest do
  @moduledoc """
  Database performance tests to ensure queries perform within acceptable limits.
  Tests critical database operations under various load conditions.
  """
  use EveDmv.DataCase, async: false

  @moduletag :skip

  alias EveDmv.{Api, Repo}
  alias EveDmv.Intelligence.CharacterAnalysis.CharacterStats
  alias EveDmv.Killmails.{KillmailEnriched, KillmailRaw}

  require Ash.Query

  # milliseconds
  @max_query_time 200
  @max_bulk_insert_time 1000
  @max_complex_query_time 500
  @bulk_insert_size 100

  describe "basic query performance" do
    test "single killmail lookup by ID" do
      # Create test killmail
      killmail_id = 99_000_001
      create(:killmail_raw, %{killmail_id: killmail_id})

      # Test query performance
      {time_microseconds, result} =
        :timer.tc(fn ->
          KillmailRaw
          |> Ash.Query.new()
          |> Ash.Query.filter(killmail_id == ^killmail_id)
          |> Ash.read_one(domain: Api)
        end)

      time_ms = time_microseconds / 1000

      assert {:ok, killmail} = result
      assert killmail.killmail_id == killmail_id
      assert time_ms < @max_query_time, "Single lookup took #{time_ms}ms"
    end

    test "character stats lookup by character ID" do
      character_id = 95_000_100
      create(:character_stats, %{character_id: character_id})

      {time_microseconds, result} =
        :timer.tc(fn ->
          CharacterStats
          |> Ash.Query.new()
          |> Ash.Query.filter(character_id == ^character_id)
          |> Ash.read_one(domain: Api)
        end)

      time_ms = time_microseconds / 1000

      assert {:ok, stats} = result
      assert stats.character_id == character_id
      assert time_ms < @max_query_time, "Character stats lookup took #{time_ms}ms"
    end

    test "recent killmails query with limit" do
      # Create 50 killmails
      for i <- 1..50 do
        create(:killmail_enriched, %{
          killmail_id: 99_100_000 + i,
          killmail_time: DateTime.add(DateTime.utc_now(), -i * 60, :second)
        })
      end

      {time_microseconds, result} =
        :timer.tc(fn ->
          KillmailEnriched
          |> Ash.Query.new()
          |> Ash.Query.sort(killmail_time: :desc)
          |> Ash.Query.limit(20)
          |> Ash.read(domain: Api)
        end)

      time_ms = time_microseconds / 1000

      assert {:ok, killmails} = result
      assert length(killmails) == 20
      assert time_ms < @max_query_time, "Recent killmails query took #{time_ms}ms"
    end
  end

  describe "complex query performance" do
    test "character killmail aggregation query" do
      character_id = 95_000_200

      # Create 30 killmails for character
      for i <- 1..30 do
        create(:killmail_raw, %{
          killmail_id: 99_200_000 + i,
          killmail_time: DateTime.add(DateTime.utc_now(), -i * 3600, :second),
          killmail_data: build_character_killmail_data(character_id, rem(i, 3) == 0)
        })
      end

      {time_microseconds, result} =
        :timer.tc(fn ->
          # Simulate character analysis aggregation query
          query = """
          SELECT 
            COUNT(*) as total_kills,
            COUNT(CASE WHEN km.killmail_data->'victim'->>'character_id' = $1 THEN 1 END) as losses,
            COUNT(CASE WHEN EXISTS(
              SELECT 1 FROM jsonb_array_elements(km.killmail_data->'attackers') attacker 
              WHERE attacker->>'character_id' = $1
            ) THEN 1 END) as kills
          FROM killmails_raw km
          WHERE km.killmail_data->'victim'->>'character_id' = $1
             OR EXISTS(
               SELECT 1 FROM jsonb_array_elements(km.killmail_data->'attackers') attacker 
               WHERE attacker->>'character_id' = $1
             )
          """

          Ecto.Adapters.SQL.query!(Repo, query, [to_string(character_id)])
        end)

      time_ms = time_microseconds / 1000

      assert result.num_rows == 1
      assert time_ms < @max_complex_query_time, "Character aggregation took #{time_ms}ms"
    end

    test "system activity aggregation query" do
      system_id = 30_000_142

      # Create killmails in system
      for i <- 1..40 do
        create(:killmail_enriched, %{
          killmail_id: 99_300_000 + i,
          solar_system_id: system_id,
          killmail_time: DateTime.add(DateTime.utc_now(), -i * 1800, :second),
          total_value: Enum.random(1_000_000..100_000_000)
        })
      end

      {time_microseconds, result} =
        :timer.tc(fn ->
          query = """
          SELECT 
            solar_system_id,
            COUNT(*) as kill_count,
            SUM(total_value) as total_isk,
            AVG(total_value) as avg_isk,
            MAX(killmail_time) as latest_kill
          FROM killmails_enriched 
          WHERE solar_system_id = $1
            AND killmail_time >= $2
          GROUP BY solar_system_id
          """

          Ecto.Adapters.SQL.query!(Repo, query, [
            system_id,
            DateTime.add(DateTime.utc_now(), -86_400, :second)
          ])
        end)

      time_ms = time_microseconds / 1000

      assert result.num_rows == 1
      [row] = result.rows
      [^system_id, kill_count, _total_isk, _avg_isk, _latest] = row
      assert kill_count > 0
      assert time_ms < @max_complex_query_time, "System aggregation took #{time_ms}ms"
    end

    test "time-based partitioned query performance" do
      # Test queries across partitioned tables
      current_month = Date.beginning_of_month(Date.utc_today())
      last_month = Date.add(current_month, -1)

      # Create killmails across multiple months
      for i <- 1..30 do
        month_offset = if i <= 15, do: 0, else: -30
        kill_time = DateTime.add(DateTime.utc_now(), month_offset * 86_400, :second)

        create(:killmail_raw, %{
          killmail_id: 99_400_000 + i,
          killmail_time: kill_time
        })
      end

      {time_microseconds, result} =
        :timer.tc(fn ->
          query = """
          SELECT 
            DATE_TRUNC('month', killmail_time) as month,
            COUNT(*) as kill_count
          FROM killmails_raw 
          WHERE killmail_time >= $1
          GROUP BY DATE_TRUNC('month', killmail_time)
          ORDER BY month
          """

          Ecto.Adapters.SQL.query!(Repo, query, [
            DateTime.add(DateTime.utc_now(), -60 * 86_400, :second)
          ])
        end)

      time_ms = time_microseconds / 1000

      assert result.num_rows >= 1
      assert time_ms < @max_complex_query_time, "Partitioned query took #{time_ms}ms"
    end
  end

  describe "bulk operations performance" do
    test "bulk killmail insertion" do
      killmails =
        for i <- 1..@bulk_insert_size do
          %{
            killmail_id: 99_500_000 + i,
            killmail_time: DateTime.add(DateTime.utc_now(), -i * 60, :second),
            solar_system_id: 30_000_142,
            killmail_data: %{
              "killmail_id" => 99_500_000 + i,
              "victim" => %{"character_id" => 95_000_000 + i},
              "attackers" => [%{"character_id" => 95_100_000 + i}]
            },
            source: "performance_test"
          }
        end

      {time_microseconds, result} =
        :timer.tc(fn ->
          Ash.bulk_create(killmails, KillmailRaw, :create,
            domain: Api,
            return_errors?: false,
            batch_size: 50
          )
        end)

      time_ms = time_microseconds / 1000

      assert {:ok, _} = result
      assert time_ms < @max_bulk_insert_time, "Bulk insert took #{time_ms}ms"

      # Verify all records were inserted
      count_query =
        KillmailRaw
        |> Ash.Query.new()
        |> Ash.Query.filter(
          killmail_id >= 99_500_001 and killmail_id <= 99_500_000 + @bulk_insert_size
        )

      assert {:ok, inserted} = Ash.read(count_query, domain: Api)
      assert length(inserted) == @bulk_insert_size
    end

    test "bulk character stats update" do
      character_ids = for i <- 1..50, do: 95_000_300 + i

      # Create initial stats
      initial_stats =
        for character_id <- character_ids do
          %{
            character_id: character_id,
            dangerous_rating: 0,
            kill_count: 0,
            loss_count: 0,
            analysis_data: "{}"
          }
        end

      # Insert initial data
      {:ok, _} =
        Ash.bulk_create(initial_stats, CharacterStats, :create,
          domain: Api,
          return_errors?: false
        )

      # Update all stats
      updates =
        for character_id <- character_ids do
          %{
            character_id: character_id,
            dangerous_rating: Enum.random(1..5),
            kill_count: Enum.random(10..100),
            loss_count: Enum.random(1..20)
          }
        end

      {time_microseconds, result} =
        :timer.tc(fn ->
          Ash.bulk_update(CharacterStats, :update, updates,
            domain: Api,
            return_errors?: false,
            batch_size: 25
          )
        end)

      time_ms = time_microseconds / 1000

      assert {:ok, _} = result
      assert time_ms < @max_bulk_insert_time, "Bulk update took #{time_ms}ms"
    end
  end

  describe "concurrent access performance" do
    test "concurrent read performance" do
      # Create test data
      for i <- 1..100 do
        create(:killmail_enriched, %{
          killmail_id: 99_600_000 + i,
          killmail_time: DateTime.utc_now()
        })
      end

      # Test concurrent reads
      {time_microseconds, results} =
        :timer.tc(fn ->
          tasks =
            for _i <- 1..10 do
              Task.async(fn ->
                KillmailEnriched
                |> Ash.Query.new()
                |> Ash.Query.sort(killmail_time: :desc)
                |> Ash.Query.limit(20)
                |> Ash.read(domain: Api)
              end)
            end

          Task.await_many(tasks, 5000)
        end)

      time_ms = time_microseconds / 1000

      # All queries should succeed
      assert Enum.all?(results, fn
               {:ok, killmails} -> length(killmails) == 20
               _ -> false
             end)

      # Average time per query should be reasonable
      avg_time_per_query = time_ms / 10

      assert avg_time_per_query < @max_query_time * 2,
             "Concurrent reads averaged #{avg_time_per_query}ms per query"
    end

    test "mixed read/write performance" do
      # Test system under mixed load
      tasks = [
        # Reader tasks
        Task.async(fn ->
          for _i <- 1..5 do
            KillmailEnriched
            |> Ash.Query.new()
            |> Ash.Query.limit(10)
            |> Ash.read(domain: Api)

            :timer.sleep(50)
          end
        end),

        # Writer task
        Task.async(fn ->
          for i <- 1..10 do
            create(:killmail_raw, %{
              killmail_id: 99_700_000 + i,
              killmail_time: DateTime.utc_now()
            })

            :timer.sleep(25)
          end
        end),

        # Analytics task
        Task.async(fn ->
          for _i <- 1..3 do
            query = """
            SELECT COUNT(*) FROM killmails_enriched 
            WHERE killmail_time >= $1
            """

            Ecto.Adapters.SQL.query!(Repo, query, [
              DateTime.add(DateTime.utc_now(), -3600, :second)
            ])

            :timer.sleep(100)
          end
        end)
      ]

      {time_microseconds, _results} =
        :timer.tc(fn ->
          Task.await_many(tasks, 10_000)
        end)

      time_ms = time_microseconds / 1000

      # Mixed workload should complete within reasonable time
      assert time_ms < 2000, "Mixed workload took #{time_ms}ms"
    end
  end

  describe "index performance" do
    test "character_id index effectiveness" do
      character_id = 95_000_400

      # Create many killmails for different characters
      for i <- 1..200 do
        char_id = if rem(i, 10) == 0, do: character_id, else: 95_000_000 + i

        create(:killmail_raw, %{
          killmail_id: 99_800_000 + i,
          killmail_data: %{
            "victim" => %{"character_id" => char_id},
            "attackers" => [%{"character_id" => char_id + 1000}]
          }
        })
      end

      # Query should be fast due to index
      {time_microseconds, result} =
        :timer.tc(fn ->
          query = """
          SELECT COUNT(*) FROM killmails_raw 
          WHERE killmail_data->'victim'->>'character_id' = $1
          """

          Ecto.Adapters.SQL.query!(Repo, query, [to_string(character_id)])
        end)

      time_ms = time_microseconds / 1000

      assert result.num_rows == 1
      assert time_ms < @max_query_time, "Indexed character query took #{time_ms}ms"
    end

    test "time-based index performance" do
      # Create killmails across time range
      base_time = DateTime.utc_now()

      for i <- 1..150 do
        # Hours back
        time_offset = -i * 3600
        kill_time = DateTime.add(base_time, time_offset, :second)

        create(:killmail_enriched, %{
          killmail_id: 99_900_000 + i,
          killmail_time: kill_time
        })
      end

      # Time-range query should be fast
      {time_microseconds, result} =
        :timer.tc(fn ->
          start_time = DateTime.add(base_time, -24 * 3600, :second)
          end_time = DateTime.add(base_time, -12 * 3600, :second)

          KillmailEnriched
          |> Ash.Query.new()
          |> Ash.Query.filter(killmail_time >= ^start_time and killmail_time <= ^end_time)
          |> Ash.read(domain: Api)
        end)

      time_ms = time_microseconds / 1000

      assert {:ok, killmails} = result
      assert length(killmails) > 0
      assert time_ms < @max_query_time, "Time-range query took #{time_ms}ms"
    end
  end

  describe "memory usage during operations" do
    test "memory efficiency of large result sets" do
      # Create large dataset
      for i <- 1..500 do
        create(:killmail_enriched, %{
          killmail_id: 99_950_000 + i,
          killmail_time: DateTime.utc_now()
        })
      end

      # Get initial memory usage
      :erlang.garbage_collect()
      initial_memory = :erlang.memory(:processes)

      # Perform memory-intensive operation
      {:ok, _killmails} =
        KillmailEnriched
        |> Ash.Query.new()
        |> Ash.Query.limit(500)
        |> Ash.read(domain: Api)

      # Check memory usage
      :erlang.garbage_collect()
      final_memory = :erlang.memory(:processes)
      memory_growth = final_memory - initial_memory

      # Memory growth should be reasonable (less than 50MB)
      assert memory_growth < 50_000_000,
             "Memory grew by #{memory_growth / 1_000_000}MB for large query"
    end
  end

  # Helper functions

  defp build_character_killmail_data(character_id, is_victim) do
    if is_victim do
      %{
        "victim" => %{"character_id" => character_id},
        "attackers" => [%{"character_id" => Enum.random(90_000_000..95_000_000)}]
      }
    else
      %{
        "victim" => %{"character_id" => Enum.random(90_000_000..95_000_000)},
        "attackers" => [%{"character_id" => character_id}]
      }
    end
  end
end

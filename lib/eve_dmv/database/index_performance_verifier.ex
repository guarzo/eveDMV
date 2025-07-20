defmodule EveDmv.Database.IndexPerformanceVerifier do
  @moduledoc """
  Verifies the effectiveness of database indexes using EXPLAIN queries.

  This module is used to validate that the Sprint 17 DB-002 performance indexes
  are being utilized correctly by PostgreSQL query planner.
  """

  require Logger
  alias EveDmv.Repo

  @doc """
  Runs EXPLAIN ANALYZE on common battle detection queries to verify index usage.

  Returns a report of index effectiveness for each query type.
  """
  def verify_battle_detection_indexes do
    Logger.info("Starting index performance verification for battle detection")

    # First check if the tables exist
    if not table_exists?("killmails_raw") do
      Logger.warning("Table killmails_raw does not exist yet")

      %{
        summary: %{
          total_queries: 0,
          passed: 0,
          failed: 0,
          errors: 0,
          success_rate: 0.0
        },
        details: [],
        recommendations: ["Table killmails_raw does not exist. Run migrations first."]
      }
    else
      queries = [
        # Spatial-temporal query for battle detection
        {
          "Battle detection by system and time",
          """
          EXPLAIN (ANALYZE, BUFFERS)
          SELECT killmail_id, killmail_time, solar_system_id
          FROM killmails_raw
          WHERE killmail_time BETWEEN '2024-01-01 00:00:00' AND '2024-01-01 01:00:00'
            AND solar_system_id = 30002765
          ORDER BY killmail_time
          """,
          "killmails_raw_time_system_idx"
        },

        # Character activity tracking
        {
          "Character activity timeline",
          """
          EXPLAIN (ANALYZE, BUFFERS)
          SELECT killmail_id, killmail_time, victim_character_id
          FROM killmails_raw
          WHERE victim_character_id = 12345
            AND killmail_time >= '2024-01-01 00:00:00'
          ORDER BY killmail_time DESC
          LIMIT 100
          """,
          "killmails_raw_character_activity_idx"
        },

        # Corporation/Alliance affiliation query
        {
          "Corporation and alliance affiliation",
          """
          EXPLAIN (ANALYZE, BUFFERS)
          SELECT COUNT(*) as kill_count
          FROM killmails_raw
          WHERE victim_corporation_id = 98765
            AND victim_alliance_id = 99999
          """,
          "killmails_raw_corp_alliance_idx"
        },

        # Complex affiliation with time
        {
          "Corporation activity over time",
          """
          EXPLAIN (ANALYZE, BUFFERS)
          SELECT DATE_TRUNC('hour', killmail_time) as hour, COUNT(*) as kills
          FROM killmails_raw
          WHERE victim_corporation_id = 98765
            AND victim_alliance_id = 99999
            AND killmail_time BETWEEN '2024-01-01 00:00:00' AND '2024-01-02 00:00:00'
          GROUP BY hour
          ORDER BY hour
          """,
          "killmails_raw_corp_alliance_time_idx"
        },

        # Participant activity tracking
        {
          "Participant character activity",
          """
          EXPLAIN (ANALYZE, BUFFERS)
          SELECT killmail_id, character_id, killmail_time
          FROM participants
          WHERE character_id = 12345
            AND killmail_time >= '2024-01-01 00:00:00'
          ORDER BY killmail_time DESC
          """,
          "participants_character_activity_idx"
        },

        # Battle system lookup (if table exists)
        {
          "Battle system and time lookup",
          """
          EXPLAIN (ANALYZE, BUFFERS)
          SELECT battle_id, system_id, start_time
          FROM battles
          WHERE system_id = 30002765
            AND start_time >= '2024-01-01 00:00:00'
            AND deleted_at IS NULL
          ORDER BY start_time
          """,
          "battles_system_time_idx"
        }
      ]

      results = Enum.map(queries, &verify_query/1)

      generate_report(results)
    end
  end

  @doc """
  Verifies a single query and checks if the expected index is being used.
  """
  def verify_query({description, query, expected_index}) do
    Logger.debug("Verifying query: #{description}")

    try do
      result = Repo.query!(query)

      # Parse EXPLAIN output
      explain_text = result.rows |> List.flatten() |> Enum.join("\n")

      # Check if expected index is used
      index_used = String.contains?(explain_text, expected_index)

      # Extract performance metrics
      metrics = extract_performance_metrics(explain_text)

      %{
        description: description,
        expected_index: expected_index,
        index_used: index_used,
        metrics: metrics,
        explain_output: explain_text,
        status: if(index_used, do: :pass, else: :fail)
      }
    rescue
      error ->
        Logger.error("Error verifying query #{description}: #{inspect(error)}")

        %{
          description: description,
          expected_index: expected_index,
          index_used: false,
          error: Exception.message(error),
          status: :error
        }
    end
  end

  @doc """
  Runs a simple benchmark comparing query performance with and without indexes.
  """
  def benchmark_index_performance do
    Logger.info("Starting index performance benchmark")

    # Test queries that should benefit from indexes
    queries = [
      {
        "Battle detection query",
        """
        SELECT k.killmail_id, k.killmail_time, k.solar_system_id
        FROM killmails_raw k
        WHERE k.killmail_time BETWEEN $1 AND $2
          AND k.solar_system_id = $3
        ORDER BY k.killmail_time
        """,
        [~N[2024-01-01 00:00:00], ~N[2024-01-01 01:00:00], 30_002_765]
      },
      {
        "Character activity query",
        """
        SELECT k.killmail_id, k.killmail_time
        FROM killmails_raw k
        WHERE k.victim_character_id = $1
          AND k.killmail_time >= $2
        ORDER BY k.killmail_time DESC
        LIMIT 100
        """,
        [12345, ~N[2024-01-01 00:00:00]]
      }
    ]

    Enum.map(queries, &benchmark_query/1)
  end

  # Private helper functions

  defp benchmark_query({description, query, params}) do
    Logger.debug("Benchmarking: #{description}")

    # Run query multiple times to get average
    times =
      for _ <- 1..5 do
        {time, _result} =
          :timer.tc(fn ->
            Repo.query!(query, params)
          end)

        time
      end

    # Convert to ms
    avg_time = Enum.sum(times) / length(times) / 1000

    %{
      description: description,
      avg_execution_time_ms: Float.round(avg_time, 2),
      min_time_ms: Float.round(Enum.min(times) / 1000, 2),
      max_time_ms: Float.round(Enum.max(times) / 1000, 2)
    }
  end

  defp extract_performance_metrics(explain_text) do
    # Extract key metrics from EXPLAIN ANALYZE output
    planning_time = extract_metric(explain_text, ~r/Planning Time: ([\d.]+) ms/)
    execution_time = extract_metric(explain_text, ~r/Execution Time: ([\d.]+) ms/)

    # Check for sequential scans
    has_seq_scan = String.contains?(explain_text, "Seq Scan")

    # Check for index scans
    index_scans =
      Regex.scan(~r/Index Scan|Index Only Scan|Bitmap Index Scan/, explain_text)
      |> length()

    %{
      planning_time_ms: planning_time,
      execution_time_ms: execution_time,
      total_time_ms: Float.round((planning_time || 0) + (execution_time || 0), 2),
      has_sequential_scan: has_seq_scan,
      index_scan_count: index_scans
    }
  end

  defp extract_metric(text, regex) do
    case Regex.run(regex, text) do
      [_, value] ->
        case Float.parse(value) do
          {float_val, _} -> Float.round(float_val, 2)
          :error -> nil
        end

      _ ->
        nil
    end
  end

  defp generate_report(results) do
    total_queries = length(results)
    passed = Enum.count(results, &(&1.status == :pass))
    failed = Enum.count(results, &(&1.status == :fail))
    errors = Enum.count(results, &(&1.status == :error))

    report = %{
      summary: %{
        total_queries: total_queries,
        passed: passed,
        failed: failed,
        errors: errors,
        success_rate: Float.round(passed / total_queries * 100, 1)
      },
      details: results,
      recommendations: generate_recommendations(results)
    }

    Logger.info("""
    Index Performance Verification Complete:
    - Total Queries: #{total_queries}
    - Passed: #{passed} (#{report.summary.success_rate}%)
    - Failed: #{failed}
    - Errors: #{errors}
    """)

    report
  end

  defp generate_recommendations(results) do
    recommendations = []

    # Check for missing indexes
    failed_queries = Enum.filter(results, &(&1.status == :fail))

    recommendations =
      if length(failed_queries) > 0 do
        [
          "#{length(failed_queries)} queries are not using expected indexes. Review query plans."
          | recommendations
        ]
      else
        recommendations
      end

    # Check for slow queries
    slow_queries =
      results
      |> Enum.filter(
        &(&1[:metrics] && &1.metrics[:total_time_ms] && &1.metrics.total_time_ms > 100)
      )

    recommendations =
      if length(slow_queries) > 0 do
        [
          "#{length(slow_queries)} queries are taking over 100ms. Consider additional optimization."
          | recommendations
        ]
      else
        recommendations
      end

    # Check for sequential scans
    seq_scan_queries =
      results
      |> Enum.filter(&(&1[:metrics] && &1.metrics[:has_sequential_scan]))

    recommendations =
      if length(seq_scan_queries) > 0 do
        [
          "#{length(seq_scan_queries)} queries are using sequential scans. May need additional indexes."
          | recommendations
        ]
      else
        recommendations
      end

    if Enum.empty?(recommendations) do
      ["All indexes are performing optimally!"]
    else
      recommendations
    end
  end

  defp table_exists?(table_name) do
    query = "SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = $1)"

    case Repo.query(query, [table_name]) do
      {:ok, %{rows: [[true]]}} -> true
      _ -> false
    end
  end
end

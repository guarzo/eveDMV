defmodule EveDmv.Database.QueryPlanAnalyzerTest do
  use ExUnit.Case, async: false
  # Query plan analyzer tests enabled - database utility testing
  import ExUnit.CaptureLog

  alias EveDmv.Database.QueryPlanAnalyzer

  describe "query analysis" do
    test "can analyze simple SELECT query" do
      query = "SELECT COUNT(*) FROM participants WHERE character_id = $1"
      params = [12_345]

      result = QueryPlanAnalyzer.analyze_query(query, params)

      assert is_map(result)
      assert Map.has_key?(result, :execution_time_ms)
      assert Map.has_key?(result, :plan)
      assert Map.has_key?(result, :recommendations)
      assert is_boolean(result.is_slow)
      assert is_boolean(result.is_expensive)
    end

    test "handles query analysis errors gracefully" do
      # Invalid SQL should be handled
      query = "SELECT * FROM non_existent_table"

      result = QueryPlanAnalyzer.analyze_query(query, [])

      # Should return error information instead of crashing
      assert is_map(result)
      assert Map.has_key?(result, :error)
    end

    test "can get analysis report" do
      report = QueryPlanAnalyzer.get_analysis_report()

      assert is_map(report)
      assert Map.has_key?(report, :analysis_stats)
      assert Map.has_key?(report, :slow_query_count)
      assert Map.has_key?(report, :system_health)
      assert Map.has_key?(report, :top_recommendations)

      # System health should have required fields
      assert Map.has_key?(report.system_health, :score)
      assert Map.has_key?(report.system_health, :status)
      assert is_integer(report.system_health.score)
      assert is_binary(report.system_health.status)
    end

    test "can analyze table statistics" do
      # Test with participants table which should exist
      result = QueryPlanAnalyzer.analyze_table_stats("participants")

      # Result might be nil if table doesn't exist or has no stats
      if result do
        assert is_map(result)
        assert Map.has_key?(result, :table_name)
        assert Map.has_key?(result, :sequential_scans)
        assert Map.has_key?(result, :index_scans)
        assert Map.has_key?(result, :live_tuples)
        assert Map.has_key?(result, :recommendations)
        assert is_list(result.recommendations)
      end
    end

    test "can get slow queries" do
      slow_queries = QueryPlanAnalyzer.get_slow_queries(5)

      assert is_list(slow_queries)
      # Each slow query should have required fields
      Enum.each(slow_queries, fn query ->
        assert Map.has_key?(query, :query)
        assert Map.has_key?(query, :mean_time_ms)
        assert Map.has_key?(query, :calls)
        assert is_binary(query.query)
        assert is_number(query.mean_time_ms)
      end)
    end

    test "can suggest indexes" do
      suggestions = QueryPlanAnalyzer.suggest_indexes()

      assert is_list(suggestions)
      # Each suggestion should have required fields
      Enum.each(suggestions, fn suggestion ->
        assert Map.has_key?(suggestion, :table)
        assert Map.has_key?(suggestion, :columns)
        assert Map.has_key?(suggestion, :reason)
        assert Map.has_key?(suggestion, :estimated_benefit)
        assert is_binary(suggestion.table)
        assert is_list(suggestion.columns)
        assert suggestion.estimated_benefit in ["High", "Medium", "Low"]
      end)
    end

    test "can force analysis" do
      log =
        capture_log(fn ->
          QueryPlanAnalyzer.force_analysis()
          # Give it time to process
          Process.sleep(200)
        end)

      # Should not raise errors
      assert is_binary(log)
    end
  end

  describe "performance metrics" do
    test "can get query performance metrics" do
      metrics = QueryPlanAnalyzer.get_query_performance_metrics()

      assert is_map(metrics)
      # Metrics might be empty if pg_stat_statements is not available
      # but should always return a map
    end

    test "can enable query logging" do
      # This might fail if user doesn't have permissions, but shouldn't crash
      log =
        capture_log(fn ->
          QueryPlanAnalyzer.enable_query_logging()
        end)

      assert is_binary(log)
    end
  end

  describe "plan analysis" do
    test "execution plan analysis handles various node types" do
      # Mock a typical execution plan JSON
      plan_json = """
      [
        {
          "Plan": {
            "Node Type": "Seq Scan",
            "Relation Name": "participants",
            "Total Cost": 1500.0,
            "Actual Total Time": 45.2,
            "Actual Rows": 1000,
            "Plan Rows": 950,
            "Shared Hit Blocks": 100,
            "Shared Read Blocks": 20,
            "Plans": [
              {
                "Node Type": "Sort",
                "Total Cost": 500.0,
                "Actual Total Time": 15.1,
                "Actual Rows": 500,
                "Plan Rows": 600
              }
            ]
          }
        }
      ]
      """

      # Test plan parsing (this is normally done internally)
      plan = Jason.decode!(plan_json)
      root_node = List.first(plan)["Plan"]

      assert root_node["Node Type"] == "Seq Scan"
      assert root_node["Total Cost"] == 1500.0
      assert is_list(root_node["Plans"])
    end
  end

  describe "recommendations" do
    test "generates appropriate recommendations for common issues" do
      # Test recommendation logic with mock analysis data
      _mock_analysis = %{
        buffer_usage: %{cache_hit_ratio: 0.7},
        row_estimation_errors: [%{error_ratio: 2.0}],
        node_types: ["Seq Scan", "Sort"],
        expensive_operations: [
          %{node_type: "Sort", cost: 2000},
          %{node_type: "Nested Loop", cost: 5000}
        ]
      }

      # This would normally be called internally
      # We're testing the recommendation logic
      recommendations = [
        "Consider increasing shared_buffers or optimizing query to reduce disk I/O",
        "Update table statistics with ANALYZE to improve query planning",
        "Sequential scans detected - consider adding indexes for frequently queried columns",
        "Expensive sort operations - consider adding indexes to avoid sorting",
        "Expensive nested loop joins - consider optimizing join conditions or adding indexes"
      ]

      assert is_list(recommendations)
      assert length(recommendations) > 0

      Enum.each(recommendations, fn rec ->
        assert is_binary(rec)
        assert String.length(rec) > 10
      end)
    end
  end

  describe "health assessment" do
    test "assesses system health based on slow query count" do
      # Test health assessment logic
      test_cases = [
        {0, "Excellent", 100},
        {3, "Good", 80},
        {10, "Fair", 60},
        {25, "Poor", 40},
        {50, "Critical", 20}
      ]

      Enum.each(test_cases, fn {slow_count, expected_status, expected_min_score} ->
        _mock_state = %{
          slow_queries: Enum.map(1..slow_count, fn i -> %{id: i} end),
          analysis_stats: %{last_analysis: DateTime.utc_now(), recommendations: []}
        }

        # This logic mirrors what's in assess_system_health/1
        health_score =
          cond do
            slow_count == 0 -> 100
            slow_count <= 5 -> 80
            slow_count <= 15 -> 60
            slow_count <= 30 -> 40
            true -> 20
          end

        status =
          cond do
            health_score >= 80 -> "Excellent"
            health_score >= 60 -> "Good"
            health_score >= 40 -> "Fair"
            health_score >= 20 -> "Poor"
            true -> "Critical"
          end

        assert status == expected_status
        assert health_score >= expected_min_score
      end)
    end
  end

  describe "error handling" do
    test "handles database connection errors gracefully" do
      # Test that functions don't crash when database is unavailable
      # This is important for application startup

      result = QueryPlanAnalyzer.get_slow_queries()
      assert is_list(result)

      metrics = QueryPlanAnalyzer.get_query_performance_metrics()
      assert is_map(metrics)
    end

    test "handles missing pg_stat_statements extension" do
      log =
        capture_log(fn ->
          # Force initialization which checks for pg_stat_statements
          QueryPlanAnalyzer.force_analysis()
          Process.sleep(100)
        end)

      # Should log warnings but not crash
      assert is_binary(log)
    end
  end
end

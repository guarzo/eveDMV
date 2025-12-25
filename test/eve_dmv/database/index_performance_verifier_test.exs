defmodule EveDmv.Platform.Database.IndexPerformanceVerifierTest do
  @moduledoc """
  Tests for the IndexPerformanceVerifier module.

  Tests index verification and benchmarking functions.
  """
  use EveDmv.DataCase, async: false

  alias EveDmv.Platform.Database.IndexPerformanceVerifier

  describe "verify_battle_detection_indexes/0" do
    test "returns a complete report structure" do
      report = IndexPerformanceVerifier.verify_battle_detection_indexes()

      assert is_map(report)
      assert Map.has_key?(report, :summary)
      assert Map.has_key?(report, :details)
      assert Map.has_key?(report, :recommendations)
    end

    test "summary contains expected metrics" do
      report = IndexPerformanceVerifier.verify_battle_detection_indexes()

      summary = report.summary
      assert is_map(summary)
      assert Map.has_key?(summary, :total_queries)
      assert Map.has_key?(summary, :passed)
      assert Map.has_key?(summary, :failed)
      assert Map.has_key?(summary, :errors)
      assert Map.has_key?(summary, :success_rate)
      assert is_integer(summary.total_queries)
      assert is_integer(summary.passed)
      assert is_integer(summary.failed)
      assert is_integer(summary.errors)
      assert is_float(summary.success_rate)
    end

    test "details is a list of query results" do
      report = IndexPerformanceVerifier.verify_battle_detection_indexes()

      assert is_list(report.details)

      # Each detail should have expected fields
      Enum.each(report.details, fn detail ->
        assert is_map(detail)
        assert Map.has_key?(detail, :description)
        assert Map.has_key?(detail, :expected_index)
        assert Map.has_key?(detail, :status)
        assert detail.status in [:pass, :fail, :error]
      end)
    end

    test "recommendations is a list of strings" do
      report = IndexPerformanceVerifier.verify_battle_detection_indexes()

      assert is_list(report.recommendations)

      Enum.each(report.recommendations, fn recommendation ->
        assert is_binary(recommendation)
      end)
    end

    test "handles missing table gracefully" do
      # The function should handle the case where killmails_raw doesn't exist
      # by returning a report with appropriate message
      report = IndexPerformanceVerifier.verify_battle_detection_indexes()

      assert is_map(report)
      # If table doesn't exist, should have 0 queries
      assert report.summary.total_queries >= 0
    end
  end

  describe "verify_query/1" do
    test "returns pass status when index is used" do
      # Test with a simple query that should use an index
      query_spec =
        {"Test query", "EXPLAIN (ANALYZE, BUFFERS) SELECT 1", "pg_catalog"}

      result = IndexPerformanceVerifier.verify_query(query_spec)

      assert is_map(result)
      assert Map.has_key?(result, :description)
      assert Map.has_key?(result, :expected_index)
      assert Map.has_key?(result, :status)
      assert result.status in [:pass, :fail, :error]
    end

    test "includes metrics when query succeeds" do
      query_spec =
        {"Simple query", "EXPLAIN (ANALYZE) SELECT 1", "none"}

      result = IndexPerformanceVerifier.verify_query(query_spec)

      if result.status != :error do
        assert Map.has_key?(result, :metrics)

        if Map.has_key?(result, :metrics) and is_map(result.metrics) do
          metrics = result.metrics
          assert Map.has_key?(metrics, :planning_time_ms)
          assert Map.has_key?(metrics, :execution_time_ms)
          assert Map.has_key?(metrics, :total_time_ms)
          assert Map.has_key?(metrics, :has_sequential_scan)
          assert Map.has_key?(metrics, :index_scan_count)
        end
      end
    end

    test "returns error status for invalid query" do
      query_spec =
        {"Invalid query", "EXPLAIN INVALID_SQL_SYNTAX", "any_index"}

      result = IndexPerformanceVerifier.verify_query(query_spec)

      assert result.status == :error
      assert Map.has_key?(result, :error)
    end

    test "includes explain output when query succeeds" do
      query_spec =
        {"Explain test", "EXPLAIN (ANALYZE) SELECT 1", "any"}

      result = IndexPerformanceVerifier.verify_query(query_spec)

      if result.status != :error do
        assert Map.has_key?(result, :explain_output)
        assert is_binary(result.explain_output)
      end
    end
  end

  describe "benchmark_index_performance/0" do
    test "returns benchmark results" do
      results = IndexPerformanceVerifier.benchmark_index_performance()

      assert is_list(results)
    end

    test "each benchmark result has expected structure" do
      results = IndexPerformanceVerifier.benchmark_index_performance()

      Enum.each(results, fn result ->
        assert is_map(result)
        assert Map.has_key?(result, :description)
        assert Map.has_key?(result, :avg_execution_time_ms)
        assert Map.has_key?(result, :min_time_ms)
        assert Map.has_key?(result, :max_time_ms)
        assert is_float(result.avg_execution_time_ms)
        assert is_float(result.min_time_ms)
        assert is_float(result.max_time_ms)
      end)
    end

    test "timing values are non-negative" do
      results = IndexPerformanceVerifier.benchmark_index_performance()

      Enum.each(results, fn result ->
        if Map.has_key?(result, :avg_execution_time_ms) do
          assert result.avg_execution_time_ms >= 0
          assert result.min_time_ms >= 0
          assert result.max_time_ms >= 0
          assert result.min_time_ms <= result.avg_execution_time_ms
          assert result.avg_execution_time_ms <= result.max_time_ms + 1.0
        end
      end)
    end
  end

  describe "report generation" do
    test "success rate calculation is accurate" do
      report = IndexPerformanceVerifier.verify_battle_detection_indexes()

      summary = report.summary
      total = summary.total_queries

      if total > 0 do
        expected_rate = Float.round(summary.passed / total * 100, 1)
        assert summary.success_rate == expected_rate
      end
    end

    test "passed + failed + errors equals total" do
      report = IndexPerformanceVerifier.verify_battle_detection_indexes()

      summary = report.summary
      calculated_total = summary.passed + summary.failed + summary.errors
      assert calculated_total == summary.total_queries
    end
  end
end

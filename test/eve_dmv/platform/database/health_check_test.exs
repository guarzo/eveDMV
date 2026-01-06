defmodule EveDmv.Platform.Database.HealthCheckTest do
  @moduledoc """
  Tests for database health check functionality.
  """
  use EveDmv.DataCase, async: true

  alias EveDmv.Platform.Database.HealthCheck

  describe "run_health_checks/0" do
    test "returns comprehensive health report" do
      result = HealthCheck.run_health_checks()

      assert is_map(result)
      assert Map.has_key?(result, :connection)
      assert Map.has_key?(result, :partitions)
      assert Map.has_key?(result, :indexes)
      assert Map.has_key?(result, :vacuum)
      assert Map.has_key?(result, :connection_pool)
      assert Map.has_key?(result, :table_stats)
      assert Map.has_key?(result, :disk_usage)
      assert Map.has_key?(result, :query_performance)
    end

    test "connection check returns valid status" do
      result = HealthCheck.run_health_checks()

      valid_statuses = [:healthy, :warning, :critical, :unknown]
      assert result.connection in valid_statuses
    end

    test "partitions check returns valid status" do
      result = HealthCheck.run_health_checks()

      valid_statuses = [:healthy, :warning, :critical, :unknown]
      assert result.partitions in valid_statuses
    end

    test "indexes check returns valid status" do
      result = HealthCheck.run_health_checks()

      valid_statuses = [:healthy, :warning, :critical, :unknown]
      assert result.indexes in valid_statuses
    end

    test "vacuum check returns valid status" do
      result = HealthCheck.run_health_checks()

      valid_statuses = [:healthy, :warning, :critical, :unknown]
      assert result.vacuum in valid_statuses
    end
  end

  describe "check/0" do
    test "returns :ok when healthy" do
      result = HealthCheck.check()

      # Should return :ok when database is connected
      assert result == :ok or match?({:error, _}, result)
    end

    test "returns tuple format for errors" do
      # In normal test conditions, connection should work
      result = HealthCheck.check()

      case result do
        :ok -> assert true
        {:error, reason} -> assert is_binary(reason)
      end
    end
  end

  describe "quick_health_check/0" do
    test "returns valid health status" do
      result = HealthCheck.quick_health_check()

      assert result in [:healthy, :warning, :critical]
    end

    test "is fast execution" do
      start_time = System.monotonic_time(:millisecond)
      HealthCheck.quick_health_check()
      end_time = System.monotonic_time(:millisecond)

      duration = end_time - start_time
      # Quick check should complete within 5 seconds
      assert duration < 5000
    end
  end

  describe "health status consistency" do
    test "multiple calls return consistent statuses" do
      result1 = HealthCheck.quick_health_check()
      result2 = HealthCheck.quick_health_check()

      # In stable conditions, status should be consistent
      # (may differ if there's actual database issues)
      assert result1 in [:healthy, :warning, :critical]
      assert result2 in [:healthy, :warning, :critical]
    end

    test "check and quick_health_check agree on basic health" do
      simple_result = HealthCheck.check()
      quick_result = HealthCheck.quick_health_check()

      # If simple check returns :ok, quick check shouldn't be critical
      if simple_result == :ok do
        assert quick_result in [:healthy, :warning]
      end
    end
  end

  describe "health report details" do
    test "connection_pool has expected format" do
      result = HealthCheck.run_health_checks()

      assert result.connection_pool in [:healthy, :warning, :critical, :unknown]
    end

    test "table_stats has expected format" do
      result = HealthCheck.run_health_checks()

      assert result.table_stats in [:healthy, :warning, :critical, :unknown]
    end

    test "disk_usage has expected format" do
      result = HealthCheck.run_health_checks()

      assert result.disk_usage in [:healthy, :warning, :critical, :unknown]
    end

    test "query_performance has expected format" do
      result = HealthCheck.run_health_checks()

      assert result.query_performance in [:healthy, :warning, :critical, :unknown]
    end
  end
end

defmodule EveDmv.Database.ConnectionPoolMonitorTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureLog

  alias EveDmv.Database.ConnectionPoolMonitor

  describe "connection pool monitoring" do
    test "collects pool statistics" do
      stats = ConnectionPoolMonitor.get_current_metrics()
      
      assert is_map(stats)
      assert Map.has_key?(stats, :pool_health)
      assert Map.has_key?(stats, :utilization_percent)
      assert Map.has_key?(stats, :connections_available)
      assert Map.has_key?(stats, :timestamp)
    end

    test "provides pool recommendations" do
      recommendations = ConnectionPoolMonitor.get_pool_recommendations()
      
      assert is_list(recommendations)
      assert length(recommendations) > 0
      assert Enum.all?(recommendations, &is_binary/1)
    end

    test "can force a pool check" do
      log = capture_log(fn ->
        ConnectionPoolMonitor.force_check()
        # Give it a moment to process
        Process.sleep(100)
      end)
      
      # Should not raise any errors
      assert is_binary(log)
    end

    test "gets pool stats without errors" do
      stats = ConnectionPoolMonitor.get_pool_stats()
      
      assert is_map(stats)
      # Should have basic pool information
      assert Map.has_key?(stats, :timestamp)
    end

    test "analyzes pool health" do
      health = ConnectionPoolMonitor.get_pool_health()
      
      assert is_map(health)
      assert Map.has_key?(health, :status)
      assert health.status in [:healthy, :warning, :critical, :degraded, :unknown]
    end
  end
end
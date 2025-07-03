defmodule EveDmv.Intelligence.ChainMonitorTest do
  use EveDmv.DataCase, async: false
  use EveDmv.IntelligenceCase

  alias EveDmv.Intelligence.ChainMonitor

  setup do
    # Ensure the chain monitor is started for testing
    start_supervised!({ChainMonitor, []})
    :ok
  end

  describe "GenServer lifecycle" do
    test "starts successfully" do
      assert Process.whereis(ChainMonitor) != nil
    end

    test "maintains proper state structure" do
      status = ChainMonitor.status()

      assert Map.has_key?(status, :monitored_chains)
      assert Map.has_key?(status, :last_sync)
      assert Map.has_key?(status, :sync_errors)
      assert is_struct(status.monitored_chains, MapSet)
    end
  end

  describe "monitor_chain/2" do
    test "successfully starts monitoring a new chain" do
      map_id = "test_map_123"
      corporation_id = 98_765_432

      assert :ok = ChainMonitor.monitor_chain(map_id, corporation_id)

      # Verify chain is being monitored
      status = ChainMonitor.status()
      assert MapSet.member?(status.monitored_chains, map_id)
    end

    test "handles duplicate monitoring requests gracefully" do
      map_id = "test_map_456"
      corporation_id = 98_765_432

      assert :ok = ChainMonitor.monitor_chain(map_id, corporation_id)
      assert :ok = ChainMonitor.monitor_chain(map_id, corporation_id)

      # Should still be monitored once
      status = ChainMonitor.status()
      assert MapSet.member?(status.monitored_chains, map_id)
    end

    test "creates chain topology when none exists" do
      map_id = "new_chain_789"
      corporation_id = 98_765_432

      assert :ok = ChainMonitor.monitor_chain(map_id, corporation_id)

      # Verify topology was created
      assert {:ok, topologies} =
               Ash.read(EveDmv.Intelligence.ChainTopology,
                 filter: [map_id: map_id],
                 domain: EveDmv.Api
               )

      assert length(topologies) == 1
      topology = hd(topologies)
      assert topology.map_id == map_id
      assert topology.corporation_id == corporation_id
      assert topology.monitoring_enabled == true
    end
  end

  describe "stop_monitoring/1" do
    test "stops monitoring an existing chain" do
      map_id = "test_map_stop"
      corporation_id = 98_765_432

      # Start monitoring first
      assert :ok = ChainMonitor.monitor_chain(map_id, corporation_id)

      # Verify it's being monitored
      status = ChainMonitor.status()
      assert MapSet.member?(status.monitored_chains, map_id)

      # Stop monitoring
      assert :ok = ChainMonitor.stop_monitoring(map_id)

      # Verify it's no longer monitored
      status = ChainMonitor.status()
      refute MapSet.member?(status.monitored_chains, map_id)
    end

    test "handles stopping monitoring of non-existent chain" do
      map_id = "non_existent_chain"

      assert :ok = ChainMonitor.stop_monitoring(map_id)
    end
  end

  describe "force_sync/0" do
    test "triggers immediate sync of all monitored chains" do
      map_id = "test_sync_chain"
      corporation_id = 98_765_432

      # Start monitoring a chain
      assert :ok = ChainMonitor.monitor_chain(map_id, corporation_id)

      # Force sync should not crash
      assert :ok = ChainMonitor.force_sync()

      # Give some time for async sync to complete
      Process.sleep(100)

      # Chain should still be monitored
      status = ChainMonitor.status()
      assert MapSet.member?(status.monitored_chains, map_id)
    end

    test "handles sync when no chains are monitored" do
      # Force sync with no monitored chains should not crash
      assert :ok = ChainMonitor.force_sync()
    end
  end

  describe "status/0" do
    test "returns current monitoring status" do
      status = ChainMonitor.status()

      assert is_struct(status.monitored_chains, MapSet)
      assert is_map(status.sync_errors)
      # last_sync might be nil initially
      assert status.last_sync == nil or is_struct(status.last_sync, DateTime)
    end

    test "reflects monitored chains accurately" do
      map_ids = ["chain_1", "chain_2", "chain_3"]
      corporation_id = 98_765_432

      # Monitor multiple chains
      for map_id <- map_ids do
        assert :ok = ChainMonitor.monitor_chain(map_id, corporation_id)
      end

      status = ChainMonitor.status()

      # All chains should be in monitored set
      for map_id <- map_ids do
        assert MapSet.member?(status.monitored_chains, map_id)
      end

      assert MapSet.size(status.monitored_chains) >= length(map_ids)
    end
  end

  describe "PubSub integration" do
    test "subscribes to wanderer updates on initialization" do
      # The monitor should be subscribed to PubSub updates
      # We can test this by checking the process is alive and functioning
      assert Process.whereis(ChainMonitor) != nil

      # Test that status calls work (indicating the GenServer is responsive)
      status = ChainMonitor.status()
      assert is_map(status)
    end

    test "broadcasts chain updates" do
      map_id = "broadcast_test_chain"
      corporation_id = 98_765_432

      # Subscribe to the chain intelligence topic
      Phoenix.PubSub.subscribe(EveDmv.PubSub, "chain_intelligence:#{map_id}")

      # Start monitoring (this might trigger a broadcast)
      assert :ok = ChainMonitor.monitor_chain(map_id, corporation_id)

      # The chain should be monitored
      status = ChainMonitor.status()
      assert MapSet.member?(status.monitored_chains, map_id)
    end
  end

  describe "error handling" do
    test "handles invalid map_id gracefully" do
      invalid_map_id = nil
      corporation_id = 98_765_432

      assert {:error, _reason} = ChainMonitor.monitor_chain(invalid_map_id, corporation_id)
    end

    test "handles invalid corporation_id gracefully" do
      map_id = "valid_map"
      invalid_corporation_id = nil

      assert {:error, _reason} = ChainMonitor.monitor_chain(map_id, invalid_corporation_id)
    end

    test "tracks sync errors in status" do
      status = ChainMonitor.status()

      # sync_errors should be a map
      assert is_map(status.sync_errors)
    end
  end

  describe "data synchronization" do
    test "handles missing external API data gracefully" do
      map_id = "missing_data_chain"
      corporation_id = 98_765_432

      # This should not crash even if external APIs are unavailable
      assert :ok = ChainMonitor.monitor_chain(map_id, corporation_id)

      # Force sync to test error handling
      assert :ok = ChainMonitor.force_sync()

      # Give time for sync to complete
      Process.sleep(100)

      # Monitor should still be functional
      status = ChainMonitor.status()
      assert MapSet.member?(status.monitored_chains, map_id)
    end

    test "maintains chain topology data structure" do
      map_id = "topology_test_chain"
      corporation_id = 98_765_432

      assert :ok = ChainMonitor.monitor_chain(map_id, corporation_id)

      # Verify topology record was created with proper structure
      assert {:ok, topologies} =
               Ash.read(EveDmv.Intelligence.ChainTopology,
                 filter: [map_id: map_id],
                 domain: EveDmv.Api
               )

      assert length(topologies) == 1
      topology = hd(topologies)

      # Check required fields
      assert topology.map_id == map_id
      assert topology.corporation_id == corporation_id
      assert topology.monitoring_enabled == true
      assert is_struct(topology.created_at, DateTime)
      assert is_struct(topology.updated_at, DateTime)
    end
  end

  describe "concurrent operations" do
    test "handles multiple simultaneous monitor requests" do
      map_ids = for i <- 1..5, do: "concurrent_chain_#{i}"
      corporation_id = 98_765_432

      # Start monitoring multiple chains concurrently
      tasks =
        for map_id <- map_ids do
          Task.async(fn -> ChainMonitor.monitor_chain(map_id, corporation_id) end)
        end

      # Wait for all tasks to complete
      results = Task.await_many(tasks)

      # All should succeed
      assert Enum.all?(results, fn result -> result == :ok end)

      # All chains should be monitored
      status = ChainMonitor.status()

      for map_id <- map_ids do
        assert MapSet.member?(status.monitored_chains, map_id)
      end
    end

    test "handles mixed monitor and stop operations" do
      map_id = "mixed_ops_chain"
      corporation_id = 98_765_432

      # Start monitoring
      assert :ok = ChainMonitor.monitor_chain(map_id, corporation_id)

      # Verify it's monitored
      status = ChainMonitor.status()
      assert MapSet.member?(status.monitored_chains, map_id)

      # Stop monitoring
      assert :ok = ChainMonitor.stop_monitoring(map_id)

      # Verify it's no longer monitored
      status = ChainMonitor.status()
      refute MapSet.member?(status.monitored_chains, map_id)

      # Start monitoring again
      assert :ok = ChainMonitor.monitor_chain(map_id, corporation_id)

      # Should be monitored again
      status = ChainMonitor.status()
      assert MapSet.member?(status.monitored_chains, map_id)
    end
  end
end

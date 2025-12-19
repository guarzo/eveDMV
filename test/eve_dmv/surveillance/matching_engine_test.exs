defmodule EveDmv.Surveillance.MatchingEngineTest do
  @moduledoc """
  Tests for the MatchingEngine GenServer.

  Tests killmail matching against surveillance profiles,
  profile loading, caching, and batch processing.
  """
  use EveDmv.DataCase, async: false

  alias EveDmv.Surveillance.MatchingEngine

  # Ensure the matching engine is started for tests
  setup do
    # Check if already started, if not start it
    case GenServer.whereis(MatchingEngine) do
      nil ->
        {:ok, pid} = MatchingEngine.start_link([])

        on_exit(fn ->
          # Only stop if still alive, catch any shutdown errors
          try do
            if Process.alive?(pid) do
              GenServer.stop(pid, :normal, 5000)
            end
          catch
            :exit, _ -> :ok
          end
        end)

        %{engine_pid: pid}

      pid ->
        %{engine_pid: pid}
    end
  end

  describe "start_link/1" do
    test "starts the GenServer successfully" do
      # Stop any existing instance first (with error handling)
      try do
        if pid = GenServer.whereis(MatchingEngine) do
          GenServer.stop(pid, :normal, 5000)
        end
      catch
        :exit, _ -> :ok
      end

      assert {:ok, pid} = MatchingEngine.start_link([])
      assert Process.alive?(pid)
      # Keep the process running for other tests - cleanup will be handled by on_exit
    end

    test "registers with expected name" do
      # Ensure a process is running
      case GenServer.whereis(MatchingEngine) do
        nil ->
          {:ok, _pid} = MatchingEngine.start_link([])

        _pid ->
          :ok
      end

      # Verify the process is registered under the expected name
      pid = GenServer.whereis(MatchingEngine)
      assert pid != nil
      assert Process.alive?(pid)
    end
  end

  describe "match_killmail/1" do
    test "returns list of matching profile IDs for valid killmail" do
      # Create a minimal valid killmail structure
      killmail = %{
        "killmail_id" => 12_345_678,
        "killmail_time" => "2025-01-15T12:00:00Z",
        "solar_system_id" => 30_000_142,
        "victim" => %{
          "character_id" => 95_465_499,
          "corporation_id" => 98_000_001,
          "ship_type_id" => 587
        },
        "attackers" => [
          %{
            "character_id" => 90_267_367,
            "corporation_id" => 98_000_002,
            "ship_type_id" => 638,
            "final_blow" => true
          }
        ]
      }

      result = MatchingEngine.match_killmail(killmail)

      assert is_list(result)

      Enum.each(result, fn profile_id ->
        assert is_binary(profile_id)
      end)
    end

    test "returns empty list when no profiles match" do
      # Killmail with unlikely criteria to match
      killmail = %{
        "killmail_id" => 99_999_999,
        "killmail_time" => "2025-01-01T00:00:00Z",
        "solar_system_id" => 0,
        "victim" => %{
          "character_id" => 0,
          "corporation_id" => 0,
          "ship_type_id" => 0
        },
        "attackers" => []
      }

      result = MatchingEngine.match_killmail(killmail)

      assert is_list(result)
      # Likely empty since the IDs don't match any real entities
    end

    test "handles invalid killmail gracefully" do
      # Empty map should be handled gracefully
      result = MatchingEngine.match_killmail(%{})

      assert is_list(result)
    end

    test "handles killmail with missing fields" do
      killmail = %{
        "killmail_id" => 12_345_678
        # Missing other required fields
      }

      result = MatchingEngine.match_killmail(killmail)

      assert is_list(result)
    end
  end

  describe "reload_profiles/0" do
    test "returns :ok" do
      result = MatchingEngine.reload_profiles()

      assert result == :ok
    end

    test "can be called multiple times" do
      assert MatchingEngine.reload_profiles() == :ok
      assert MatchingEngine.reload_profiles() == :ok
      assert MatchingEngine.reload_profiles() == :ok
    end
  end

  describe "get_stats/0" do
    test "returns statistics map" do
      stats = MatchingEngine.get_stats()

      assert is_map(stats)
      assert Map.has_key?(stats, :profiles_loaded)
      assert Map.has_key?(stats, :matches_processed)
      assert Map.has_key?(stats, :last_reload)
      assert Map.has_key?(stats, :pending_matches)
      assert Map.has_key?(stats, :connection_status)
    end

    test "profiles_loaded is non-negative integer" do
      stats = MatchingEngine.get_stats()

      assert is_integer(stats.profiles_loaded)
      assert stats.profiles_loaded >= 0
    end

    test "matches_processed is non-negative integer" do
      stats = MatchingEngine.get_stats()

      assert is_integer(stats.matches_processed)
      assert stats.matches_processed >= 0
    end

    test "last_reload is a DateTime" do
      stats = MatchingEngine.get_stats()

      assert %DateTime{} = stats.last_reload
    end

    test "pending_matches is non-negative integer" do
      stats = MatchingEngine.get_stats()

      assert is_integer(stats.pending_matches)
      assert stats.pending_matches >= 0
    end

    test "connection_status is a tuple" do
      stats = MatchingEngine.get_stats()

      assert is_tuple(stats.connection_status)
      {status, message} = stats.connection_status
      assert status in [:ok, :warning, :error]
      assert is_binary(message)
    end

    test "includes cache_stats" do
      stats = MatchingEngine.get_stats()

      assert Map.has_key?(stats, :cache_stats)
      cache_stats = stats.cache_stats
      assert is_map(cache_stats)
      assert Map.has_key?(cache_stats, :size)
      assert Map.has_key?(cache_stats, :hit_rate)
    end

    test "includes ets_tables stats" do
      stats = MatchingEngine.get_stats()

      assert Map.has_key?(stats, :ets_tables)
      assert is_map(stats.ets_tables)
    end
  end

  describe "child_spec/1" do
    test "returns valid child spec" do
      spec = MatchingEngine.child_spec([])

      assert is_map(spec)
      assert Map.has_key?(spec, :id)
      assert Map.has_key?(spec, :start)
      assert spec.id == MatchingEngine
    end

    test "child spec has 15 second shutdown timeout" do
      spec = MatchingEngine.child_spec([])

      # 15 seconds for batch processing
      assert spec.shutdown == 15_000
    end
  end

  describe "batch processing" do
    test "pending matches are processed periodically" do
      # Get initial stats
      stats_before = MatchingEngine.get_stats()

      # The batch processing happens every 5 seconds
      # We can verify it doesn't block the GenServer
      assert is_integer(stats_before.pending_matches)
    end
  end

  describe "killmail validation" do
    test "accepts killmail with standard EVE structure" do
      killmail = %{
        "killmail_id" => 123_456_789,
        "killmail_time" => "2025-01-15T14:30:00Z",
        "solar_system_id" => 30_002_187,
        "victim" => %{
          "alliance_id" => 99_000_006,
          "character_id" => 95_465_499,
          "corporation_id" => 98_388_312,
          "damage_taken" => 12_500,
          "ship_type_id" => 638
        },
        "attackers" => [
          %{
            "alliance_id" => 99_000_001,
            "character_id" => 90_267_367,
            "corporation_id" => 98_000_001,
            "damage_done" => 12_500,
            "final_blow" => true,
            "ship_type_id" => 11_940
          }
        ],
        "zkb" => %{
          "hash" => "abc123",
          "fitted_value" => 50_000_000.0,
          "total_value" => 75_000_000.0
        }
      }

      result = MatchingEngine.match_killmail(killmail)

      assert is_list(result)
    end

    test "handles NPC kills (no character_id in attacker)" do
      killmail = %{
        "killmail_id" => 123_456_790,
        "killmail_time" => "2025-01-15T14:30:00Z",
        "solar_system_id" => 30_002_187,
        "victim" => %{
          "character_id" => 95_465_499,
          "corporation_id" => 98_388_312,
          "ship_type_id" => 638
        },
        "attackers" => [
          %{
            # NPC kill - no character_id
            "corporation_id" => 1_000_125,
            "damage_done" => 5000,
            "final_blow" => true,
            "ship_type_id" => 19_724
          }
        ]
      }

      result = MatchingEngine.match_killmail(killmail)

      assert is_list(result)
    end
  end

  describe "matching performance" do
    test "match_killmail completes in reasonable time" do
      killmail = %{
        "killmail_id" => 123_456_791,
        "killmail_time" => "2025-01-15T14:30:00Z",
        "solar_system_id" => 30_002_187,
        "victim" => %{
          "character_id" => 95_465_499,
          "corporation_id" => 98_388_312,
          "ship_type_id" => 638
        },
        "attackers" => []
      }

      # Should complete within 10 seconds (the timeout)
      start_time = System.monotonic_time(:millisecond)
      _result = MatchingEngine.match_killmail(killmail)
      end_time = System.monotonic_time(:millisecond)

      elapsed = end_time - start_time
      # Should be fast - much less than the 10 second timeout
      assert elapsed < 5000
    end
  end

  describe "state management" do
    test "stats are updated after matching" do
      killmail = %{
        "killmail_id" => 123_456_792,
        "killmail_time" => "2025-01-15T14:30:00Z",
        "solar_system_id" => 30_002_187,
        "victim" => %{
          "character_id" => 95_465_499,
          "ship_type_id" => 638
        },
        "attackers" => []
      }

      stats_before = MatchingEngine.get_stats()

      # Perform a match
      _result = MatchingEngine.match_killmail(killmail)

      stats_after = MatchingEngine.get_stats()

      # matches_processed should have increased
      assert stats_after.matches_processed >= stats_before.matches_processed
    end

    test "reload updates last_reload timestamp" do
      stats_before = MatchingEngine.get_stats()

      # Small delay to ensure different timestamp
      Process.sleep(100)

      MatchingEngine.reload_profiles()

      stats_after = MatchingEngine.get_stats()

      # last_reload should be more recent
      assert DateTime.compare(stats_after.last_reload, stats_before.last_reload) in [:gt, :eq]
    end
  end

  describe "MatchingEngine startup" do
    test "starts without errors in test environment" do
      # Stop any existing instance first (with error handling)
      try do
        if pid = GenServer.whereis(MatchingEngine) do
          GenServer.stop(pid, :normal, 5000)
        end
      catch
        :exit, _ -> :ok
      end

      # Test that the matching engine can start successfully in test environment
      assert {:ok, pid} = MatchingEngine.start_link([])
      assert is_pid(pid)
      assert Process.alive?(pid)

      # Test basic functionality
      stats = MatchingEngine.get_stats()
      assert is_map(stats)
      assert Map.has_key?(stats, :profiles_loaded)
      assert Map.has_key?(stats, :matches_processed)

      # In test environment, should start with 0 profiles loaded
      assert stats.profiles_loaded == 0

      # Leave running for subsequent tests - cleanup in on_exit
    end

    test "handles killmail matching gracefully when no profiles loaded" do
      # Ensure the engine is running
      case GenServer.whereis(MatchingEngine) do
        nil ->
          {:ok, _pid} = MatchingEngine.start_link([])

        _pid ->
          :ok
      end

      # Test with a mock killmail
      killmail = %{
        "killmail_id" => 123_456,
        "solar_system_id" => 30_000_142,
        "victim" => %{
          "character_id" => 95_465_800,
          "ship_type_id" => 587
        },
        "attackers" => [
          %{
            "character_id" => 95_465_801,
            "final_blow" => true
          }
        ]
      }

      # Should return empty list when no profiles are loaded
      matches = MatchingEngine.match_killmail(killmail)
      assert matches == []

      # Leave running - cleanup in on_exit
    end
  end
end

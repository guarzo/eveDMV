defmodule EveDmv.Surveillance.MatchingEngineTest do
  use EveDmv.DataCase, async: false

  alias EveDmv.Surveillance.MatchingEngine

  describe "MatchingEngine startup" do
    test "starts without errors in test environment" do
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

      # Cleanup
      GenServer.stop(pid)
    end

    test "handles killmail matching gracefully when no profiles loaded" do
      assert {:ok, pid} = MatchingEngine.start_link([])

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

      # Cleanup
      GenServer.stop(pid)
    end
  end
end

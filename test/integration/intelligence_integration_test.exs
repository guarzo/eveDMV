defmodule EveDmv.Integration.IntelligenceIntegrationTest do
  @moduledoc """
  Integration tests for the complete intelligence analysis system.

  Tests the full intelligence workflow from killmail ingestion through
  character analysis, threat assessment, and intelligence reporting.
  """

  use EveDmv.IntelligenceCase, async: false

  alias EveDmv.Intelligence.{
    CharacterAnalyzer,
    CharacterStats,
    ChainMonitor,
    WandererSSE,
    IntelligenceCoordinator
  }

  alias EveDmv.Killmails.{KillmailPipeline, KillmailEnriched}

  @moduletag :integration
  @moduletag timeout: 60_000

  describe "full intelligence workflow" do
    test "processes killmail through complete intelligence pipeline" do
      # Step 1: Ingest killmail through pipeline
      character_id = 95_465_999
      killmail_data = create_realistic_killmail_data(character_id)

      # Simulate pipeline processing
      assert {:ok, _} = KillmailPipeline.process_killmail(killmail_data)

      # Step 2: Trigger character analysis
      assert {:ok, character_stats} = CharacterAnalyzer.analyze_character(character_id)

      # Step 3: Verify intelligence data is generated
      assert character_stats.character_id == character_id
      assert character_stats.dangerous_rating >= 0
      assert character_stats.dangerous_rating <= 5
      assert is_binary(character_stats.analysis_data)

      # Step 4: Verify intelligence data structure
      {:ok, analysis_data} = Jason.decode(character_stats.analysis_data)

      required_fields = [
        "basic_stats",
        "ship_usage",
        "geographic_patterns",
        "temporal_patterns",
        "danger_rating",
        "behavioral_patterns"
      ]

      Enum.each(required_fields, fn field ->
        assert Map.has_key?(analysis_data, field), "Missing field: #{field}"
      end)
    end

    test "intelligence coordination across multiple systems" do
      # Test coordination between different intelligence modules
      character_id = 95_465_998

      # Create comprehensive test data
      killmails = create_realistic_killmail_set(character_id, count: 30)
      wh_activity = create_wormhole_activity(character_id, "C5", count: 10)

      # Simulate real-time intelligence updates
      assert {:ok, character_stats} = CharacterAnalyzer.analyze_character(character_id)

      # Test intelligence aggregation
      intelligence_summary = IntelligenceCoordinator.generate_threat_summary([character_id])

      assert is_map(intelligence_summary)
      assert Map.has_key?(intelligence_summary, "characters")
      assert Map.has_key?(intelligence_summary, "summary_statistics")
      assert Map.has_key?(intelligence_summary, "threat_assessment")
    end

    test "handles concurrent intelligence analysis" do
      # Test system behavior under concurrent analysis requests
      character_ids = Enum.map(1..5, fn i -> 95_466_000 + i end)

      # Create test data for each character
      for character_id <- character_ids do
        create_realistic_killmail_set(character_id, count: 15)
      end

      # Analyze all characters concurrently
      assert {:ok, results} = CharacterAnalyzer.analyze_characters(character_ids)

      # Verify all analyses completed
      assert length(results) == 5

      successful_results = Enum.filter(results, &match?({:ok, _}, &1))
      assert length(successful_results) >= 4, "Expected at least 4 successful analyses"
    end

    test "intelligence data persistence and retrieval" do
      character_id = 95_465_997

      # Create and analyze character
      create_realistic_killmail_set(character_id, count: 25)
      assert {:ok, character_stats} = CharacterAnalyzer.analyze_character(character_id)

      # Verify data is persisted
      retrieved_stats = CharacterStats.get_by_character_id(character_id)
      assert {:ok, ^character_stats} = retrieved_stats

      # Test data retrieval by different criteria
      corp_stats = CharacterStats.get_by_corporation(character_stats.corporation_id)
      assert {:ok, corp_characters} = corp_stats
      assert length(corp_characters) >= 1

      # Verify character is in corporation results
      character_found =
        Enum.any?(corp_characters, fn stats ->
          stats.character_id == character_id
        end)

      assert character_found, "Character not found in corporation stats"
    end

    test "real-time intelligence updates via SSE" do
      # Test SSE integration for real-time intelligence
      map_id = "test_map_#{System.unique_integer()}"
      character_id = 95_465_996

      # Start SSE monitoring
      assert :ok = WandererSSE.monitor_map(map_id)

      # Simulate character location event
      location_event = %{
        "type" => "character_location_changed",
        "payload" => %{
          "character_id" => character_id,
          "solar_system_id" => 30_000_142,
          "ship_type_id" => 587,
          "timestamp" => DateTime.utc_now()
        }
      }

      # Process the event through chain monitor
      GenServer.cast(ChainMonitor, {
        :wanderer_event,
        map_id,
        location_event["type"],
        location_event["payload"]
      })

      # Allow processing time
      Process.sleep(100)

      # Verify event was processed
      status = ChainMonitor.get_status()
      assert is_map(status)

      # Clean up
      WandererSSE.stop_monitoring(map_id)
    end

    test "intelligence quality assessment" do
      character_id = 95_465_995

      # Create varying quality data scenarios
      scenarios = [
        # High quality: lots of recent data
        %{count: 100, days_back: 30, expected_quality: "Excellent"},
        # Medium quality: moderate data
        %{count: 50, days_back: 60, expected_quality: "Good"},
        # Low quality: minimal data
        %{count: 15, days_back: 90, expected_quality: "Fair"}
      ]

      for %{count: count, days_back: days_back, expected_quality: expected_quality} <- scenarios do
        test_character_id = character_id + length(scenarios)

        # Create data with specific time distribution
        create_realistic_killmail_set(test_character_id,
          count: count,
          days_back: days_back
        )

        assert {:ok, character_stats} = CharacterAnalyzer.analyze_character(test_character_id)

        # Check quality assessment
        assert character_stats.data_quality == expected_quality,
               "Expected #{expected_quality}, got #{character_stats.data_quality}"

        # Verify completeness score
        assert character_stats.completeness_score >= 0
        assert character_stats.completeness_score <= 100
      end
    end

    test "error handling and recovery in intelligence pipeline" do
      # Test system resilience to various error conditions

      # Test 1: Invalid character ID
      invalid_character_id = -1
      assert {:error, :no_data} = CharacterAnalyzer.analyze_character(invalid_character_id)

      # Test 2: Insufficient data
      sparse_character_id = 95_465_994
      create_realistic_killmail_set(sparse_character_id, count: 5)

      assert {:error, :insufficient_data} =
               CharacterAnalyzer.analyze_character(sparse_character_id)

      # Test 3: Corrupted killmail data
      corrupted_character_id = 95_465_993
      create_corrupted_killmail_data(corrupted_character_id)

      # Should handle gracefully and still provide analysis
      result = CharacterAnalyzer.analyze_character(corrupted_character_id)
      assert match?({:ok, _} | {:error, _}, result)
    end

    test "intelligence performance metrics" do
      character_id = 95_465_992

      # Create substantial dataset for performance testing
      create_realistic_killmail_set(character_id, count: 200)

      # Measure analysis performance
      {time_microseconds, {:ok, character_stats}} =
        :timer.tc(CharacterAnalyzer, :analyze_character, [character_id])

      # Performance assertions
      time_seconds = time_microseconds / 1_000_000

      # Analysis should complete within reasonable time (10 seconds)
      assert time_seconds < 10.0, "Analysis took too long: #{time_seconds}s"

      # Verify analysis quality wasn't compromised for speed
      assert character_stats.completeness_score > 50
      assert character_stats.dangerous_rating >= 0
    end
  end

  describe "intelligence data integrity" do
    test "validates intelligence data consistency" do
      character_id = 95_465_991

      # Create consistent test data
      create_realistic_killmail_set(character_id, count: 50)

      assert {:ok, character_stats} = CharacterAnalyzer.analyze_character(character_id)

      # Parse analysis data
      {:ok, analysis_data} = Jason.decode(character_stats.analysis_data)

      # Validate data consistency
      basic_stats = analysis_data["basic_stats"]

      # K/D ratio should match kill/loss counts
      expected_kd = basic_stats["kills"]["count"] / max(1, basic_stats["losses"]["count"])
      actual_kd = character_stats.kd_ratio

      assert_in_delta expected_kd,
                      actual_kd,
                      0.01,
                      "K/D ratio inconsistency: expected #{expected_kd}, got #{actual_kd}"

      # Solo ratio should be consistent
      if basic_stats["kills"]["count"] > 0 do
        expected_solo_ratio = basic_stats["kills"]["solo"] / basic_stats["kills"]["count"]
        actual_solo_ratio = character_stats.solo_ratio

        assert_in_delta expected_solo_ratio, actual_solo_ratio, 0.01, "Solo ratio inconsistency"
      end
    end

    test "handles intelligence data versioning" do
      character_id = 95_465_990

      # Create initial analysis
      create_realistic_killmail_set(character_id, count: 30)
      assert {:ok, initial_stats} = CharacterAnalyzer.analyze_character(character_id)

      # Add more data and re-analyze
      create_realistic_killmail_set(character_id, count: 20, offset: 30)
      assert {:ok, updated_stats} = CharacterAnalyzer.analyze_character(character_id)

      # Verify data evolution
      assert updated_stats.last_analyzed_at >= initial_stats.last_analyzed_at

      # Activity counts should increase or stay same
      assert updated_stats.kill_count >= initial_stats.kill_count
      assert updated_stats.loss_count >= initial_stats.loss_count
    end
  end

  # Helper functions for integration tests

  defp create_realistic_killmail_data(character_id) do
    %{
      "killmail_id" => System.unique_integer([:positive]),
      "killmail_time" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "solar_system_id" => 30_000_142,
      "participants" => [
        %{
          "character_id" => character_id,
          "character_name" => "Test Character #{character_id}",
          "corporation_id" => 1_000_001,
          "corporation_name" => "Test Corp",
          "ship_type_id" => 587,
          "ship_name" => "Rifter",
          "is_victim" => false,
          "final_blow" => true,
          "damage_done" => 1_500
        },
        %{
          "character_id" => character_id + 1,
          "character_name" => "Victim Character",
          "corporation_id" => 1_000_002,
          "corporation_name" => "Victim Corp",
          "ship_type_id" => 588,
          "ship_name" => "Punisher",
          "is_victim" => true,
          "final_blow" => false,
          "damage_done" => 0
        }
      ],
      "zkb" => %{
        "totalValue" => 5_000_000
      }
    }
  end

  defp create_corrupted_killmail_data(character_id) do
    # Create killmail with missing/invalid data
    create(:killmail_raw, %{
      character_id: character_id,
      killmail_data: %{
        # Invalid participants
        "participants" => nil,
        "killmail_time" => "invalid_date",
        "solar_system_id" => "not_a_number"
      }
    })
  end
end

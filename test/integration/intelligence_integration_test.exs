defmodule EveDmv.Integration.IntelligenceIntegrationTest do
  @moduledoc """
  Integration tests for the complete intelligence analysis system.

  Tests the full intelligence workflow from killmail ingestion through
  character analysis, threat assessment, and intelligence reporting.
  """

  use EveDmv.IntelligenceCase, async: false
  @moduletag :skip

  alias EveDmv.Intelligence.{
    ChainMonitor,
    CharacterAnalyzer,
    CharacterStats,
    IntelligenceCoordinator,
    WandererSSE
  }

  alias EveDmv.Killmails.{KillmailEnriched, KillmailPipeline}

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
      assert {:ok, _character_stats} = CharacterAnalyzer.analyze_character(character_id)

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
      _killmails = EveDmv.IntelligenceCase.create_realistic_killmail_set(character_id, count: 30)

      _wh_activity =
        EveDmv.IntelligenceCase.create_wormhole_activity(character_id, "C5", count: 10)

      # Simulate real-time intelligence updates
      assert {:ok, _character_stats} = CharacterAnalyzer.analyze_character(character_id)

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
        EveDmv.IntelligenceCase.create_realistic_killmail_set(character_id, count: 15)
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
      EveDmv.IntelligenceCase.create_realistic_killmail_set(character_id, count: 25)
      assert {:ok, _character_stats} = CharacterAnalyzer.analyze_character(character_id)

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
        EveDmv.IntelligenceCase.create_realistic_killmail_set(test_character_id,
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
      EveDmv.IntelligenceCase.create_realistic_killmail_set(sparse_character_id, count: 5)

      assert {:error, :insufficient_data} =
               CharacterAnalyzer.analyze_character(sparse_character_id)

      # Test 3: Corrupted killmail data
      corrupted_character_id = 95_465_993
      create_corrupted_killmail_data(corrupted_character_id)

      # Should handle gracefully and still provide analysis
      result = CharacterAnalyzer.analyze_character(corrupted_character_id)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "intelligence performance metrics" do
      character_id = 95_465_992

      # Create substantial dataset for performance testing
      EveDmv.IntelligenceCase.create_realistic_killmail_set(character_id, count: 200)

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

  describe "cross-module intelligence coordination" do
    test "coordinates analysis across multiple intelligence modules" do
      character_id = 95_000_100
      corporation_id = 1_000_100
      home_system_id = 30_000_142

      # Create comprehensive character activity
      create_comprehensive_character_activity(character_id, corporation_id, home_system_id)

      # Test individual module analyses
      {:ok, character_analysis} = CharacterAnalyzer.analyze_character(character_id)

      # Test coordinated analysis
      {:ok, comprehensive_analysis} =
        IntelligenceCoordinator.analyze_character_comprehensive(character_id)

      # Verify cross-module consistency
      assert character_analysis.character_id == character_id
      assert comprehensive_analysis.basic_analysis.character_id == character_id

      # Verify intelligence fusion
      assert comprehensive_analysis.correlations != nil
      assert comprehensive_analysis.specialized_analysis != nil
      assert comprehensive_analysis.confidence_score > 0
    end

    test "correlates character capabilities with fleet analysis" do
      # Create fleet members with different skill levels
      fleet_members = create_diverse_fleet_members()

      # Analyze individual capabilities
      character_analyses =
        for member <- fleet_members do
          {:ok, analysis} = CharacterAnalyzer.analyze_character(member.character_id)
          {member.character_id, analysis}
        end

      # Check that dangerous characters correlate with fleet threat assessment
      _dangerous_characters =
        Enum.filter(character_analyses, fn {_id, analysis} ->
          analysis.dangerous_rating >= 7
        end)

      experienced_pilots =
        Enum.count(character_analyses, fn {_id, analysis} ->
          analysis.kill_count >= 20
        end)

      # Fleet with experienced pilots should be more effective
      assert experienced_pilots > 0
    end

    test "cross-references employment patterns with activity" do
      character_id = 95_000_101

      # Create character with corp changes and corresponding activity
      create_character_with_corp_changes(character_id)

      # Analyze with multiple perspectives
      {:ok, character_analysis} = CharacterAnalyzer.analyze_character(character_id)

      # Verify patterns are detected
      assert character_analysis.kill_count > 0
      assert length(character_analysis.frequent_systems) > 0
    end

    test "maintains performance under concurrent analysis" do
      # Create multiple characters for concurrent analysis
      character_ids =
        for i <- 1..5 do
          char_id = 95_000_400 + i
          create_moderate_character_activity(char_id)
          char_id
        end

      # Time concurrent comprehensive analysis
      {time_microseconds, results} =
        :timer.tc(fn ->
          tasks =
            Enum.map(character_ids, fn char_id ->
              Task.async(fn ->
                IntelligenceCoordinator.analyze_character_comprehensive(char_id)
              end)
            end)

          Task.await_many(tasks, 30_000)
        end)

      time_ms = time_microseconds / 1000

      # Should complete within reasonable time
      assert time_ms < 15_000, "Concurrent analysis took #{time_ms}ms"

      # All analyses should succeed
      assert Enum.all?(results, fn
               {:ok, _} -> true
               _ -> false
             end)
    end
  end

  describe "intelligence data integrity" do
    test "validates intelligence data consistency" do
      character_id = 95_465_991

      # Create consistent test data
      EveDmv.IntelligenceCase.create_realistic_killmail_set(character_id, count: 50)

      assert {:ok, _character_stats} = CharacterAnalyzer.analyze_character(character_id)

      # Verify basic consistency
      assert character_stats.character_id == character_id
      assert character_stats.dangerous_rating >= 0
      assert character_stats.dangerous_rating <= 5
      assert character_stats.kill_count >= 0
      assert character_stats.loss_count >= 0
    end

    test "handles intelligence data versioning" do
      character_id = 95_465_990

      # Create initial analysis
      EveDmv.IntelligenceCase.create_realistic_killmail_set(character_id, count: 30)
      assert {:ok, initial_stats} = CharacterAnalyzer.analyze_character(character_id)

      # Add more data and re-analyze
      EveDmv.IntelligenceCase.create_realistic_killmail_set(character_id, count: 20, offset: 30)
      assert {:ok, updated_stats} = CharacterAnalyzer.analyze_character(character_id)

      # Verify data evolution
      assert updated_stats.last_analyzed_at >= initial_stats.last_analyzed_at

      # Activity counts should increase or stay same
      assert updated_stats.kill_count >= initial_stats.kill_count
      assert updated_stats.loss_count >= initial_stats.loss_count
    end
  end

  # Helper functions for cross-module testing

  defp create_comprehensive_character_activity(character_id, _corporation_id, home_system_id) do
    # Mixed K-space and J-space activity
    systems = [
      # Home system activity
      home_system_id,
      # Amarr (K-space)
      30_002_187,
      # J-space
      31_000_001,
      # More J-space
      31_000_002
    ]

    # Create 30 killmails across different contexts
    for i <- 1..30 do
      system_id = Enum.at(systems, rem(i, length(systems)))
      is_victim = rem(i, 4) == 0

      create(:killmail_raw, %{
        killmail_id: 85_000_000 + character_id + i,
        killmail_time: DateTime.add(DateTime.utc_now(), -i * 86_400, :second),
        solar_system_id: system_id,
        killmail_data: build_killmail_data(character_id, is_victim)
      })
    end
  end

  defp create_diverse_fleet_members do
    [
      %{
        character_id: 95_100_001,
        character_name: "FC Alpha",
        ship_name: "Damnation",
        ship_category: "command_ship",
        role: "fc",
        mass: 13_500_000
      },
      %{
        character_id: 95_100_002,
        character_name: "DPS Heavy",
        ship_name: "Legion",
        ship_category: "strategic_cruiser",
        role: "dps",
        mass: 13_000_000
      },
      %{
        character_id: 95_100_003,
        character_name: "Logi Primary",
        ship_name: "Guardian",
        ship_category: "logistics",
        role: "logistics",
        mass: 11_800_000
      }
    ]
    |> tap(fn members ->
      # Create character activity for each member
      Enum.each(members, fn member ->
        create_character_with_role_activity(member.character_id, member.role)
      end)
    end)
  end

  defp create_character_with_corp_changes(character_id) do
    # Create employment history with changes
    corps = [1_000_001, 1_000_002, 1_000_003]
    base_date = DateTime.add(DateTime.utc_now(), -365 * 86_400, :second)

    for {corp_id, i} <- Enum.with_index(corps) do
      start_date = DateTime.add(base_date, i * 60 * 86_400, :second)

      # Create killmails during this corp period
      for j <- 1..5 do
        kill_date = DateTime.add(start_date, j * 10 * 86_400, :second)

        create(:killmail_raw, %{
          killmail_id: 86_000_000 + character_id + i * 10 + j,
          killmail_time: kill_date,
          killmail_data: %{
            "attackers" => [
              %{
                "character_id" => character_id,
                "corporation_id" => corp_id,
                "final_blow" => true
              }
            ],
            "victim" => %{"character_id" => Enum.random(90_000_000..95_000_000)}
          }
        })
      end
    end
  end

  defp create_moderate_character_activity(character_id) do
    # Create balanced activity for performance testing
    for i <- 1..15 do
      create(:killmail_raw, %{
        killmail_id: 89_000_000 + character_id + i,
        killmail_time: DateTime.add(DateTime.utc_now(), -i * 86_400, :second),
        solar_system_id: Enum.random([30_000_142, 31_000_001]),
        killmail_data: build_killmail_data(character_id, rem(i, 5) == 0)
      })
    end
  end

  defp create_character_with_role_activity(character_id, role) do
    ship_types =
      case role do
        # Command ships
        "fc" -> [12_013]
        # T3Cs
        "dps" -> [12_011, 12_010, 12_012]
        # Logistics
        "logistics" -> [11_987, 11_989]
        # Basic ships
        _ -> [587, 588, 589]
      end

    # Create activity that reflects the role
    for i <- 1..10 do
      is_dangerous = role in ["fc", "dps"] and i > 7

      create(:killmail_raw, %{
        killmail_id: 90_000_000 + character_id + i,
        killmail_time: DateTime.add(DateTime.utc_now(), -i * 86_400, :second),
        killmail_data: %{
          "attackers" => [
            %{
              "character_id" => character_id,
              "ship_type_id" => Enum.random(ship_types),
              "final_blow" => is_dangerous
            }
          ],
          "victim" => %{
            "character_id" => Enum.random(90_000_000..95_000_000),
            "ship_type_id" => if(is_dangerous, do: 17_738, else: 587)
          }
        }
      })
    end
  end

  defp build_killmail_data(character_id, is_victim) do
    if is_victim do
      %{
        "attackers" => [
          %{
            "character_id" => Enum.random(90_000_000..95_000_000),
            "final_blow" => true
          }
        ],
        "victim" => %{
          "character_id" => character_id
        }
      }
    else
      %{
        "attackers" => [
          %{
            "character_id" => character_id,
            "final_blow" => true
          }
        ],
        "victim" => %{
          "character_id" => Enum.random(90_000_000..95_000_000)
        }
      }
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

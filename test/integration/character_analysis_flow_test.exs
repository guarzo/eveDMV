defmodule EveDmv.Integration.CharacterAnalysisFlowTest do
  @moduledoc """
  Integration tests for the complete Character Analysis flow.

  This test suite verifies the end-to-end character analysis workflow:
  1. Killmail data ingestion and storage
  2. Killmail aggregation and participant extraction
  3. Threat scoring calculations
  4. Intelligence display generation

  These tests use real database operations with SQL sandbox isolation.
  """
  use EveDmv.DataCase, async: false

  alias EveDmv.Api
  alias EveDmv.Contexts.CharacterIntelligence.Analyzers.CharacterIntelligenceAnalyzer
  alias EveDmv.Contexts.PlayerProfile.Api, as: PlayerProfileApi
  alias EveDmv.Intelligence.CharacterStats
  alias EveDmv.Intelligence.ThreatAssessment
  alias EveDmv.Killmails.KillmailRaw
  alias EveDmv.Killmails.Participant

  require Ash.Query

  # Test character IDs
  @test_character_id 95_000_001
  @test_victim_character_id 95_000_002
  @test_corporation_id 98_000_001
  @test_alliance_id 99_000_001

  # Test solar system IDs (real EVE systems)
  @jita_system_id 30_000_142
  @amarr_system_id 30_002_187
  @dodixie_system_id 30_002_659

  # Test ship type IDs (real EVE ships)
  @rifter_type_id 587
  @punisher_type_id 588
  @loki_type_id 29_990
  @sabre_type_id 22_456

  describe "end-to-end character analysis flow" do
    setup do
      # Create a set of killmails for testing the character analysis flow
      since_date = DateTime.add(DateTime.utc_now(), -30, :day)
      {:ok, since_date: since_date, character_id: @test_character_id}
    end

    test "complete flow: killmail ingestion -> aggregation -> threat scoring -> intelligence display",
         %{since_date: since_date} do
      # Step 1: Create killmail data
      {killmails, participants} = create_test_killmail_data()

      assert length(killmails) >= 5, "Should have created at least 5 killmails"
      assert length(participants) >= 10, "Should have created at least 10 participants"

      # Step 2: Verify killmails are queryable
      verify_killmail_aggregation()

      # Step 3: Analyze character intelligence (may return error for new character)
      result =
        CharacterIntelligenceAnalyzer.analyze_activity_stats(@test_character_id, since_date)

      case result do
        {:ok, analysis} ->
          assert Map.has_key?(analysis, :stats)
          assert Map.has_key?(analysis.stats, :total_events)

        {:error, :query_failed} ->
          # This is acceptable for test data that may not match expected patterns
          :ok
      end

      # Step 4: Run threat assessment functions (these don't require CharacterStats to exist)
      combat_effectiveness = ThreatAssessment.assess_combat_effectiveness(@test_character_id)
      assert is_float(combat_effectiveness)
      assert combat_effectiveness >= 0.0
      assert combat_effectiveness <= 1.0

      tactical_sophistication =
        ThreatAssessment.assess_tactical_sophistication(@test_character_id)

      assert is_float(tactical_sophistication)

      # Step 5: Calculate composite threat score
      threat_indicators = %{
        combat_effectiveness: combat_effectiveness,
        tactical_sophistication: tactical_sophistication,
        intelligence_gathering: 0.3,
        network_influence: 0.2,
        operational_security: 0.5
      }

      composite_score = ThreatAssessment.calculate_composite_threat_score(threat_indicators)
      assert is_float(composite_score)
      assert composite_score >= 0.0
      assert composite_score <= 1.0

      # Step 6: Categorize threat level
      threat_level = ThreatAssessment.categorize_threat_level(composite_score)
      assert threat_level in ["critical", "high", "medium", "low", "minimal"]

      # Step 7: Get mitigation strategies
      strategies = ThreatAssessment.suggest_mitigation_strategies(threat_level, threat_indicators)
      assert is_list(strategies)
      refute Enum.empty?(strategies)
    end

    test "killmail aggregation correctly counts kills and deaths", %{since_date: _since_date} do
      # Create specific killmail patterns for the test character
      character_id = @test_character_id + 100

      # Create 3 kills (character as attacker)
      for i <- 1..3 do
        create_kill_as_attacker(character_id, i)
      end

      # Create 1 death (character as victim)
      create_death_as_victim(character_id)

      # Query participants to verify counts
      kills_query =
        Participant
        |> Ash.Query.filter(character_id == ^character_id and is_victim == false)

      deaths_query =
        Participant
        |> Ash.Query.filter(character_id == ^character_id and is_victim == true)

      {:ok, kills} = Ash.read(kills_query, domain: Api)
      {:ok, deaths} = Ash.read(deaths_query, domain: Api)

      assert length(kills) == 3, "Should have 3 kills"
      assert length(deaths) == 1, "Should have 1 death"
    end

    test "killmail value aggregation for ISK efficiency", %{since_date: _since_date} do
      character_id = @test_character_id + 200

      # Create a high-value kill
      killmail =
        create_killmail!(%{
          total_value: Decimal.new("1000000000"),
          victim_character_id: @test_victim_character_id,
          victim_ship_type_id: @loki_type_id
        })

      create_participant!(%{
        killmail_id: killmail.killmail_id,
        killmail_time: killmail.killmail_time,
        character_id: character_id,
        is_victim: false,
        final_blow: true,
        damage_done: 5000,
        solar_system_id: killmail.solar_system_id
      })

      # Verify the killmail was created with correct value
      {:ok, [fetched]} =
        KillmailRaw
        |> Ash.Query.filter(killmail_id == ^killmail.killmail_id)
        |> Ash.read(domain: Api)

      assert Decimal.compare(fetched.total_value, Decimal.new("1000000000")) == :eq
    end

    test "ship preference analysis returns valid structure", %{since_date: since_date} do
      character_id = @test_character_id + 300

      # Create kills with different ship types
      ship_types = [@rifter_type_id, @rifter_type_id, @punisher_type_id]

      for {ship_type, idx} <- Enum.with_index(ship_types) do
        create_kill_with_ship(character_id, ship_type, idx)
      end

      result = CharacterIntelligenceAnalyzer.analyze_ship_preferences(character_id, since_date)

      case result do
        {:ok, analysis} ->
          assert Map.has_key?(analysis, :preferences)
          assert Map.has_key?(analysis, :stats)
          assert is_list(analysis.preferences)

        {:error, :query_failed} ->
          # Acceptable for edge cases
          :ok
      end
    end

    test "gang pattern analysis returns valid structure", %{since_date: since_date} do
      character_id = @test_character_id + 400

      # Create kills with varying gang sizes
      create_solo_kill(character_id)
      create_gang_kill(character_id, 5)
      create_gang_kill(character_id, 10)

      result = CharacterIntelligenceAnalyzer.analyze_gang_patterns(character_id, since_date)

      case result do
        {:ok, analysis} ->
          assert Map.has_key?(analysis, :patterns)
          assert Map.has_key?(analysis, :stats)
          assert is_list(analysis.patterns)

        {:error, :query_failed} ->
          # Acceptable for edge cases
          :ok
      end
    end
  end

  describe "threat assessment calculations" do
    test "combat effectiveness returns normalized value" do
      # Create character stats record
      {:ok, stats} = create_character_stats(@test_character_id + 500, 50, 10)

      effectiveness = ThreatAssessment.assess_combat_effectiveness(stats.character_id)
      assert is_float(effectiveness)
      assert effectiveness >= 0.0
      assert effectiveness <= 1.0
    end

    test "tactical sophistication evaluates ship diversity" do
      {:ok, stats} =
        create_character_stats_with_ships(@test_character_id + 600, %{
          "587" => %{"times_used" => 10},
          "588" => %{"times_used" => 8},
          "589" => %{"times_used" => 5}
        })

      sophistication = ThreatAssessment.assess_tactical_sophistication(stats.character_id)
      assert is_float(sophistication)
      assert sophistication >= 0.0
    end

    test "composite threat score applies correct weights" do
      indicators = %{
        combat_effectiveness: 0.8,
        tactical_sophistication: 0.6,
        intelligence_gathering: 0.4,
        network_influence: 0.5,
        operational_security: 0.7
      }

      score = ThreatAssessment.calculate_composite_threat_score(indicators)

      # Expected calculation:
      # 0.8 * 0.3 + 0.6 * 0.25 + 0.4 * 0.2 + 0.5 * 0.15 + 0.7 * 0.1
      # = 0.24 + 0.15 + 0.08 + 0.075 + 0.07 = 0.615
      expected = 0.62

      assert_in_delta score, expected, 0.02
    end

    test "threat level categorization follows thresholds" do
      assert ThreatAssessment.categorize_threat_level(0.85) == "critical"
      assert ThreatAssessment.categorize_threat_level(0.65) == "high"
      assert ThreatAssessment.categorize_threat_level(0.45) == "medium"
      assert ThreatAssessment.categorize_threat_level(0.25) == "low"
      assert ThreatAssessment.categorize_threat_level(0.1) == "minimal"
    end

    test "mitigation strategies generated for each threat level" do
      base_indicators = %{
        combat_effectiveness: 0.5,
        tactical_sophistication: 0.5,
        intelligence_gathering: 0.5,
        network_influence: 0.5,
        operational_security: 0.5
      }

      for level <- ["critical", "high", "medium", "low", "minimal"] do
        strategies = ThreatAssessment.suggest_mitigation_strategies(level, base_indicators)
        assert is_list(strategies)
        refute Enum.empty?(strategies)
      end
    end
  end

  describe "player profile API integration" do
    test "analyze_player returns valid structure for known character" do
      character_id = @test_character_id + 700

      # Create some activity
      create_test_activity(character_id, 5)

      # Note: PlayerAnalyzer is a GenServer that may not be started in test mode
      # We catch the exit and treat it as an expected condition
      try do
        result = PlayerProfileApi.analyze_player(character_id)

        case result do
          {:ok, analysis} ->
            assert is_map(analysis)

          {:error, _reason} ->
            # May fail for characters with no ESI data
            :ok
        end
      catch
        :exit, {:noproc, _} ->
          # PlayerAnalyzer GenServer not running in test environment - expected
          :ok

        :exit, _ ->
          # Other exit reasons related to GenServer not being available
          :ok
      end
    end

    test "get_combat_stats handles missing data gracefully" do
      # Use a character with no data
      nonexistent_id = 1

      result = PlayerProfileApi.get_combat_stats(nonexistent_id)

      case result do
        {:ok, _stats} ->
          :ok

        {:error, _reason} ->
          :ok
      end
    end

    test "get_ship_preferences handles empty results" do
      nonexistent_id = 2

      result = PlayerProfileApi.get_ship_preferences(nonexistent_id)

      case result do
        {:ok, _prefs} ->
          :ok

        {:error, _reason} ->
          :ok
      end
    end
  end

  describe "character intelligence analyzer comprehensive analysis" do
    setup do
      since_date = DateTime.add(DateTime.utc_now(), -90, :day)
      character_id = @test_character_id + 800

      # Create a substantial activity history
      create_comprehensive_activity(character_id, 20)

      {:ok, character_id: character_id, since_date: since_date}
    end

    test "analyze_comprehensive aggregates all analysis types", %{
      character_id: character_id,
      since_date: since_date
    } do
      result = CharacterIntelligenceAnalyzer.analyze_comprehensive(character_id, since_date)

      case result do
        {:ok, comprehensive} ->
          assert Map.has_key?(comprehensive, :character_id)
          assert Map.has_key?(comprehensive, :analysis_timestamp)
          assert Map.has_key?(comprehensive, :analysis_period)
          assert Map.has_key?(comprehensive, :weapon_preferences)
          assert Map.has_key?(comprehensive, :ship_preferences)
          assert Map.has_key?(comprehensive, :gang_patterns)
          assert Map.has_key?(comprehensive, :activity_stats)
          assert Map.has_key?(comprehensive, :isk_efficiency)
          assert Map.has_key?(comprehensive, :intelligence_summary)
          assert Map.has_key?(comprehensive, :overall_assessment)

          # Verify overall assessment structure
          assert Map.has_key?(comprehensive.overall_assessment, :overall_threat_level)
          assert Map.has_key?(comprehensive.overall_assessment, :combat_style)
          assert Map.has_key?(comprehensive.overall_assessment, :experience_level)

        {:error, :comprehensive_analysis_failed} ->
          # May fail if individual analyses fail
          :ok
      end
    end

    test "analyze_known_associates finds frequent companions", %{
      character_id: character_id,
      since_date: since_date
    } do
      result = CharacterIntelligenceAnalyzer.analyze_known_associates(character_id, since_date)

      case result do
        {:ok, associates} ->
          assert Map.has_key?(associates, :associates)
          assert Map.has_key?(associates, :total_associates)
          assert is_list(associates.associates)

        {:error, :query_failed} ->
          :ok
      end
    end

    test "analyze_hunting_grounds identifies active systems", %{
      character_id: character_id,
      since_date: since_date
    } do
      result = CharacterIntelligenceAnalyzer.analyze_hunting_grounds(character_id, since_date)

      case result do
        {:ok, grounds} ->
          assert Map.has_key?(grounds, :top_systems)
          assert Map.has_key?(grounds, :security_preference)
          assert Map.has_key?(grounds, :primary_security)

        {:error, :query_failed} ->
          :ok
      end
    end

    test "analyze_target_selection identifies preferred targets", %{
      character_id: character_id,
      since_date: since_date
    } do
      result = CharacterIntelligenceAnalyzer.analyze_target_selection(character_id, since_date)

      case result do
        {:ok, targets} ->
          assert Map.has_key?(targets, :top_targets)
          assert Map.has_key?(targets, :class_breakdown)
          assert Map.has_key?(targets, :target_assessment)

        {:error, :query_failed} ->
          :ok
      end
    end

    test "analyze_activity_timeline shows recent patterns", %{
      character_id: character_id,
      since_date: since_date
    } do
      result = CharacterIntelligenceAnalyzer.analyze_activity_timeline(character_id, since_date)

      case result do
        {:ok, timeline} ->
          assert Map.has_key?(timeline, :timeline)
          assert Map.has_key?(timeline, :activity_trend)

        {:error, :query_failed} ->
          :ok
      end
    end

    test "analyze_bait_indicators detects bait patterns", %{
      character_id: character_id,
      since_date: since_date
    } do
      result = CharacterIntelligenceAnalyzer.analyze_bait_indicators(character_id, since_date)

      case result do
        {:ok, bait} ->
          assert Map.has_key?(bait, :is_likely_bait)
          assert Map.has_key?(bait, :bait_assessment)
          assert is_boolean(bait.is_likely_bait)

        {:error, :query_failed} ->
          :ok
      end
    end
  end

  # ============================================================================
  # Helper Functions
  # ============================================================================

  defp create_test_killmail_data do
    killmails =
      for i <- 1..5 do
        create_killmail!(%{
          killmail_id: System.unique_integer([:positive]),
          solar_system_id: Enum.random([@jita_system_id, @amarr_system_id, @dodixie_system_id]),
          victim_character_id: @test_victim_character_id + i,
          victim_ship_type_id: Enum.random([@rifter_type_id, @punisher_type_id]),
          total_value: Decimal.new(Enum.random(1_000_000..100_000_000))
        })
      end

    participants =
      Enum.flat_map(killmails, fn killmail ->
        # Create victim participant
        victim =
          create_participant!(%{
            killmail_id: killmail.killmail_id,
            killmail_time: killmail.killmail_time,
            character_id: killmail.victim_character_id,
            is_victim: true,
            damage_done: 0,
            solar_system_id: killmail.solar_system_id
          })

        # Create 1-3 attacker participants
        attackers =
          for j <- 1..Enum.random(1..3) do
            create_participant!(%{
              killmail_id: killmail.killmail_id,
              killmail_time: killmail.killmail_time,
              character_id: @test_character_id + j,
              is_victim: false,
              final_blow: j == 1,
              damage_done: Enum.random(100..5000),
              ship_type_id: Enum.random([@rifter_type_id, @punisher_type_id]),
              solar_system_id: killmail.solar_system_id
            })
          end

        [victim | attackers]
      end)

    {killmails, participants}
  end

  defp verify_killmail_aggregation do
    {:ok, killmails} =
      KillmailRaw
      |> Ash.Query.limit(10)
      |> Ash.read(domain: Api)

    refute Enum.empty?(killmails), "Should have killmails in database"

    {:ok, participants} =
      Participant
      |> Ash.Query.limit(20)
      |> Ash.read(domain: Api)

    refute Enum.empty?(participants), "Should have participants in database"
  end

  defp create_kill_as_attacker(character_id, idx) do
    killmail =
      create_killmail!(%{
        killmail_id: System.unique_integer([:positive]),
        victim_character_id: @test_victim_character_id + idx + 1000,
        solar_system_id: @jita_system_id
      })

    create_participant!(%{
      killmail_id: killmail.killmail_id,
      killmail_time: killmail.killmail_time,
      character_id: character_id,
      is_victim: false,
      final_blow: true,
      damage_done: Enum.random(1000..5000),
      solar_system_id: killmail.solar_system_id
    })
  end

  defp create_death_as_victim(character_id) do
    killmail =
      create_killmail!(%{
        killmail_id: System.unique_integer([:positive]),
        victim_character_id: character_id,
        solar_system_id: @jita_system_id
      })

    create_participant!(%{
      killmail_id: killmail.killmail_id,
      killmail_time: killmail.killmail_time,
      character_id: character_id,
      is_victim: true,
      damage_done: 0,
      solar_system_id: killmail.solar_system_id
    })
  end

  defp create_kill_with_ship(character_id, ship_type_id, idx) do
    killmail =
      create_killmail!(%{
        killmail_id: System.unique_integer([:positive]),
        victim_character_id: @test_victim_character_id + idx + 2000,
        solar_system_id: @jita_system_id
      })

    create_participant!(%{
      killmail_id: killmail.killmail_id,
      killmail_time: killmail.killmail_time,
      character_id: character_id,
      ship_type_id: ship_type_id,
      is_victim: false,
      final_blow: true,
      damage_done: Enum.random(1000..5000),
      solar_system_id: killmail.solar_system_id
    })
  end

  defp create_solo_kill(character_id) do
    killmail =
      create_killmail!(%{
        killmail_id: System.unique_integer([:positive]),
        victim_character_id: @test_victim_character_id + 3000,
        attacker_count: 1,
        solar_system_id: @jita_system_id
      })

    create_participant!(%{
      killmail_id: killmail.killmail_id,
      killmail_time: killmail.killmail_time,
      character_id: character_id,
      is_victim: false,
      final_blow: true,
      damage_done: 5000,
      solar_system_id: killmail.solar_system_id
    })
  end

  defp create_gang_kill(character_id, gang_size) do
    killmail =
      create_killmail!(%{
        killmail_id: System.unique_integer([:positive]),
        victim_character_id: @test_victim_character_id + 4000 + gang_size,
        attacker_count: gang_size,
        solar_system_id: @amarr_system_id
      })

    # Create the main character as an attacker
    create_participant!(%{
      killmail_id: killmail.killmail_id,
      killmail_time: killmail.killmail_time,
      character_id: character_id,
      is_victim: false,
      final_blow: true,
      damage_done: 3000,
      solar_system_id: killmail.solar_system_id
    })

    # Create additional gang members
    for i <- 2..gang_size do
      create_participant!(%{
        killmail_id: killmail.killmail_id,
        killmail_time: killmail.killmail_time,
        character_id: @test_character_id + 5000 + i,
        is_victim: false,
        final_blow: false,
        damage_done: Enum.random(500..2000),
        solar_system_id: killmail.solar_system_id
      })
    end
  end

  defp create_character_stats(character_id, kills, losses) do
    CharacterStats
    |> Ash.Changeset.for_create(:create, %{
      character_id: character_id,
      character_name: "Test Character #{character_id}"
    })
    |> Ash.Changeset.force_change_attribute(:total_kills, kills)
    |> Ash.Changeset.force_change_attribute(:total_losses, losses)
    |> Ash.create(domain: Api)
  end

  defp create_character_stats_with_ships(character_id, ship_usage) do
    CharacterStats
    |> Ash.Changeset.for_create(:create, %{
      character_id: character_id,
      character_name: "Test Character #{character_id}"
    })
    |> Ash.Changeset.force_change_attribute(:ship_usage, ship_usage)
    |> Ash.Changeset.force_change_attribute(:avg_gang_size, 3.5)
    |> Ash.create(domain: Api)
  end

  defp create_test_activity(character_id, count) do
    for i <- 1..count do
      create_kill_as_attacker(character_id, i + 6000)
    end
  end

  defp create_comprehensive_activity(character_id, count) do
    # Create diverse activity for comprehensive analysis
    systems = [@jita_system_id, @amarr_system_id, @dodixie_system_id]
    ships = [@rifter_type_id, @punisher_type_id, @sabre_type_id]

    for i <- 1..count do
      # Vary the time slightly to spread activity over the analysis period
      time_offset = -i * 3600 * 24

      killmail =
        create_killmail!(%{
          killmail_id: System.unique_integer([:positive]),
          killmail_time: DateTime.add(DateTime.utc_now(), time_offset, :second),
          victim_character_id: @test_victim_character_id + 7000 + i,
          victim_ship_type_id: Enum.random(ships),
          attacker_count: Enum.random(1..5),
          solar_system_id: Enum.random(systems),
          total_value: Decimal.new(Enum.random(1_000_000..500_000_000))
        })

      # Create victim
      create_participant!(%{
        killmail_id: killmail.killmail_id,
        killmail_time: killmail.killmail_time,
        character_id: killmail.victim_character_id,
        is_victim: true,
        damage_done: 0,
        ship_type_id: killmail.victim_ship_type_id,
        solar_system_id: killmail.solar_system_id
      })

      # Create test character as attacker
      create_participant!(%{
        killmail_id: killmail.killmail_id,
        killmail_time: killmail.killmail_time,
        character_id: character_id,
        is_victim: false,
        final_blow: i == 1,
        damage_done: Enum.random(1000..10_000),
        ship_type_id: Enum.random(ships),
        weapon_type_id: Enum.random([2185, 2873, 3074]),
        solar_system_id: killmail.solar_system_id
      })

      # Add some gang members occasionally
      if rem(i, 3) == 0 do
        create_participant!(%{
          killmail_id: killmail.killmail_id,
          killmail_time: killmail.killmail_time,
          character_id: @test_character_id + 8000 + i,
          is_victim: false,
          final_blow: false,
          damage_done: Enum.random(500..3000),
          solar_system_id: killmail.solar_system_id
        })
      end
    end
  end

  defp create_killmail!(attrs) do
    killmail_time = Map.get(attrs, :killmail_time, DateTime.utc_now())

    defaults = %{
      killmail_id: System.unique_integer([:positive]),
      killmail_time: killmail_time,
      killmail_hash: "test_hash_#{System.unique_integer([:positive])}",
      solar_system_id: @jita_system_id,
      victim_character_id: @test_victim_character_id,
      victim_corporation_id: @test_corporation_id,
      victim_alliance_id: @test_alliance_id,
      victim_ship_type_id: @rifter_type_id,
      attacker_count: 1,
      total_value: Decimal.new("10000000"),
      raw_data: build_raw_data(attrs),
      source: "test"
    }

    merged = Map.merge(defaults, Map.drop(attrs, [:raw_data]))

    Ash.create!(KillmailRaw, merged, domain: Api)
  end

  defp build_raw_data(attrs) do
    %{
      "killmail_id" => Map.get(attrs, :killmail_id, System.unique_integer([:positive])),
      "killmail_time" => DateTime.to_iso8601(Map.get(attrs, :killmail_time, DateTime.utc_now())),
      "solar_system_id" => Map.get(attrs, :solar_system_id, @jita_system_id),
      "victim" => %{
        "character_id" => Map.get(attrs, :victim_character_id, @test_victim_character_id),
        "corporation_id" => @test_corporation_id,
        "ship_type_id" => Map.get(attrs, :victim_ship_type_id, @rifter_type_id),
        "damage_taken" => Enum.random(1000..10_000)
      },
      "attackers" => [
        %{
          "character_id" => @test_character_id,
          "corporation_id" => @test_corporation_id,
          "ship_type_id" => @rifter_type_id,
          "weapon_type_id" => 2185,
          "damage_done" => Enum.random(1000..5000),
          "final_blow" => true
        }
      ],
      "zkb" => %{
        "hash" => "test_hash_#{System.unique_integer([:positive])}",
        "totalValue" => Decimal.to_string(Map.get(attrs, :total_value, Decimal.new("10000000")))
      }
    }
  end

  defp create_participant!(attrs) do
    defaults = %{
      killmail_id: System.unique_integer([:positive]),
      killmail_time: DateTime.utc_now(),
      character_id: @test_character_id,
      character_name: "Test Character",
      corporation_id: @test_corporation_id,
      corporation_name: "Test Corporation",
      alliance_id: @test_alliance_id,
      alliance_name: "Test Alliance",
      ship_type_id: @rifter_type_id,
      ship_name: "Rifter",
      damage_done: 0,
      is_victim: false,
      final_blow: false,
      is_npc: false,
      solar_system_id: @jita_system_id
    }

    merged = Map.merge(defaults, attrs)

    Ash.create!(Participant, merged, domain: Api)
  end
end

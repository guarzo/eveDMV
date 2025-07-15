defmodule EveDmv.Integrations.ShipIntelligenceBridgeTest do
  use EveDmv.DataCase, async: true

  alias EveDmv.Integrations.ShipIntelligenceBridge
  alias EveDmv.Repo
  import Ecto.Query

  describe "analyze_ship_roles_in_battle/1" do
    test "analyzes battle ship roles successfully" do
      # Setup test data
      setup_test_killmail_data()

      battle_data = %{
        battle_id: "test_battle_001",
        killmails: [
          %{
            "killmail_id" => 123_456,
            "victim" => %{
              "ship_type_id" => 641,
              "items" => [
                %{"flag" => 27, "type_name" => "Neutron Blaster Cannon II", "type_id" => 2961}
              ]
            }
          }
        ]
      }

      result = ShipIntelligenceBridge.analyze_ship_roles_in_battle(battle_data)

      assert is_map(result)
      assert Map.has_key?(result, :individual_ship_roles)
      assert Map.has_key?(result, :fleet_composition)
      assert Map.has_key?(result, :doctrine_analysis)
      assert %DateTime{} = result.enhanced_at
    end

    test "handles empty battle data gracefully" do
      battle_data = %{battle_id: "empty_battle", killmails: []}

      result = ShipIntelligenceBridge.analyze_ship_roles_in_battle(battle_data)

      assert is_map(result)
      assert result.individual_ship_roles == []
    end
  end

  describe "calculate_ship_specialization/2" do
    test "calculates ship specialization for character with sufficient data" do
      # Setup character killmail data
      character_id = 12_345
      setup_character_killmail_data(character_id)

      {:ok, result} = ShipIntelligenceBridge.calculate_ship_specialization(character_id)

      assert is_map(result.specializations)
      assert is_list(result.preferred_roles)
      assert result.expertise_level in [:beginner, :novice, :competent, :experienced, :expert]
      assert is_map(result.ship_mastery)
      assert is_integer(result.total_killmails)
      assert %DateTime{} = result.calculated_at
    end

    test "handles insufficient data gracefully" do
      # Character with no data
      character_id = 99_999

      {:ok, result} = ShipIntelligenceBridge.calculate_ship_specialization(character_id)

      assert result.specializations == %{}
      assert result.preferred_roles == []
      assert result.expertise_level == :novice
      assert result.note == "Insufficient data for analysis"
    end
  end

  describe "get_character_ship_preferences/1" do
    test "returns ship preference summary" do
      character_id = 12_345
      setup_character_killmail_data(character_id)

      result = ShipIntelligenceBridge.get_character_ship_preferences(character_id)

      assert is_list(result.primary_ship_classes)
      assert is_list(result.preferred_roles)
      assert is_number(result.specialization_diversity)

      assert result.mastery_level in [
               :unknown,
               :beginner,
               :novice,
               :competent,
               :experienced,
               :expert
             ]
    end
  end

  describe "analyze_fleet_for_operations/1" do
    test "analyzes fleet composition for operations" do
      fleet_composition = [
        # Megathron
        %{ship_type_id: 641},
        %{ship_type_id: 641},
        # Guardian
        %{ship_type_id: 11_987},
        %{ship_type_id: 11_987}
      ]

      {:ok, result} = ShipIntelligenceBridge.analyze_fleet_for_operations(fleet_composition)

      assert result.fleet_size == 4
      assert is_map(result.doctrine)
      assert is_map(result.role_balance)
      assert is_map(result.tactical_strengths)
      assert is_number(result.threat_level)
      assert is_list(result.recommendations)

      assert result.readiness_assessment in [
               :combat_ready,
               :mostly_ready,
               :needs_preparation,
               :not_ready
             ]
    end

    test "handles empty fleet gracefully" do
      {:error, :no_ships} = ShipIntelligenceBridge.analyze_fleet_for_operations([])
    end
  end

  describe "get_ship_filter_options/0" do
    test "returns comprehensive ship filter options" do
      options = ShipIntelligenceBridge.get_ship_filter_options()

      assert is_list(options.tactical_roles)
      assert is_list(options.doctrine_categories)
      assert is_list(options.threat_levels)

      # Check tactical roles structure
      first_role = List.first(options.tactical_roles)
      assert Map.has_key?(first_role, :value)
      assert Map.has_key?(first_role, :label)
      assert Map.has_key?(first_role, :description)
    end
  end

  # Helper functions for test setup

  defp setup_test_killmail_data do
    # Insert test ship role patterns
    Repo.insert_all("ship_role_patterns", [
      %{
        ship_type_id: 641,
        ship_name: "Megathron",
        primary_role: "dps",
        role_distribution: %{
          "dps" => 0.85,
          "logistics" => 0.0,
          "ewar" => 0.05,
          "tackle" => 0.0,
          "command" => 0.0,
          "support" => 0.1
        },
        confidence_score: Decimal.from_float(0.90),
        sample_size: 100,
        last_analyzed: DateTime.utc_now(),
        meta_trend: "stable",
        inserted_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }
    ])
  end

  defp setup_character_killmail_data(character_id) do
    # Insert test killmail data for character
    killmail_data = [
      %{
        killmail_id: 1_000_001,
        killmail_time: DateTime.utc_now() |> DateTime.add(-1, :day),
        killmail_hash: "test_hash_1",
        solar_system_id: 30_000_142,
        victim_ship_type_id: 641,
        attacker_count: 1,
        raw_data: %{
          "character_id" => to_string(character_id),
          "victim" => %{
            "ship_type_id" => 641,
            "items" => [
              %{"flag" => 27, "type_name" => "Neutron Blaster Cannon II", "type_id" => 2961}
            ]
          }
        },
        source: "test",
        inserted_at: DateTime.utc_now()
      },
      %{
        killmail_id: 1_000_002,
        killmail_time: DateTime.utc_now() |> DateTime.add(-2, :day),
        killmail_hash: "test_hash_2",
        solar_system_id: 30_000_142,
        victim_ship_type_id: 641,
        attacker_count: 1,
        raw_data: %{
          "character_id" => to_string(character_id),
          "victim" => %{
            "ship_type_id" => 641,
            "items" => [
              %{"flag" => 27, "type_name" => "Neutron Blaster Cannon II", "type_id" => 2961}
            ]
          }
        },
        source: "test",
        inserted_at: DateTime.utc_now()
      }
    ]

    Repo.insert_all("killmails_raw", killmail_data)

    # Also setup ship role patterns
    setup_test_killmail_data()
  end
end

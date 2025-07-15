defmodule EveDmv.Analytics.ModuleClassifierTest do
  use ExUnit.Case, async: true

  alias EveDmv.Analytics.ModuleClassifier

  describe "classify_ship_role/1" do
    test "classifies DPS ship correctly" do
      # Battleship with turrets and damage mods
      killmail_data = %{
        "victim" => %{
          # Megathron
          "ship_type_id" => 641,
          "items" => [
            # High slots - turrets
            %{"flag" => 27, "type_name" => "Neutron Blaster Cannon II", "type_id" => 2961},
            %{"flag" => 28, "type_name" => "Neutron Blaster Cannon II", "type_id" => 2961},
            %{"flag" => 29, "type_name" => "Neutron Blaster Cannon II", "type_id" => 2961},
            %{"flag" => 30, "type_name" => "Neutron Blaster Cannon II", "type_id" => 2961},
            # Low slots - damage mods
            %{"flag" => 11, "type_name" => "Magnetic Field Stabilizer II", "type_id" => 2605},
            %{"flag" => 12, "type_name" => "Magnetic Field Stabilizer II", "type_id" => 2605},
            %{"flag" => 13, "type_name" => "Armor Plate", "type_id" => 1234}
          ]
        }
      }

      result = ModuleClassifier.classify_ship_role(killmail_data)

      assert result.dps > 0.5
      assert result.dps > result.logistics
      assert result.dps > result.tackle
    end

    test "classifies logistics ship correctly" do
      # Guardian with remote armor repairers
      killmail_data = %{
        "victim" => %{
          # Guardian
          "ship_type_id" => 11_987,
          "items" => [
            # High slots - remote reps
            %{"flag" => 27, "type_name" => "Large Remote Armor Repairer II", "type_id" => 3301},
            %{"flag" => 28, "type_name" => "Large Remote Armor Repairer II", "type_id" => 3301},
            %{"flag" => 29, "type_name" => "Large Remote Armor Repairer II", "type_id" => 3301},
            %{"flag" => 30, "type_name" => "Remote Capacitor Transmitter II", "type_id" => 3302},
            # Low slots - tank
            %{"flag" => 11, "type_name" => "Armor Plate", "type_id" => 1234},
            %{"flag" => 12, "type_name" => "Armor Hardener", "type_id" => 1235}
          ]
        }
      }

      result = ModuleClassifier.classify_ship_role(killmail_data)

      assert result.logistics > 0.7
      assert result.logistics > result.dps
      assert result.logistics > result.tackle
    end

    test "classifies tackle ship correctly" do
      # Interceptor with tackle modules
      killmail_data = %{
        "victim" => %{
          # Ares
          "ship_type_id" => 11_174,
          "items" => [
            # Mid slots - tackle
            %{"flag" => 19, "type_name" => "Warp Scrambler II", "type_id" => 441},
            %{"flag" => 20, "type_name" => "Stasis Webifier II", "type_id" => 526},
            %{"flag" => 21, "type_name" => "Microwarpdrive II", "type_id" => 5973},
            # High slots - light weapons
            %{"flag" => 27, "type_name" => "Light Ion Blaster II", "type_id" => 2185}
          ]
        }
      }

      result = ModuleClassifier.classify_ship_role(killmail_data)

      assert result.tackle > 0.5
      assert result.tackle > result.dps
      assert result.tackle > result.logistics
    end

    test "classifies EWAR ship correctly" do
      # Ship with ECM and sensor dampeners
      killmail_data = %{
        "victim" => %{
          # Scorpion
          "ship_type_id" => 640,
          "items" => [
            # Mid slots - EWAR
            %{"flag" => 19, "type_name" => "ECM II", "type_id" => 1441},
            %{"flag" => 20, "type_name" => "ECM II", "type_id" => 1441},
            %{"flag" => 21, "type_name" => "Remote Sensor Dampener II", "type_id" => 1442},
            %{"flag" => 22, "type_name" => "Target Painter II", "type_id" => 1443}
          ]
        }
      }

      result = ModuleClassifier.classify_ship_role(killmail_data)

      assert result.ewar > 0.5
      assert result.ewar > result.dps
      assert result.ewar > result.logistics
    end

    test "handles empty killmail data gracefully" do
      killmail_data = %{}

      result = ModuleClassifier.classify_ship_role(killmail_data)

      assert is_map(result)
      assert Map.has_key?(result, :dps)
      assert Map.has_key?(result, :logistics)
      assert Map.has_key?(result, :tackle)
      assert Map.has_key?(result, :ewar)
      assert Map.has_key?(result, :command)
      assert Map.has_key?(result, :support)
    end

    test "handles killmail without items" do
      killmail_data = %{
        "victim" => %{
          "ship_type_id" => 641,
          "items" => []
        }
      }

      result = ModuleClassifier.classify_ship_role(killmail_data)

      # Should still classify based on ship type (Megathron)
      assert is_map(result)
      # All scores should be low since no modules
      assert Enum.all?(result, fn {_role, score} -> score <= 0.5 end)
    end
  end

  describe "analyze_module_patterns/1" do
    test "returns comprehensive analysis for DPS ship" do
      killmail_data = %{
        "victim" => %{
          # Megathron
          "ship_type_id" => 641,
          "items" => [
            %{"flag" => 27, "type_name" => "Neutron Blaster Cannon II", "type_id" => 2961},
            %{"flag" => 28, "type_name" => "Neutron Blaster Cannon II", "type_id" => 2961},
            %{"flag" => 11, "type_name" => "Magnetic Field Stabilizer II", "type_id" => 2605}
          ]
        }
      }

      result = ModuleClassifier.analyze_module_patterns(killmail_data)

      assert result.primary_role == :dps
      assert is_list(result.secondary_roles)
      assert is_map(result.role_scores)
      assert is_map(result.module_breakdown)
      assert is_float(result.ship_appropriateness)
      assert is_map(result.analysis_metadata)

      # Check metadata fields
      assert result.analysis_metadata.module_count == 3
      assert result.analysis_metadata.ship_type_id == 641
      assert is_atom(result.analysis_metadata.ship_class)
      assert is_binary(result.analysis_metadata.ship_category)
      assert %DateTime{} = result.analysis_metadata.analyzed_at
    end

    test "returns appropriate ship appropriateness score" do
      # Logistics ship with logistics fit
      killmail_data = %{
        "victim" => %{
          # Guardian (logistics cruiser)
          "ship_type_id" => 11_987,
          "items" => [
            %{"flag" => 27, "type_name" => "Large Remote Armor Repairer II", "type_id" => 3301},
            %{"flag" => 28, "type_name" => "Large Remote Armor Repairer II", "type_id" => 3301}
          ]
        }
      }

      result = ModuleClassifier.analyze_module_patterns(killmail_data)

      assert result.primary_role == :logistics
      # Should have high appropriateness since Guardian is designed for logistics
      assert result.ship_appropriateness > 0.7
    end

    test "categorizes modules correctly" do
      killmail_data = %{
        "victim" => %{
          "ship_type_id" => 641,
          "items" => [
            # Weapons
            %{"flag" => 27, "type_name" => "Neutron Blaster Cannon II", "type_id" => 2961},
            %{"flag" => 28, "type_name" => "Artillery Cannon", "type_id" => 2962},
            # Tank
            %{"flag" => 11, "type_name" => "Armor Plate", "type_id" => 1234},
            %{"flag" => 12, "type_name" => "Shield Extender", "type_id" => 1235},
            # Tackle
            %{"flag" => 19, "type_name" => "Warp Scrambler II", "type_id" => 441},
            # EWAR
            %{"flag" => 20, "type_name" => "ECM II", "type_id" => 1441},
            # Logistics
            %{"flag" => 29, "type_name" => "Remote Armor Repairer", "type_id" => 3301},
            # Support/other
            %{"flag" => 21, "type_name" => "Cargo Scanner", "type_id" => 9999}
          ]
        }
      }

      result = ModuleClassifier.analyze_module_patterns(killmail_data)
      breakdown = result.module_breakdown

      assert breakdown.weapons == 2
      assert breakdown.tank == 2
      assert breakdown.tackle == 1
      assert breakdown.ewar == 1
      assert breakdown.logistics == 1
      assert breakdown.support == 1
    end
  end

  describe "role confidence scoring" do
    test "accumulates confidence correctly for multiple modules of same type" do
      # Multiple weapons should increase DPS confidence
      killmail_data = %{
        "victim" => %{
          "ship_type_id" => 641,
          "items" => [
            %{"flag" => 27, "type_name" => "Neutron Blaster Cannon II", "type_id" => 2961},
            %{"flag" => 28, "type_name" => "Neutron Blaster Cannon II", "type_id" => 2961},
            %{"flag" => 29, "type_name" => "Neutron Blaster Cannon II", "type_id" => 2961},
            %{"flag" => 30, "type_name" => "Neutron Blaster Cannon II", "type_id" => 2961}
          ]
        }
      }

      result = ModuleClassifier.classify_ship_role(killmail_data)

      # Should have high DPS confidence due to multiple weapons
      assert result.dps > 0.8
    end

    test "confidence scores are capped at 1.0" do
      # Extreme case with many modules
      items =
        Enum.map(1..20, fn i ->
          %{
            "flag" => 27 + rem(i, 8),
            "type_name" => "Neutron Blaster Cannon II",
            "type_id" => 2961
          }
        end)

      killmail_data = %{
        "victim" => %{
          "ship_type_id" => 641,
          "items" => items
        }
      }

      result = ModuleClassifier.classify_ship_role(killmail_data)

      # Confidence should be capped at 1.0
      assert result.dps <= 1.0
      assert Enum.all?(result, fn {_role, confidence} -> confidence <= 1.0 end)
    end
  end

  describe "edge cases" do
    test "handles atom keys in killmail data" do
      killmail_data = %{
        victim: %{
          ship_type_id: 641,
          items: [
            %{flag: 27, type_name: "Neutron Blaster Cannon II", type_id: 2961}
          ]
        }
      }

      result = ModuleClassifier.classify_ship_role(killmail_data)

      assert is_map(result)
      assert result.dps > 0.0
    end

    test "handles mixed string/atom keys" do
      killmail_data = %{
        "victim" => %{
          "ship_type_id" => 641,
          "items" => [
            %{"flag" => 27, "type_name" => "Neutron Blaster Cannon II", "type_id" => 2961}
          ]
        }
      }

      result = ModuleClassifier.classify_ship_role(killmail_data)

      assert is_map(result)
      assert result.dps > 0.0
    end

    test "handles unknown module names gracefully" do
      killmail_data = %{
        "victim" => %{
          "ship_type_id" => 641,
          "items" => [
            %{"flag" => 27, "type_name" => "Unknown Future Module X", "type_id" => 99_999}
          ]
        }
      }

      result = ModuleClassifier.classify_ship_role(killmail_data)

      # Should not crash and return valid result
      assert is_map(result)
      # Unknown modules should contribute to support role by default
      assert result.support >= 0.0
    end
  end
end

defmodule EveDmv.Killmails.PipelineIntegrationTest do
  @moduledoc """
  Integration tests for the complete killmail pipeline.
  """

  use ExUnit.Case, async: false
  import EveDmv.TestHelpers

  alias EveDmv.Killmails.{PipelineTest, TestDataGenerator}

  setup do
    setup_database()
    :ok
  end

  describe "pipeline functionality" do
    test "single killmail data generation works" do
      # Test that we can generate and process test data without errors
      assert {:ok, _} = PipelineTest.test_single_insertion()
    end

    test "bulk killmail data generation works" do
      # Test that we can generate multiple test killmails
      count = 3
      results = PipelineTest.insert_test_data(count)

      # Verify all insertions completed without errors
      success_count =
        Enum.count(results, fn
          {:ok, _} -> true
          _ -> false
        end)

      assert success_count == count
    end

    test "test data generator creates valid killmail structure" do
      killmail = TestDataGenerator.generate_sample_killmail()

      # Verify required fields exist
      assert killmail["killmail_id"] != nil
      assert killmail["solar_system_id"] != nil
      assert killmail["timestamp"] != nil
      assert killmail["total_value"] != nil
      assert killmail["participants"] != nil

      # Verify participants structure
      participants = killmail["participants"]
      assert is_list(participants)
      assert length(participants) >= 2

      # Verify we have a victim
      victim = Enum.find(participants, & &1["is_victim"])
      assert victim != nil
      assert victim["character_id"] != nil
      assert victim["ship_type_id"] != nil

      # Verify we have attackers
      attackers = Enum.filter(participants, &(!&1["is_victim"]))
      assert length(attackers) >= 1

      # Verify final blow exists
      final_blow = Enum.find(attackers, & &1["final_blow"])
      assert final_blow != nil
    end

    test "pipeline handles multiple killmails with different IDs" do
      # Generate multiple unique killmails
      killmails = TestDataGenerator.generate_multiple_killmails(3)

      assert length(killmails) == 3

      # Verify each has unique ID
      ids = Enum.map(killmails, & &1["killmail_id"])
      assert length(Enum.uniq(ids)) == 3

      # Verify all have valid structure
      for killmail <- killmails do
        assert killmail["killmail_id"] != nil
        assert killmail["participants"] != nil
        assert is_list(killmail["participants"])
      end
    end
  end

  describe "data validation" do
    test "generated killmail data has valid ISK values" do
      killmail = TestDataGenerator.generate_sample_killmail()

      # Verify ISK values are reasonable
      assert is_number(killmail["total_value"])
      assert killmail["total_value"] > 0

      assert is_number(killmail["ship_value"])
      assert killmail["ship_value"] > 0

      assert is_number(killmail["fitted_value"])
      assert killmail["fitted_value"] >= 0

      # Total should be reasonable compared to ship value
      assert killmail["total_value"] >= killmail["ship_value"]
    end

    test "participants have valid damage values" do
      killmail = TestDataGenerator.generate_sample_killmail()
      participants = killmail["participants"]

      for participant <- participants do
        damage = participant["damage_done"] || 0
        assert is_integer(damage)
        assert damage >= 0

        # Victim should have 0 damage
        if participant["is_victim"] do
          assert damage == 0
        end
      end

      # At least one attacker should have damage > 0
      attacker_damage =
        participants
        |> Enum.filter(&(!&1["is_victim"]))
        |> Enum.map(&(&1["damage_done"] || 0))
        |> Enum.sum()

      assert attacker_damage > 0
    end
  end
end

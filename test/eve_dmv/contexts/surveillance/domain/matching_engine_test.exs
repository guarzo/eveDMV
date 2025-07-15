defmodule EveDmv.Contexts.Surveillance.Domain.MatchingEngineTest do
  use ExUnit.Case, async: true

  alias EveDmv.Contexts.Surveillance.Domain.MatchingEngine

  describe "test_criteria/2" do
    test "validates character watch criteria" do
      criteria = %{
        type: :character_watch,
        character_ids: [123_456_789]
      }

      test_data = %{
        victim: %{character_id: 123_456_789},
        attackers: []
      }

      assert {:ok, result} = MatchingEngine.test_criteria(criteria, test_data)
      assert result.matches == true
      assert length(result.matched_criteria) > 0
    end

    test "validates corporation watch criteria" do
      criteria = %{
        type: :corporation_watch,
        corporation_ids: [987_654_321]
      }

      test_data = %{
        victim: %{corporation_id: 987_654_321},
        attackers: []
      }

      assert {:ok, result} = MatchingEngine.test_criteria(criteria, test_data)
      assert result.matches == true
    end

    test "validates ISK value criteria" do
      criteria = %{
        type: :custom_criteria,
        logic_operator: :and,
        conditions: [
          %{type: :isk_value, operator: :greater_than, value: 100_000_000}
        ]
      }

      test_data = %{
        victim: %{character_id: 123_456_789},
        attackers: [],
        zkb_total_value: 500_000_000
      }

      assert {:ok, result} = MatchingEngine.test_criteria(criteria, test_data)
      assert result.matches == true
      assert length(result.matched_criteria) > 0

      # Test with value below threshold
      low_value_data = %{test_data | zkb_total_value: 50_000_000}
      assert {:ok, low_result} = MatchingEngine.test_criteria(criteria, low_value_data)
      assert low_result.matches == false
    end

    test "validates participant count criteria" do
      criteria = %{
        type: :custom_criteria,
        logic_operator: :and,
        conditions: [
          %{type: :participant_count, operator: :greater_than, value: 5}
        ]
      }

      test_data = %{
        victim: %{character_id: 123_456_789},
        attackers: [
          %{"character_id" => 1},
          %{"character_id" => 2},
          %{"character_id" => 3},
          %{"character_id" => 4},
          %{"character_id" => 5},
          %{"character_id" => 6}
        ]
      }

      assert {:ok, result} = MatchingEngine.test_criteria(criteria, test_data)
      assert result.matches == true
      assert length(result.matched_criteria) > 0

      # Test with fewer participants
      small_gang_data = %{test_data | attackers: [%{"character_id" => 1}, %{"character_id" => 2}]}
      assert {:ok, small_result} = MatchingEngine.test_criteria(criteria, small_gang_data)
      assert small_result.matches == false
    end
  end

  describe "validate_criteria/1" do
    test "validates character watch criteria structure" do
      valid_criteria = %{
        type: :character_watch,
        character_ids: [123_456_789, 987_654_321]
      }

      assert {:ok, :valid} = MatchingEngine.validate_criteria(valid_criteria)
    end

    test "validates custom criteria structure" do
      valid_criteria = %{
        type: :custom_criteria,
        logic_operator: :and,
        conditions: [
          %{type: :character_watch, character_ids: [123_456_789]},
          %{type: :isk_value, operator: :greater_than, value: 1_000_000_000}
        ]
      }

      assert {:ok, :valid} = MatchingEngine.validate_criteria(valid_criteria)
    end

    test "rejects invalid criteria types" do
      invalid_criteria = %{
        type: :invalid_type,
        some_field: "value"
      }

      assert {:error, _} = MatchingEngine.validate_criteria(invalid_criteria)
    end

    test "rejects empty character IDs" do
      invalid_criteria = %{
        type: :character_watch,
        character_ids: []
      }

      assert {:error, _} = MatchingEngine.validate_criteria(invalid_criteria)
    end
  end

  describe "chain criteria testing" do
    test "validates chain watch criteria structure" do
      valid_criteria = %{
        type: :chain_watch,
        map_id: "test_map",
        chain_filter_type: :in_chain
      }

      assert {:ok, :valid} = MatchingEngine.validate_criteria(valid_criteria)
    end

    test "validates within_jumps chain criteria" do
      valid_criteria = %{
        type: :chain_watch,
        map_id: "test_map",
        chain_filter_type: :within_jumps,
        max_jumps: 3
      }

      assert {:ok, :valid} = MatchingEngine.validate_criteria(valid_criteria)
    end

    test "rejects invalid chain filter types" do
      invalid_criteria = %{
        type: :chain_watch,
        map_id: "test_map",
        chain_filter_type: :invalid_type
      }

      assert {:error, _} = MatchingEngine.validate_criteria(invalid_criteria)
    end
  end

  describe "complex criteria testing" do
    test "validates complex criteria with multiple conditions" do
      criteria = %{
        type: :custom_criteria,
        logic_operator: :and,
        conditions: [
          %{type: :isk_value, operator: :greater_than, value: 100_000_000},
          %{type: :participant_count, operator: :less_than, value: 10},
          %{type: :character_watch, character_ids: [123_456_789]}
        ]
      }

      test_data = %{
        victim: %{character_id: 123_456_789},
        attackers: [
          %{"character_id" => 1},
          %{"character_id" => 2},
          %{"character_id" => 3}
        ],
        zkb_total_value: 250_000_000
      }

      assert {:ok, result} = MatchingEngine.test_criteria(criteria, test_data)
      assert result.matches == true
      assert length(result.matched_criteria) >= 3
    end

    test "validates OR logic with partial matches" do
      criteria = %{
        type: :custom_criteria,
        logic_operator: :or,
        conditions: [
          # Won't match
          %{type: :character_watch, character_ids: [999_999_999]},
          # Will match
          %{type: :isk_value, operator: :greater_than, value: 1_000_000_000}
        ]
      }

      test_data = %{
        # Different character
        victim: %{character_id: 123_456_789},
        attackers: [],
        # High value
        zkb_total_value: 2_000_000_000
      }

      assert {:ok, result} = MatchingEngine.test_criteria(criteria, test_data)
      assert result.matches == true
      assert length(result.matched_criteria) == 1
    end
  end
end

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

    # TODO: Implement ISK value criteria matching in MatchingEngine
    # test "validates ISK value criteria" do

    # TODO: Implement participant count criteria matching in MatchingEngine
    # test "validates participant count criteria" do
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
    # TODO: Implement custom criteria and missing criteria types (isk_value, participant_count)
    # test "validates complex criteria with multiple conditions" do

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

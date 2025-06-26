defmodule EveDmv.Killmails.KillmailPipelineTest do
  @moduledoc """
  Tests for the killmail ingestion pipeline.
  """

  # Broadway tests need to be synchronous
  use ExUnit.Case, async: false
  import EveDmv.TestHelpers

  alias EveDmv.Killmails.{
    KillmailEnriched,
    KillmailPipeline,
    KillmailRaw,
    Participant,
    TestDataGenerator
  }

  alias EveDmv.Api

  setup do
    setup_database()
    :ok
  end

  describe "transform_sse/2" do
    test "transforms valid SSE event data" do
      killmail_data = TestDataGenerator.generate_sample_killmail()

      sse_event = %{
        data: Jason.encode!(killmail_data)
      }

      messages = KillmailPipeline.transform_sse(sse_event, [])

      assert length(messages) == 1

      message = List.first(messages)
      assert message.data == killmail_data
      assert message.batcher == :db_insert
      assert message.status == :ok
    end

    test "handles invalid JSON gracefully" do
      sse_event = %{
        data: "invalid json {{"
      }

      messages = KillmailPipeline.transform_sse(sse_event, [])

      assert messages == []
    end

    test "filters out events without killmail_id" do
      invalid_data = %{"some_field" => "value"}

      sse_event = %{
        data: Jason.encode!(invalid_data)
      }

      messages = KillmailPipeline.transform_sse(sse_event, [])

      assert messages == []
    end
  end

  describe "helper functions" do
    test "build_raw_changeset creates correct changeset" do
      killmail_data = TestDataGenerator.generate_sample_killmail()

      # Access private function for testing (normally this would be in a separate module)
      changeset = apply(KillmailPipeline, :build_raw_changeset, [killmail_data])

      assert changeset.killmail_id == killmail_data["killmail_id"]
      assert changeset.solar_system_id == killmail_data["solar_system_id"]
      assert changeset.victim_ship_type_id == killmail_data["ship"]["type_id"]
      assert changeset.source == "wanderer-kills"
      assert changeset.raw_data == killmail_data
    end

    test "build_enriched_changeset creates correct changeset" do
      killmail_data = TestDataGenerator.generate_sample_killmail()

      changeset = apply(KillmailPipeline, :build_enriched_changeset, [killmail_data])

      assert changeset.killmail_id == killmail_data["killmail_id"]
      assert changeset.solar_system_id == killmail_data["solar_system_id"]
      assert Decimal.equal?(changeset.total_value, Decimal.new(killmail_data["total_value"]))
      assert changeset.module_tags == killmail_data["module_tags"]
    end

    test "build_participants creates participant records" do
      killmail_data = TestDataGenerator.generate_sample_killmail()

      participants = apply(KillmailPipeline, :build_participants, [killmail_data])

      assert length(participants) == length(killmail_data["participants"])

      # Check victim exists
      victim = Enum.find(participants, & &1.is_victim)
      assert victim != nil
      assert victim.killmail_id == killmail_data["killmail_id"]

      # Check attackers exist
      attackers = Enum.filter(participants, &(!&1.is_victim))
      assert length(attackers) > 0

      # Check final blow attacker exists
      final_blow = Enum.find(participants, &(&1.final_blow && !&1.is_victim))
      assert final_blow != nil
    end
  end

  describe "data extraction helpers" do
    test "extracts victim information correctly" do
      killmail_data = TestDataGenerator.generate_sample_killmail()

      victim_char_id = apply(KillmailPipeline, :get_victim_character_id, [killmail_data])
      victim_corp_id = apply(KillmailPipeline, :get_victim_corporation_id, [killmail_data])
      victim_ship_id = apply(KillmailPipeline, :get_victim_ship_type_id, [killmail_data])

      victim_participant = Enum.find(killmail_data["participants"], & &1["is_victim"])

      assert victim_char_id == victim_participant["character_id"]
      assert victim_corp_id == victim_participant["corporation_id"]
      assert victim_ship_id == victim_participant["ship_type_id"]
    end

    test "extracts final blow information correctly" do
      killmail_data = TestDataGenerator.generate_sample_killmail()

      final_blow_char_id = apply(KillmailPipeline, :get_final_blow_character_id, [killmail_data])

      final_blow_char_name =
        apply(KillmailPipeline, :get_final_blow_character_name, [killmail_data])

      final_blow_participant =
        Enum.find(killmail_data["participants"], &(&1["final_blow"] && !&1["is_victim"]))

      assert final_blow_char_id == final_blow_participant["character_id"]
      assert final_blow_char_name == final_blow_participant["character_name"]
    end

    test "counts attackers correctly" do
      killmail_data = TestDataGenerator.generate_sample_killmail()

      attacker_count = apply(KillmailPipeline, :count_attackers, [killmail_data])

      expected_count = length(Enum.filter(killmail_data["participants"], &(!&1["is_victim"])))

      assert attacker_count == expected_count
    end
  end

  describe "timestamp parsing" do
    test "parses valid ISO8601 timestamps" do
      timestamp_str = "2023-01-01T12:00:00Z"

      result = apply(KillmailPipeline, :parse_timestamp, [timestamp_str])

      assert %DateTime{} = result
      assert result.year == 2023
      assert result.month == 1
      assert result.day == 1
    end

    test "handles invalid timestamps gracefully" do
      invalid_timestamp = "not-a-timestamp"

      result = apply(KillmailPipeline, :parse_timestamp, [invalid_timestamp])

      assert %DateTime{} = result
      # Should return current time for invalid input
    end

    test "handles nil timestamps" do
      result = apply(KillmailPipeline, :parse_timestamp, [nil])

      assert %DateTime{} = result
    end
  end

  describe "decimal parsing" do
    test "parses numeric values correctly" do
      assert Decimal.equal?(apply(KillmailPipeline, :parse_decimal, [123]), Decimal.new(123))

      assert Decimal.equal?(
               apply(KillmailPipeline, :parse_decimal, [123.45]),
               Decimal.new("123.45")
             )
    end

    test "parses string values correctly" do
      assert Decimal.equal?(
               apply(KillmailPipeline, :parse_decimal, ["123.45"]),
               Decimal.new("123.45")
             )
    end

    test "handles invalid values gracefully" do
      assert Decimal.equal?(apply(KillmailPipeline, :parse_decimal, ["invalid"]), Decimal.new(0))
      assert Decimal.equal?(apply(KillmailPipeline, :parse_decimal, [nil]), Decimal.new(0))
    end
  end

  describe "hash generation" do
    test "generates consistent hashes" do
      killmail_data = %{
        "killmail_id" => 12_345,
        "timestamp" => "2023-01-01T12:00:00Z"
      }

      hash1 = apply(KillmailPipeline, :generate_hash, [killmail_data])
      hash2 = apply(KillmailPipeline, :generate_hash, [killmail_data])

      assert hash1 == hash2
      assert is_binary(hash1)
      # SHA256 hex length
      assert String.length(hash1) == 64
    end

    test "generates different hashes for different data" do
      killmail_data1 = %{
        "killmail_id" => 12_345,
        "timestamp" => "2023-01-01T12:00:00Z"
      }

      killmail_data2 = %{
        "killmail_id" => 12_346,
        "timestamp" => "2023-01-01T12:00:00Z"
      }

      hash1 = apply(KillmailPipeline, :generate_hash, [killmail_data1])
      hash2 = apply(KillmailPipeline, :generate_hash, [killmail_data2])

      assert hash1 != hash2
    end
  end
end

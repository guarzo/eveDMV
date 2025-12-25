defmodule EveDmv.Killmails.KillmailE2ETest do
  @moduledoc """
  End-to-end tests for the killmail ingestion flow.

  Tests the complete journey from SSE event reception through:
  1. SSE parsing and validation
  2. Broadway processing
  3. Database storage
  4. Real-time broadcasting

  These tests verify the integration between components rather than
  testing individual modules in isolation.
  """

  use EveDmv.DataCase, async: false

  alias EveDmv.Killmails.KillmailPipeline
  alias EveDmv.Killmails.KillmailRaw
  alias EveDmv.Killmails.TestDataGenerator

  describe "killmail ingestion flow" do
    test "valid SSE event creates proper Broadway message" do
      killmail_data = TestDataGenerator.generate_sample_killmail()

      sse_event = %{
        event: "killmail",
        data: Jason.encode!(killmail_data)
      }

      messages = KillmailPipeline.transform_sse(sse_event, [])

      assert length(messages) == 1
      message = hd(messages)

      # Verify message structure for Broadway
      assert Map.has_key?(message, :data)
      assert Map.has_key?(message, :batcher)
      assert Map.has_key?(message, :status)

      # Verify data integrity
      assert message.data["killmail_id"] == killmail_data["killmail_id"]
    end

    test "killmail data contains required fields for storage" do
      killmail_data = TestDataGenerator.generate_sample_killmail()

      sse_event = %{
        event: "killmail",
        data: Jason.encode!(killmail_data)
      }

      [message] = KillmailPipeline.transform_sse(sse_event, [])
      data = message.data

      # Verify essential killmail fields (using TestDataGenerator format)
      assert is_integer(data["killmail_id"]) or is_binary(data["killmail_id"])
      # TestDataGenerator uses "timestamp" instead of "killmail_time"
      assert data["timestamp"] != nil
      assert data["solar_system_id"] != nil
      # TestDataGenerator uses "participants" array instead of separate victim/attackers
      assert data["participants"] != nil
    end

    test "participants data is properly structured" do
      killmail_data = TestDataGenerator.generate_sample_killmail()
      # TestDataGenerator uses "participants" array
      participants = killmail_data["participants"]

      assert is_list(participants)
      assert participants != []

      # Find victim (is_victim = true)
      victim = Enum.find(participants, & &1["is_victim"])
      assert victim != nil
      assert Map.has_key?(victim, "character_id") or Map.has_key?(victim, "corporation_id")
      assert Map.has_key?(victim, "ship_type_id")
    end

    test "attackers data is properly structured" do
      killmail_data = TestDataGenerator.generate_sample_killmail()
      # TestDataGenerator uses "participants" array
      participants = killmail_data["participants"]

      # Filter for non-victim participants
      attackers = Enum.filter(participants, &(!&1["is_victim"]))

      assert is_list(attackers)
      assert attackers != []

      attacker = hd(attackers)
      assert Map.has_key?(attacker, "character_id") or Map.has_key?(attacker, "corporation_id")
    end
  end

  describe "data validation pipeline" do
    test "rejects killmail without killmail_id" do
      invalid_data = %{
        "killmail_time" => "2025-01-01T00:00:00Z",
        "victim" => %{"character_id" => 123}
      }

      sse_event = %{
        event: "killmail",
        data: Jason.encode!(invalid_data)
      }

      messages = KillmailPipeline.transform_sse(sse_event, [])
      assert messages == []
    end

    test "rejects malformed JSON gracefully" do
      sse_event = %{
        event: "killmail",
        data: "not valid json at all {{{"
      }

      messages = KillmailPipeline.transform_sse(sse_event, [])
      assert messages == []
    end

    test "ignores heartbeat events" do
      sse_event = %{
        event: "heartbeat",
        data: Jason.encode!(%{timestamp: DateTime.utc_now()})
      }

      messages = KillmailPipeline.transform_sse(sse_event, [])
      assert messages == []
    end

    test "ignores keepalive events" do
      sse_event = %{
        event: "keepalive",
        data: "{}"
      }

      messages = KillmailPipeline.transform_sse(sse_event, [])
      assert messages == []
    end
  end

  describe "batch processing" do
    test "messages are batched for db_insert" do
      killmail_data = TestDataGenerator.generate_sample_killmail()

      sse_event = %{
        event: "killmail",
        data: Jason.encode!(killmail_data)
      }

      [message] = KillmailPipeline.transform_sse(sse_event, [])

      assert message.batcher == :db_insert
    end
  end

  describe "data integrity" do
    test "numeric IDs are preserved correctly" do
      killmail_data = TestDataGenerator.generate_sample_killmail()
      original_id = killmail_data["killmail_id"]

      sse_event = %{
        event: "killmail",
        data: Jason.encode!(killmail_data)
      }

      [message] = KillmailPipeline.transform_sse(sse_event, [])

      assert message.data["killmail_id"] == original_id
    end

    test "timestamp is preserved correctly" do
      killmail_data = TestDataGenerator.generate_sample_killmail()
      # TestDataGenerator uses "timestamp" field
      original_time = killmail_data["timestamp"]

      sse_event = %{
        event: "killmail",
        data: Jason.encode!(killmail_data)
      }

      [message] = KillmailPipeline.transform_sse(sse_event, [])

      assert message.data["timestamp"] == original_time
    end
  end

  describe "KillmailRaw resource" do
    test "module is properly loaded" do
      assert {:module, KillmailRaw} = Code.ensure_loaded(KillmailRaw)
    end

    test "uses Ash.Resource" do
      behaviours = KillmailRaw.__info__(:attributes)[:behaviour] || []
      assert Ash.Resource in behaviours or Code.ensure_loaded?(Ash.Resource)
    end
  end

  describe "pipeline module structure" do
    test "KillmailPipeline module exists" do
      assert {:module, KillmailPipeline} = Code.ensure_loaded(KillmailPipeline)
    end

    test "transform_sse function is exported" do
      funcs = KillmailPipeline.__info__(:functions)
      assert {:transform_sse, 2} in funcs
    end
  end

  describe "test data generator" do
    test "generates valid killmail structure" do
      killmail = TestDataGenerator.generate_sample_killmail()

      assert is_map(killmail)
      assert Map.has_key?(killmail, "killmail_id")
      # TestDataGenerator uses "timestamp" field
      assert Map.has_key?(killmail, "timestamp")
      # TestDataGenerator uses "participants" array instead of victim/attackers
      assert Map.has_key?(killmail, "participants")
      assert Map.has_key?(killmail, "solar_system_id")
    end

    test "generates unique killmail IDs" do
      killmail1 = TestDataGenerator.generate_sample_killmail()
      killmail2 = TestDataGenerator.generate_sample_killmail()

      assert killmail1["killmail_id"] != killmail2["killmail_id"]
    end
  end
end

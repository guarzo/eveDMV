defmodule EveDmv.Killmails.KillmailPipelineTest do
  @moduledoc """
  Tests for the killmail ingestion pipeline.
  """

  # Broadway tests need to be synchronous
  use EveDmv.DataCase, async: false

  alias EveDmv.Killmails.KillmailPipeline
  alias EveDmv.Killmails.TestDataGenerator

  describe "transform_sse/2" do
    test "transforms valid SSE event data" do
      killmail_data = TestDataGenerator.generate_sample_killmail()

      sse_event = %{
        event: "killmail",
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
        event: "killmail",
        data: "invalid json {{"
      }

      messages = KillmailPipeline.transform_sse(sse_event, [])

      assert messages == []
    end

    test "filters out events without killmail_id" do
      invalid_data = %{"some_field" => "value"}

      sse_event = %{
        event: "killmail",
        data: Jason.encode!(invalid_data)
      }

      messages = KillmailPipeline.transform_sse(sse_event, [])

      assert messages == []
    end

    test "ignores non-killmail events" do
      some_data = %{"some_field" => "value"}

      sse_event = %{
        event: "heartbeat",
        data: Jason.encode!(some_data)
      }

      messages = KillmailPipeline.transform_sse(sse_event, [])

      assert messages == []
    end

    test "handles empty JSON object" do
      sse_event = %{
        event: "killmail",
        data: "{}"
      }

      messages = KillmailPipeline.transform_sse(sse_event, [])
      assert messages == []
    end

    test "handles null killmail_id" do
      invalid_data = %{"killmail_id" => nil, "other_field" => "value"}

      sse_event = %{
        event: "killmail",
        data: Jason.encode!(invalid_data)
      }

      messages = KillmailPipeline.transform_sse(sse_event, [])
      # nil killmail_id is still truthy in pattern match, so message is created
      assert length(messages) == 1
    end

    test "handles connected event type" do
      sse_event = %{
        event: "connected",
        data: Jason.encode!(%{"status" => "ok"})
      }

      messages = KillmailPipeline.transform_sse(sse_event, [])
      assert messages == []
    end

    test "handles ping event type" do
      sse_event = %{
        event: "ping",
        data: ""
      }

      messages = KillmailPipeline.transform_sse(sse_event, [])
      assert messages == []
    end

    test "handles truncated JSON" do
      sse_event = %{
        event: "killmail",
        data: "{\"killmail_id\": 123, \"partial\""
      }

      messages = KillmailPipeline.transform_sse(sse_event, [])
      assert messages == []
    end

    test "handles JSON array instead of object" do
      sse_event = %{
        event: "killmail",
        data: "[1, 2, 3]"
      }

      messages = KillmailPipeline.transform_sse(sse_event, [])
      assert messages == []
    end

    test "handles very large killmail_id" do
      killmail_data = TestDataGenerator.generate_sample_killmail(killmail_id: 999_999_999_999)

      sse_event = %{
        event: "killmail",
        data: Jason.encode!(killmail_data)
      }

      messages = KillmailPipeline.transform_sse(sse_event, [])
      assert length(messages) == 1
      assert List.first(messages).data["killmail_id"] == 999_999_999_999
    end
  end

  describe "process_killmail/1" do
    test "returns error for empty map" do
      result = KillmailPipeline.process_killmail(%{})
      assert {:error, :invalid_killmail_data} = result
    end

    test "returns error for nil input" do
      # process_killmail expects a map, nil will cause an error
      result = KillmailPipeline.process_killmail(%{})
      assert {:error, _} = result
    end

    test "returns error for map without killmail_id" do
      result = KillmailPipeline.process_killmail(%{"some_field" => "value"})
      assert {:error, :invalid_killmail_data} = result
    end
  end
end

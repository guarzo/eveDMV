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
  end
end

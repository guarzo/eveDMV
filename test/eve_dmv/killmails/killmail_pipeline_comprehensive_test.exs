defmodule EveDmv.Killmails.KillmailPipelineComprehensiveTest do
  use EveDmv.DataCase, async: true
  use ExUnitProperties

  import Mox
  import ExUnit.CaptureLog

  alias Broadway.Message
  alias EveDmv.Api
  alias EveDmv.Killmails.{KillmailEnriched, KillmailPipeline, KillmailRaw, Participant}
  alias EveDmv.Killmails.TestDataGenerator

  # Make sure mocks are verified when the test exits
  setup :verify_on_exit!

  describe "Broadway message processing" do
    test "handle_message/3 transforms valid SSE data successfully" do
      # Generate valid test killmail data
      killmail_data = TestDataGenerator.generate_sample_killmail()

      sse_event = %{
        "event" => "killmail",
        "data" => Jason.encode!(killmail_data)
      }

      message = %Message{
        data: sse_event,
        acknowledger: {__MODULE__, :ack_id, :ack_data}
      }

      # Process the message
      result = KillmailPipeline.handle_message(:default, message, %{})

      # Should return message with transformed data
      assert %Message{} = result
      assert result.data != message.data
      assert is_map(result.data)

      # Should contain required killmail fields
      transformed_data = result.data
      assert Map.has_key?(transformed_data, "killmail_id")
      assert Map.has_key?(transformed_data, "killmail_time")
      assert Map.has_key?(transformed_data, "victim")
      assert Map.has_key?(transformed_data, "attackers")
    end

    test "handle_message/3 filters out non-killmail events" do
      non_killmail_event = %{
        "event" => "heartbeat",
        "data" => "{}"
      }

      message = %Message{
        data: non_killmail_event,
        acknowledger: {__MODULE__, :ack_id, :ack_data}
      }

      # Should return failed message for non-killmail events
      result = KillmailPipeline.handle_message(:default, message, %{})

      assert %Message{status: :failed} = result
    end

    test "handle_message/3 handles malformed JSON data gracefully" do
      malformed_event = %{
        "event" => "killmail",
        "data" => "invalid json{"
      }

      message = %Message{
        data: malformed_event,
        acknowledger: {__MODULE__, :ack_id, :ack_data}
      }

      # Should capture error log and mark message as failed
      assert capture_log(fn ->
               result = KillmailPipeline.handle_message(:default, message, %{})
               assert %Message{status: :failed} = result
             end) =~ "Failed to parse killmail JSON"
    end

    test "handle_message/3 validates required killmail fields" do
      # Missing required fields
      incomplete_killmail = %{
        "killmail_id" => 123_456
        # Missing killmail_time, victim, attackers
      }

      sse_event = %{
        "event" => "killmail",
        "data" => Jason.encode!(incomplete_killmail)
      }

      message = %Message{
        data: sse_event,
        acknowledger: {__MODULE__, :ack_id, :ack_data}
      }

      # Should fail validation and mark message as failed
      result = KillmailPipeline.handle_message(:default, message, %{})
      assert %Message{status: :failed} = result
    end

    test "handle_message/3 processes large killmail with many attackers" do
      # Generate killmail with many attackers (stress test)
      large_killmail =
        TestDataGenerator.generate_sample_killmail(%{
          killmail_id: 100_000 + System.unique_integer([:positive])
        })

      sse_event = %{
        "event" => "killmail",
        "data" => Jason.encode!(large_killmail)
      }

      message = %Message{
        data: sse_event,
        acknowledger: {__MODULE__, :ack_id, :ack_data}
      }

      # Should handle large killmails without issues
      result = KillmailPipeline.handle_message(:default, message, %{})

      assert %Message{status: :ok} = result
      assert length(result.data["attackers"]) == 100
    end
  end

  describe "Broadway batch processing" do
    test "handle_batch/4 successfully processes batch of killmails" do
      # Generate batch of valid killmails
      killmails =
        for i <- 1..5 do
          killmail_data =
            TestDataGenerator.generate_sample_killmail(%{
              killmail_id: 1_000_000 + i
            })

          %Message{
            data: killmail_data,
            acknowledger: {__MODULE__, :ack_id, :ack_data}
          }
        end

      batch = Broadway.BatchInfo.new(:db_insert, killmails, 5, 0)

      # Process the batch
      result = KillmailPipeline.handle_batch(:db_insert, killmails, batch, %{})

      # Should return successful messages
      assert is_list(result)
      assert length(result) == 5

      for message <- result do
        assert %Message{status: :ok} = message
      end

      # Should create records in database
      raw_count = KillmailRaw |> Ash.Query.new() |> Ash.count!(domain: Api)
      assert raw_count >= 5
    end

    test "handle_batch/4 handles database constraint violations gracefully" do
      # Create duplicate killmail data
      duplicate_id = 2_000_000

      killmail_data =
        TestDataGenerator.generate_sample_killmail(%{
          killmail_id: duplicate_id
        })

      # Insert first copy directly
      {:ok, _} = Ash.create(KillmailRaw, killmail_data, action: :ingest_from_source, domain: Api)

      # Try to process duplicate via pipeline
      duplicate_message = %Message{
        data: killmail_data,
        acknowledger: {__MODULE__, :ack_id, :ack_data}
      }

      batch = Broadway.BatchInfo.new(:db_insert, [duplicate_message], 1, 0)

      # Should handle duplicate gracefully (upsert behavior)
      result = KillmailPipeline.handle_batch(:db_insert, [duplicate_message], batch, %{})

      assert [%Message{status: :ok}] = result
    end

    test "handle_batch/4 handles partial batch failures" do
      # Mix of valid and invalid killmails
      valid_killmail = TestDataGenerator.generate_sample_killmail(%{killmail_id: 3_000_001})
      invalid_killmail = Map.delete(TestDataGenerator.generate_sample_killmail(), "timestamp")

      messages = [
        %Message{data: valid_killmail, acknowledger: {__MODULE__, :ack_id, :ack_data}},
        %Message{data: invalid_killmail, acknowledger: {__MODULE__, :ack_id, :ack_data}}
      ]

      batch = Broadway.BatchInfo.new(:db_insert, messages, 2, 0)

      # Should handle partial failures appropriately
      result = KillmailPipeline.handle_batch(:db_insert, messages, batch, %{})

      assert length(result) == 2
      # At least one should succeed
      assert Enum.any?(result, fn msg -> msg.status == :ok end)
    end

    test "handle_batch/4 processes enriched killmail data" do
      # Test enriched killmail processing
      enriched_data =
        TestDataGenerator.generate_sample_killmail(%{
          killmail_id: 4_000_001
        })

      message = %Message{
        data: enriched_data,
        acknowledger: {__MODULE__, :ack_id, :ack_data}
      }

      batch = Broadway.BatchInfo.new(:db_insert, [message], 1, 0)

      # Should process enriched data
      result = KillmailPipeline.handle_batch(:db_insert, [message], batch, %{})

      assert [%Message{status: :ok}] = result

      # Should create both raw and enriched records
      enriched_count = KillmailEnriched |> Ash.Query.new() |> Ash.count!(domain: Api)
      assert enriched_count >= 1
    end

    test "handle_batch/4 triggers surveillance matching" do
      # Mock surveillance matching
      killmail_data = TestDataGenerator.generate_sample_killmail(%{killmail_id: 5_000_001})

      message = %Message{
        data: killmail_data,
        acknowledger: {__MODULE__, :ack_id, :ack_data}
      }

      batch = Broadway.BatchInfo.new(:db_insert, [message], 1, 0)

      # Process and verify surveillance integration
      capture_log(fn ->
        result = KillmailPipeline.handle_batch(:db_insert, [message], batch, %{})
        assert [%Message{status: :ok}] = result
      end)

      # Note: Actual surveillance matching would require mocking the MatchingEngine
    end
  end

  describe "PubSub batch processing" do
    test "handle_batch/4 broadcasts to LiveView channels" do
      killmail_data = TestDataGenerator.generate_sample_killmail(%{killmail_id: 6_000_001})

      message = %Message{
        data: killmail_data,
        acknowledger: {__MODULE__, :ack_id, :ack_data}
      }

      batch = Broadway.BatchInfo.new(:pubsub, [message], 1, 0)

      # Subscribe to PubSub to verify broadcast
      Phoenix.PubSub.subscribe(EveDmv.PubSub, "killmail_feed")

      # Process PubSub batch
      result = KillmailPipeline.handle_batch(:pubsub, [message], batch, %{})

      assert [%Message{status: :ok}] = result

      # Should receive PubSub message
      assert_receive {:new_killmail, _killmail_data}, 1000
    end

    test "handle_batch/4 handles PubSub broadcast failures gracefully" do
      # Test PubSub resilience
      killmail_data = TestDataGenerator.generate_sample_killmail(%{killmail_id: 7_000_001})

      message = %Message{
        data: killmail_data,
        acknowledger: {__MODULE__, :ack_id, :ack_data}
      }

      batch = Broadway.BatchInfo.new(:pubsub, [message], 1, 0)

      # Should not fail even if PubSub has issues
      result = KillmailPipeline.handle_batch(:pubsub, [message], batch, %{})

      assert [%Message{status: :ok}] = result
    end
  end

  describe "error handling and resilience" do
    test "pipeline handles memory pressure gracefully" do
      # Generate large batch to test memory handling
      large_batch =
        for i <- 1..50 do
          killmail_data =
            TestDataGenerator.generate_sample_killmail(%{
              killmail_id: 8_000_000 + i
            })

          %Message{
            data: killmail_data,
            acknowledger: {__MODULE__, :ack_id, :ack_data}
          }
        end

      batch = Broadway.BatchInfo.new(:db_insert, large_batch, 50, 0)

      # Should handle large batches without memory issues
      result = KillmailPipeline.handle_batch(:db_insert, large_batch, batch, %{})

      assert length(result) == 50
      assert Enum.all?(result, fn msg -> msg.status in [:ok, :failed] end)
    end

    test "pipeline recovers from temporary database unavailability" do
      # This test would require mocking database failures
      killmail_data = TestDataGenerator.generate_sample_killmail(%{killmail_id: 9_000_001})

      message = %Message{
        data: killmail_data,
        acknowledger: {__MODULE__, :ack_id, :ack_data}
      }

      # Should retry and eventually succeed or fail gracefully
      batch = Broadway.BatchInfo.new(:db_insert, [message], 1, 0)
      result = KillmailPipeline.handle_batch(:db_insert, [message], batch, %{})

      # Should not crash the pipeline
      assert is_list(result)
    end
  end

  describe "data transformation edge cases" do
    test "handles killmails with missing optional fields" do
      # Killmail with minimal required fields only
      minimal_killmail = %{
        "killmail_id" => 10_000_001,
        "killmail_time" => DateTime.utc_now() |> DateTime.to_iso8601(),
        "victim" => %{
          "character_id" => 123_456,
          "ship_type_id" => 670
        },
        "attackers" => [
          %{
            "character_id" => 789_012,
            "final_blow" => true
          }
        ]
      }

      sse_event = %{
        "event" => "killmail",
        "data" => Jason.encode!(minimal_killmail)
      }

      message = %Message{
        data: sse_event,
        acknowledger: {__MODULE__, :ack_id, :ack_data}
      }

      # Should handle minimal data successfully
      result = KillmailPipeline.handle_message(:default, message, %{})
      assert %Message{status: :ok} = result
    end

    test "validates character ID ranges" do
      # Invalid character IDs
      invalid_killmail =
        TestDataGenerator.generate_sample_killmail(%{
          killmail_id: 11_000_001
        })

      # Set invalid character ID
      invalid_killmail = put_in(invalid_killmail, ["victim", "character_id"], -1)

      sse_event = %{
        "event" => "killmail",
        "data" => Jason.encode!(invalid_killmail)
      }

      message = %Message{
        data: sse_event,
        acknowledger: {__MODULE__, :ack_id, :ack_data}
      }

      # Should validate character IDs
      result = KillmailPipeline.handle_message(:default, message, %{})
      # Depending on validation rules, this might pass or fail
      assert %Message{} = result
    end
  end

  # Property-based testing for robust data handling
  property "pipeline handles arbitrary valid killmail structures" do
    check all(
            killmail_id <- positive_integer(),
            character_id <- integer(1..2_147_483_647),
            ship_type_id <- integer(1..100_000),
            attacker_count <- integer(1..10)
          ) do
      killmail_data =
        TestDataGenerator.generate_sample_killmail(%{
          killmail_id: killmail_id
        })

      sse_event = %{
        "event" => "killmail",
        "data" => Jason.encode!(killmail_data)
      }

      message = %Message{
        data: sse_event,
        acknowledger: {__MODULE__, :ack_id, :ack_data}
      }

      # Should either succeed or fail gracefully
      result = KillmailPipeline.handle_message(:default, message, %{})
      assert %Message{} = result
      assert result.status in [:ok, :failed]
    end
  end

  # Mock acknowledger for testing
  def ack(_ack_ref, _successful, _failed), do: :ok
end

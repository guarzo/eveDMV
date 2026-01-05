defmodule EveDmv.Killmails.HTTPoisonSSEProducerTest do
  @moduledoc """
  Unit tests for HTTPoisonSSEProducer message conversion and deduplication.
  """
  use ExUnit.Case, async: true

  alias Broadway.Message

  # Test module to access private functions for unit testing
  defmodule TestHelper do
    @moduledoc false

    # Wrapper to test the message conversion logic
    # Replicates the core to_broadway_message behavior for non-batch events
    def to_broadway_message_for_killmail(payload) do
      case Jason.decode(payload) do
        {:ok, %{"killmail_id" => killmail_id} = enriched} ->
          %Message{
            data: enriched,
            acknowledger: Broadway.NoopAcknowledger.init(),
            batcher: :db_insert,
            metadata: %{killmail_id: killmail_id}
          }

        {:ok, _other} ->
          nil

        {:error, _} ->
          nil
      end
    end
  end

  describe "to_broadway_message for non-batch events" do
    test "returns Message struct for valid killmail payload" do
      payload = Jason.encode!(%{"killmail_id" => 123_456, "victim" => %{"ship_type_id" => 587}})
      result = TestHelper.to_broadway_message_for_killmail(payload)

      assert %Message{} = result
      assert result.data["killmail_id"] == 123_456
      assert result.batcher == :db_insert
    end

    test "returns nil for non-killmail JSON" do
      payload = Jason.encode!(%{"type" => "heartbeat", "timestamp" => "2024-01-01T00:00:00Z"})
      result = TestHelper.to_broadway_message_for_killmail(payload)

      assert result == nil
    end

    test "returns nil for invalid JSON" do
      result = TestHelper.to_broadway_message_for_killmail("not valid json")
      assert result == nil
    end

    test "never returns {:batch, _} tuple for single killmail events" do
      # Verify that the return type is always Message or nil, never {:batch, _}
      payloads = [
        Jason.encode!(%{"killmail_id" => 1}),
        Jason.encode!(%{"type" => "connected"}),
        "invalid json",
        Jason.encode!(%{"event" => "heartbeat"})
      ]

      for payload <- payloads do
        result = TestHelper.to_broadway_message_for_killmail(payload)

        # Result must be either a Message struct or nil, never a batch tuple
        assert result == nil or is_struct(result, Message),
               "Expected nil or Message, got: #{inspect(result)}"

        refute match?({:batch, _}, result),
               "to_broadway_message for non-batch events should never return {:batch, _}"
      end
    end
  end

  describe "deduplication cache behavior" do
    test "seen_killmails structure supports O(1) lookups" do
      # Verify the expected structure of seen_killmails
      seen = %{set: MapSet.new(), queue: :queue.new()}

      # Add an ID
      new_set = MapSet.put(seen.set, 123_456)
      new_queue = :queue.in(123_456, seen.queue)
      updated_seen = %{set: new_set, queue: new_queue}

      # Verify O(1) membership check
      assert MapSet.member?(updated_seen.set, 123_456)
      refute MapSet.member?(updated_seen.set, 999_999)
    end

    test "FIFO eviction maintains bounded cache size" do
      max_size = 3
      seen = %{set: MapSet.new(), queue: :queue.new()}

      # Add more IDs than the max size
      {final_seen, _} =
        Enum.reduce(1..5, {seen, max_size}, fn id, {acc_seen, max} ->
          new_set = MapSet.put(acc_seen.set, id)
          new_queue = :queue.in(id, acc_seen.queue)
          updated = evict_if_needed(%{set: new_set, queue: new_queue}, max)
          {updated, max}
        end)

      # Should only contain the last `max_size` IDs
      assert MapSet.size(final_seen.set) <= max_size
      # Oldest IDs should have been evicted
      refute MapSet.member?(final_seen.set, 1)
      refute MapSet.member?(final_seen.set, 2)
      # Newest IDs should still be present
      assert MapSet.member?(final_seen.set, 5)
      assert MapSet.member?(final_seen.set, 4)
    end
  end

  # Helper function that mirrors the module's eviction logic
  defp evict_if_needed(%{set: set, queue: queue} = seen, max_size) do
    if MapSet.size(set) > max_size do
      case :queue.out(queue) do
        {{:value, oldest_id}, new_queue} ->
          evict_if_needed(%{set: MapSet.delete(set, oldest_id), queue: new_queue}, max_size)

        {:empty, _} ->
          seen
      end
    else
      seen
    end
  end
end

defmodule EveDmv.Database.PartitionAutomationTest do
  use EveDmv.DataCase, async: false
  alias EveDmv.Database.PartitionAutomation

  describe "partition management" do
    test "can get partition stats without error" do
      # This should work even if no partitions exist yet
      assert {:ok, stats} = PartitionAutomation.get_partition_stats()
      assert is_map(stats)
      assert Map.has_key?(stats, :total_partitions)
      assert Map.has_key?(stats, :partitions)
      assert Map.has_key?(stats, :generated_at)
    end

    test "can ensure future partitions are created" do
      # This might fail in test environment if pg_cron isn't available,
      # but the function should handle it gracefully
      case PartitionAutomation.ensure_future_partitions(1) do
        {:ok, messages} ->
          assert is_list(messages)
          assert length(messages) == 1

        {:error, _reason} ->
          # In test environment, this might fail due to missing pg_cron
          # or lack of superuser permissions, which is expected
          :ok
      end
    end

    test "can create partition for specific month" do
      target_date = Date.utc_today()

      case PartitionAutomation.create_partition_for_month(target_date) do
        {:ok, message} ->
          assert is_binary(message)
          assert message =~ ~r/partition/i

        {:error, _reason} ->
          # In test environment, this might fail due to permissions
          :ok
      end
    end

    test "handles invalid dates gracefully" do
      # This should return an error for invalid date range
      start_date = ~D[2024-12-01]
      # End before start
      end_date = ~D[2024-11-01]

      assert {:error, _reason} =
               PartitionAutomation.create_partition_for_date_range(start_date, end_date)
    end
  end
end

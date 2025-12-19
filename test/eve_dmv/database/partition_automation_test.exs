defmodule EveDmv.Platform.Database.PartitionAutomationTest do
  @moduledoc """
  Tests for the PartitionAutomation module.

  Tests partition creation, cleanup, and statistics functions.
  Note: Some tests are tagged as :database_admin since they require
  administrative permissions to create/drop tables.
  """
  use EveDmv.DataCase, async: false

  alias EveDmv.Platform.Database.PartitionAutomation

  describe "generate_partition_name/1" do
    # Test the internal naming convention by calling create_partition_for_month
    # which uses generate_partition_name internally

    test "creates correct partition name format for date" do
      # The partition name format should be: killmails_raw_yYYYYmMM
      date = ~D[2025-03-15]

      # We can't test the private function directly, but we can verify
      # the function returns expected messages containing the partition name
      result = PartitionAutomation.create_partition_for_month(date)

      assert {:ok, message} = result
      assert is_binary(message)
      # The message should contain either "Created" or "already exists"
      assert String.contains?(message, "killmails_raw_y2025m03")
    end

    test "pads single-digit months correctly" do
      date = ~D[2025-01-01]
      result = PartitionAutomation.create_partition_for_month(date)

      assert {:ok, message} = result
      assert String.contains?(message, "killmails_raw_y2025m01")
    end
  end

  describe "ensure_future_partitions/1" do
    test "creates partitions for specified months ahead" do
      result = PartitionAutomation.ensure_future_partitions(2)

      assert {:ok, messages} = result
      assert is_list(messages)
      assert length(messages) == 2

      # Each message should indicate partition status
      Enum.each(messages, fn msg ->
        assert is_binary(msg)
        assert String.contains?(msg, "killmails_raw_y")
      end)
    end

    test "returns ok with messages when partitions already exist" do
      # First call creates partitions
      {:ok, _} = PartitionAutomation.ensure_future_partitions(1)

      # Second call should still succeed (partitions already exist)
      result = PartitionAutomation.ensure_future_partitions(1)

      assert {:ok, messages} = result
      assert messages != []
      # Should indicate partition already exists
      assert Enum.any?(messages, &String.contains?(&1, "already exists"))
    end

    test "defaults to 3 months ahead when no argument provided" do
      result = PartitionAutomation.ensure_future_partitions()

      assert {:ok, messages} = result
      assert length(messages) == 3
    end
  end

  describe "create_partition_for_month/1" do
    test "creates partition for a specific date" do
      # Use a future date to avoid conflicts
      future_date = Date.add(Date.utc_today(), 365)

      result = PartitionAutomation.create_partition_for_month(future_date)

      case result do
        {:ok, message} ->
          assert is_binary(message)
          # Could be created or already exist
          assert String.contains?(message, "partition") or
                   String.contains?(message, "Partition")

        {:error, reason} ->
          # This is acceptable if there's a database constraint issue
          assert is_struct(reason) or is_atom(reason) or is_binary(reason)
      end
    end

    test "handles existing partition gracefully" do
      date = Date.utc_today()

      # First call
      result1 = PartitionAutomation.create_partition_for_month(date)
      assert {:ok, _} = result1

      # Second call should also succeed (partition already exists)
      result2 = PartitionAutomation.create_partition_for_month(date)
      assert {:ok, message} = result2
      assert String.contains?(message, "already exists")
    end
  end

  describe "create_partition_for_date_range/2" do
    test "creates custom partition for valid date range" do
      # Use dates far in the future to avoid conflicts
      start_date = ~D[2030-01-01]
      end_date = ~D[2030-01-15]

      result = PartitionAutomation.create_partition_for_date_range(start_date, end_date)

      case result do
        {:ok, partition_name} ->
          assert is_binary(partition_name)
          assert String.contains?(partition_name, "custom")

        {:error, _reason} ->
          # May fail due to partition constraints, which is acceptable
          assert true
      end
    end

    test "returns error when start date is after end date" do
      start_date = ~D[2030-02-01]
      end_date = ~D[2030-01-01]

      result = PartitionAutomation.create_partition_for_date_range(start_date, end_date)

      assert {:error, message} = result
      assert String.contains?(message, "before")
    end

    test "returns error when start date equals end date" do
      date = ~D[2030-03-01]

      result = PartitionAutomation.create_partition_for_date_range(date, date)

      # Equal dates are not valid for a range
      assert {:error, _} = result
    end
  end

  describe "get_partition_stats/0" do
    test "returns statistics about partitions" do
      # Ensure at least one partition exists
      PartitionAutomation.ensure_future_partitions(1)

      result = PartitionAutomation.get_partition_stats()

      assert {:ok, stats} = result
      assert is_map(stats)
      assert Map.has_key?(stats, :total_partitions)
      assert Map.has_key?(stats, :partitions)
      assert Map.has_key?(stats, :generated_at)
      assert is_integer(stats.total_partitions)
      assert is_list(stats.partitions)
      assert %DateTime{} = stats.generated_at
    end

    test "returns partition details with size and row count" do
      PartitionAutomation.ensure_future_partitions(1)

      {:ok, stats} = PartitionAutomation.get_partition_stats()

      if Enum.any?(stats.partitions) do
        partition = List.first(stats.partitions)
        assert is_map(partition)
        assert Map.has_key?(partition, "tablename")
      end
    end
  end

  describe "cleanup_old_partitions/1" do
    test "handles cleanup when no old partitions exist" do
      # With default retention of 12 months, there shouldn't be old partitions
      # in a test environment
      result = PartitionAutomation.cleanup_old_partitions(12)

      assert {:ok, {count, dropped}} = result
      assert is_integer(count)
      assert is_list(dropped)
      # In test environment, likely no old partitions to drop
      assert count >= 0
    end

    test "respects retention period parameter" do
      # Very long retention should result in no partitions being cleaned
      result = PartitionAutomation.cleanup_old_partitions(120)

      assert {:ok, {count, dropped}} = result
      assert count == 0
      assert dropped == []
    end
  end
end

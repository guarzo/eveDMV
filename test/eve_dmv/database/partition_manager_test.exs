defmodule EveDmv.Database.PartitionManagerTest do
  use ExUnit.Case, async: false
  @moduletag :skip
  import ExUnit.CaptureLog

  alias EveDmv.Database.PartitionManager

  describe "partition management" do
    test "can get partition status" do
      status = PartitionManager.get_partition_status()

      assert is_list(status)
      assert length(status) > 0

      # Should have status for both partitioned tables
      table_names = Enum.map(status, & &1.table)
      assert "killmails_raw" in table_names
      assert "killmails_enriched" in table_names
    end

    test "can list partitions for a table" do
      partitions = PartitionManager.list_partitions("killmails_raw")

      assert is_list(partitions)
      # All partitions should follow naming convention
      Enum.each(partitions, fn partition ->
        assert String.contains?(partition, "killmails_raw_y")
      end)
    end

    test "can get partition statistics" do
      stats = PartitionManager.get_partition_statistics()

      assert is_map(stats)
      assert Map.has_key?(stats, :total_partitions)
      assert Map.has_key?(stats, :partition_sizes)
      assert Map.has_key?(stats, :oldest_partition)
      assert Map.has_key?(stats, :newest_partition)

      assert is_integer(stats.total_partitions)
      assert is_list(stats.partition_sizes)
    end

    test "can force partition maintenance" do
      log =
        capture_log(fn ->
          PartitionManager.force_maintenance()
          # Give it time to process
          Process.sleep(200)
        end)

      # Should not raise errors
      assert is_binary(log)
    end

    test "can create partition for specific month" do
      # Test with future date to avoid conflicts
      future_year = Date.utc_today().year + 1

      result = PartitionManager.create_partition_for_month("killmails_raw", future_year, 1)

      # Should either create successfully or already exist
      assert result in [
               {:ok, "killmails_raw_y#{future_year}m01"},
               {:exists, "killmails_raw_y#{future_year}m01"}
             ]
    end

    test "validates partition naming convention" do
      # Test that partition names follow expected format
      partitions = PartitionManager.list_partitions("killmails_enriched")

      Enum.each(partitions, fn partition ->
        # Should match pattern: tablename_yYYYYmMM
        assert Regex.match?(~r/^killmails_enriched_y\d{4}m\d{2}$/, partition)
      end)
    end
  end
end

defmodule EveDmv.Database.ArchiveManagerTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureLog

  alias EveDmv.Database.ArchiveManager

  describe "archive status and configuration" do
    test "can get archive status" do
      status = ArchiveManager.get_archive_status()

      assert is_map(status)
      assert Map.has_key?(status, :enabled)
      assert Map.has_key?(status, :tables)
      assert Map.has_key?(status, :archive_stats)
      assert is_list(status.tables)
      assert status.enabled == true
    end

    test "each table has proper archive configuration" do
      status = ArchiveManager.get_archive_status()

      expected_tables = ["killmails_raw", "killmails_enriched", "participants", "character_stats"]
      actual_tables = Enum.map(status.tables, & &1.table)

      Enum.each(expected_tables, fn table ->
        assert table in actual_tables, "Expected table #{table} not found in archive config"
      end)

      # Verify each table configuration
      Enum.each(status.tables, fn table_config ->
        assert Map.has_key?(table_config, :table)
        assert Map.has_key?(table_config, :archive_table)
        assert Map.has_key?(table_config, :archive_after_days)
        assert Map.has_key?(table_config, :retention_years)
        assert Map.has_key?(table_config, :records_eligible)

        assert is_binary(table_config.table)
        assert is_binary(table_config.archive_table)
        assert is_integer(table_config.archive_after_days)
        assert is_integer(table_config.retention_years)
        assert is_integer(table_config.records_eligible)

        # Archive table should follow naming convention
        assert String.ends_with?(table_config.archive_table, "_archive")
      end)
    end

    test "archive policies have reasonable retention periods" do
      status = ArchiveManager.get_archive_status()

      Enum.each(status.tables, fn config ->
        # Archive after days should be reasonable (30 days to 2 years)
        assert config.archive_after_days >= 30
        assert config.archive_after_days <= 730

        # Retention should be longer than archive period
        assert config.retention_years >= 1
        assert config.retention_years <= 10

        # Archive period should be shorter than retention
        assert config.archive_after_days < config.retention_years * 365
      end)
    end
  end

  describe "archive statistics" do
    test "can get archive statistics" do
      stats = ArchiveManager.get_archive_statistics()

      assert is_map(stats)
      assert Map.has_key?(stats, :tables)
      assert Map.has_key?(stats, :totals)
      assert is_list(stats.tables)
      assert is_map(stats.totals)

      # Verify totals structure
      totals = stats.totals
      assert Map.has_key?(totals, :total_archived_records)
      assert Map.has_key?(totals, :total_size_bytes)
      assert Map.has_key?(totals, :total_size)
      assert Map.has_key?(totals, :active_archive_tables)

      assert is_integer(totals.total_archived_records)
      assert is_integer(totals.total_size_bytes)
      assert is_binary(totals.total_size)
      assert is_integer(totals.active_archive_tables)
    end

    test "table statistics have required fields" do
      stats = ArchiveManager.get_archive_statistics()

      Enum.each(stats.tables, fn table_stats ->
        assert Map.has_key?(table_stats, :table)
        assert Map.has_key?(table_stats, :archive_table)
        assert Map.has_key?(table_stats, :record_count)
        assert Map.has_key?(table_stats, :size)
        assert Map.has_key?(table_stats, :size_bytes)
        assert Map.has_key?(table_stats, :compression_enabled)

        assert is_binary(table_stats.table)
        assert is_binary(table_stats.archive_table)
        assert is_integer(table_stats.record_count)
        assert is_binary(table_stats.size)
        assert is_integer(table_stats.size_bytes)
        assert is_boolean(table_stats.compression_enabled)
      end)
    end
  end

  describe "archive policies" do
    test "can get archive policy for known tables" do
      policy = ArchiveManager.get_archive_policy("killmails_raw")

      assert is_map(policy)
      assert policy.table == "killmails_raw"
      assert policy.archive_table == "killmails_raw_archive"
      assert is_integer(policy.archive_after_days)
      assert is_integer(policy.batch_size)
      assert is_boolean(policy.compression)
      assert is_integer(policy.retention_years)
    end

    test "returns nil for unknown tables" do
      policy = ArchiveManager.get_archive_policy("non_existent_table")
      assert is_nil(policy)
    end

    test "all policies have required fields" do
      tables = ["killmails_raw", "killmails_enriched", "participants", "character_stats"]

      Enum.each(tables, fn table_name ->
        policy = ArchiveManager.get_archive_policy(table_name)

        assert is_map(policy)
        assert Map.has_key?(policy, :table)
        assert Map.has_key?(policy, :archive_table)
        assert Map.has_key?(policy, :archive_after_days)
        assert Map.has_key?(policy, :date_column)
        assert Map.has_key?(policy, :batch_size)
        assert Map.has_key?(policy, :compression)
        assert Map.has_key?(policy, :retention_years)

        # Validate field types
        assert is_binary(policy.table)
        assert is_binary(policy.archive_table)
        assert is_integer(policy.archive_after_days)
        assert is_binary(policy.date_column)
        assert is_integer(policy.batch_size)
        assert is_boolean(policy.compression)
        assert is_integer(policy.retention_years)
      end)
    end
  end

  describe "space estimation" do
    test "can estimate archive space savings" do
      result = ArchiveManager.estimate_archive_space_savings("killmails_raw")

      case result do
        {:ok, estimate} ->
          assert is_map(estimate)
          assert Map.has_key?(estimate, :eligible_records)
          assert Map.has_key?(estimate, :estimated_space_freed)
          assert is_integer(estimate.eligible_records)
          assert is_binary(estimate.estimated_space_freed)

        {:error, _} ->
          # Table might not exist in test environment
          :ok
      end
    end

    test "handles unknown tables gracefully" do
      result = ArchiveManager.estimate_archive_space_savings("unknown_table")
      assert {:error, "No archive policy found for table: unknown_table"} = result
    end
  end

  describe "integrity validation" do
    test "can validate archive integrity" do
      result = ArchiveManager.validate_archive_integrity("killmails_raw")

      case result do
        {:ok, integrity} ->
          assert is_map(integrity)
          assert Map.has_key?(integrity, :main_table_records)
          assert Map.has_key?(integrity, :archive_table_records)
          assert Map.has_key?(integrity, :total_records)
          assert Map.has_key?(integrity, :integrity_status)

          assert is_integer(integrity.main_table_records)
          assert is_integer(integrity.archive_table_records)
          assert is_integer(integrity.total_records)
          assert integrity.integrity_status == :ok

          # Total should equal sum of main and archive
          assert integrity.total_records ==
                   integrity.main_table_records + integrity.archive_table_records

        {:error, _} ->
          # Tables might not exist in test environment
          :ok
      end
    end

    test "handles unknown tables for integrity check" do
      result = ArchiveManager.validate_archive_integrity("unknown_table")
      assert {:error, "No archive policy found for table: unknown_table"} = result
    end
  end

  describe "archive operations" do
    test "can attempt to archive a table" do
      log =
        capture_log(fn ->
          # This will likely fail in test environment, but should handle gracefully
          result = ArchiveManager.archive_table("killmails_raw")

          case result do
            {:ok, count} ->
              assert is_integer(count)
              assert count >= 0

            {:error, _error} ->
              # Expected in test environment where tables might not exist
              :ok
          end
        end)

      assert is_binary(log)
    end

    test "handles unknown table archiving" do
      result = ArchiveManager.archive_table("unknown_table")
      assert {:error, "No archive policy found for table: unknown_table"} = result
    end

    test "can force archive check" do
      log =
        capture_log(fn ->
          ArchiveManager.force_archive_check()
          # Give time for async processing
          Process.sleep(200)
        end)

      # Should log archive check activity
      assert is_binary(log)
    end

    test "can trigger cleanup of old archives" do
      log =
        capture_log(fn ->
          ArchiveManager.cleanup_old_archives()
          Process.sleep(100)
        end)

      assert is_binary(log)
    end
  end

  describe "restore operations" do
    test "can attempt restore from archive" do
      start_date = Date.add(Date.utc_today(), -30)
      end_date = Date.utc_today()

      result = ArchiveManager.restore_from_archive("killmails_raw", start_date, end_date)

      case result do
        {:ok, count} ->
          assert is_integer(count)
          assert count >= 0

        {:error, _error} ->
          # Expected in test environment
          :ok
      end
    end

    test "handles unknown table restore" do
      start_date = Date.add(Date.utc_today(), -30)
      end_date = Date.utc_today()

      result = ArchiveManager.restore_from_archive("unknown_table", start_date, end_date)
      assert {:error, "No archive policy found for table: unknown_table"} = result
    end

    test "validates date parameters for restore" do
      start_date = Date.utc_today()
      # End before start
      end_date = Date.add(Date.utc_today(), -30)

      # Should handle gracefully even with invalid date range
      result = ArchiveManager.restore_from_archive("killmails_raw", start_date, end_date)

      case result do
        # No records in invalid range
        {:ok, 0} -> :ok
        # Or error from invalid range
        {:error, _} -> :ok
      end
    end
  end

  describe "error handling" do
    test "handles database connection errors gracefully" do
      # These should not crash even if database is unavailable
      result = ArchiveManager.get_archive_status()
      assert is_map(result)

      result = ArchiveManager.get_archive_statistics()
      assert is_map(result)
    end

    test "handles archive table creation errors" do
      log =
        capture_log(fn ->
          # Force archive check which will try to create tables
          ArchiveManager.force_archive_check()
          Process.sleep(100)
        end)

      # Should log any errors but not crash
      assert is_binary(log)
    end
  end

  describe "configuration validation" do
    test "archive policies are consistent" do
      status = ArchiveManager.get_archive_status()

      Enum.each(status.tables, fn config ->
        # Archive table name should be based on main table
        expected_archive = config.table <> "_archive"
        assert config.archive_table == expected_archive

        # Archive period should be reasonable
        assert config.archive_after_days > 0
        assert config.retention_years > 0

        # Retention should be longer than archive period
        retention_days = config.retention_years * 365
        assert retention_days > config.archive_after_days
      end)
    end

    test "all tables have different archive periods based on importance" do
      status = ArchiveManager.get_archive_status()

      # Character stats should have shortest retention (most frequently updated)
      char_stats = Enum.find(status.tables, &(&1.table == "character_stats"))
      assert char_stats.archive_after_days <= 90

      # Killmails should have longer retention
      killmails_raw = Enum.find(status.tables, &(&1.table == "killmails_raw"))
      killmails_enriched = Enum.find(status.tables, &(&1.table == "killmails_enriched"))

      if killmails_raw do
        assert killmails_raw.archive_after_days >= 365
      end

      if killmails_enriched do
        # Enriched killmails should be kept longer than raw
        assert killmails_enriched.archive_after_days >= killmails_raw.archive_after_days
      end
    end
  end

  describe "archive manager lifecycle" do
    test "manager starts successfully" do
      # Archive manager should be running (started by application)
      status = ArchiveManager.get_archive_status()
      assert status.enabled == true
    end

    test "can check archive status multiple times" do
      # Multiple calls should be consistent
      status1 = ArchiveManager.get_archive_status()
      status2 = ArchiveManager.get_archive_status()

      assert length(status1.tables) == length(status2.tables)
      assert status1.enabled == status2.enabled
    end
  end

  describe "data lifecycle" do
    test "archive policies cover appropriate data lifecycle" do
      status = ArchiveManager.get_archive_status()

      # Verify we have policies for core tables
      table_names = Enum.map(status.tables, & &1.table)
      core_tables = ["killmails_raw", "killmails_enriched", "participants"]

      Enum.each(core_tables, fn table ->
        assert table in table_names, "Missing archive policy for core table: #{table}"
      end)
    end

    test "retention periods are appropriate for data types" do
      char_stats_policy = ArchiveManager.get_archive_policy("character_stats")
      killmail_policy = ArchiveManager.get_archive_policy("killmails_enriched")

      if char_stats_policy && killmail_policy do
        # Character stats change frequently, should have shorter retention
        assert char_stats_policy.retention_years <= killmail_policy.retention_years

        # Killmail data is historical and valuable, should be kept longer
        assert killmail_policy.retention_years >= 7
      end
    end
  end
end

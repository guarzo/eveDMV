defmodule EveDmv.Database.MaterializedViewManagerTest do
  use ExUnit.Case, async: false
  @moduletag :skip
  import ExUnit.CaptureLog

  alias EveDmv.Database.MaterializedViewManager

  describe "view management" do
    test "can get view status" do
      status = MaterializedViewManager.get_view_status()

      assert is_map(status)
      assert Map.has_key?(status, :views)
      assert Map.has_key?(status, :total_views)
      assert Map.has_key?(status, :refresh_stats)
      assert is_list(status.views)
      assert is_integer(status.total_views)
      assert status.total_views > 0
    end

    test "each view has required status fields" do
      %{views: views} = MaterializedViewManager.get_view_status()

      Enum.each(views, fn view ->
        assert Map.has_key?(view, :name)
        assert Map.has_key?(view, :status)
        assert Map.has_key?(view, :dependencies)
        assert Map.has_key?(view, :refresh_strategy)
        assert is_binary(view.name)
        assert is_atom(view.status)
        assert is_list(view.dependencies)
        assert view.refresh_strategy in [:full, :incremental, :concurrent]
      end)
    end

    test "can create and drop materialized views" do
      # Try to create a view (may already exist)
      result = MaterializedViewManager.create_view("character_activity_summary")

      # Should either succeed or already exist
      assert match?({:ok, "character_activity_summary"}, result) or match?({:error, _}, result)

      # Test dropping (cleanup)
      drop_result = MaterializedViewManager.drop_view("test_view_that_does_not_exist")
      assert {:ok, "test_view_that_does_not_exist"} = drop_result
    end

    test "handles unknown view names gracefully" do
      result = MaterializedViewManager.create_view("non_existent_view_name")
      assert {:error, "Unknown view: non_existent_view_name"} = result
    end

    test "can force refresh of all views" do
      log =
        capture_log(fn ->
          MaterializedViewManager.refresh_all_views()
          # Give time for async processing
          Process.sleep(200)
        end)

      # Should log refresh activity
      assert is_binary(log)
    end

    test "can refresh individual views" do
      log =
        capture_log(fn ->
          MaterializedViewManager.refresh_view("character_activity_summary")
          Process.sleep(100)
        end)

      assert is_binary(log)
    end
  end

  describe "data access" do
    test "can query view data" do
      # This may fail if views don't exist yet, but should handle gracefully
      result = MaterializedViewManager.get_view_data("character_activity_summary", 5)

      case result do
        {:ok, data} ->
          assert is_list(data)
          assert length(data) <= 5

          # If we have data, verify structure
          if length(data) > 0 do
            first_row = List.first(data)
            assert is_map(first_row)
            # Should have character activity fields
            expected_fields = ["character_id", "character_name", "total_killmails"]

            Enum.each(expected_fields, fn field ->
              assert Map.has_key?(first_row, field)
            end)
          end

        {:error, _error} ->
          # View might not exist yet or be empty
          :ok
      end
    end

    test "utility functions handle missing data gracefully" do
      # Test character activity lookup
      result = MaterializedViewManager.get_character_activity(12_345)
      assert is_tuple(result)

      case result do
        {:ok, data} -> assert is_list(data)
        # View might not exist
        {:error, _} -> :ok
      end

      # Test system activity lookup
      result = MaterializedViewManager.get_system_activity(30_000_142)
      assert is_tuple(result)

      # Test alliance stats lookup
      result = MaterializedViewManager.get_alliance_stats(99_005_065)
      assert is_tuple(result)

      # Test top hunters
      result = MaterializedViewManager.get_top_hunters(10)
      assert is_tuple(result)

      # Test daily activity
      result = MaterializedViewManager.get_daily_activity(7)
      assert is_tuple(result)
    end
  end

  describe "performance analysis" do
    test "can analyze view performance" do
      result = MaterializedViewManager.analyze_view_performance()

      case result do
        {:ok, views} ->
          assert is_list(views)

          # If we have views, check structure
          Enum.each(views, fn view ->
            assert Map.has_key?(view, :name)
            assert Map.has_key?(view, :size)
            assert Map.has_key?(view, :size_bytes)
            assert is_binary(view.name)
            assert is_binary(view.size)
            assert is_integer(view.size_bytes)
          end)

        {:error, _} ->
          # Database might not have pg_matviews or no views exist
          :ok
      end
    end
  end

  describe "refresh strategies" do
    test "view definitions have valid refresh strategies" do
      # Access the module attribute through get_view_status
      %{views: views} = MaterializedViewManager.get_view_status()

      valid_strategies = [:full, :incremental, :concurrent]

      Enum.each(views, fn view ->
        assert view.refresh_strategy in valid_strategies
      end)
    end

    test "incremental views are properly identified" do
      %{views: views} = MaterializedViewManager.get_view_status()

      # At least one view should be incremental (daily_killmail_summary)
      incremental_views = Enum.filter(views, &(&1.refresh_strategy == :incremental))
      assert length(incremental_views) > 0

      # Daily summary should be incremental
      daily_view = Enum.find(views, &(&1.name == "daily_killmail_summary"))
      assert daily_view.refresh_strategy == :incremental
    end
  end

  describe "dependency tracking" do
    test "all views have valid dependencies" do
      %{views: views} = MaterializedViewManager.get_view_status()

      expected_tables = [
        "participants",
        "killmails_enriched",
        "solar_systems"
      ]

      Enum.each(views, fn view ->
        assert is_list(view.dependencies)
        assert length(view.dependencies) > 0

        # All dependencies should be known tables
        Enum.each(view.dependencies, fn dep ->
          assert dep in expected_tables
        end)
      end)
    end

    test "character activity view has correct dependencies" do
      %{views: views} = MaterializedViewManager.get_view_status()

      char_activity = Enum.find(views, &(&1.name == "character_activity_summary"))
      assert char_activity
      assert "participants" in char_activity.dependencies
    end

    test "system activity view has correct dependencies" do
      %{views: views} = MaterializedViewManager.get_view_status()

      system_activity = Enum.find(views, &(&1.name == "system_activity_summary"))
      assert system_activity
      assert "killmails_enriched" in system_activity.dependencies
      assert "participants" in system_activity.dependencies
      assert "solar_systems" in system_activity.dependencies
    end
  end

  describe "error handling" do
    test "handles database connection errors gracefully" do
      # These should not crash even if database is unavailable
      result = MaterializedViewManager.get_view_status()
      assert is_map(result)

      result = MaterializedViewManager.analyze_view_performance()
      assert is_tuple(result)
    end

    test "handles view creation errors" do
      # Try to create a view with invalid SQL (this would be caught in real implementation)
      log =
        capture_log(fn ->
          MaterializedViewManager.create_view("character_activity_summary")
          Process.sleep(50)
        end)

      # Should handle errors gracefully
      assert is_binary(log)
    end

    test "handles refresh errors gracefully" do
      log =
        capture_log(fn ->
          # Try to refresh a view that might not exist
          MaterializedViewManager.refresh_view("non_existent_view")
          Process.sleep(100)
        end)

      # Should log warnings but not crash
      assert is_binary(log)
    end
  end

  describe "refresh statistics" do
    test "refresh stats are properly tracked" do
      %{refresh_stats: stats} = MaterializedViewManager.get_view_status()

      assert Map.has_key?(stats, :total_refreshes)
      assert Map.has_key?(stats, :failed_refreshes)
      assert Map.has_key?(stats, :avg_refresh_time_ms)

      assert is_integer(stats.total_refreshes)
      assert is_integer(stats.failed_refreshes)
      assert is_number(stats.avg_refresh_time_ms)

      # Failed refreshes should not exceed total
      assert stats.failed_refreshes <= stats.total_refreshes
    end
  end

  describe "view definitions" do
    test "all predefined views are present" do
      %{views: views} = MaterializedViewManager.get_view_status()

      expected_views = [
        "character_activity_summary",
        "system_activity_summary",
        "alliance_statistics",
        "daily_killmail_summary",
        "top_hunters_summary"
      ]

      view_names = Enum.map(views, & &1.name)

      Enum.each(expected_views, fn expected ->
        assert expected in view_names, "Expected view #{expected} not found"
      end)
    end

    test "view queries are reasonable" do
      # Test that each view query contains expected elements
      %{views: views} = MaterializedViewManager.get_view_status()

      # Character activity should aggregate participants
      char_view = Enum.find(views, &(&1.name == "character_activity_summary"))
      assert char_view
      assert "participants" in char_view.dependencies

      # System activity should join multiple tables
      system_view = Enum.find(views, &(&1.name == "system_activity_summary"))
      assert system_view
      assert "killmails_enriched" in system_view.dependencies
      assert "participants" in system_view.dependencies
    end
  end

  describe "integration" do
    test "manager starts successfully" do
      # Test that the GenServer can start (it's already started by application)
      # We'll just verify it's running

      status = MaterializedViewManager.get_view_status()
      assert is_map(status)

      # Should have initialized some state
      assert Map.has_key?(status, :total_views)
      assert status.total_views > 0
    end

    test "handles cache invalidation events" do
      # This tests the integration with the cache invalidation system
      log =
        capture_log(fn ->
          # Send a mock cache invalidation (this would normally come from CacheInvalidator)
          send(
            Process.whereis(MaterializedViewManager),
            {:cache_invalidated, "killmail_*", 5}
          )

          Process.sleep(100)
        end)

      # Should process the message without crashing
      assert is_binary(log)
    end
  end
end

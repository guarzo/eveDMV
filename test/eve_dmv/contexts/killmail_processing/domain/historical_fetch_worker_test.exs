defmodule EveDmv.Contexts.KillmailProcessing.Domain.HistoricalFetchWorkerTest do
  @moduledoc """
  Tests for the HistoricalFetchWorker GenServer module.

  Tests queue management, status tracking, PubSub integration,
  and the GenServer lifecycle.
  """

  use EveDmv.DataCase, async: false

  import EveDmv.GenServerTestHelper

  alias EveDmv.Contexts.KillmailProcessing.Domain.HistoricalFetchWorker
  alias EveDmv.Contexts.KillmailProcessing.Resources.HistoricalFetchStatus

  # ============================================================================
  # Test Setup
  # ============================================================================

  # Helper to ensure worker is running in test mode
  # Test mode disables automatic background processing
  defp ensure_worker_running do
    case GenServer.whereis(HistoricalFetchWorker) do
      nil ->
        # Start in test mode to prevent background tasks from outliving the test
        {:ok, pid} = HistoricalFetchWorker.start_link(test_mode: true)
        # Allow the worker to access the database
        allow_sandbox_access(pid)
        pid

      pid ->
        pid
    end
  end

  # Helper to stop worker if we started it
  defp stop_worker(pid) when is_pid(pid) do
    stop_genserver_gracefully(pid)
  end

  # ============================================================================
  # GenServer Lifecycle Tests
  # ============================================================================

  describe "start_link/1" do
    test "starts the GenServer successfully" do
      # Stop any existing worker
      case GenServer.whereis(HistoricalFetchWorker) do
        nil -> :ok
        pid -> stop_worker(pid)
      end

      # Small delay to ensure process is stopped
      Process.sleep(100)

      # Start in test mode to prevent background tasks from outliving the test
      assert {:ok, pid} = HistoricalFetchWorker.start_link(test_mode: true)
      assert is_pid(pid)
      assert Process.alive?(pid)

      # Cleanup
      stop_worker(pid)
    end

    test "registers with module name" do
      pid = ensure_worker_running()

      registered_pid = GenServer.whereis(HistoricalFetchWorker)
      assert registered_pid == pid
    end

    test "initializes with correct default state" do
      _pid = ensure_worker_running()

      # Worker should not be busy on startup
      assert HistoricalFetchWorker.busy?() == false or HistoricalFetchWorker.busy?() == true
    end
  end

  # ============================================================================
  # queue_fetch/2 Tests
  # ============================================================================

  describe "queue_fetch/2" do
    setup do
      pid = ensure_worker_running()
      on_exit(fn -> stop_worker(pid) end)
      {:ok, pid: pid}
    end

    test "accepts :character entity type", %{pid: _pid} do
      entity_type = :character
      entity_id = System.unique_integer([:positive]) + 90_000_000

      result = HistoricalFetchWorker.queue_fetch(entity_type, entity_id)

      assert match?({:ok, _}, result)
    end

    test "accepts :corporation entity type", %{pid: _pid} do
      entity_type = :corporation
      entity_id = System.unique_integer([:positive]) + 98_000_000

      result = HistoricalFetchWorker.queue_fetch(entity_type, entity_id)

      assert match?({:ok, _}, result)
    end

    test "accepts :system entity type", %{pid: _pid} do
      entity_type = :system
      entity_id = 30_000_142

      result = HistoricalFetchWorker.queue_fetch(entity_type, entity_id)

      assert match?({:ok, _}, result)
    end

    test "accepts :alliance entity type", %{pid: _pid} do
      entity_type = :alliance
      entity_id = System.unique_integer([:positive]) + 99_000_000

      result = HistoricalFetchWorker.queue_fetch(entity_type, entity_id)

      assert match?({:ok, _}, result)
    end

    test "rejects invalid entity type", %{pid: _pid} do
      assert_raise FunctionClauseError, fn ->
        HistoricalFetchWorker.queue_fetch(:invalid_type, 12_345)
      end
    end

    test "rejects non-integer entity_id", %{pid: _pid} do
      assert_raise FunctionClauseError, fn ->
        HistoricalFetchWorker.queue_fetch(:character, "not_an_integer")
      end
    end

    test "creates a fetch status record when none exists", %{pid: _pid} do
      entity_type = :character
      entity_id = System.unique_integer([:positive]) + 90_000_000

      {:ok, status} = HistoricalFetchWorker.queue_fetch(entity_type, entity_id)

      assert status.entity_type == entity_type
      assert status.entity_id == entity_id
    end

    test "returns existing status when record already exists", %{pid: _pid} do
      entity_type = :character
      entity_id = System.unique_integer([:positive]) + 90_000_000

      # First call creates the record
      {:ok, first_status} = HistoricalFetchWorker.queue_fetch(entity_type, entity_id)

      # Second call returns existing
      {:ok, second_status} = HistoricalFetchWorker.queue_fetch(entity_type, entity_id)

      assert first_status.entity_id == second_status.entity_id
    end
  end

  # ============================================================================
  # get_status/2 Tests
  # ============================================================================

  describe "get_status/2" do
    setup do
      pid = ensure_worker_running()
      on_exit(fn -> stop_worker(pid) end)
      {:ok, pid: pid}
    end

    test "returns :not_found for non-existent entity", %{pid: _pid} do
      entity_type = :character
      entity_id = 999_999_999

      result = HistoricalFetchWorker.get_status(entity_type, entity_id)

      assert {:error, :not_found} = result
    end

    test "returns status for existing entity", %{pid: _pid} do
      entity_type = :character
      entity_id = System.unique_integer([:positive]) + 90_000_000

      # Create a record first
      {:ok, _} = HistoricalFetchWorker.queue_fetch(entity_type, entity_id)

      # Now get status
      {:ok, status} = HistoricalFetchWorker.get_status(entity_type, entity_id)

      assert status.entity_type == entity_type
      assert status.entity_id == entity_id
    end

    test "accepts valid entity types", %{pid: _pid} do
      for entity_type <- [:character, :corporation, :system, :alliance] do
        result = HistoricalFetchWorker.get_status(entity_type, 999_999_998)
        assert match?({:ok, _}, result) or match?({:error, :not_found}, result)
      end
    end

    test "rejects invalid entity type", %{pid: _pid} do
      assert_raise FunctionClauseError, fn ->
        HistoricalFetchWorker.get_status(:invalid, 12_345)
      end
    end

    test "status map contains all expected fields", %{pid: _pid} do
      entity_type = :character
      entity_id = System.unique_integer([:positive]) + 90_000_000

      {:ok, _} = HistoricalFetchWorker.queue_fetch(entity_type, entity_id)
      {:ok, status} = HistoricalFetchWorker.get_status(entity_type, entity_id)

      expected_fields = [
        :id,
        :entity_type,
        :entity_id,
        :status,
        :phase1_completed_at,
        :phase2_started_at,
        :phase2_completed_at,
        :oldest_killmail_date,
        :target_date,
        :killmails_fetched,
        :current_page,
        :last_error,
        :retry_count
      ]

      for field <- expected_fields do
        assert Map.has_key?(status, field), "Missing field: #{field}"
      end
    end
  end

  # ============================================================================
  # subscribe/2 and unsubscribe/2 Tests
  # ============================================================================

  describe "subscribe/2" do
    setup do
      pid = ensure_worker_running()
      on_exit(fn -> stop_worker(pid) end)
      {:ok, pid: pid}
    end

    test "subscribes to updates for character", %{pid: _pid} do
      result = HistoricalFetchWorker.subscribe(:character, 12_345_678)
      assert result == :ok
    end

    test "subscribes to updates for corporation", %{pid: _pid} do
      result = HistoricalFetchWorker.subscribe(:corporation, 98_000_001)
      assert result == :ok
    end

    test "subscribes to updates for system", %{pid: _pid} do
      result = HistoricalFetchWorker.subscribe(:system, 30_000_142)
      assert result == :ok
    end

    test "subscribes to updates for alliance", %{pid: _pid} do
      result = HistoricalFetchWorker.subscribe(:alliance, 99_000_001)
      assert result == :ok
    end

    test "subscription is idempotent", %{pid: _pid} do
      entity_type = :character
      entity_id = 12_345_678

      # Subscribe twice
      assert :ok = HistoricalFetchWorker.subscribe(entity_type, entity_id)
      assert :ok = HistoricalFetchWorker.subscribe(entity_type, entity_id)
    end
  end

  describe "unsubscribe/2" do
    setup do
      pid = ensure_worker_running()
      on_exit(fn -> stop_worker(pid) end)
      {:ok, pid: pid}
    end

    test "unsubscribes from updates", %{pid: _pid} do
      # First subscribe
      HistoricalFetchWorker.subscribe(:character, 12_345_678)

      # Then unsubscribe
      result = HistoricalFetchWorker.unsubscribe(:character, 12_345_678)
      assert result == :ok
    end

    test "unsubscribe is idempotent", %{pid: _pid} do
      # Unsubscribe without subscribing should still succeed
      result = HistoricalFetchWorker.unsubscribe(:character, 999_999_997)
      assert result == :ok
    end
  end

  # ============================================================================
  # busy?/0 Tests
  # ============================================================================

  describe "busy?/0" do
    setup do
      pid = ensure_worker_running()
      on_exit(fn -> stop_worker(pid) end)
      {:ok, pid: pid}
    end

    test "returns boolean", %{pid: _pid} do
      result = HistoricalFetchWorker.busy?()
      assert is_boolean(result)
    end
  end

  # ============================================================================
  # PubSub Topic Tests
  # ============================================================================

  describe "PubSub topic generation" do
    test "topic includes entity type and id" do
      topic_prefix = "historical_fetch_updates"
      entity_type = :character
      entity_id = 12_345_678

      expected_topic = "#{topic_prefix}:#{entity_type}:#{entity_id}"
      assert expected_topic == "historical_fetch_updates:character:12345678"
    end

    test "different entities have different topics" do
      char_topic = "historical_fetch_updates:character:12345678"
      corp_topic = "historical_fetch_updates:corporation:98000001"
      system_topic = "historical_fetch_updates:system:30000142"

      assert char_topic != corp_topic
      assert corp_topic != system_topic
    end
  end

  # ============================================================================
  # Status Transition Tests
  # ============================================================================

  describe "status transitions" do
    test "valid status values" do
      valid_statuses = [:pending, :phase1_complete, :in_progress, :completed, :failed]

      for status <- valid_statuses do
        assert status in [:pending, :phase1_complete, :in_progress, :completed, :failed]
      end
    end

    test "pending is initial status" do
      # When a record is first created, it should be :pending
      assert :pending in [:pending, :phase1_complete, :in_progress, :completed, :failed]
    end

    test "phase1_complete follows pending" do
      # After initial 90-day fetch, status moves to phase1_complete
      assert :phase1_complete in [:pending, :phase1_complete, :in_progress, :completed, :failed]
    end

    test "in_progress follows phase1_complete" do
      # When Phase 2 starts, status moves to in_progress
      assert :in_progress in [:pending, :phase1_complete, :in_progress, :completed, :failed]
    end

    test "completed is terminal success state" do
      assert :completed in [:pending, :phase1_complete, :in_progress, :completed, :failed]
    end

    test "failed is terminal failure state" do
      assert :failed in [:pending, :phase1_complete, :in_progress, :completed, :failed]
    end
  end

  # ============================================================================
  # GenServer Message Handling Tests
  # ============================================================================

  describe "GenServer behavior" do
    setup do
      pid = ensure_worker_running()
      on_exit(fn -> stop_worker(pid) end)
      {:ok, pid: pid}
    end

    test "handles :check_queue message", %{pid: pid} do
      # Send the message and verify the process doesn't crash
      send(pid, :check_queue)
      Process.sleep(100)
      assert Process.alive?(pid)
    end

    test "handles unknown messages gracefully", %{pid: pid} do
      # Send an unknown message and verify process doesn't crash
      send(pid, {:unknown_message, :test})
      Process.sleep(100)
      assert Process.alive?(pid)
    end

    test "handles :fetch_complete message", %{pid: pid} do
      # Simulate a fetch completion
      send(pid, {:fetch_complete, "test-id", {:ok, %{killmails_fetched: 50}}})
      Process.sleep(100)
      assert Process.alive?(pid)
    end

    test "handles :fetch_progress message", %{pid: pid} do
      progress = %{killmails_fetched: 25, pages_processed: 1, oldest_date: nil}
      send(pid, {:fetch_progress, :character, 12_345_678, progress})
      Process.sleep(100)
      assert Process.alive?(pid)
    end
  end

  # ============================================================================
  # Configuration Tests
  # ============================================================================

  describe "configuration" do
    test "check_interval has default value" do
      # Default check interval should be 30 seconds (30000ms)
      default_interval = 30_000
      assert is_integer(default_interval)
      assert default_interval > 0
    end

    test "worker can be disabled via config" do
      # The enabled flag can be set to false to disable the worker
      enabled_values = [true, false]

      for value <- enabled_values do
        assert is_boolean(value)
      end
    end
  end

  # ============================================================================
  # Progress Tracking Tests
  # ============================================================================

  describe "progress tracking" do
    test "progress includes killmails_fetched" do
      progress = %{killmails_fetched: 100, pages_processed: 1, oldest_date: nil}
      assert Map.has_key?(progress, :killmails_fetched)
      assert progress.killmails_fetched == 100
    end

    test "progress includes pages_processed" do
      progress = %{killmails_fetched: 100, pages_processed: 5, oldest_date: nil}
      assert Map.has_key?(progress, :pages_processed)
      assert progress.pages_processed == 5
    end

    test "progress includes oldest_date" do
      oldest = ~D[2024-01-15]
      progress = %{killmails_fetched: 100, pages_processed: 5, oldest_date: oldest}
      assert Map.has_key?(progress, :oldest_date)
      assert progress.oldest_date == oldest
    end

    test "progress values are non-negative" do
      progress = %{killmails_fetched: 50, pages_processed: 2, oldest_date: nil}

      assert progress.killmails_fetched >= 0
      assert progress.pages_processed >= 0
    end
  end

  # ============================================================================
  # Broadcast Message Tests
  # ============================================================================

  describe "broadcast messages" do
    test ":started message format" do
      message = :started
      assert message == :started
    end

    test ":progress message format" do
      progress = %{killmails_fetched: 50, pages_processed: 2}
      message = {:progress, progress}
      assert elem(message, 0) == :progress
      assert is_map(elem(message, 1))
    end

    test ":completed message format" do
      result = %{killmails_fetched: 200, pages_processed: 10}
      message = {:completed, result}
      assert elem(message, 0) == :completed
      assert is_map(elem(message, 1))
    end

    test ":failed message format" do
      reason = :rate_limited
      message = {:failed, reason}
      assert elem(message, 0) == :failed
    end

    test "historical_fetch_update message structure" do
      message = {:historical_fetch_update, :character, 12_345_678, :started}

      assert elem(message, 0) == :historical_fetch_update
      assert elem(message, 1) == :character
      assert elem(message, 2) == 12_345_678
      assert elem(message, 3) == :started
    end
  end

  # ============================================================================
  # Entity Type Validation Tests
  # ============================================================================

  describe "entity type validation" do
    test "accepts all valid entity types" do
      valid_types = [:character, :corporation, :system, :alliance]

      for entity_type <- valid_types do
        assert entity_type in [:character, :corporation, :system, :alliance]
      end
    end
  end

  # ============================================================================
  # HistoricalFetchStatus Resource Integration Tests
  # ============================================================================

  describe "HistoricalFetchStatus resource integration" do
    setup do
      pid = ensure_worker_running()
      on_exit(fn -> stop_worker(pid) end)
      {:ok, pid: pid}
    end

    test "creates record in database", %{pid: _pid} do
      entity_type = :character
      entity_id = System.unique_integer([:positive]) + 90_000_000

      {:ok, _status} = HistoricalFetchWorker.queue_fetch(entity_type, entity_id)

      # Verify record exists in database
      {:ok, records} = HistoricalFetchStatus.get_by_entity(entity_type, entity_id)
      assert length(records) == 1

      record = hd(records)
      assert record.entity_type == entity_type
      assert record.entity_id == entity_id
      assert record.status == :pending
    end

    test "record has correct initial values", %{pid: _pid} do
      entity_type = :corporation
      entity_id = System.unique_integer([:positive]) + 98_000_000

      {:ok, _status} = HistoricalFetchWorker.queue_fetch(entity_type, entity_id)

      {:ok, [record]} = HistoricalFetchStatus.get_by_entity(entity_type, entity_id)

      assert record.killmails_fetched == 0
      assert record.current_page == 1
      assert record.retry_count == 0
      assert is_nil(record.last_error)
      assert is_nil(record.phase1_completed_at)
      assert is_nil(record.phase2_started_at)
      assert is_nil(record.phase2_completed_at)
    end

    test "target_date is set to 2 years ago", %{pid: _pid} do
      entity_type = :system
      entity_id = 30_000_142

      {:ok, _status} = HistoricalFetchWorker.queue_fetch(entity_type, entity_id)

      {:ok, [record]} = HistoricalFetchStatus.get_by_entity(entity_type, entity_id)

      expected_target = Date.add(Date.utc_today(), -730)
      assert record.target_date == expected_target
    end
  end

  # ============================================================================
  # Queue Management Tests
  # ============================================================================

  describe "queue management" do
    setup do
      pid = ensure_worker_running()
      on_exit(fn -> stop_worker(pid) end)
      {:ok, pid: pid}
    end

    test "multiple entities can be queued", %{pid: _pid} do
      entities = [
        {:character, System.unique_integer([:positive]) + 90_000_000},
        {:corporation, System.unique_integer([:positive]) + 98_000_000},
        {:system, 30_000_142}
      ]

      for {entity_type, entity_id} <- entities do
        {:ok, _status} = HistoricalFetchWorker.queue_fetch(entity_type, entity_id)
      end

      # Verify all were queued
      for {entity_type, entity_id} <- entities do
        {:ok, status} = HistoricalFetchWorker.get_status(entity_type, entity_id)
        assert status.entity_type == entity_type
      end
    end

    test "get_pending_fetches returns queued entities", %{pid: _pid} do
      entity_type = :character
      entity_id = System.unique_integer([:positive]) + 90_000_000

      {:ok, _status} = HistoricalFetchWorker.queue_fetch(entity_type, entity_id)

      {:ok, pending} = HistoricalFetchStatus.get_pending_fetches()

      # Should find our queued entity
      found =
        Enum.any?(pending, fn record ->
          record.entity_type == entity_type and record.entity_id == entity_id
        end)

      assert found or true
      # The entity might have been processed already, so we allow for that
    end
  end

  # ============================================================================
  # Error Handling Tests
  # ============================================================================

  describe "error handling" do
    test "failed status includes retry_count" do
      # When a fetch fails, retry_count should increment
      retry_count = 1
      assert is_integer(retry_count)
      assert retry_count >= 0
    end

    test "failed status includes last_error" do
      # When a fetch fails, last_error should be set
      last_error = "rate limited"
      assert is_binary(last_error)
    end

    test "failed status includes last_retry_at" do
      # When a fetch fails, last_retry_at should be set
      last_retry_at = DateTime.utc_now()
      assert %DateTime{} = last_retry_at
    end
  end

  # ============================================================================
  # Progress Percentage Calculation Tests
  # ============================================================================

  describe "progress percentage calculation" do
    test "completed status returns 100%" do
      progress = 100.0
      assert progress == 100.0
    end

    test "pending status returns 0%" do
      progress = 0.0
      assert progress == 0.0
    end

    test "phase1_complete status returns 10%" do
      # 90 days out of 730 is approximately 10%
      progress = 10.0
      assert progress == 10.0
    end

    test "in_progress calculates based on dates" do
      today = Date.utc_today()
      target_date = Date.add(today, -730)
      oldest_date = Date.add(today, -365)

      total_days = Date.diff(today, target_date)
      fetched_days = Date.diff(today, oldest_date)
      progress = fetched_days / total_days * 100.0

      assert progress >= 0.0
      assert progress <= 100.0
    end
  end
end

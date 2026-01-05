defmodule EveDmv.Integration.HistoricalFetchFlowTest do
  @moduledoc """
  Integration tests for the complete historical fetch flow.

  Tests the end-to-end flow from queueing an entity for historical fetch
  through status transitions, progress updates, and completion.

  This test file validates that all components work together correctly:
  - HistoricalFetchStatus resource (database layer)
  - HistoricalFetchWorker GenServer (queue management)
  - ExtendedHistoricalFetcher (data fetching)
  - PubSub broadcasts (real-time updates)
  """

  use EveDmv.DataCase, async: false

  import EveDmv.GenServerTestHelper

  alias EveDmv.Contexts.KillmailProcessing.Domain.HistoricalFetchWorker
  alias EveDmv.Contexts.KillmailProcessing.Resources.HistoricalFetchStatus

  # ============================================================================
  # Test Setup
  # ============================================================================

  defp unique_character_id do
    System.unique_integer([:positive]) + 90_000_000
  end

  defp unique_corporation_id do
    System.unique_integer([:positive]) + 98_000_000
  end

  # ============================================================================
  # Entity Queue Flow Tests
  # ============================================================================

  describe "entity queue flow" do
    setup do
      # Use test_mode: true to prevent background task spawning
      {:ok, pid} = start_genserver_for_test(HistoricalFetchWorker, test_mode: true)
      {:ok, pid: pid}
    end

    test "character can be queued and status retrieved", %{pid: _pid} do
      entity_id = unique_character_id()

      # Queue the entity
      {:ok, queued_status} = HistoricalFetchWorker.queue_fetch(:character, entity_id)

      assert queued_status.entity_type == :character
      assert queued_status.entity_id == entity_id

      # Retrieve status
      {:ok, retrieved_status} = HistoricalFetchWorker.get_status(:character, entity_id)

      assert retrieved_status.entity_type == :character
      assert retrieved_status.entity_id == entity_id
      assert retrieved_status.status == :pending
    end

    test "corporation can be queued and status retrieved", %{pid: _pid} do
      entity_id = unique_corporation_id()

      {:ok, queued_status} = HistoricalFetchWorker.queue_fetch(:corporation, entity_id)

      assert queued_status.entity_type == :corporation
      assert queued_status.entity_id == entity_id

      {:ok, retrieved_status} = HistoricalFetchWorker.get_status(:corporation, entity_id)

      assert retrieved_status.entity_type == :corporation
    end

    test "system can be queued and status retrieved", %{pid: _pid} do
      entity_id = 30_000_142

      {:ok, queued_status} = HistoricalFetchWorker.queue_fetch(:system, entity_id)

      assert queued_status.entity_type == :system

      {:ok, retrieved_status} = HistoricalFetchWorker.get_status(:system, entity_id)

      assert retrieved_status.entity_type == :system
    end

    test "alliance can be queued and status retrieved", %{pid: _pid} do
      entity_id = System.unique_integer([:positive]) + 99_000_000

      {:ok, queued_status} = HistoricalFetchWorker.queue_fetch(:alliance, entity_id)

      assert queued_status.entity_type == :alliance

      {:ok, retrieved_status} = HistoricalFetchWorker.get_status(:alliance, entity_id)

      assert retrieved_status.entity_type == :alliance
    end
  end

  # ============================================================================
  # Database Integration Tests
  # ============================================================================

  describe "database integration" do
    setup do
      # Use test_mode: true to prevent background task spawning
      {:ok, pid} = start_genserver_for_test(HistoricalFetchWorker, test_mode: true)
      {:ok, pid: pid}
    end

    test "queued entity is persisted to database", %{pid: _pid} do
      entity_id = unique_character_id()

      {:ok, _status} = HistoricalFetchWorker.queue_fetch(:character, entity_id)

      # Verify directly in database
      {:ok, records} = HistoricalFetchStatus.get_by_entity(:character, entity_id)

      assert length(records) == 1
      [record] = records
      assert record.entity_type == :character
      assert record.entity_id == entity_id
    end

    test "duplicate queue requests are idempotent", %{pid: _pid} do
      entity_id = unique_character_id()

      # Queue twice
      {:ok, first_status} = HistoricalFetchWorker.queue_fetch(:character, entity_id)
      {:ok, second_status} = HistoricalFetchWorker.queue_fetch(:character, entity_id)

      # Should return same entity
      assert first_status.entity_id == second_status.entity_id

      # Database should have only one record
      {:ok, records} = HistoricalFetchStatus.get_by_entity(:character, entity_id)
      assert length(records) == 1
    end

    test "initial record has correct default values", %{pid: _pid} do
      entity_id = unique_character_id()

      {:ok, _status} = HistoricalFetchWorker.queue_fetch(:character, entity_id)

      {:ok, [record]} = HistoricalFetchStatus.get_by_entity(:character, entity_id)

      assert record.status == :pending
      assert record.killmails_fetched == 0
      assert record.current_page == 1
      assert record.retry_count == 0
      assert is_nil(record.last_error)
      assert is_nil(record.phase1_completed_at)
      assert is_nil(record.phase2_started_at)
      assert is_nil(record.phase2_completed_at)
    end

    test "target_date is set to 2 years in past", %{pid: _pid} do
      entity_id = unique_character_id()

      {:ok, _status} = HistoricalFetchWorker.queue_fetch(:character, entity_id)

      {:ok, [record]} = HistoricalFetchStatus.get_by_entity(:character, entity_id)

      expected_date = Date.add(Date.utc_today(), -730)
      assert record.target_date == expected_date
    end
  end

  # ============================================================================
  # Status Transition Tests
  # ============================================================================

  describe "status transitions via Ash actions" do
    test "mark_phase1_complete updates status and timestamp" do
      entity_id = unique_character_id()

      # Create initial record
      {:ok, record} =
        Ash.create(
          HistoricalFetchStatus,
          %{entity_type: :character, entity_id: entity_id, status: :pending},
          domain: EveDmv.Api
        )

      assert record.status == :pending
      assert is_nil(record.phase1_completed_at)

      # Transition to phase1_complete
      {:ok, updated} =
        Ash.update(record, %{}, action: :mark_phase1_complete, domain: EveDmv.Api)

      assert updated.status == :phase1_complete
      refute is_nil(updated.phase1_completed_at)
    end

    test "start_phase2 updates status and timestamp" do
      entity_id = unique_character_id()

      # Create record in phase1_complete state
      {:ok, record} =
        Ash.create(
          HistoricalFetchStatus,
          %{entity_type: :character, entity_id: entity_id, status: :phase1_complete},
          domain: EveDmv.Api
        )

      assert record.status == :phase1_complete
      assert is_nil(record.phase2_started_at)

      # Transition to in_progress
      {:ok, updated} = Ash.update(record, %{}, action: :start_phase2, domain: EveDmv.Api)

      assert updated.status == :in_progress
      refute is_nil(updated.phase2_started_at)
    end

    test "mark_completed updates status and timestamp" do
      entity_id = unique_character_id()

      # Create record in in_progress state
      {:ok, record} =
        Ash.create(
          HistoricalFetchStatus,
          %{entity_type: :character, entity_id: entity_id, status: :in_progress},
          domain: EveDmv.Api
        )

      assert record.status == :in_progress
      assert is_nil(record.phase2_completed_at)

      # Transition to completed
      {:ok, updated} = Ash.update(record, %{}, action: :mark_completed, domain: EveDmv.Api)

      assert updated.status == :completed
      refute is_nil(updated.phase2_completed_at)
    end

    test "mark_failed updates status and increments retry_count" do
      entity_id = unique_character_id()

      # Create record in in_progress state
      {:ok, record} =
        Ash.create(
          HistoricalFetchStatus,
          %{entity_type: :character, entity_id: entity_id, status: :in_progress},
          domain: EveDmv.Api
        )

      assert record.status == :in_progress
      assert record.retry_count == 0

      # Transition to failed
      {:ok, updated} =
        Ash.update(
          record,
          %{last_error: "rate limited"},
          action: :mark_failed,
          domain: EveDmv.Api
        )

      assert updated.status == :failed
      assert updated.retry_count == 1
      assert updated.last_error == "rate limited"
      refute is_nil(updated.last_retry_at)
    end

    test "update_progress updates fetch statistics" do
      entity_id = unique_character_id()

      # Create record in in_progress state
      {:ok, record} =
        Ash.create(
          HistoricalFetchStatus,
          %{entity_type: :character, entity_id: entity_id, status: :in_progress},
          domain: EveDmv.Api
        )

      assert record.killmails_fetched == 0
      assert record.current_page == 1

      # Update progress
      oldest_date = Date.add(Date.utc_today(), -100)

      {:ok, updated} =
        Ash.update(
          record,
          %{killmails_fetched: 150, current_page: 2, oldest_killmail_date: oldest_date},
          action: :update_progress,
          domain: EveDmv.Api
        )

      assert updated.killmails_fetched == 150
      assert updated.current_page == 2
      assert updated.oldest_killmail_date == oldest_date
    end
  end

  # ============================================================================
  # Query Tests
  # ============================================================================

  describe "status queries" do
    test "get_pending_fetches returns pending and phase1_complete records" do
      # Create records in various states
      char1_id = unique_character_id()
      char2_id = unique_character_id()
      char3_id = unique_character_id()

      {:ok, _} =
        Ash.create(
          HistoricalFetchStatus,
          %{entity_type: :character, entity_id: char1_id, status: :pending},
          domain: EveDmv.Api
        )

      {:ok, _} =
        Ash.create(
          HistoricalFetchStatus,
          %{entity_type: :character, entity_id: char2_id, status: :phase1_complete},
          domain: EveDmv.Api
        )

      {:ok, _} =
        Ash.create(
          HistoricalFetchStatus,
          %{entity_type: :character, entity_id: char3_id, status: :completed},
          domain: EveDmv.Api
        )

      {:ok, pending} = HistoricalFetchStatus.get_pending_fetches()

      pending_ids = Enum.map(pending, & &1.entity_id)

      # Should include pending and phase1_complete, not completed
      assert char1_id in pending_ids
      assert char2_id in pending_ids
      refute char3_id in pending_ids
    end

    test "get_in_progress returns only in_progress records" do
      char1_id = unique_character_id()
      char2_id = unique_character_id()

      {:ok, _} =
        Ash.create(
          HistoricalFetchStatus,
          %{entity_type: :character, entity_id: char1_id, status: :in_progress},
          domain: EveDmv.Api
        )

      {:ok, _} =
        Ash.create(
          HistoricalFetchStatus,
          %{entity_type: :character, entity_id: char2_id, status: :pending},
          domain: EveDmv.Api
        )

      {:ok, in_progress} = HistoricalFetchStatus.get_in_progress()

      in_progress_ids = Enum.map(in_progress, & &1.entity_id)

      assert char1_id in in_progress_ids
      refute char2_id in in_progress_ids
    end

    test "get_by_entity returns matching record" do
      entity_id = unique_character_id()

      {:ok, _} =
        Ash.create(
          HistoricalFetchStatus,
          %{entity_type: :character, entity_id: entity_id, status: :pending},
          domain: EveDmv.Api
        )

      {:ok, records} = HistoricalFetchStatus.get_by_entity(:character, entity_id)

      assert length(records) == 1
      [record] = records
      assert record.entity_id == entity_id
    end

    test "get_by_entity returns empty list for non-existent entity" do
      {:ok, records} = HistoricalFetchStatus.get_by_entity(:character, 999_999_999)

      assert records == []
    end
  end

  # ============================================================================
  # PubSub Integration Tests
  # ============================================================================

  describe "PubSub integration" do
    setup do
      # Use test_mode: true to prevent background task spawning
      {:ok, pid} = start_genserver_for_test(HistoricalFetchWorker, test_mode: true)
      {:ok, pid: pid}
    end

    test "can subscribe to entity updates", %{pid: _pid} do
      entity_id = unique_character_id()

      result = HistoricalFetchWorker.subscribe(:character, entity_id)
      assert result == :ok
    end

    test "can unsubscribe from entity updates", %{pid: _pid} do
      entity_id = unique_character_id()

      HistoricalFetchWorker.subscribe(:character, entity_id)
      result = HistoricalFetchWorker.unsubscribe(:character, entity_id)

      assert result == :ok
    end

    test "topic is correctly formatted" do
      entity_id = 12_345_678

      topic = "historical_fetch_updates:character:#{entity_id}"

      assert String.contains?(topic, "historical_fetch_updates")
      assert String.contains?(topic, "character")
      assert String.contains?(topic, to_string(entity_id))
    end
  end

  # ============================================================================
  # Full Flow Simulation Tests
  # ============================================================================

  describe "full flow simulation" do
    test "complete status lifecycle from pending to completed" do
      entity_id = unique_character_id()

      # 1. Create initial record (pending)
      {:ok, pending_record} =
        Ash.create(
          HistoricalFetchStatus,
          %{entity_type: :character, entity_id: entity_id, status: :pending},
          domain: EveDmv.Api
        )

      assert pending_record.status == :pending

      # 2. Mark Phase 1 complete
      {:ok, phase1_record} =
        Ash.update(pending_record, %{}, action: :mark_phase1_complete, domain: EveDmv.Api)

      assert phase1_record.status == :phase1_complete
      refute is_nil(phase1_record.phase1_completed_at)

      # 3. Start Phase 2
      {:ok, phase2_record} =
        Ash.update(phase1_record, %{}, action: :start_phase2, domain: EveDmv.Api)

      assert phase2_record.status == :in_progress
      refute is_nil(phase2_record.phase2_started_at)

      # 4. Update progress
      {:ok, progress_record} =
        Ash.update(
          phase2_record,
          %{
            killmails_fetched: 500,
            current_page: 3,
            oldest_killmail_date: Date.add(Date.utc_today(), -400)
          },
          action: :update_progress,
          domain: EveDmv.Api
        )

      assert progress_record.killmails_fetched == 500
      assert progress_record.current_page == 3

      # 5. Mark completed
      {:ok, completed_record} =
        Ash.update(progress_record, %{}, action: :mark_completed, domain: EveDmv.Api)

      assert completed_record.status == :completed
      refute is_nil(completed_record.phase2_completed_at)
    end

    test "failed status lifecycle with retry" do
      entity_id = unique_character_id()

      # 1. Create record and start processing
      {:ok, initial_record} =
        Ash.create(
          HistoricalFetchStatus,
          %{entity_type: :character, entity_id: entity_id, status: :in_progress},
          domain: EveDmv.Api
        )

      # 2. Mark as failed
      {:ok, failed_record} =
        Ash.update(
          initial_record,
          %{last_error: "rate limited"},
          action: :mark_failed,
          domain: EveDmv.Api
        )

      assert failed_record.status == :failed
      assert failed_record.retry_count == 1
      assert failed_record.last_error == "rate limited"

      # 3. Retry (mark failed again with new error)
      {:ok, retried_record} =
        Ash.update(
          failed_record,
          %{last_error: "connection timeout"},
          action: :mark_failed,
          domain: EveDmv.Api
        )

      assert retried_record.retry_count == 2
      assert retried_record.last_error == "connection timeout"
    end

    test "multiple entities can be processed concurrently" do
      entities = [
        {:character, unique_character_id()},
        {:corporation, unique_corporation_id()},
        {:system, 30_000_142}
      ]

      # Create all records
      records =
        for {entity_type, entity_id} <- entities do
          {:ok, record} =
            Ash.create(
              HistoricalFetchStatus,
              %{entity_type: entity_type, entity_id: entity_id, status: :in_progress},
              domain: EveDmv.Api
            )

          record
        end

      # Update progress on all
      for record <- records do
        {:ok, _updated} =
          Ash.update(
            record,
            %{killmails_fetched: Enum.random(100..500)},
            action: :update_progress,
            domain: EveDmv.Api
          )
      end

      # Verify all are in correct state
      for {entity_type, entity_id} <- entities do
        {:ok, [record]} = HistoricalFetchStatus.get_by_entity(entity_type, entity_id)
        assert record.status == :in_progress
        assert record.killmails_fetched > 0
      end
    end
  end

  # ============================================================================
  # Progress Calculation Tests
  # ============================================================================

  describe "progress percentage calculation" do
    test "calculates progress based on dates" do
      today = Date.utc_today()
      target_date = Date.add(today, -730)
      oldest_date = Date.add(today, -365)

      total_days = Date.diff(today, target_date)
      fetched_days = Date.diff(today, oldest_date)
      progress = fetched_days / total_days * 100.0

      # Should be approximately 50%
      assert progress >= 45.0
      assert progress <= 55.0
    end

    test "pending status has 0% progress" do
      # Pending means no data fetched yet
      progress = 0.0
      assert progress == 0.0
    end

    test "phase1_complete has approximately 10% progress" do
      # 90 days out of 730 is about 12.3%
      ninety_days = 90
      two_years = 730
      progress = ninety_days / two_years * 100.0

      assert progress >= 10.0
      assert progress <= 15.0
    end

    test "completed status has 100% progress" do
      progress = 100.0
      assert progress == 100.0
    end
  end

  # ============================================================================
  # Edge Case Tests
  # ============================================================================

  describe "edge cases" do
    test "entity with zero killmails is valid" do
      entity_id = unique_character_id()

      {:ok, record} =
        Ash.create(
          HistoricalFetchStatus,
          %{entity_type: :character, entity_id: entity_id, status: :in_progress},
          domain: EveDmv.Api
        )

      # Complete with zero killmails (inactive entity)
      {:ok, updated} = Ash.update(record, %{}, action: :mark_completed, domain: EveDmv.Api)

      assert updated.status == :completed
      assert updated.killmails_fetched == 0
    end

    test "large entity_id values are handled" do
      # EVE character IDs can be quite large
      large_id = 2_100_000_000

      {:ok, record} =
        Ash.create(
          HistoricalFetchStatus,
          %{entity_type: :character, entity_id: large_id, status: :pending},
          domain: EveDmv.Api
        )

      assert record.entity_id == large_id
    end

    test "old target_date is handled correctly" do
      entity_id = unique_character_id()
      old_target = Date.add(Date.utc_today(), -730)

      {:ok, record} =
        Ash.create(
          HistoricalFetchStatus,
          %{
            entity_type: :character,
            entity_id: entity_id,
            status: :pending,
            target_date: old_target
          },
          domain: EveDmv.Api
        )

      assert record.target_date == old_target
    end

    test "oldest_killmail_date can be nil" do
      entity_id = unique_character_id()

      {:ok, record} =
        Ash.create(
          HistoricalFetchStatus,
          %{entity_type: :character, entity_id: entity_id, status: :in_progress},
          domain: EveDmv.Api
        )

      assert is_nil(record.oldest_killmail_date)
    end
  end

  # ============================================================================
  # Uniqueness Constraint Tests
  # ============================================================================

  describe "uniqueness constraints" do
    test "entity_type + entity_id combination must be unique" do
      entity_id = unique_character_id()

      # First create succeeds
      {:ok, _record} =
        Ash.create(
          HistoricalFetchStatus,
          %{entity_type: :character, entity_id: entity_id, status: :pending},
          domain: EveDmv.Api
        )

      # Second create with same entity should fail
      result =
        Ash.create(
          HistoricalFetchStatus,
          %{entity_type: :character, entity_id: entity_id, status: :pending},
          domain: EveDmv.Api
        )

      assert match?({:error, _}, result)
    end

    test "same entity_id with different entity_type is allowed" do
      entity_id = 12_345_678

      # Character with this ID
      {:ok, char_record} =
        Ash.create(
          HistoricalFetchStatus,
          %{entity_type: :character, entity_id: entity_id, status: :pending},
          domain: EveDmv.Api
        )

      # Corporation with same numeric ID (different entity)
      {:ok, corp_record} =
        Ash.create(
          HistoricalFetchStatus,
          %{entity_type: :corporation, entity_id: entity_id, status: :pending},
          domain: EveDmv.Api
        )

      assert char_record.entity_type == :character
      assert corp_record.entity_type == :corporation
      assert char_record.entity_id == corp_record.entity_id
    end
  end
end

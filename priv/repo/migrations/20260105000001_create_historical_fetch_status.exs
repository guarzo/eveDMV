defmodule EveDmv.Repo.Migrations.CreateHistoricalFetchStatus do
  @moduledoc """
  Creates the historical_fetch_status table for tracking 2-year killmail fetch progress.

  This table supports the extended historical fetch feature that fetches up to 2 years
  of killmail data for characters, corporations, systems, and alliances.

  ## Status Flow
  - pending: Initial state, waiting to be processed
  - phase1_complete: 90-day fetch complete, ready for Phase 2
  - in_progress: Currently fetching extended history
  - completed: All historical data fetched
  - failed: Fetch failed with error

  ## Entity Types
  - character: Individual EVE characters
  - corporation: EVE corporations
  - system: Solar systems
  - alliance: EVE alliances
  """
  use Ecto.Migration

  def up do
    create table(:historical_fetch_status, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :entity_type, :string, null: false, size: 20
      add :entity_id, :bigint, null: false
      add :status, :string, null: false, default: "pending", size: 20

      # Phase tracking timestamps
      add :phase1_completed_at, :utc_datetime_usec
      add :phase2_started_at, :utc_datetime_usec
      add :phase2_completed_at, :utc_datetime_usec

      # Progress tracking
      add :oldest_killmail_date, :date
      add :target_date, :date
      add :killmails_fetched, :integer, default: 0
      add :current_page, :integer, default: 1

      # Error handling
      add :last_error, :text
      add :retry_count, :integer, default: 0
      add :last_retry_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    # Unique constraint on entity
    create unique_index(:historical_fetch_status, [:entity_type, :entity_id],
             name: :historical_fetch_status_entity_type_entity_id_index)

    # Index for looking up by status (for job processing)
    create index(:historical_fetch_status, [:status],
             name: :idx_historical_fetch_status_status)

    # Partial index for pending fetches (efficient for job queue)
    create index(:historical_fetch_status, [:status],
             where: "status IN ('pending', 'phase1_complete', 'in_progress')",
             name: :idx_historical_fetch_status_pending)

    # Check constraints for valid values
    create constraint(:historical_fetch_status, :valid_entity_type,
             check: "entity_type IN ('character', 'corporation', 'system', 'alliance')")

    create constraint(:historical_fetch_status, :valid_status,
             check: "status IN ('pending', 'phase1_complete', 'in_progress', 'completed', 'failed')")
  end

  def down do
    drop constraint(:historical_fetch_status, :valid_status)
    drop constraint(:historical_fetch_status, :valid_entity_type)
    drop index(:historical_fetch_status, [:status], name: :idx_historical_fetch_status_pending)
    drop index(:historical_fetch_status, [:status], name: :idx_historical_fetch_status_status)
    drop index(:historical_fetch_status, [:entity_type, :entity_id])
    drop table(:historical_fetch_status)
  end
end

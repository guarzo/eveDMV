defmodule EveDmv.Contexts.KillmailProcessing.Resources.HistoricalFetchStatus do
  @moduledoc """
  Tracks the status of historical killmail fetches for entities.

  Supports character, corporation, system, and alliance entities.
  Tracks both Phase 1 (90-day) and Phase 2 (2-year) fetch progress.

  ## Status Flow
  - `:pending` - Initial state, waiting to be processed
  - `:phase1_complete` - 90-day fetch complete, ready for Phase 2 (2-year fetch)
  - `:in_progress` - Currently fetching extended history
  - `:completed` - All historical data fetched
  - `:failed` - Fetch failed with error

  ## Entity Types
  - `:character` - Individual EVE characters
  - `:corporation` - EVE corporations
  - `:system` - Solar systems
  - `:alliance` - EVE alliances
  """

  use Ash.Resource,
    domain: EveDmv.Api,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("historical_fetch_status")
    repo(EveDmv.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :entity_type, :atom do
      constraints(one_of: [:character, :corporation, :system, :alliance])
      allow_nil?(false)
      public?(true)
    end

    attribute :entity_id, :integer do
      allow_nil?(false)
      public?(true)
    end

    attribute :status, :atom do
      constraints(one_of: [:pending, :phase1_complete, :in_progress, :completed, :failed])
      default(:pending)
      allow_nil?(false)
      public?(true)
    end

    attribute :phase1_completed_at, :utc_datetime_usec do
      public?(true)
    end

    attribute :phase2_started_at, :utc_datetime_usec do
      public?(true)
    end

    attribute :phase2_completed_at, :utc_datetime_usec do
      public?(true)
    end

    attribute :oldest_killmail_date, :date do
      public?(true)
    end

    attribute :target_date, :date do
      public?(true)
    end

    attribute :killmails_fetched, :integer do
      default(0)
      public?(true)
    end

    attribute :current_page, :integer do
      default(1)
      public?(true)
    end

    attribute :last_error, :string do
      public?(true)
    end

    attribute :retry_count, :integer do
      default(0)
      public?(true)
    end

    attribute :last_retry_at, :utc_datetime_usec do
      public?(true)
    end

    timestamps()
  end

  identities do
    identity(:unique_entity, [:entity_type, :entity_id])
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)
      accept([:entity_type, :entity_id, :status, :target_date])

      change(fn changeset, _context ->
        # Set target_date to 2 years ago if not provided
        if Ash.Changeset.get_attribute(changeset, :target_date) == nil do
          two_years_ago = Date.add(Date.utc_today(), -730)
          Ash.Changeset.change_attribute(changeset, :target_date, two_years_ago)
        else
          changeset
        end
      end)
    end

    update :mark_phase1_complete do
      accept([])
      require_atomic?(false)

      change(fn changeset, _context ->
        changeset
        |> Ash.Changeset.change_attribute(:status, :phase1_complete)
        |> Ash.Changeset.change_attribute(:phase1_completed_at, DateTime.utc_now())
      end)
    end

    update :start_phase2 do
      accept([])
      require_atomic?(false)

      change(fn changeset, _context ->
        changeset
        |> Ash.Changeset.change_attribute(:status, :in_progress)
        |> Ash.Changeset.change_attribute(:phase2_started_at, DateTime.utc_now())
      end)
    end

    update :update_progress do
      accept([:oldest_killmail_date, :killmails_fetched, :current_page])
    end

    update :mark_completed do
      accept([])
      require_atomic?(false)

      change(fn changeset, _context ->
        changeset
        |> Ash.Changeset.change_attribute(:status, :completed)
        |> Ash.Changeset.change_attribute(:phase2_completed_at, DateTime.utc_now())
      end)
    end

    update :mark_failed do
      accept([:last_error])
      require_atomic?(false)

      change(fn changeset, _context ->
        current_retry = Ash.Changeset.get_attribute(changeset, :retry_count) || 0

        changeset
        |> Ash.Changeset.change_attribute(:status, :failed)
        |> Ash.Changeset.change_attribute(:retry_count, current_retry + 1)
        |> Ash.Changeset.change_attribute(:last_retry_at, DateTime.utc_now())
      end)
    end

    read :get_by_entity do
      argument(:entity_type, :atom, allow_nil?: false)
      argument(:entity_id, :integer, allow_nil?: false)

      filter(expr(entity_type == ^arg(:entity_type) and entity_id == ^arg(:entity_id)))

      prepare(fn query, _context ->
        Ash.Query.limit(query, 1)
      end)
    end

    read :get_pending_fetches do
      filter(expr(status in [:pending, :phase1_complete]))

      prepare(fn query, _context ->
        Ash.Query.sort(query, inserted_at: :asc)
      end)
    end

    read :get_in_progress do
      filter(expr(status == :in_progress))
    end
  end

  calculations do
    calculate :progress_percentage, :float do
      calculation(fn records, _context ->
        Enum.map(records, fn record ->
          case record.status do
            :completed ->
              100.0

            :pending ->
              0.0

            # 90 days = ~10% of 2 years
            :phase1_complete ->
              10.0

            :in_progress ->
              if record.oldest_killmail_date && record.target_date do
                today = Date.utc_today()
                total_days = Date.diff(today, record.target_date)
                fetched_days = Date.diff(today, record.oldest_killmail_date)
                min(100.0, fetched_days / max(total_days, 1) * 100.0)
              else
                10.0
              end

            :failed ->
              0.0

            _ ->
              0.0
          end
        end)
      end)
    end
  end

  code_interface do
    domain(EveDmv.Api)

    define(:create)
    define(:get_by_entity, args: [:entity_type, :entity_id])
    define(:get_pending_fetches)
    define(:get_in_progress)
    define(:mark_phase1_complete)
    define(:start_phase2)
    define(:update_progress)
    define(:mark_completed)
    define(:mark_failed)
  end
end

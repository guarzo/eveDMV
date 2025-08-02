defmodule EveDmv.Contexts.BattleAnalysis.Resources.BattleReportComment do
  @moduledoc """
  Comments on battle reports resource.

  Enables community discussion and tactical analysis commentary
  on shared battle reports.
  """
  """

  use Ash.Resource,
    domain: EveDmv.Contexts.BattleAnalysis.Api,
    data_layer: AshPostgres.DataLayer

  resource do
    description("Comments and discussions on battle reports")
    base_filter(expr(is_nil(deleted_at)))
  end

  postgres do
    table("battle_report_comments")
    repo(EveDmv.Repo)
    base_filter_sql("deleted_at IS NULL")
  end

  attributes do
    uuid_primary_key(:id)

    attribute :battle_report_id, :uuid do
      description("Battle report being commented on")
      allow_nil?(false)
    end

    attribute :commenter_character_id, :integer do
      description("Character ID of the commenter")
      allow_nil?(false)
    end

    attribute :parent_comment_id, :uuid do
      description("Parent comment for threaded discussions")
      allow_nil?(true)
    end

    attribute :content, :string do
      description("Comment content")
      allow_nil?(false)
      constraints(max_length: 2000)
    end

    attribute :comment_type, :atom do
      description("Type of comment")
      constraints(one_of: [:general, :tactical_analysis, :question, :correction])
      default(:general)
    end

    attribute :upvotes, :integer do
      description("Number of upvotes")
      default(0)
    end

    attribute :downvotes, :integer do
      description("Number of downvotes")
      default(0)
    end

    attribute :tactical_timestamp, :integer do
      description("Related timestamp in battle (seconds)")
      allow_nil?(true)
    end

    attribute :verified_participant, :boolean do
      description("Whether commenter participated in the battle")
      default(false)
    end

    attribute :deleted_at, :utc_datetime do
      description("Soft delete timestamp")
      allow_nil?(true)
    end

    timestamps()
  end

  relationships do
    belongs_to :battle_report, EveDmv.Contexts.BattleAnalysis.Resources.BattleReport do
      source_attribute(:battle_report_id)
      destination_attribute(:id)
    end

    belongs_to :parent_comment, __MODULE__ do
      source_attribute(:parent_comment_id)
      destination_attribute(:id)
    end

    has_many :replies, __MODULE__ do
      destination_attribute(:parent_comment_id)
    end
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)

      accept([
        :battle_report_id,
        :commenter_character_id,
        :parent_comment_id,
        :content,
        :comment_type,
        :tactical_timestamp,
        :verified_participant
      ])
    end

    update :upvote do
      accept([])
      require_atomic?(false)

      change(fn changeset, _context ->
        current_upvotes = Ash.Changeset.get_attribute(changeset, :upvotes) || 0
        Ash.Changeset.change_attribute(changeset, :upvotes, current_upvotes + 1)
      end)
    end

    update :downvote do
      accept([])
      require_atomic?(false)

      change(fn changeset, _context ->
        current_downvotes = Ash.Changeset.get_attribute(changeset, :downvotes) || 0
        Ash.Changeset.change_attribute(changeset, :downvotes, current_downvotes + 1)
      end)
    end

    update :soft_delete do
      accept([])
      require_atomic?(false)

      change(fn changeset, _context ->
        Ash.Changeset.change_attribute(changeset, :deleted_at, DateTime.utc_now())
      end)
    end
  end

  validations do
    validate(present([:battle_report_id, :commenter_character_id, :content]))
  end

  code_interface do
    define(:create)
    define(:upvote)
    define(:downvote)
    define(:soft_delete)
    define(:read)
    define(:destroy)
  end
end

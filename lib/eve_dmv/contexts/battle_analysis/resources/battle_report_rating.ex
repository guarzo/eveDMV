defmodule EveDmv.Contexts.BattleAnalysis.Resources.BattleReportRating do
  @moduledoc """
  Individual battle report rating resource.

  Stores detailed ratings and reviews for battle reports, enabling
  sophisticated community feedback and curation systems.
  """
  """

  use Ash.Resource,
    domain: EveDmv.Contexts.BattleAnalysis.Api,
    data_layer: AshPostgres.DataLayer

  resource do
    description("Individual ratings for battle reports")
  end

  postgres do
    table("battle_report_ratings")
    repo(EveDmv.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :battle_report_id, :uuid do
      description("Battle report being rated")
      allow_nil?(false)
    end

    attribute :rater_character_id, :integer do
      description("Character ID of the rater")
      allow_nil?(false)
    end

    attribute :overall_rating, :decimal do
      description("Overall rating (1-10)")
      allow_nil?(false)
      constraints(min: 1.0, max: 10.0)
    end

    attribute :category_ratings, :map do
      description("Detailed category ratings")
      default(%{})
    end

    attribute :comment, :string do
      description("Rating comment/review")
      allow_nil?(true)
      constraints(max_length: 1000)
    end

    attribute :helpful_votes, :integer do
      description("Number of helpful votes")
      default(0)
    end

    attribute :verified_participant, :boolean do
      description("Whether rater participated in the battle")
      default(false)
    end

    timestamps()
  end

  relationships do
    belongs_to :battle_report, EveDmv.Contexts.BattleAnalysis.Resources.BattleReport do
      source_attribute(:battle_report_id)
      destination_attribute(:id)
    end
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)

      accept([
        :battle_report_id,
        :rater_character_id,
        :overall_rating,
        :category_ratings,
        :comment,
        :verified_participant
      ])
    end

    update :vote_helpful do
      accept([])
      require_atomic?(false)

      change(fn changeset, _context ->
        current_votes = Ash.Changeset.get_attribute(changeset, :helpful_votes) || 0
        Ash.Changeset.change_attribute(changeset, :helpful_votes, current_votes + 1)
      end)
    end
  end

  identities do
    identity(:unique_rater_per_report, [:battle_report_id, :rater_character_id])
  end

  validations do
    validate(present([:battle_report_id, :rater_character_id, :overall_rating]))
  end

  code_interface do
    define(:create)
    define(:vote_helpful)
    define(:read)
    define(:destroy)
  end
end

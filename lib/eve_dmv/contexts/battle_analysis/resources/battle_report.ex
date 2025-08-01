defmodule EveDmv.Contexts.BattleAnalysis.Resources.BattleReport do
  @moduledoc """
  Community-shareable battle report resource.

  Battle reports are community-created content that enhance battles with:
  - Custom titles and descriptions
  - Video integration (YouTube, Twitch)
  - Tactical highlights and annotations
  - Community ratings and feedback
  - Educational content and analysis
  """

  use Ash.Resource,
    domain: EveDmv.Contexts.BattleAnalysis.Api,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource]

  resource do
    description("Community battle reports with ratings and highlights")
    base_filter(expr(is_nil(deleted_at)))
  end

  postgres do
    table("battle_reports")
    repo(EveDmv.Repo)
    base_filter_sql("deleted_at IS NULL")
  end

  json_api do
    type("battle_report")

    routes do
      base("/battle_reports")
      get(:read)
      index(:read)
      post(:create)
      patch(:update)
      delete(:destroy)
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :battle_id, :uuid do
      description("Reference to the battle this report covers")
      allow_nil?(false)
    end

    attribute :creator_character_id, :integer do
      description("Character ID of the report creator")
      allow_nil?(false)
    end

    attribute :title, :string do
      description("Report title")
      allow_nil?(false)
      constraints(max_length: 200)
    end

    attribute :description, :string do
      description("Report description")
      allow_nil?(true)
      constraints(max_length: 2000)
    end

    attribute :visibility, :atom do
      description("Report visibility setting")
      constraints(one_of: [:public, :unlisted, :private])
      default(:public)
    end

    attribute :tags, {:array, :string} do
      description("Report tags for categorization")
      default([])
    end

    attribute :video_links, {:array, :map} do
      description("Associated video links with metadata")
      default([])
    end

    attribute :tactical_highlights, {:array, :map} do
      description("Timestamped tactical highlights")
      default([])
    end

    attribute :auto_analysis, :map do
      description("Automated analysis data")
      default(%{})
    end

    attribute :community_ratings, {:array, :map} do
      description("Community ratings and reviews")
      default([])
    end

    attribute :average_rating, :decimal do
      description("Average community rating")
      default(0.0)
      constraints(min: 0.0, max: 10.0)
    end

    attribute :total_ratings, :integer do
      description("Total number of ratings")
      default(0)
    end

    attribute :view_count, :integer do
      description("Number of times viewed")
      default(0)
    end

    attribute :share_count, :integer do
      description("Number of times shared")
      default(0)
    end

    attribute :bookmark_count, :integer do
      description("Number of bookmarks")
      default(0)
    end

    attribute :featured_score, :decimal do
      description("Calculated featured score for curation")
      default(0.0)
    end

    attribute :allow_comments, :boolean do
      description("Allow community comments")
      default(true)
    end

    attribute :allow_ratings, :boolean do
      description("Allow community ratings")
      default(true)
    end

    attribute :deleted_at, :utc_datetime do
      description("Soft delete timestamp")
      allow_nil?(true)
    end

    timestamps()
  end

  relationships do
    belongs_to :battle, EveDmv.Contexts.BattleAnalysis.Resources.Battle do
      source_attribute(:battle_id)
      destination_attribute(:id)
    end

    has_many :comments, EveDmv.Contexts.BattleAnalysis.Resources.BattleReportComment do
      destination_attribute(:battle_report_id)
    end

    has_many :ratings, EveDmv.Contexts.BattleAnalysis.Resources.BattleReportRating do
      destination_attribute(:battle_report_id)
    end
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)

      accept([
        :battle_id,
        :creator_character_id,
        :title,
        :description,
        :visibility,
        :tags,
        :video_links,
        :tactical_highlights,
        :auto_analysis,
        :allow_comments,
        :allow_ratings
      ])
    end

    update :update do
      primary?(true)

      accept([
        :title,
        :description,
        :visibility,
        :tags,
        :video_links,
        :tactical_highlights,
        :allow_comments,
        :allow_ratings
      ])
    end

    update :add_rating do
      accept([])
      require_atomic?(false)

      argument :rating_score, :decimal do
        allow_nil?(false)
        constraints(min: 1.0, max: 10.0)
      end

      argument :rater_character_id, :integer do
        allow_nil?(false)
      end

      argument :comment, :string do
        allow_nil?(true)
        constraints(max_length: 500)
      end

      argument :categories, :map do
        allow_nil?(true)
      end

      change(fn changeset, %{arguments: args} ->
        # Add the rating to community_ratings array
        current_ratings = Ash.Changeset.get_attribute(changeset, :community_ratings) || []

        new_rating = %{
          rating_id: generate_rating_id(),
          rater_character_id: args.rater_character_id,
          rating_score: args.rating_score,
          comment: args.comment,
          categories: args.categories || %{},
          rated_at: DateTime.utc_now()
        }

        updated_ratings = [new_rating | current_ratings]

        # Recalculate averages
        total_count = length(updated_ratings)
        total_score = Enum.reduce(updated_ratings, 0, &(&1.rating_score + &2))
        new_average = if total_count > 0, do: total_score / total_count, else: 0.0

        changeset
        |> Ash.Changeset.change_attribute(:community_ratings, updated_ratings)
        |> Ash.Changeset.change_attribute(:total_ratings, total_count)
        |> Ash.Changeset.change_attribute(:average_rating, Decimal.new(new_average))
        |> recalculate_featured_score()
      end)
    end

    update :add_tactical_highlight do
      accept([])
      require_atomic?(false)

      argument :highlight_data, :map do
        allow_nil?(false)
      end

      argument :creator_character_id, :integer do
        allow_nil?(false)
      end

      change(fn changeset, %{arguments: args} ->
        current_highlights = Ash.Changeset.get_attribute(changeset, :tactical_highlights) || []

        new_highlight =
          Map.merge(args.highlight_data, %{
            highlight_id: generate_highlight_id(),
            creator_character_id: args.creator_character_id,
            created_at: DateTime.utc_now()
          })

        updated_highlights = [new_highlight | current_highlights]

        Ash.Changeset.change_attribute(changeset, :tactical_highlights, updated_highlights)
      end)
    end

    update :increment_views do
      accept([])
      require_atomic?(false)

      change(fn changeset, _context ->
        current_views = Ash.Changeset.get_attribute(changeset, :view_count) || 0
        Ash.Changeset.change_attribute(changeset, :view_count, current_views + 1)
      end)
    end
  end

  preparations do
    prepare(build(load: [:battle]))
  end

  validations do
    validate(
      present([:battle_id, :creator_character_id, :title], message: "Required fields missing")
    )
  end

  code_interface do
    define(:create)
    define(:update)
    define(:add_rating)
    define(:add_tactical_highlight)
    define(:increment_views)
    define(:read)
    define(:destroy)
  end

  # Helper functions

  defp generate_rating_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16()
  end

  defp generate_highlight_id do
    :crypto.strong_rand_bytes(12) |> Base.encode16(case: :lower)
  end

  defp recalculate_featured_score(changeset) do
    average_rating = Ash.Changeset.get_attribute(changeset, :average_rating) || Decimal.new(0)
    total_ratings = Ash.Changeset.get_attribute(changeset, :total_ratings) || 0
    view_count = Ash.Changeset.get_attribute(changeset, :view_count) || 0

    # Calculate featured score based on rating, popularity, and engagement
    base_score = Decimal.to_float(average_rating) / 10.0
    popularity_factor = min(0.3, :math.log(total_ratings + 1) / :math.log(50))
    engagement_factor = min(0.2, :math.log(view_count + 1) / :math.log(1000))

    featured_score = base_score * 0.6 + popularity_factor + engagement_factor
    final_score = min(1.0, featured_score)

    Ash.Changeset.change_attribute(changeset, :featured_score, Decimal.new(final_score))
  end
end

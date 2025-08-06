defmodule EveDmv.Contexts.Corporation.Resources.RecruitmentApplication do
  @moduledoc """
  Ash resource for recruitment application data.

  Represents applications submitted to corporations for membership,
  including application status, review data, and processing history.
  """

  use Ash.Resource,
    domain: EveDmv.Api,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("recruitment_applications")
    repo(EveDmv.Repo)

    identity_index_names(
      unique_character_application_per_corp: "recruitment_apps_unique_char_corp_idx"
    )
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([
        :corporation_id,
        :character_id,
        :character_name,
        :application_text,
        :previous_corporations,
        :skill_points,
        :timezone,
        :playtime_hours,
        :referrer,
        :status
      ])

      validate(present([:corporation_id, :character_id, :character_name, :application_text]))
      validate(attribute_does_not_equal(:corporation_id, 0))
      validate(attribute_does_not_equal(:character_id, 0))

      change(set_attribute(:status, :pending))
      change(set_attribute(:submitted_at, &DateTime.utc_now/0))
    end

    update :update do
      accept([
        :status,
        :reviewer_notes,
        :background_check_results,
        :interview_notes,
        :recommendation,
        :processed_by,
        :processed_at
      ])
    end

    update :approve do
      accept([:reviewer_notes, :processed_by])

      change(set_attribute(:status, :approved))
      change(set_attribute(:processed_at, &DateTime.utc_now/0))
    end

    update :reject do
      accept([:reviewer_notes, :processed_by, :rejection_reason])

      change(set_attribute(:status, :rejected))
      change(set_attribute(:processed_at, &DateTime.utc_now/0))
    end

    update :request_interview do
      accept([:reviewer_notes, :processed_by])

      change(set_attribute(:status, :interview_requested))
      change(set_attribute(:processed_at, &DateTime.utc_now/0))
    end

    read :by_corporation do
      argument(:corporation_id, :integer, allow_nil?: false)
      filter(expr(corporation_id == ^arg(:corporation_id)))
    end

    read :by_character do
      argument(:character_id, :integer, allow_nil?: false)
      filter(expr(character_id == ^arg(:character_id)))
    end

    read :by_status do
      argument(:corporation_id, :integer, allow_nil?: false)
      argument(:status, :atom, allow_nil?: false)

      filter(
        expr(
          corporation_id == ^arg(:corporation_id) and
            status == ^arg(:status)
        )
      )
    end

    read :pending_review do
      argument(:corporation_id, :integer, allow_nil?: false)

      filter(
        expr(
          corporation_id == ^arg(:corporation_id) and
            status in [:pending, :under_review]
        )
      )
    end

    read :recent_applications do
      argument(:corporation_id, :integer, allow_nil?: false)
      argument(:days_threshold, :integer, default: 30)

      filter(
        expr(
          corporation_id == ^arg(:corporation_id) and
            submitted_at > ago(^arg(:days_threshold), :day)
        )
      )
    end
  end

  attributes do
    integer_primary_key(:id)

    attribute :corporation_id, :integer do
      allow_nil?(false)
      constraints(min: 1)
    end

    attribute :character_id, :integer do
      allow_nil?(false)
      constraints(min: 1)
    end

    attribute :character_name, :string do
      allow_nil?(false)
      constraints(min_length: 1, max_length: 255)
    end

    attribute :application_text, :string do
      allow_nil?(false)
      constraints(min_length: 10, max_length: 5000)
    end

    attribute :previous_corporations, {:array, :map} do
      default([])
    end

    attribute :skill_points, :integer do
      constraints(min: 0)
    end

    attribute :timezone, :string do
      constraints(max_length: 50)
    end

    attribute :playtime_hours, :integer do
      # Max hours per week
      constraints(min: 0, max: 168)
    end

    attribute :referrer, :string do
      constraints(max_length: 255)
    end

    # Application processing
    attribute :status, :atom do
      constraints(
        one_of: [
          :pending,
          :under_review,
          :interview_requested,
          :interviewing,
          :approved,
          :rejected,
          :withdrawn,
          :expired
        ]
      )

      default(:pending)
    end

    attribute :submitted_at, :utc_datetime do
      default(&DateTime.utc_now/0)
    end

    attribute(:processed_at, :utc_datetime)
    attribute(:processed_by, :string)

    # Review data
    attribute :reviewer_notes, :string do
      constraints(max_length: 2000)
    end

    attribute :background_check_results, :map do
      default(%{})
    end

    attribute :interview_notes, :string do
      constraints(max_length: 2000)
    end

    attribute :recommendation, :atom do
      constraints(
        one_of: [
          :strongly_recommend,
          :recommend,
          :conditional_recommend,
          :not_recommend,
          :strongly_reject
        ]
      )
    end

    attribute :rejection_reason, :string do
      constraints(max_length: 500)
    end

    # Scoring and assessment
    attribute :application_score, :decimal do
      default(0.0)
      constraints(min: 0.0, max: 100.0)
    end

    attribute :background_score, :decimal do
      default(0.0)
      constraints(min: 0.0, max: 100.0)
    end

    attribute :compatibility_score, :decimal do
      default(0.0)
      constraints(min: 0.0, max: 100.0)
    end

    attribute :interview_score, :decimal do
      constraints(min: 0.0, max: 100.0)
    end

    timestamps()
  end

  relationships do
    belongs_to :corporation, EveDmv.Contexts.Corporation.Resources.Corporation do
      source_attribute(:corporation_id)
      destination_attribute(:corporation_id)
    end
  end

  calculations do
    calculate(
      :days_since_submitted,
      :integer,
      expr(
        if(is_nil(submitted_at),
          do: 0,
          else: date_part("day", now() - submitted_at)
        )
      )
    )

    calculate(
      :processing_time_days,
      :integer,
      expr(
        if(is_nil(processed_at) or is_nil(submitted_at),
          do: nil,
          else: date_part("day", processed_at - submitted_at)
        )
      )
    )

    calculate(
      :is_overdue,
      :boolean,
      expr(
        status in [:pending, :under_review, :interview_requested] and
          submitted_at < ago(7, :day)
      )
    )

    calculate(
      :needs_attention,
      :boolean,
      expr(
        status in [:pending, :under_review] and
          submitted_at < ago(3, :day)
      )
    )

    calculate(
      :overall_score,
      :decimal,
      expr(
        application_score * 0.3 +
          background_score * 0.4 +
          compatibility_score * 0.3
      )
    )

    calculate(
      :application_quality,
      :atom,
      expr(
        cond do
          length(application_text) >= 500 -> :detailed
          length(application_text) >= 200 -> :adequate
          length(application_text) >= 100 -> :brief
          true -> :minimal
        end
      )
    )

    calculate(
      :experience_level,
      :atom,
      expr(
        cond do
          is_nil(skill_points) -> :unknown
          skill_points >= 50_000_000 -> :veteran
          skill_points >= 20_000_000 -> :experienced
          skill_points >= 5_000_000 -> :intermediate
          true -> :newbie
        end
      )
    )

    calculate(
      :status_category,
      :atom,
      expr(
        cond do
          status in [:pending, :under_review] -> :in_process
          status in [:interview_requested, :interviewing] -> :interviewing
          status in [:approved] -> :approved
          status in [:rejected, :withdrawn, :expired] -> :closed
          true -> :unknown
        end
      )
    )
  end

  validations do
    validate present([:corporation_id, :character_id, :character_name, :application_text]) do
      message("Corporation ID, character ID, character name, and application text are required")
    end

    validate string_length(:application_text, min: 10, max: 5000) do
      message("Application text must be between 10 and 5000 characters")
    end

    validate numericality(:skill_points, greater_than_or_equal_to: 0) do
      message("Skill points cannot be negative")
      where([present(:skill_points)])
    end

    validate numericality(:playtime_hours,
               greater_than_or_equal_to: 0,
               less_than_or_equal_to: 168
             ) do
      message("Playtime hours must be between 0 and 168 (hours per week)")
      where([present(:playtime_hours)])
    end

    validate compare(:processed_at, greater_than_or_equal_to: :submitted_at) do
      message("Processing date cannot be before submission date")
      where([present([:processed_at, :submitted_at])])
    end

    validate present([:processed_by]) do
      message("Processed by is required when application is processed")
      where([present(:processed_at)])
    end

    validate present([:rejection_reason]) do
      message("Rejection reason is required for rejected applications")
      where([attribute_equals(:status, :rejected)])
    end
  end

  identities do
    identity(:unique_character_application_per_corp, [:corporation_id, :character_id],
      where: expr(status not in [:rejected, :withdrawn, :expired])
    )
  end

  code_interface do
    define(:submit_application, action: :create)
    define(:update_application, action: :update)
    define(:approve_application, action: :approve)
    define(:reject_application, action: :reject)
    define(:request_interview, action: :request_interview)
    define(:list_by_corporation, action: :by_corporation, args: [:corporation_id])
    define(:list_by_character, action: :by_character, args: [:character_id])
    define(:list_pending_review, action: :pending_review, args: [:corporation_id])
    define(:list_recent_applications, action: :recent_applications, args: [:corporation_id])
  end
end

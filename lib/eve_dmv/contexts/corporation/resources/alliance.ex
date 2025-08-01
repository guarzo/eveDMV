defmodule EveDmv.Contexts.Corporation.Resources.Alliance do
  @moduledoc """
  Ash resource for alliance data.

  Represents alliances that contain multiple corporations.
  """

  use Ash.Resource,
    domain: EveDmv.Api,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("alliances")
    repo(EveDmv.Repo)
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([
        :alliance_id,
        :alliance_name,
        :ticker,
        :executor_corporation_id,
        :founded_date,
        :member_count
      ])

      validate(present([:alliance_id, :alliance_name]))
      validate(attribute_does_not_equal(:alliance_id, 0))
    end

    update :update do
      accept([
        :alliance_name,
        :ticker,
        :executor_corporation_id,
        :founded_date,
        :member_count
      ])
    end

    read :by_alliance_id do
      argument(:alliance_id, :integer, allow_nil?: false)
      filter(expr(alliance_id == ^arg(:alliance_id)))
    end

    read :search do
      argument(:name_search, :string)
      argument(:ticker_search, :string)

      filter(
        expr(
          if(not is_nil(^arg(:name_search)),
            do: contains(alliance_name, ^arg(:name_search)),
            else: true
          ) and
            if(not is_nil(^arg(:ticker_search)),
              do: contains(ticker, ^arg(:ticker_search)),
              else: true
            )
        )
      )
    end
  end

  attributes do
    integer_primary_key(:id)

    attribute :alliance_id, :integer do
      allow_nil?(false)
      constraints(min: 1)
    end

    attribute :alliance_name, :string do
      allow_nil?(false)
      constraints(min_length: 1, max_length: 255)
    end

    attribute :ticker, :string do
      constraints(min_length: 1, max_length: 5)
    end

    attribute :executor_corporation_id, :integer do
      constraints(min: 1)
    end

    attribute(:founded_date, :date)

    attribute :member_count, :integer do
      default(0)
      constraints(min: 0)
    end

    timestamps()
  end

  relationships do
    has_many :corporations, EveDmv.Contexts.Corporation.Resources.Corporation do
      source_attribute(:alliance_id)
      destination_attribute(:alliance_id)
    end
  end

  calculations do
    calculate(:corporation_count, :integer, expr(count(corporations)))

    calculate(:total_members, :integer, expr(sum(corporations, field: :member_count)))
  end

  aggregates do
    count(:total_corporation_count, :corporations)

    sum(:total_member_count, :corporations, :member_count)

    max(:largest_corporation_size, :corporations, :member_count)

    avg :average_corporation_size, :corporations, :member_count do
      filter(expr(member_count > 0))
    end
  end

  validations do
    validate present([:alliance_name]) do
      message("Alliance name is required")
    end

    validate match(:ticker, ~r/^[A-Z0-9]{1,5}$/) do
      message("Ticker must be 1-5 uppercase alphanumeric characters")
      where([present(:ticker)])
    end
  end

  identities do
    identity(:unique_alliance_id, [:alliance_id])
  end

  code_interface do
    define(:create_alliance, action: :create)
    define(:update_alliance, action: :update)
    define(:get_by_alliance_id, action: :by_alliance_id, args: [:alliance_id])
    define(:search_alliances, action: :search)
    define(:list_all, action: :read)
  end
end

defmodule EveDmv.Contexts.Combat.Resources.BattleKillmail do
  @moduledoc """
  Junction table linking battles to killmails.

  Many-to-many relationship between battles and killmails.
  """

  use Ash.Resource,
    domain: EveDmv.Contexts.BattleAnalysis.Api,
    data_layer: AshPostgres.DataLayer

  resource do
    description("Junction table linking battles to killmails")
  end

  postgres do
    table("battle_killmails")
    repo(EveDmv.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :battle_id, :uuid do
      description("Reference to battle")
      allow_nil?(false)
    end

    attribute :killmail_id, :integer do
      description("Reference to killmail")
      allow_nil?(false)
    end

    attribute :added_at, :utc_datetime do
      description("When this killmail was added to the battle")
      allow_nil?(false)
      default(&DateTime.utc_now/0)
    end

    timestamps()
  end

  relationships do
    belongs_to :battle, EveDmv.Contexts.BattleAnalysis.Resources.Battle do
      source_attribute(:battle_id)
      destination_attribute(:id)
    end

    belongs_to :killmail, EveDmv.Killmails.KillmailRaw do
      source_attribute(:killmail_id)
      destination_attribute(:killmail_id)
    end
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)
      accept([:battle_id, :killmail_id])
    end
  end

  identities do
    identity(:unique_battle_killmail, [:battle_id, :killmail_id])
  end

  validations do
    validate(
      present([:battle_id, :killmail_id], message: "Battle ID and Killmail ID are required")
    )
  end

  code_interface do
    define(:create)
    define(:read)
    define(:destroy)
  end
end

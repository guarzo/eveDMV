defmodule EveDmv.Contexts.Combat.Resources.Battle do
  @moduledoc """
  Battle resource for persistent battle storage.

  Links killmails together into battles for analysis and tracking.
  """

  use Ash.Resource,
    domain: EveDmv.Contexts.Combat.Api,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource]

  resource do
    description("Persistent battle entities that group related killmails")
    base_filter(expr(is_nil(deleted_at)))
  end

  postgres do
    table("battles")
    repo(EveDmv.Repo)
    base_filter_sql("deleted_at IS NULL")
  end

  json_api do
    type("battle")

    routes do
      base("/battles")
      get(:read)
      index(:read)
      post(:create)
      patch(:update)
      delete(:destroy)
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :battle_id, :string do
      description("Unique deterministic battle identifier")
      allow_nil?(false)
    end

    attribute :system_id, :integer do
      description("Primary solar system where battle occurred")
      allow_nil?(true)
    end

    attribute :constellation_id, :integer do
      description("Constellation where battle occurred")
      allow_nil?(true)
    end

    attribute :region_id, :integer do
      description("Region where battle occurred")
      allow_nil?(true)
    end

    attribute :start_time, :utc_datetime do
      description("When the battle started")
      allow_nil?(true)
    end

    attribute :end_time, :utc_datetime do
      description("When the battle ended")
      allow_nil?(true)
    end

    attribute :participant_count, :integer do
      description("Number of unique participants")
      allow_nil?(true)
      default(0)
    end

    attribute :total_isk_destroyed, :integer do
      description("Total ISK value destroyed in battle")
      allow_nil?(true)
      default(0)
    end

    attribute :battle_type, :atom do
      description("Type of battle (single_kill, small_gang, etc.)")
      constraints(one_of: [:single_kill, :small_gang, :medium_gang, :large_gang, :fleet_battle])
      allow_nil?(true)
    end

    attribute :metadata, :map do
      description("Additional battle metadata and analysis")
      allow_nil?(true)
      default(%{})
    end

    attribute :deleted_at, :utc_datetime do
      description("Soft delete timestamp")
      allow_nil?(true)
    end

    timestamps()
  end

  relationships do
    many_to_many :killmails, EveDmv.Killmails.KillmailRaw do
      through(EveDmv.Contexts.BattleAnalysis.Resources.BattleKillmail)
      source_attribute_on_join_resource(:battle_id)
      destination_attribute_on_join_resource(:killmail_id)
      destination_attribute(:killmail_id)
    end

    has_many :combat_logs, EveDmv.Contexts.BattleAnalysis.Resources.CombatLog do
      destination_attribute(:battle_id)
    end
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)

      accept([
        :battle_id,
        :system_id,
        :constellation_id,
        :region_id,
        :start_time,
        :end_time,
        :participant_count,
        :total_isk_destroyed,
        :battle_type,
        :metadata
      ])

      # battle_id uniqueness enforced by identity constraint
    end

    update :update do
      primary?(true)

      accept([
        :system_id,
        :constellation_id,
        :region_id,
        :start_time,
        :end_time,
        :participant_count,
        :total_isk_destroyed,
        :battle_type,
        :metadata
      ])
    end
  end

  identities do
    identity(:unique_battle_id, [:battle_id])
  end

  validations do
    validate(present([:battle_id], message: "Battle ID is required"))
  end

  code_interface do
    define(:create)
    define(:update)
    define(:read)
    define(:destroy)
  end
end

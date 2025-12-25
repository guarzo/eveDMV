defmodule EveDmv.Repo.Migrations.AddSdeBuildNumber do
  @moduledoc """
  Adds sde_build_number field to eve_item_types and eve_solar_systems tables.

  This field stores the CCP SDE build number (e.g., 3142455) as an integer,
  enabling simpler version comparison compared to parsing version strings.

  Part of Phase 5 of the SDE Data Source Migration Plan.
  """
  use Ecto.Migration

  def change do
    # Add sde_build_number to eve_item_types
    alter table(:eve_item_types) do
      add_if_not_exists :sde_build_number, :bigint, null: true
    end

    # Add sde_build_number to eve_solar_systems
    alter table(:eve_solar_systems) do
      add_if_not_exists :sde_build_number, :bigint, null: true
    end

    # Create indexes for efficient version queries
    create_if_not_exists index(:eve_item_types, [:sde_build_number],
      name: :eve_item_types_sde_build_number_idx
    )

    create_if_not_exists index(:eve_solar_systems, [:sde_build_number],
      name: :eve_solar_systems_sde_build_number_idx
    )
  end
end

defmodule EveDmv.Repo.Migrations.RemoveDuplicateIndexes do
  @moduledoc """
  Removes duplicate indexes identified in the performance remediation plan (Track D).

  The following indexes are duplicates that waste disk space and slow down writes:
  - idx_solar_systems_constellation_idx: Duplicate of idx_solar_systems_constellation
  - idx_solar_systems_region_idx: Duplicate of idx_solar_systems_region

  See docs/PERFORMANCE_REMEDIATION_PLAN.md for details.
  """

  use Ecto.Migration

  def change do
    # Duplicate of idx_solar_systems_constellation
    drop_if_exists(
      index(:eve_solar_systems, [:constellation_id], name: :idx_solar_systems_constellation_idx)
    )

    # Duplicate of idx_solar_systems_region
    drop_if_exists(index(:eve_solar_systems, [:region_id], name: :idx_solar_systems_region_idx))
  end
end

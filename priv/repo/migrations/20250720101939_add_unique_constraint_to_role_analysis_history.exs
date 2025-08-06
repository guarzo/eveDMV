defmodule EveDmv.Repo.Migrations.AddUniqueConstraintToRoleAnalysisHistory do
  use Ecto.Migration

  def change do
    # Drop the existing regular index
    drop_if_exists index(:role_analysis_history, [:ship_type_id, :analysis_date])

    # Add unique constraint for ship_type_id + analysis_date combination
    # This allows ON CONFLICT to work properly in ShipRoleAnalysisWorker
    create unique_index(:role_analysis_history, [:ship_type_id, :analysis_date])
  end
end

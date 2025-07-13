defmodule EveDmv.Repo.Migrations.AddRoleAnalysisHistoryUniqueConstraint do
  use Ecto.Migration

  def up do
    # Add unique constraint to prevent duplicate entries per ship per day
    create unique_index(:role_analysis_history, [:ship_type_id, :analysis_date], 
                        name: "role_analysis_history_ship_date_unique_idx")
  end

  def down do
    drop_if_exists unique_index(:role_analysis_history, [:ship_type_id, :analysis_date], 
                                name: "role_analysis_history_ship_date_unique_idx")
  end
end
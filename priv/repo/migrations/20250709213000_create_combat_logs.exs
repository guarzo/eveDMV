defmodule EveDmv.Repo.Migrations.CreateCombatLogs do
  use Ecto.Migration

  def change do
    create table(:combat_logs, primary_key: false) do
      add :id, :uuid, primary_key: true
      
      # Metadata
      add :pilot_name, :string, null: false
      add :uploaded_at, :utc_datetime_usec, null: false
      add :file_name, :string
      add :file_size, :integer
      
      # Time range
      add :start_time, :utc_datetime_usec
      add :end_time, :utc_datetime_usec
      
      # Raw content (compressed)
      add :raw_content, :text, null: false
      add :content_hash, :string, null: false
      
      # Parsed data
      add :parsed_data, :map, default: %{}
      add :event_count, :integer, default: 0
      add :parse_status, :string, default: "pending"
      add :parse_error, :text
      
      # Analysis results
      add :summary, :map, default: %{}
      add :performance_metrics, :map, default: %{}
      
      # Associated battle
      add :battle_id, :string
      add :battle_correlation, :map, default: %{}
      
      timestamps()
    end
    
    # Indexes
    create index(:combat_logs, [:pilot_name])
    create index(:combat_logs, [:battle_id])
    create index(:combat_logs, [:content_hash])
    create index(:combat_logs, [:uploaded_at])
    create index(:combat_logs, [:parse_status])
  end
end
defmodule EveDmv.Repo.Migrations.AddShipRolePatternTables do
  use Ecto.Migration

  def up do
    # Ship role patterns table for dynamic role analysis
    create table(:ship_role_patterns, primary_key: false) do
      add :ship_type_id, :integer, primary_key: true, null: false
      add :ship_name, :string, size: 100
      add :primary_role, :string, size: 50
      add :role_distribution, :map, default: %{}
      add :confidence_score, :decimal, precision: 3, scale: 2
      add :sample_size, :integer, default: 0
      add :last_analyzed, :utc_datetime
      add :meta_trend, :string, size: 20
      
      # Reference data from ship_info.md
      add :reference_role, :string, size: 50
      add :typical_doctrines, {:array, :text}, default: []
      add :tactical_notes, :text
      
      timestamps()
    end

    # Doctrine patterns table for fleet composition analysis
    create table(:doctrine_patterns, primary_key: false) do
      add :id, :serial, primary_key: true
      add :doctrine_name, :string, size: 100, null: false
      add :ship_composition, :map, default: %{} # Type IDs and typical counts
      add :tank_type, :string, size: 20 # shield/armor/hull
      add :engagement_range, :string, size: 20 # close/medium/long/extreme
      add :tactical_role, :string, size: 50 # brawler/sniper/kiter/alpha
      add :reference_source, :string, size: 50 # ship_info.md, detected, etc.
      
      timestamps()
    end

    # Role analysis history for tracking changes over time
    create table(:role_analysis_history, primary_key: false) do
      add :id, :serial, primary_key: true
      add :ship_type_id, :integer, null: false
      add :analysis_date, :date, null: false
      add :role_distribution, :map, default: %{}
      add :meta_indicators, :map, default: %{}
      
      timestamps()
    end

    # Indexes for performance
    create index(:ship_role_patterns, [:ship_type_id])
    create index(:ship_role_patterns, [:primary_role])
    create index(:ship_role_patterns, [:last_analyzed])
    create index(:ship_role_patterns, [:reference_role])
    
    create index(:doctrine_patterns, [:doctrine_name])
    create index(:doctrine_patterns, [:tank_type])
    create index(:doctrine_patterns, [:tactical_role])
    create index(:doctrine_patterns, [:reference_source])
    
    create index(:role_analysis_history, [:ship_type_id])
    create index(:role_analysis_history, [:analysis_date])
    create index(:role_analysis_history, [:ship_type_id, :analysis_date])
    
    # Foreign key constraints to eve_item_types (skip for now - will add via alter if needed)
    # Note: Foreign keys to eve_item_types may cause issues if static data not loaded
  end

  def down do
    
    drop index(:role_analysis_history, [:ship_type_id, :analysis_date])
    drop index(:role_analysis_history, [:analysis_date])
    drop index(:role_analysis_history, [:ship_type_id])
    
    drop index(:doctrine_patterns, [:reference_source])
    drop index(:doctrine_patterns, [:tactical_role])
    drop index(:doctrine_patterns, [:tank_type])
    drop index(:doctrine_patterns, [:doctrine_name])
    
    drop index(:ship_role_patterns, [:reference_role])
    drop index(:ship_role_patterns, [:last_analyzed])
    drop index(:ship_role_patterns, [:primary_role])
    drop index(:ship_role_patterns, [:ship_type_id])
    
    drop table(:role_analysis_history)
    drop table(:doctrine_patterns)
    drop table(:ship_role_patterns)
  end
end
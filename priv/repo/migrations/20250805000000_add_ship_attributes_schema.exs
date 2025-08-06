defmodule EveDmv.Repo.Migrations.AddShipAttributesSchema do
  @moduledoc """
  Sprint 1: Add ship attributes schema for real DPS/EHP calculations.
  
  This migration extends the EVE ship data with dogma attributes needed
  for accurate fleet analysis without hardcoded values.
  """

  use Ecto.Migration

  def up do
    # Extend eve_item_types table with basic ship attributes
    alter table(:eve_item_types) do
      add :base_hp, :bigint, comment: "Total base hit points (shield + armor + structure)"
      add :base_capacitor, :bigint, comment: "Base capacitor amount"
      add :base_damage, :decimal, precision: 10, scale: 2, comment: "Estimated base DPS"
      add :base_speed, :decimal, precision: 10, scale: 2, comment: "Maximum velocity in m/s"
      add :sig_radius, :decimal, precision: 10, scale: 2, comment: "Signature radius in meters"
      add :scan_resolution, :decimal, precision: 10, scale: 2, comment: "Scan resolution for targeting"
      add :max_targets, :integer, comment: "Maximum locked targets"
    end

    # Create comprehensive ship attributes table for dogma data
    create table(:ship_attributes, primary_key: false) do
      add :type_id, :bigint, null: false, primary_key: true
      
      # Defense attributes
      add :shield_hp, :bigint, comment: "Shield hit points"
      add :armor_hp, :bigint, comment: "Armor hit points" 
      add :structure_hp, :bigint, comment: "Structure hit points"
      
      # Resistance attributes (0.0-1.0, where 0.5 = 50% resistance)
      add :shield_em_resist, :decimal, precision: 5, scale: 4, comment: "Shield EM damage resistance"
      add :shield_thermal_resist, :decimal, precision: 5, scale: 4, comment: "Shield thermal damage resistance"
      add :shield_kinetic_resist, :decimal, precision: 5, scale: 4, comment: "Shield kinetic damage resistance"
      add :shield_explosive_resist, :decimal, precision: 5, scale: 4, comment: "Shield explosive damage resistance"
      
      add :armor_em_resist, :decimal, precision: 5, scale: 4, comment: "Armor EM damage resistance"
      add :armor_thermal_resist, :decimal, precision: 5, scale: 4, comment: "Armor thermal damage resistance"
      add :armor_kinetic_resist, :decimal, precision: 5, scale: 4, comment: "Armor kinetic damage resistance"
      add :armor_explosive_resist, :decimal, precision: 5, scale: 4, comment: "Armor explosive damage resistance"
      
      # Calculated composite values
      add :calculated_dps, :decimal, precision: 10, scale: 2, comment: "Estimated DPS output"
      add :calculated_ehp, :decimal, precision: 15, scale: 2, comment: "Effective hit points (worst case)"
      add :calculated_ehp_uniform, :decimal, precision: 15, scale: 2, comment: "EHP against uniform damage"
      
      # Ship classification
      add :role_classification, :text, comment: "Tactical role: dps, tank, support, tackle, logistics"
      add :size_class, :text, comment: "Size classification: frigate, cruiser, battleship, capital"
      add :tactical_category, :text, comment: "Tactical usage: brawler, sniper, kiter, ewar"
      
      # Performance ratings (0.0-1.0 scale)
      add :damage_rating, :decimal, precision: 3, scale: 2, comment: "Relative damage output rating"
      add :tank_rating, :decimal, precision: 3, scale: 2, comment: "Relative tank strength rating"
      add :speed_rating, :decimal, precision: 3, scale: 2, comment: "Relative speed/agility rating"
      add :utility_rating, :decimal, precision: 3, scale: 2, comment: "Relative utility/support rating"
      
      # Metadata
      add :data_source, :text, default: "sde_import", comment: "Source of attribute data"
      add :confidence_score, :decimal, precision: 3, scale: 2, default: 0.5, comment: "Data quality confidence"
      add :last_updated, :utc_datetime, comment: "When attributes were last calculated"
      
      timestamps()
    end

    # Add foreign key constraint
    alter table(:ship_attributes) do
      modify :type_id, references(:eve_item_types, column: :type_id, type: :bigint, 
                                  name: "ship_attributes_type_id_fkey")
    end

    # Create indexes for performance
    create index(:ship_attributes, [:role_classification])
    create index(:ship_attributes, [:size_class])
    create index(:ship_attributes, [:tactical_category])
    create index(:ship_attributes, [:calculated_dps])
    create index(:ship_attributes, [:calculated_ehp])
    create index(:ship_attributes, [:damage_rating, :tank_rating])

    # Add indexes to eve_item_types for new columns
    create index(:eve_item_types, [:base_damage])
    create index(:eve_item_types, [:base_hp])
    create index(:eve_item_types, [:is_ship, :published], where: "is_ship = true AND published = true")

    # Create view for easy ship attribute queries
    execute """
    CREATE VIEW ship_performance_summary AS
    SELECT 
      i.type_id,
      i.type_name,
      i.group_name,
      i.category_name,
      i.mass,
      i.base_damage,
      i.base_hp,
      i.base_speed,
      sa.calculated_dps,
      sa.calculated_ehp,
      sa.role_classification,
      sa.size_class,
      sa.tactical_category,
      sa.damage_rating,
      sa.tank_rating,
      sa.speed_rating,
      CASE 
        WHEN sa.calculated_dps > 0 AND sa.calculated_ehp > 0 
        THEN sa.calculated_dps / (sa.calculated_ehp / 1000)
        ELSE 0 
      END as dps_per_kehp,
      sa.confidence_score
    FROM eve_item_types i
    LEFT JOIN ship_attributes sa ON i.type_id = sa.type_id
    WHERE i.is_ship = true AND i.published = true;
    """
  end

  def down do
    # Drop view
    execute "DROP VIEW IF EXISTS ship_performance_summary;"
    
    # Drop indexes
    drop_if_exists index(:eve_item_types, [:is_ship, :published])
    drop_if_exists index(:eve_item_types, [:base_hp])
    drop_if_exists index(:eve_item_types, [:base_damage])
    drop_if_exists index(:ship_attributes, [:damage_rating, :tank_rating])
    drop_if_exists index(:ship_attributes, [:calculated_ehp])
    drop_if_exists index(:ship_attributes, [:calculated_dps])
    drop_if_exists index(:ship_attributes, [:tactical_category])
    drop_if_exists index(:ship_attributes, [:size_class])
    drop_if_exists index(:ship_attributes, [:role_classification])
    
    # Drop foreign key constraint and table
    drop constraint(:ship_attributes, "ship_attributes_type_id_fkey")
    drop table(:ship_attributes)
    
    # Remove columns from eve_item_types
    alter table(:eve_item_types) do
      remove :max_targets
      remove :scan_resolution
      remove :sig_radius
      remove :base_speed
      remove :base_damage
      remove :base_capacitor
      remove :base_hp
    end
  end
end
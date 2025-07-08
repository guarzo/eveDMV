defmodule EveDmv.Repo.Migrations.RemoveEnrichedShipTypeFk do
  use Ecto.Migration

  def change do
    # Remove the foreign key constraint on victim_ship_type_id
    drop constraint(:killmails_enriched, :killmails_enriched_victim_ship_type_id_fkey)
    
    # Add an index for performance since we're removing the FK
    create index(:killmails_enriched, [:victim_ship_type_id])
  end
end
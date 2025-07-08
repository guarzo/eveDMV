defmodule EveDmv.Repo.Migrations.RemoveParticipantShipTypeFk do
  use Ecto.Migration

  def change do
    # Remove the foreign key constraint that's causing failures
    drop constraint(:participants, :participants_ship_type_id_fkey)
    
    # Add an index for performance since we're removing the FK
    create index(:participants, [:ship_type_id])
  end
end
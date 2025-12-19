defmodule EveDmv.Repo.Migrations.DropParticipantItemTypeForeignKeys do
  @moduledoc """
  Removes foreign key constraints from participants table for ship_type_id and weapon_type_id.

  These constraints are being removed because:
  1. The SDE import only includes killmail-relevant item categories
  2. Killmails can reference items outside these categories (SKINs, apparel, structures, etc.)
  3. This causes foreign key violations during bulk insert

  The relationships are kept in the Ash resource for preloading, but without DB-level enforcement.
  """

  use Ecto.Migration

  def up do
    # Drop ship_type_id foreign key if it exists
    execute """
    ALTER TABLE participants
    DROP CONSTRAINT IF EXISTS participants_ship_type_id_fkey
    """

    # Drop weapon_type_id foreign key if it exists
    execute """
    ALTER TABLE participants
    DROP CONSTRAINT IF EXISTS participants_weapon_type_id_fkey
    """
  end

  def down do
    # Note: We don't recreate the foreign keys on rollback because
    # the existing data may contain type_ids not in eve_item_types.
    # If you need to add these constraints back, clean the data first.
    :ok
  end
end

defmodule EveDmv.Repo.Migrations.AddCompositeKillmailConstraint do
  @moduledoc """
  Add composite unique constraint on (killmail_id, killmail_time) for partitioned table.
  
  This is needed for ON CONFLICT to work with partitioned tables, as the constraint
  must include the partition key.
  """
  
  use Ecto.Migration
  
  def up do
    # Add composite unique constraint on the parent table
    # This will propagate to all partitions
    execute """
    ALTER TABLE killmails_raw 
    ADD CONSTRAINT killmails_raw_unique_killmail_id_time 
    UNIQUE (killmail_id, killmail_time)
    """
  end
  
  def down do
    execute """
    ALTER TABLE killmails_raw 
    DROP CONSTRAINT IF EXISTS killmails_raw_unique_killmail_id_time
    """
  end
end
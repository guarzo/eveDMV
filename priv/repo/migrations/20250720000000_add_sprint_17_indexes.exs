defmodule EveDmv.Repo.Migrations.AddSprint17Indexes do
  @moduledoc """
  Add Sprint 17 performance indexes that tests are expecting.
  """

  use Ecto.Migration
  @disable_ddl_transaction true
  @disable_migration_lock true

  def up do
    # For partitioned tables, we need to create indexes on the parent table differently
    # These will automatically propagate to existing and future partitions

    execute """
    CREATE INDEX IF NOT EXISTS killmails_raw_time_system_idx
    ON killmails_raw (killmail_time, solar_system_id)
    """

    execute """
    CREATE INDEX IF NOT EXISTS killmails_raw_character_activity_idx
    ON killmails_raw (victim_character_id, killmail_time)
    """

    execute """
    CREATE INDEX IF NOT EXISTS killmails_raw_corp_alliance_idx
    ON killmails_raw (victim_corporation_id, victim_alliance_id)
    """

    execute """
    CREATE INDEX IF NOT EXISTS killmails_raw_corp_alliance_time_idx
    ON killmails_raw (victim_corporation_id, victim_alliance_id, killmail_time)
    """

    # Participants indexes (if table exists)
    execute """
    DO $$
    BEGIN
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'participants') THEN
            CREATE INDEX IF NOT EXISTS participants_damage_final_blow_idx
            ON participants (damage_done, final_blow);

            CREATE INDEX IF NOT EXISTS participants_ship_weapon_names_idx
            ON participants (ship_name, weapon_name);
        END IF;
    END $$;
    """
  end

  def down do
    execute "DROP INDEX IF EXISTS participants_ship_weapon_names_idx"
    execute "DROP INDEX IF EXISTS participants_damage_final_blow_idx"
    execute "DROP INDEX IF EXISTS killmails_raw_corp_alliance_time_idx"
    execute "DROP INDEX IF EXISTS killmails_raw_corp_alliance_idx"
    execute "DROP INDEX IF EXISTS killmails_raw_character_activity_idx"
    execute "DROP INDEX IF EXISTS killmails_raw_time_system_idx"
  end
end
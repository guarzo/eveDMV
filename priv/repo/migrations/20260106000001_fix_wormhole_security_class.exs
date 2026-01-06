defmodule EveDmv.Repo.Migrations.FixWormholeSecurityClass do
  @moduledoc """
  Fixes the security_class field for wormhole systems.

  Wormhole systems were incorrectly classified as 'nullsec' because the
  wormhole_class_id from the region data wasn't being properly propagated
  during the initial SDE import.

  This migration uses the authoritative region_id ranges from CCP's SDE:
  - region_id 11000001-11000032: Standard wormhole space (C1-C6, shattered, etc.)

  Per CLAUDE.md guidelines, we use region_id (authoritative SDE data) rather
  than system_name patterns to identify wormholes.
  """
  use Ecto.Migration

  def up do
    # Update all systems in wormhole regions to have security_class = 'wormhole'
    # Wormhole region IDs are in the 11000000-12000000 range (11xxxxxx)
    execute("""
    UPDATE eve_solar_systems
    SET security_class = 'wormhole'
    WHERE region_id >= 11000000 AND region_id < 12000000
      AND (security_class IS NULL OR security_class != 'wormhole')
    """)

    # Log the count of affected rows for visibility
    execute("""
    DO $$
    DECLARE
      affected_count INTEGER;
    BEGIN
      SELECT COUNT(*) INTO affected_count
      FROM eve_solar_systems
      WHERE region_id >= 11000000 AND region_id < 12000000;

      RAISE NOTICE 'Updated % wormhole systems to security_class = wormhole', affected_count;
    END $$;
    """)
  end

  def down do
    # Revert to calculated security_class based on security_status
    # Note: This loses the wormhole classification but maintains data integrity
    execute("""
    UPDATE eve_solar_systems
    SET security_class = CASE
      WHEN security_status >= 0.45 THEN 'highsec'
      WHEN security_status >= 0.05 THEN 'lowsec'
      ELSE 'nullsec'
    END
    WHERE region_id >= 11000000 AND region_id < 12000000
    """)
  end
end

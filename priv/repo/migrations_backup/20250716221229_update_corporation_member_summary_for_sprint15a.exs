defmodule EveDmv.Repo.Migrations.UpdateCorporationMemberSummaryForSprint15a do
  use Ecto.Migration

  def up do
    # First drop the existing view if it exists
    execute "DROP MATERIALIZED VIEW IF EXISTS corporation_member_summary CASCADE"
    
    # Create the optimized Sprint 15A version that includes per-member statistics
    execute """
    CREATE MATERIALIZED VIEW corporation_member_summary AS
    SELECT
      p.corporation_id,
      p.corporation_name,
      p.character_id,
      p.character_name,
      COUNT(*) as total_killmails,
      COUNT(*) FILTER (WHERE NOT p.is_victim) as kills,
      COUNT(*) FILTER (WHERE p.is_victim) as losses,
      SUM(kr.total_value) FILTER (WHERE NOT p.is_victim) as isk_destroyed,
      SUM(kr.total_value) FILTER (WHERE p.is_victim) as isk_lost,
      MIN(kr.killmail_time) as first_seen,
      MAX(kr.killmail_time) as last_seen,
      COUNT(DISTINCT p.solar_system_id) as systems_active,
      COUNT(DISTINCT p.ship_type_id) as ships_flown,
      COUNT(DISTINCT DATE_TRUNC('day', kr.killmail_time)) as days_active,
      RANK() OVER (PARTITION BY p.corporation_id ORDER BY COUNT(*) DESC) as activity_rank
    FROM participants p
    JOIN killmails_raw kr ON p.killmail_id = kr.killmail_id
    WHERE p.corporation_id IS NOT NULL
    AND kr.killmail_time >= NOW() - INTERVAL '90 days'
    GROUP BY p.corporation_id, p.corporation_name, p.character_id, p.character_name
    HAVING COUNT(*) >= 5
    WITH DATA
    """
    
    # Create indexes for the new view
    execute "CREATE INDEX IF NOT EXISTS idx_corp_member_corp_char ON corporation_member_summary (corporation_id, character_id)"
    execute "CREATE INDEX IF NOT EXISTS idx_corp_member_last_seen ON corporation_member_summary (corporation_id, last_seen DESC)"
    execute "CREATE INDEX IF NOT EXISTS idx_corp_member_activity ON corporation_member_summary (corporation_id, activity_rank)"
    
    # Create refresh functions for the views
    execute """
    CREATE OR REPLACE FUNCTION refresh_character_activity_summary()
    RETURNS void AS $$
    BEGIN
      REFRESH MATERIALIZED VIEW CONCURRENTLY character_activity_summary;
    END;
    $$ LANGUAGE plpgsql;
    """
    
    execute """
    CREATE OR REPLACE FUNCTION refresh_corporation_member_summary()
    RETURNS void AS $$
    BEGIN
      REFRESH MATERIALIZED VIEW CONCURRENTLY corporation_member_summary;
    END;
    $$ LANGUAGE plpgsql;
    """
    
    execute """
    CREATE OR REPLACE FUNCTION refresh_all_performance_views()
    RETURNS void AS $$
    BEGIN
      -- Refresh base views first
      REFRESH MATERIALIZED VIEW CONCURRENTLY character_activity_summary;
      -- Then dependent views
      REFRESH MATERIALIZED VIEW CONCURRENTLY corporation_member_summary;
    END;
    $$ LANGUAGE plpgsql;
    """
  end

  def down do
    # Drop the functions
    execute "DROP FUNCTION IF EXISTS refresh_all_performance_views()"
    execute "DROP FUNCTION IF EXISTS refresh_corporation_member_summary()"
    execute "DROP FUNCTION IF EXISTS refresh_character_activity_summary()"
    
    # Drop the Sprint 15A version
    execute "DROP MATERIALIZED VIEW IF EXISTS corporation_member_summary CASCADE"
    
    # Recreate the original simpler version if needed
    execute """
    CREATE MATERIALIZED VIEW IF NOT EXISTS corporation_member_summary AS
    SELECT 
      cas.corporation_id,
      cas.corporation_name,
      cas.alliance_id,
      cas.alliance_name,
      COUNT(DISTINCT cas.character_id) as member_count,
      SUM(cas.kills) as total_kills,
      SUM(cas.losses) as total_losses,
      SUM(cas.final_blows) as total_final_blows,
      SUM(cas.isk_destroyed) as total_isk_destroyed,
      SUM(cas.isk_lost) as total_isk_lost,
      SUM(cas.total_damage) as total_damage,
      AVG(cas.kills) as avg_member_kills,
      AVG(cas.losses) as avg_member_losses,
      AVG(cas.isk_destroyed) as avg_member_isk_destroyed,
      AVG(cas.isk_efficiency_percent) as avg_isk_efficiency,
      MAX(cas.last_activity_date) as last_member_activity,
      CASE 
        WHEN SUM(cas.losses) = 0 THEN 100.0
        ELSE ROUND((SUM(cas.kills)::decimal / SUM(cas.losses)::decimal), 2)
      END as corp_kill_death_ratio,
      CASE 
        WHEN (SUM(cas.isk_destroyed) + SUM(cas.isk_lost)) = 0 THEN 50.0
        ELSE ROUND(
          (SUM(cas.isk_destroyed)::decimal / 
           (SUM(cas.isk_destroyed) + SUM(cas.isk_lost))::decimal) * 100, 2
        )
      END as corp_isk_efficiency_percent,
      ROUND(
        (COUNT(CASE WHEN cas.last_activity_date >= NOW() - INTERVAL '30 days' THEN 1 END)::decimal / 
         COUNT(DISTINCT cas.character_id)::decimal) * 100, 2
      ) as active_member_percent,
      ROUND(AVG(cas.kills + cas.losses), 2) as avg_member_activity,
      NOW() as refreshed_at
    FROM character_activity_summary cas
    WHERE cas.corporation_id IS NOT NULL
    GROUP BY 
      cas.corporation_id, cas.corporation_name, 
      cas.alliance_id, cas.alliance_name
    WITH DATA
    """
  end
end
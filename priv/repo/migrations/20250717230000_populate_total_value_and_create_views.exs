defmodule EveDmv.Repo.Migrations.PopulateTotalValueAndCreateViews do
  @moduledoc """
  Sprint 15A Performance Optimization - Phase 2: Populate total_value and create materialized views
  
  1. Populates the total_value column in killmails_raw from JSON data
  2. Creates the character_activity_summary materialized view
  3. Creates the corporation_member_summary materialized view
  4. Sets up indexes for optimal query performance
  """

  use Ecto.Migration

  def up do
    # Step 1: Populate total_value from existing JSON data
    execute("""
    UPDATE killmails_raw 
    SET total_value = COALESCE(
      (raw_data->'zkb'->>'totalValue')::numeric,
      0
    )
    WHERE total_value IS NULL
    """)

    # Step 2: Create character_activity_summary materialized view
    execute("""
    CREATE MATERIALIZED VIEW IF NOT EXISTS character_activity_summary AS
    SELECT 
      p.character_id,
      p.character_name,
      p.corporation_id,
      p.corporation_name,
      p.alliance_id,
      p.alliance_name,
      COUNT(CASE WHEN NOT p.is_victim THEN 1 END) as kills,
      COUNT(CASE WHEN p.is_victim THEN 1 END) as losses,
      COUNT(CASE WHEN NOT p.is_victim AND p.final_blow THEN 1 END) as final_blows,
      SUM(CASE WHEN NOT p.is_victim THEN COALESCE(k.total_value, 0) END) as isk_destroyed,
      SUM(CASE WHEN p.is_victim THEN COALESCE(k.total_value, 0) END) as isk_lost,
      SUM(p.damage_done) as total_damage,
      COUNT(DISTINCT p.ship_type_id) as ships_used,
      COUNT(DISTINCT p.solar_system_id) as systems_active,
      MAX(p.killmail_time) as last_activity_date,
      MIN(p.killmail_time) as first_activity_date,
      CASE 
        WHEN COUNT(CASE WHEN p.is_victim THEN 1 END) = 0 THEN 100.0
        ELSE ROUND(
          (COUNT(CASE WHEN NOT p.is_victim THEN 1 END)::decimal / 
           (COUNT(CASE WHEN NOT p.is_victim THEN 1 END) + COUNT(CASE WHEN p.is_victim THEN 1 END))::decimal) * 100, 2
        )
      END as kill_death_ratio_percent,
      CASE 
        WHEN (SUM(CASE WHEN NOT p.is_victim THEN COALESCE(k.total_value, 0) END) + 
              SUM(CASE WHEN p.is_victim THEN COALESCE(k.total_value, 0) END)) = 0 THEN 50.0
        ELSE ROUND(
          (SUM(CASE WHEN NOT p.is_victim THEN COALESCE(k.total_value, 0) END)::decimal / 
           (SUM(CASE WHEN NOT p.is_victim THEN COALESCE(k.total_value, 0) END) + 
            SUM(CASE WHEN p.is_victim THEN COALESCE(k.total_value, 0) END))::decimal) * 100, 2
        )
      END as isk_efficiency_percent,
      NOW() as refreshed_at
    FROM participants p
    JOIN killmails_raw k ON p.killmail_id = k.killmail_id AND p.killmail_time = k.killmail_time
    WHERE p.character_id IS NOT NULL
    GROUP BY 
      p.character_id, p.character_name, p.corporation_id, 
      p.corporation_name, p.alliance_id, p.alliance_name
    WITH DATA
    """)

    # Step 3: Create corporation_member_summary materialized view
    execute("""
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
    """)

    # Step 4: Create indexes on materialized views for optimal performance
    create(unique_index(:character_activity_summary, [:character_id], 
           name: "character_activity_summary_character_id_idx"))
    
    create(index(:character_activity_summary, [:corporation_id, :kills], 
           name: "character_activity_summary_corp_kills_idx"))
    
    create(index(:character_activity_summary, [:isk_efficiency_percent], 
           name: "character_activity_summary_isk_efficiency_idx"))
    
    create(index(:character_activity_summary, [:last_activity_date], 
           name: "character_activity_summary_last_activity_idx"))

    create(unique_index(:corporation_member_summary, [:corporation_id], 
           name: "corporation_member_summary_corp_id_idx"))
    
    create(index(:corporation_member_summary, [:total_kills], 
           name: "corporation_member_summary_kills_idx"))
    
    create(index(:corporation_member_summary, [:avg_member_activity], 
           name: "corporation_member_summary_activity_idx"))

    # Step 5: Create refresh functions
    execute("""
    CREATE OR REPLACE FUNCTION refresh_character_activity_summary()
    RETURNS void AS $$
    BEGIN
      REFRESH MATERIALIZED VIEW CONCURRENTLY character_activity_summary;
    END;
    $$ LANGUAGE plpgsql;
    """)

    execute("""
    CREATE OR REPLACE FUNCTION refresh_corporation_member_summary()
    RETURNS void AS $$
    BEGIN
      REFRESH MATERIALIZED VIEW CONCURRENTLY character_activity_summary;
      REFRESH MATERIALIZED VIEW CONCURRENTLY corporation_member_summary;
    END;
    $$ LANGUAGE plpgsql;
    """)

    execute("""
    CREATE OR REPLACE FUNCTION refresh_all_performance_views()
    RETURNS void AS $$
    BEGIN
      REFRESH MATERIALIZED VIEW CONCURRENTLY character_activity_summary;
      REFRESH MATERIALIZED VIEW CONCURRENTLY corporation_member_summary;
    END;
    $$ LANGUAGE plpgsql;
    """)
  end

  def down do
    # Drop functions
    execute("DROP FUNCTION IF EXISTS refresh_character_activity_summary();")
    execute("DROP FUNCTION IF EXISTS refresh_corporation_member_summary();")
    execute("DROP FUNCTION IF EXISTS refresh_all_performance_views();")
    
    # Drop indexes
    drop_if_exists(index(:character_activity_summary, [:character_id], unique: true))
    drop_if_exists(index(:character_activity_summary, [:corporation_id, :kills]))
    drop_if_exists(index(:character_activity_summary, [:isk_efficiency_percent]))
    drop_if_exists(index(:character_activity_summary, [:last_activity_date]))
    
    drop_if_exists(index(:corporation_member_summary, [:corporation_id], unique: true))
    drop_if_exists(index(:corporation_member_summary, [:total_kills]))
    drop_if_exists(index(:corporation_member_summary, [:avg_member_activity]))
    
    # Drop materialized views
    execute("DROP MATERIALIZED VIEW IF EXISTS corporation_member_summary;")
    execute("DROP MATERIALIZED VIEW IF EXISTS character_activity_summary;")
    
    # Reset total_value column (optional - could leave it populated)
    execute("UPDATE killmails_raw SET total_value = NULL;")
  end
end
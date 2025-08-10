defmodule EveDmv.Repo.Migrations.OptimizeMaterializedViews do
  use Ecto.Migration

  def up do
    # Create view refresh tracking table if it doesn't exist
    create_if_not_exists table(:view_refresh_tracking, primary_key: false) do
      add :view_name, :string, primary_key: true
      add :last_refresh, :utc_datetime_usec
      add :refresh_duration_ms, :integer
      add :row_count, :bigint
      add :refresh_count, :integer, default: 0
      add :last_error, :text
      
      timestamps()
    end
    
    # Add indexes on materialized views for better query performance
    
    # Note: character_activity_summary indexes removed - view doesn't exist yet
    
    # ship_type_usage indexes (matches actual view structure)
    create_if_not_exists index(:ship_type_usage, [:ship_type_id],
      unique: true,
      name: :ship_type_usage_ship_type_id_idx
    )
    
    create_if_not_exists index(:ship_type_usage, [:effectiveness_ratio],
      name: :ship_type_usage_effectiveness_idx
    )
    
    create_if_not_exists index(:ship_type_usage, [:unique_pilots],
      name: :ship_type_usage_pilots_idx
    )
    
    # Note: system_activity_heatmap indexes removed - view doesn't exist yet
    
    # Create function for incremental refresh strategy
    execute """
    CREATE OR REPLACE FUNCTION refresh_materialized_view_incremental(
      view_name text,
      time_column text DEFAULT 'last_updated',
      lookback_hours integer DEFAULT 2
    )
    RETURNS void AS $$
    DECLARE
      last_refresh timestamp;
      refresh_from timestamp;
    BEGIN
      -- Get last refresh time
      SELECT last_refresh INTO last_refresh
      FROM view_refresh_tracking
      WHERE view_name = view_name;
      
      -- Calculate refresh window with lookback
      IF last_refresh IS NULL THEN
        -- Full refresh if never refreshed
        EXECUTE 'REFRESH MATERIALIZED VIEW CONCURRENTLY ' || view_name;
      ELSE
        -- Set refresh_from with lookback buffer
        refresh_from := last_refresh - (lookback_hours || ' hours')::interval;
        
        -- Log the incremental refresh
        RAISE NOTICE 'Incremental refresh of % from %', view_name, refresh_from;
        
        -- For now, do concurrent refresh (true incremental would need custom logic)
        EXECUTE 'REFRESH MATERIALIZED VIEW CONCURRENTLY ' || view_name;
      END IF;
      
      -- Update tracking
      INSERT INTO view_refresh_tracking (view_name, last_refresh, row_count)
      VALUES (view_name, NOW(), 0)
      ON CONFLICT (view_name) 
      DO UPDATE SET 
        last_refresh = NOW(),
        refresh_count = view_refresh_tracking.refresh_count + 1;
    END;
    $$ LANGUAGE plpgsql;
    """
    
    # Create optimized aggregation functions
    execute """
    CREATE OR REPLACE FUNCTION calculate_activity_score(
      kill_count integer,
      death_count integer,
      days_active integer
    )
    RETURNS numeric AS $$
    BEGIN
      IF days_active = 0 THEN
        RETURN 0;
      END IF;
      
      RETURN ROUND(
        ((kill_count * 2.0 + death_count) / GREATEST(days_active, 1)) * 100,
        2
      );
    END;
    $$ LANGUAGE plpgsql IMMUTABLE;
    """
    
    # Create function to analyze view performance
    execute """
    CREATE OR REPLACE FUNCTION analyze_materialized_view_performance()
    RETURNS TABLE(
      view_name text,
      size_bytes bigint,
      size_pretty text,
      row_count bigint,
      last_refresh timestamp,
      refresh_lag interval,
      index_count integer,
      index_size_bytes bigint
    ) AS $$
    BEGIN
      RETURN QUERY
      SELECT 
        v.matviewname::text as view_name,
        pg_relation_size(c.oid) as size_bytes,
        pg_size_pretty(pg_relation_size(c.oid)) as size_pretty,
        COALESCE(t.row_count, 0) as row_count,
        t.last_refresh,
        NOW() - t.last_refresh as refresh_lag,
        COUNT(i.indexname)::integer as index_count,
        SUM(pg_relation_size(i.indexname::regclass))::bigint as index_size_bytes
      FROM pg_matviews v
      JOIN pg_class c ON c.relname = v.matviewname
      LEFT JOIN view_refresh_tracking t ON t.view_name = v.matviewname
      LEFT JOIN pg_indexes i ON i.tablename = v.matviewname
      WHERE v.schemaname = 'public'
      GROUP BY v.matviewname, c.oid, t.row_count, t.last_refresh;
    END;
    $$ LANGUAGE plpgsql;
    """
    
    # Create additional performance-focused materialized views
    
    # Fleet composition analysis view
    execute """
    CREATE MATERIALIZED VIEW IF NOT EXISTS fleet_composition_summary AS
    SELECT 
      DATE_TRUNC('day', killmail_time) as day,
      solar_system_id,
      COUNT(DISTINCT CASE WHEN attacker_count <= 5 THEN killmail_id END) as small_gang_kills,
      COUNT(DISTINCT CASE WHEN attacker_count BETWEEN 6 AND 20 THEN killmail_id END) as medium_fleet_kills,
      COUNT(DISTINCT CASE WHEN attacker_count > 20 THEN killmail_id END) as large_fleet_kills,
      AVG(attacker_count) as avg_fleet_size,
      MAX(attacker_count) as max_fleet_size
    FROM killmails_raw
    WHERE killmail_time >= NOW() - INTERVAL '30 days'
    GROUP BY DATE_TRUNC('day', killmail_time), solar_system_id
    WITH DATA;
    """
    
    create_if_not_exists index(:fleet_composition_summary, [:day, :solar_system_id],
      unique: true,
      name: :fleet_composition_summary_day_system_idx
    )
    
    # High-value target tracking
    execute """
    CREATE MATERIALIZED VIEW IF NOT EXISTS high_value_targets AS
    SELECT 
      victim_character_id,
      victim_corporation_id,
      victim_alliance_id,
      COUNT(*) as loss_count,
      SUM(total_value) as total_loss_value,
      AVG(total_value) as avg_loss_value,
      MAX(total_value) as max_loss_value,
      MAX(killmail_time) as last_loss
    FROM killmails_raw
    WHERE total_value > 100000000  -- 100M ISK minimum
      AND killmail_time >= NOW() - INTERVAL '90 days'
      AND victim_character_id IS NOT NULL
    GROUP BY victim_character_id, victim_corporation_id, victim_alliance_id
    HAVING SUM(total_value) > 1000000000  -- 1B ISK total losses
    WITH DATA;
    """
    
    create_if_not_exists index(:high_value_targets, [:victim_character_id],
      unique: true,
      name: :high_value_targets_character_idx
    )
    
    create_if_not_exists index(:high_value_targets, [:total_loss_value],
      name: :high_value_targets_value_idx
    )
    
    # Timezone activity patterns
    execute """
    CREATE MATERIALIZED VIEW IF NOT EXISTS timezone_activity_patterns AS
    SELECT 
      EXTRACT(HOUR FROM killmail_time AT TIME ZONE 'UTC') as hour_utc,
      EXTRACT(DOW FROM killmail_time AT TIME ZONE 'UTC') as day_of_week,
      COUNT(*) as killmail_count,
      COUNT(DISTINCT victim_character_id) as unique_victims,
      COUNT(DISTINCT solar_system_id) as unique_systems,
      AVG(attacker_count) as avg_attackers
    FROM killmails_raw
    WHERE killmail_time >= NOW() - INTERVAL '30 days'
    GROUP BY 
      EXTRACT(HOUR FROM killmail_time AT TIME ZONE 'UTC'),
      EXTRACT(DOW FROM killmail_time AT TIME ZONE 'UTC')
    WITH DATA;
    """
    
    create_if_not_exists index(:timezone_activity_patterns, [:hour_utc, :day_of_week],
      unique: true,
      name: :timezone_activity_patterns_hour_day_idx
    )
    
    # Initial refresh of all views
    execute "REFRESH MATERIALIZED VIEW CONCURRENTLY ship_type_usage"
    execute "REFRESH MATERIALIZED VIEW fleet_composition_summary"
    execute "REFRESH MATERIALIZED VIEW high_value_targets"
    execute "REFRESH MATERIALIZED VIEW timezone_activity_patterns"
    
    # Note: character_activity_summary and system_activity_heatmap refresh removed - views don't exist yet
  end

  def down do
    # Drop new materialized views
    execute "DROP MATERIALIZED VIEW IF EXISTS timezone_activity_patterns CASCADE"
    execute "DROP MATERIALIZED VIEW IF EXISTS high_value_targets CASCADE"
    execute "DROP MATERIALIZED VIEW IF EXISTS fleet_composition_summary CASCADE"
    
    # Drop functions
    execute "DROP FUNCTION IF EXISTS analyze_materialized_view_performance()"
    execute "DROP FUNCTION IF EXISTS calculate_activity_score(integer, integer, integer)"
    execute "DROP FUNCTION IF EXISTS refresh_materialized_view_incremental(text, text, integer)"
    
    # Drop tracking table
    drop_if_exists table(:view_refresh_tracking)
  end
end
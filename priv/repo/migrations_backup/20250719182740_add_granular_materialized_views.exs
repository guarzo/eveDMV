defmodule EveDmv.Repo.Migrations.AddGranularMaterializedViews do
  use Ecto.Migration
  require Logger

  def up do
    # Create recent activity view (smaller, refreshes more frequently)
    execute """
    CREATE MATERIALIZED VIEW IF NOT EXISTS recent_character_activity AS
    SELECT
      p.character_id,
      p.character_name,
      COUNT(*) FILTER (WHERE p.is_victim = false) as kills_24h,
      COUNT(*) FILTER (WHERE p.is_victim = true) as losses_24h,
      SUM(k.total_value) as isk_involved_24h,
      MAX(k.killmail_time) as last_seen
    FROM participants p
    JOIN killmails_raw k ON p.killmail_id = k.killmail_id
    WHERE k.killmail_time >= NOW() - INTERVAL '24 hours'
    GROUP BY p.character_id, p.character_name;
    """

    # Create unique index for concurrent refresh
    execute """
    CREATE UNIQUE INDEX IF NOT EXISTS idx_recent_character_activity_character_id
    ON recent_character_activity (character_id);
    """

    # System activity heatmap for the last 7 days
    execute """
    CREATE MATERIALIZED VIEW IF NOT EXISTS system_activity_heatmap AS
    SELECT
      k.solar_system_id,
      s.solar_system_name,
      s.security_status,
      DATE_TRUNC('hour', k.killmail_time) as hour,
      COUNT(*) as kill_count,
      SUM(k.total_value) as total_isk_destroyed,
      COUNT(DISTINCT k.victim_character_id) as unique_victims,
      COUNT(DISTINCT p.character_id) FILTER (WHERE p.is_victim = false) as unique_attackers
    FROM killmails_raw k
    LEFT JOIN eve_solar_systems s ON k.solar_system_id = s.solar_system_id
    LEFT JOIN participants p ON k.killmail_id = p.killmail_id
    WHERE k.killmail_time >= NOW() - INTERVAL '7 days'
    GROUP BY k.solar_system_id, s.solar_system_name, s.security_status, DATE_TRUNC('hour', k.killmail_time);
    """

    # Create indexes for efficient querying
    execute """
    CREATE INDEX IF NOT EXISTS idx_system_activity_heatmap_system_hour
    ON system_activity_heatmap (solar_system_id, hour DESC);
    """

    execute """
    CREATE INDEX IF NOT EXISTS idx_system_activity_heatmap_hour
    ON system_activity_heatmap (hour DESC);
    """

    # Corporation activity summary (last 30 days)
    execute """
    CREATE MATERIALIZED VIEW IF NOT EXISTS corporation_activity_summary AS
    SELECT
      p.corporation_id,
      p.corporation_name,
      COUNT(DISTINCT p.character_id) as active_members,
      COUNT(*) FILTER (WHERE p.is_victim = false) as total_kills,
      COUNT(*) FILTER (WHERE p.is_victim = true) as total_losses,
      SUM(k.total_value) FILTER (WHERE p.is_victim = false) as isk_destroyed,
      SUM(k.total_value) FILTER (WHERE p.is_victim = true) as isk_lost,
      COUNT(DISTINCT k.solar_system_id) as systems_active,
      MAX(k.killmail_time) as last_activity
    FROM participants p
    JOIN killmails_raw k ON p.killmail_id = k.killmail_id
    WHERE k.killmail_time >= NOW() - INTERVAL '30 days'
      AND p.corporation_id IS NOT NULL
    GROUP BY p.corporation_id, p.corporation_name;
    """

    execute """
    CREATE UNIQUE INDEX IF NOT EXISTS idx_corporation_activity_summary_corp_id
    ON corporation_activity_summary (corporation_id);
    """

    # Ship usage trends (last 7 days)
    execute """
    CREATE MATERIALIZED VIEW IF NOT EXISTS ship_usage_trends AS
    SELECT
      p.ship_type_id,
      ship.type_name as ship_name,
      ship_group.group_name as ship_group,
      DATE_TRUNC('day', k.killmail_time) as day,
      COUNT(*) FILTER (WHERE p.is_victim = false) as used_count,
      COUNT(*) FILTER (WHERE p.is_victim = true) as lost_count,
      AVG(k.total_value) FILTER (WHERE p.is_victim = true) as avg_loss_value
    FROM participants p
    JOIN killmails_raw k ON p.killmail_id = k.killmail_id
    LEFT JOIN eve_item_types ship ON p.ship_type_id = ship.type_id
    LEFT JOIN eve_item_groups ship_group ON ship.group_id = ship_group.group_id
    WHERE k.killmail_time >= NOW() - INTERVAL '7 days'
      AND p.ship_type_id IS NOT NULL
    GROUP BY p.ship_type_id, ship.type_name, ship_group.group_name, DATE_TRUNC('day', k.killmail_time);
    """

    execute """
    CREATE INDEX IF NOT EXISTS idx_ship_usage_trends_ship_day
    ON ship_usage_trends (ship_type_id, day DESC);
    """

    # High-value kill summary
    execute """
    CREATE MATERIALIZED VIEW IF NOT EXISTS high_value_kills_summary AS
    SELECT
      k.killmail_id,
      k.killmail_time,
      k.solar_system_id,
      s.solar_system_name,
      k.victim_ship_type_id,
      ship.type_name as victim_ship_name,
      k.victim_character_id,
      victim.character_name as victim_name,
      k.victim_corporation_id,
      victim.corporation_name as victim_corp,
      k.total_value,
      k.attacker_count
    FROM killmails_raw k
    LEFT JOIN eve_solar_systems s ON k.solar_system_id = s.solar_system_id
    LEFT JOIN eve_item_types ship ON k.victim_ship_type_id = ship.type_id
    LEFT JOIN participants victim ON k.killmail_id = victim.killmail_id AND victim.is_victim = true
    WHERE k.total_value >= 1000000000  -- 1 billion ISK threshold
      AND k.killmail_time >= NOW() - INTERVAL '30 days'
    ORDER BY k.total_value DESC
    LIMIT 1000;
    """

    execute """
    CREATE INDEX IF NOT EXISTS idx_high_value_kills_summary_value
    ON high_value_kills_summary (total_value DESC);
    """

    execute """
    CREATE INDEX IF NOT EXISTS idx_high_value_kills_summary_time
    ON high_value_kills_summary (killmail_time DESC);
    """

    # Initial refresh of all views
    execute "REFRESH MATERIALIZED VIEW recent_character_activity;"
    execute "REFRESH MATERIALIZED VIEW system_activity_heatmap;"
    execute "REFRESH MATERIALIZED VIEW corporation_activity_summary;"
    execute "REFRESH MATERIALIZED VIEW ship_usage_trends;"
    execute "REFRESH MATERIALIZED VIEW high_value_kills_summary;"

    Logger.info("Granular materialized views created successfully")
  end

  def down do
    execute "DROP MATERIALIZED VIEW IF EXISTS high_value_kills_summary CASCADE;"
    execute "DROP MATERIALIZED VIEW IF EXISTS ship_usage_trends CASCADE;"
    execute "DROP MATERIALIZED VIEW IF EXISTS corporation_activity_summary CASCADE;"
    execute "DROP MATERIALIZED VIEW IF EXISTS system_activity_heatmap CASCADE;"
    execute "DROP MATERIALIZED VIEW IF EXISTS recent_character_activity CASCADE;"
  end
end

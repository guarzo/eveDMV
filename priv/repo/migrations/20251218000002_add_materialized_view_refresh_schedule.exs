defmodule EveDmv.Repo.Migrations.AddMaterializedViewRefreshSchedule do
  @moduledoc """
  Adds scheduled pg_cron jobs to automatically refresh materialized views.

  This migration sets up automated refresh schedules for all materialized views
  to keep analytics data fresh without manual intervention.

  Schedule Overview:
  - ship_type_usage: Every 4 hours (heavy query, less frequent)
  - fleet_composition_summary: Every 2 hours
  - high_value_targets: Every 6 hours (less volatile data)
  - timezone_activity_patterns: Every 4 hours
  - character_activity_summary: Every 2 hours (if exists)
  - system_activity_heatmap: Every 2 hours (if exists)

  Note: pg_cron extension must be installed and configured.
  In CI/test environments without pg_cron, this migration will skip gracefully.
  """

  use Ecto.Migration

  def up do
    # Check if pg_cron extension is available
    pg_cron_available = check_pg_cron_available()

    if pg_cron_available do
      # Create a wrapper function that handles errors gracefully
      execute """
      CREATE OR REPLACE FUNCTION safe_refresh_materialized_view(view_name text)
      RETURNS void AS $$
      DECLARE
        start_time timestamp;
        end_time timestamp;
        duration_ms integer;
      BEGIN
        start_time := clock_timestamp();

        -- Check if view exists before refreshing
        IF EXISTS (
          SELECT 1 FROM pg_matviews WHERE matviewname = view_name
        ) THEN
          -- Attempt concurrent refresh first
          BEGIN
            EXECUTE 'REFRESH MATERIALIZED VIEW CONCURRENTLY ' || quote_ident(view_name);
          EXCEPTION WHEN OTHERS THEN
            -- Fall back to non-concurrent refresh if concurrent fails
            -- (e.g., if unique index doesn't exist)
            EXECUTE 'REFRESH MATERIALIZED VIEW ' || quote_ident(view_name);
          END;

          end_time := clock_timestamp();
          duration_ms := EXTRACT(MILLISECONDS FROM (end_time - start_time))::integer;

          -- Update tracking table
          INSERT INTO view_refresh_tracking (view_name, last_refresh, refresh_duration_ms, refresh_count, inserted_at, updated_at)
          VALUES (view_name, NOW(), duration_ms, 1, NOW(), NOW())
          ON CONFLICT (view_name)
          DO UPDATE SET
            last_refresh = NOW(),
            refresh_duration_ms = duration_ms,
            refresh_count = view_refresh_tracking.refresh_count + 1,
            updated_at = NOW(),
            last_error = NULL;

          RAISE NOTICE 'Refreshed materialized view % in % ms', view_name, duration_ms;
        ELSE
          RAISE NOTICE 'Materialized view % does not exist, skipping refresh', view_name;
        END IF;
      EXCEPTION WHEN OTHERS THEN
        -- Log error but don't fail
        INSERT INTO view_refresh_tracking (view_name, last_refresh, last_error, inserted_at, updated_at)
        VALUES (view_name, NOW(), SQLERRM, NOW(), NOW())
        ON CONFLICT (view_name)
        DO UPDATE SET
          last_error = SQLERRM,
          updated_at = NOW();

        RAISE WARNING 'Failed to refresh materialized view %: %', view_name, SQLERRM;
      END;
      $$ LANGUAGE plpgsql;
      """

      # Schedule refresh jobs using pg_cron
      # Ship type usage - every 4 hours at minute 15
      execute """
      SELECT cron.schedule(
        'refresh_ship_type_usage',
        '15 */4 * * *',
        $$SELECT safe_refresh_materialized_view('ship_type_usage')$$
      );
      """

      # Fleet composition summary - every 2 hours at minute 30
      execute """
      SELECT cron.schedule(
        'refresh_fleet_composition_summary',
        '30 */2 * * *',
        $$SELECT safe_refresh_materialized_view('fleet_composition_summary')$$
      );
      """

      # High value targets - every 6 hours at minute 45
      execute """
      SELECT cron.schedule(
        'refresh_high_value_targets',
        '45 */6 * * *',
        $$SELECT safe_refresh_materialized_view('high_value_targets')$$
      );
      """

      # Timezone activity patterns - every 4 hours at minute 0
      execute """
      SELECT cron.schedule(
        'refresh_timezone_activity_patterns',
        '0 */4 * * *',
        $$SELECT safe_refresh_materialized_view('timezone_activity_patterns')$$
      );
      """

      # Character activity summary - every 2 hours at minute 10 (if exists)
      execute """
      SELECT cron.schedule(
        'refresh_character_activity_summary',
        '10 */2 * * *',
        $$SELECT safe_refresh_materialized_view('character_activity_summary')$$
      );
      """

      # System activity heatmap - every 2 hours at minute 20 (if exists)
      execute """
      SELECT cron.schedule(
        'refresh_system_activity_heatmap',
        '20 */2 * * *',
        $$SELECT safe_refresh_materialized_view('system_activity_heatmap')$$
      );
      """

      # Log scheduled jobs
      execute """
      DO $$
      BEGIN
        RAISE NOTICE 'Materialized view refresh jobs scheduled successfully';
      END $$;
      """
    else
      # Log that pg_cron is not available
      execute """
      DO $$
      BEGIN
        RAISE NOTICE 'pg_cron extension not available - materialized view refresh jobs not scheduled';
        RAISE NOTICE 'Views will need to be refreshed manually or via application code';
      END $$;
      """
    end
  end

  def down do
    pg_cron_available = check_pg_cron_available()

    if pg_cron_available do
      # Remove scheduled jobs (only if they exist)
      execute """
      DO $$
      BEGIN
        IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'refresh_ship_type_usage') THEN
          PERFORM cron.unschedule('refresh_ship_type_usage');
        END IF;
      END $$;
      """

      execute """
      DO $$
      BEGIN
        IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'refresh_fleet_composition_summary') THEN
          PERFORM cron.unschedule('refresh_fleet_composition_summary');
        END IF;
      END $$;
      """

      execute """
      DO $$
      BEGIN
        IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'refresh_high_value_targets') THEN
          PERFORM cron.unschedule('refresh_high_value_targets');
        END IF;
      END $$;
      """

      execute """
      DO $$
      BEGIN
        IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'refresh_timezone_activity_patterns') THEN
          PERFORM cron.unschedule('refresh_timezone_activity_patterns');
        END IF;
      END $$;
      """

      execute """
      DO $$
      BEGIN
        IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'refresh_character_activity_summary') THEN
          PERFORM cron.unschedule('refresh_character_activity_summary');
        END IF;
      END $$;
      """

      execute """
      DO $$
      BEGIN
        IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'refresh_system_activity_heatmap') THEN
          PERFORM cron.unschedule('refresh_system_activity_heatmap');
        END IF;
      END $$;
      """
    end

    # Drop helper function
    execute "DROP FUNCTION IF EXISTS safe_refresh_materialized_view(text)"
  end

  # Helper to check if pg_cron is available
  defp check_pg_cron_available do
    # This will be evaluated at migration runtime
    # We use execute and check for the extension
    case Ecto.Adapters.SQL.query(
           EveDmv.Repo,
           "SELECT 1 FROM pg_extension WHERE extname = 'pg_cron'",
           []
         ) do
      {:ok, %{num_rows: 1}} -> true
      _ -> false
    end
  rescue
    _ -> false
  end
end

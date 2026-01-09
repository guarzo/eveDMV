defmodule EveDmv.Repo.Migrations.ConsolidateMaterializedViewRefresh do
  @moduledoc """
  Consolidates materialized view refresh to pg_cron only.

  This migration:
  1. Updates pg_cron schedules to be less aggressive (off-peak hours)
  2. Adds advisory locks to prevent concurrent refresh attempts
  3. Staggers refresh times to avoid pool exhaustion

  See docs/PERFORMANCE_REMEDIATION_PLAN.md Track C for details.

  Updated Schedule (all times UTC):
  - character_activity_summary: 2 AM daily (heavy query, off-peak only)
  - system_activity_heatmap: Every 6 hours (medium weight)
  - fleet_composition_summary: 2:30 AM daily (staggered from above)
  - high_value_targets: Every 12 hours (light weight)
  - timezone_activity_patterns: 3 AM daily (heavy, off-peak)
  - ship_type_usage: 4 AM daily (staggered)
  """

  use Ecto.Migration

  def up do
    pg_cron_available = check_pg_cron_available()

    if pg_cron_available do
      # Update safe_refresh_materialized_view function to use advisory locks
      execute """
      CREATE OR REPLACE FUNCTION safe_refresh_materialized_view(view_name text)
      RETURNS void AS $$
      DECLARE
        lock_id bigint;
        start_time timestamp;
        end_time timestamp;
        duration_ms integer;
      BEGIN
        -- Generate consistent lock ID from view name
        lock_id := hashtext(view_name);

        -- Try to acquire advisory lock (non-blocking)
        IF NOT pg_try_advisory_lock(lock_id) THEN
          RAISE NOTICE 'Skipping refresh of % - another refresh in progress', view_name;
          RETURN;
        END IF;

        BEGIN
          start_time := clock_timestamp();

          -- Check if view exists before refreshing
          IF EXISTS (
            SELECT 1 FROM pg_matviews WHERE matviewname = view_name
          ) THEN
            -- Set session-level work_mem for large sorts
            SET LOCAL work_mem = '32MB';

            -- Attempt concurrent refresh first
            BEGIN
              EXECUTE 'REFRESH MATERIALIZED VIEW CONCURRENTLY ' || quote_ident(view_name);
            EXCEPTION WHEN OTHERS THEN
              -- Fall back to non-concurrent refresh if concurrent fails
              EXECUTE 'REFRESH MATERIALIZED VIEW ' || quote_ident(view_name);
            END;

            end_time := clock_timestamp();
            duration_ms := EXTRACT(MILLISECONDS FROM (end_time - start_time))::integer;

            -- Update tracking table
            INSERT INTO view_refresh_tracking (view_name, last_refresh, last_full_refresh_time, refresh_duration_ms, refresh_count, inserted_at, updated_at)
            VALUES (view_name, NOW(), NOW(), duration_ms, 1, NOW(), NOW())
            ON CONFLICT (view_name)
            DO UPDATE SET
              last_refresh = NOW(),
              last_full_refresh_time = NOW(),
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

        -- Release lock
        PERFORM pg_advisory_unlock(lock_id);
      END;
      $$ LANGUAGE plpgsql;
      """

      # Unschedule all existing jobs first to avoid duplicates
      unschedule_existing_jobs()

      # Schedule updated jobs with less aggressive intervals
      # Only schedule if the materialized view exists

      # Character activity summary - 2 AM daily (heavy query, off-peak only)
      if view_exists?("character_activity_summary") do
        execute """
        SELECT cron.schedule(
          'refresh_character_activity_summary',
          '0 2 * * *',
          $$SELECT safe_refresh_materialized_view('character_activity_summary')$$
        );
        """
      end

      # System activity heatmap - every 6 hours (medium weight)
      if view_exists?("system_activity_heatmap") do
        execute """
        SELECT cron.schedule(
          'refresh_system_activity_heatmap',
          '0 */6 * * *',
          $$SELECT safe_refresh_materialized_view('system_activity_heatmap')$$
        );
        """
      end

      # Fleet composition summary - 2:30 AM daily (staggered from above)
      if view_exists?("fleet_composition_summary") do
        execute """
        SELECT cron.schedule(
          'refresh_fleet_composition_summary',
          '30 2 * * *',
          $$SELECT safe_refresh_materialized_view('fleet_composition_summary')$$
        );
        """
      end

      # High value targets - every 12 hours (light weight)
      if view_exists?("high_value_targets") do
        execute """
        SELECT cron.schedule(
          'refresh_high_value_targets',
          '0 */12 * * *',
          $$SELECT safe_refresh_materialized_view('high_value_targets')$$
        );
        """
      end

      # Timezone activity patterns - 3 AM daily (heavy, off-peak)
      if view_exists?("timezone_activity_patterns") do
        execute """
        SELECT cron.schedule(
          'refresh_timezone_activity_patterns',
          '0 3 * * *',
          $$SELECT safe_refresh_materialized_view('timezone_activity_patterns')$$
        );
        """
      end

      # Ship type usage - 4 AM daily (staggered)
      if view_exists?("ship_type_usage") do
        execute """
        SELECT cron.schedule(
          'refresh_ship_type_usage',
          '0 4 * * *',
          $$SELECT safe_refresh_materialized_view('ship_type_usage')$$
        );
        """
      end

      execute """
      DO $$
      BEGIN
        RAISE NOTICE 'Materialized view refresh jobs rescheduled with advisory locks';
        RAISE NOTICE 'Schedule: character_activity_summary at 2 AM, system_activity_heatmap every 6h';
        RAISE NOTICE 'Schedule: fleet_composition_summary at 2:30 AM, high_value_targets every 12h';
        RAISE NOTICE 'Schedule: timezone_activity_patterns at 3 AM, ship_type_usage at 4 AM';
      END $$;
      """
    else
      execute """
      DO $$
      BEGIN
        RAISE NOTICE 'pg_cron not available - materialized view consolidation skipped';
      END $$;
      """
    end
  end

  def down do
    pg_cron_available = check_pg_cron_available()

    if pg_cron_available do
      # Revert to original schedules from migration 20251218000002
      unschedule_existing_jobs()

      # Restore original more frequent schedules
      # Only schedule if the materialized view exists
      if view_exists?("ship_type_usage") do
        execute """
        SELECT cron.schedule(
          'refresh_ship_type_usage',
          '15 */4 * * *',
          $$SELECT safe_refresh_materialized_view('ship_type_usage')$$
        );
        """
      end

      if view_exists?("fleet_composition_summary") do
        execute """
        SELECT cron.schedule(
          'refresh_fleet_composition_summary',
          '30 */2 * * *',
          $$SELECT safe_refresh_materialized_view('fleet_composition_summary')$$
        );
        """
      end

      if view_exists?("high_value_targets") do
        execute """
        SELECT cron.schedule(
          'refresh_high_value_targets',
          '45 */6 * * *',
          $$SELECT safe_refresh_materialized_view('high_value_targets')$$
        );
        """
      end

      if view_exists?("timezone_activity_patterns") do
        execute """
        SELECT cron.schedule(
          'refresh_timezone_activity_patterns',
          '0 */4 * * *',
          $$SELECT safe_refresh_materialized_view('timezone_activity_patterns')$$
        );
        """
      end

      if view_exists?("character_activity_summary") do
        execute """
        SELECT cron.schedule(
          'refresh_character_activity_summary',
          '10 */2 * * *',
          $$SELECT safe_refresh_materialized_view('character_activity_summary')$$
        );
        """
      end

      if view_exists?("system_activity_heatmap") do
        execute """
        SELECT cron.schedule(
          'refresh_system_activity_heatmap',
          '20 */2 * * *',
          $$SELECT safe_refresh_materialized_view('system_activity_heatmap')$$
        );
        """
      end

      # Restore original function without advisory locks
      execute """
      CREATE OR REPLACE FUNCTION safe_refresh_materialized_view(view_name text)
      RETURNS void AS $$
      DECLARE
        start_time timestamp;
        end_time timestamp;
        duration_ms integer;
      BEGIN
        start_time := clock_timestamp();

        IF EXISTS (
          SELECT 1 FROM pg_matviews WHERE matviewname = view_name
        ) THEN
          BEGIN
            EXECUTE 'REFRESH MATERIALIZED VIEW CONCURRENTLY ' || quote_ident(view_name);
          EXCEPTION WHEN OTHERS THEN
            EXECUTE 'REFRESH MATERIALIZED VIEW ' || quote_ident(view_name);
          END;

          end_time := clock_timestamp();
          duration_ms := EXTRACT(MILLISECONDS FROM (end_time - start_time))::integer;

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
    end
  end

  defp unschedule_existing_jobs do
    job_names = [
      "refresh_ship_type_usage",
      "refresh_fleet_composition_summary",
      "refresh_high_value_targets",
      "refresh_timezone_activity_patterns",
      "refresh_character_activity_summary",
      "refresh_system_activity_heatmap"
    ]

    Enum.each(job_names, fn job_name ->
      # Use parameterized query to avoid SQL injection risk pattern
      Ecto.Adapters.SQL.query(
        EveDmv.Repo,
        """
        SELECT CASE WHEN EXISTS (SELECT 1 FROM cron.job WHERE jobname = $1)
          THEN cron.unschedule($1)
          ELSE NULL
        END
        """,
        [job_name]
      )
    end)
  end

  defp check_pg_cron_available do
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

  defp view_exists?(view_name) do
    case Ecto.Adapters.SQL.query(
           EveDmv.Repo,
           "SELECT 1 FROM pg_matviews WHERE matviewname = $1",
           [view_name]
         ) do
      {:ok, %{num_rows: 1}} -> true
      _ -> false
    end
  rescue
    _ -> false
  end
end
